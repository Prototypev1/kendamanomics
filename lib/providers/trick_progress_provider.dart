import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:kendamanomics_mobile/mixins/logger_mixin.dart';
import 'package:kendamanomics_mobile/models/submission.dart';
import 'package:kendamanomics_mobile/models/trick.dart';
import 'package:kendamanomics_mobile/services/auth_service.dart';
import 'package:kendamanomics_mobile/services/submission_service.dart';
import 'package:kendamanomics_mobile/services/trick_service.dart';
import 'package:kiwi/kiwi.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tuple/tuple.dart';

enum TrickProgressProviderState {
  none,
  loading,
  uploadingSubmission,
  uploadingVideoExceeds40mb,
  uploadingVideoMoreThan5s,
  revokingSubmission,
  errorVideoTooLarge,
  errorUnknownVideoUpload,
  errorSubmissionCreation,
  success,
}

class TrickProgressProvider extends ChangeNotifier with LoggerMixin, WidgetsBindingObserver {
  final _submissionService = KiwiContainer().resolve<SubmissionService>();
  final _authService = KiwiContainer().resolve<AuthService>();
  final _trickService = KiwiContainer().resolve<TrickService>();
  final _deviceInfo = DeviceInfoPlugin();
  final Submission submission;
  final Trick? trick;
  bool _fetchedFirstLaced = false;
  TrickProgressProviderState _state = TrickProgressProviderState.loading;
  bool _hasLogs = false;
  bool _settingsOpened = false;
  Timer? _timer;
  Permission _permission = Permission.photos;
  PermissionStatus _permissionStatus = PermissionStatus.denied;
  String? _firstLacedPlayer;
  int? _totalLacedCount;
  int? _trickPoints;

  TrickProgressProviderState get state => _state;
  bool get isUploading => [
        TrickProgressProviderState.uploadingSubmission,
        TrickProgressProviderState.uploadingVideoExceeds40mb,
        TrickProgressProviderState.uploadingVideoMoreThan5s,
      ].contains(_state);
  bool get hasLogs => _hasLogs;
  bool get getUploadInstructionsDialogShown => _submissionService.uploadInstructionsDialogShown;
  bool get fetchedFirstLaced => _fetchedFirstLaced;
  String get uploadInstructionsMD => _submissionService.uploadInstructionsMD;
  PermissionStatus get permissionStatus => _permissionStatus;
  String? get firstLacedPlayer => _firstLacedPlayer;
  int? get totalLacedCount => _totalLacedCount;
  int? get trickPoints => _trickPoints;

  TrickProgressProvider({this.trick, required this.submission}) {
    _submissionService.subscribe(_listenToSubmissionService);
    _setPermission();
    _updatePermissionStatus();
    WidgetsBinding.instance.addObserver(this);
    _getTrickStats();
  }

  void _getTrickStats() {
    _fetchFirstLacedPlayer(trickId: trick!.id!);
    _fetchTotalLacedCount(trickId: trick!.id!);
    _fetchTrickPoints(trickId: trick!.id!);
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
      case AppLifecycleState.resumed:
        await _updatePermissionStatus();
        if ([PermissionStatus.granted, PermissionStatus.limited].contains(_permissionStatus) && _settingsOpened) {
          await uploadTrickSubmission();
        }

        _settingsOpened = false;
        break;
    }

    super.didChangeAppLifecycleState(state);
  }

  Future<void> _updatePermissionStatus() async {
    _permissionStatus = await _permission.status;
  }

  void uploadInstructionsDialogShown() => _submissionService.uploadInstructionsDialogShown = true;

  void _listenToSubmissionService(SubmissionServiceEvent event, dynamic params) {
    switch (event) {
      case SubmissionServiceEvent.submissionLogsFetched:
        if (params.first == true) {
          _hasLogs = true;
          notifyListeners();
        }
        break;
      case SubmissionServiceEvent.submissionStatusChanged:
        break;
    }
  }

  Future<void> resolvePermissions() async {
    if (_permissionStatus == PermissionStatus.granted) return;
    _permissionStatus = await _permission.status;
    if (_permissionStatus == PermissionStatus.denied) {
      _permissionStatus = await _permission.request();
    }
  }

  // changes status to revoked
  // deletes the video from supabase
  Future<void> revokeSubmission() async {
    logI('revoking submission ${submission.submissionID}');
    _state = TrickProgressProviderState.revokingSubmission;
    notifyListeners();
    if (submission.submissionID == null || submission.status == SubmissionStatus.waitingForSubmission) {
      _state = TrickProgressProviderState.none;
      notifyListeners();
      return;
    }
    final successfulVideoDelete = await _removeSubmissionVideoFromStorage();

    if (!successfulVideoDelete) {
      _state = TrickProgressProviderState.none;
      notifyListeners();
      return;
    }

    final successfulRevoke = await _updateSubmissionData(status: SubmissionStatus.revoked);

    if (successfulRevoke) {
      _state = TrickProgressProviderState.none;
      submission.resetSubmission();
      _submissionService.notifyRebuildParentScreen(submission);
    }
  }

  Future<void> uploadTrickSubmission() async {
    if (trick?.id == null || submission.status != SubmissionStatus.waitingForSubmission) return;
    logI('creating new submission');

    _state = TrickProgressProviderState.uploadingSubmission;
    final videoFile = await _selectVideo();
    if (videoFile == null) {
      _state = TrickProgressProviderState.none;
      return;
    }

    await _checkVideoSize(videoFile);

    // if video with given name already exists, it means that the user didn't revoke the submission, hence show snackbar
    int timerCounter = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      timerCounter++;
      if (timerCounter == 4) {
        _state = TrickProgressProviderState.uploadingVideoMoreThan5s;
        notifyListeners();
        _timer?.cancel();
      }
    });
    final response = await _uploadVideoToStorage(videoFile);
    _timer?.cancel();
    final path = response.item2;
    if (path == null) {
      final code = response.item1;
      if (code == '413') {
        _state = TrickProgressProviderState.errorVideoTooLarge;
      } else {
        _state = TrickProgressProviderState.errorUnknownVideoUpload;
      }

      notifyListeners();
      return;
    }

    final id = await _createSubmission(videoUrl: path);
    if (id == null) {
      _state = TrickProgressProviderState.errorSubmissionCreation;
      notifyListeners();
      return;
    }

    submission.submissionUpdated(id: id, newVideoUrl: path, newStatus: SubmissionStatus.inReview);
    _submissionService.notifyRebuildParentScreen(submission);
    _state = TrickProgressProviderState.success;
  }

  Future<File?> _selectVideo() async {
    logI('selecting video');

    final picker = ImagePicker();
    final videoXFile = await picker.pickVideo(source: ImageSource.gallery);
    if (videoXFile != null) {
      return File(videoXFile.path);
    }

    return null;
  }

  Future<void> _checkVideoSize(File videoFile) async {
    final videoSize = await videoFile.length();
    logI('video size is $videoSize');
    if (videoSize / 1000000 > 40) {
      _state = TrickProgressProviderState.uploadingVideoExceeds40mb;
    }

    logI('after checking size, state is $_state');
    notifyListeners();
  }

  Future<Tuple2<String, String?>> _uploadVideoToStorage(File videoFile) async {
    logI('uploading video to storage');
    try {
      final path = await _submissionService.uploadVideoFile(videoFile: videoFile, trickName: trick!.name!);
      logI('video uploaded to storage successfully, path: $path');
      return Tuple2('200', path);
    } on StorageException catch (e) {
      logE('error uploading video to storage: ${e.statusCode} - ${e.message}');
      return Tuple2(e.statusCode ?? '400', null);
    }
  }

  Future<bool> _removeSubmissionVideoFromStorage() async {
    logI('deleting submission video from storage, id: ${submission.submissionID}, url: ${submission.videoUrl}');
    try {
      await _submissionService.removeVideoFromStorage(videoName: submission.videoUrl!);
      logI('video successfully deleted');
      return true;
    } on StorageException catch (e) {
      logE('error deleting video from storage: ${e.statusCode} - ${e.message}');
      return false;
    }
  }

  Future<String?> _createSubmission({required String videoUrl}) async {
    logI('creating submission');
    try {
      final submissionID = await _submissionService.createSubmission(
        playerID: _authService.player!.id,
        trickID: trick!.id!,
        tamaID: trick!.tamaID!,
        videoUrl: videoUrl,
      );

      logI('submission created succcessfully, id: $submissionID');
      return submissionID;
    } on PostgrestException catch (e) {
      logE('error creating submission: ${e.message}');
      return null;
    }
  }

  Future<bool> _updateSubmissionData({required SubmissionStatus status}) async {
    logI('updating submission data, id: ${submission.submissionID}, status: $status');
    try {
      await _submissionService.updateSubmissionData(submissionID: submission.submissionID!, status: status);
      logI('status successfully udpated to $status');
      return true;
    } on PostgrestException catch (e) {
      logE('error revoking submission: ${e.message}');
      return false;
    }
  }

  Future<void> _fetchFirstLacedPlayer({required String trickId}) async {
    logI('fetching first laced player for the trick id: $trickId');
    try {
      final trickStat = await _trickService.getFirstLacedPlayer(trickId: trickId);
      if (trickStat != null) {
        _firstLacedPlayer = '${trickStat.firstLacedPlayerFirstname ?? ''} ${trickStat.firstLacedPlayerLastname ?? ''}';
      } else {
        logE('error fetching first laced player data');
      }

      _fetchedFirstLaced = true;
      notifyListeners();
    } catch (e) {
      logE('error occurred while fetching first player laced: $e');
    }
  }

  Future<void> _fetchTotalLacedCount({required String trickId}) async {
    logI('fetching total laced player count for the trick id: $trickId');
    try {
      final trickStat = await _trickService.getTotalLacedCountForTrick(trickId: trickId);
      if (trickStat != null) {
        _totalLacedCount = trickStat.totalLacedCount;
        notifyListeners();
      } else {
        logE('error fetching total laced count');
      }
    } catch (e) {
      logE('error occurred while fetching total laced count: $e');
    }
  }

  Future<void> _fetchTrickPoints({required String trickId}) async {
    logI('fetching trick points for the trick id: $trickId');
    try {
      final trickStat = await _trickService.getTrickPoints(trickId: trickId);
      if (trickStat != null) {
        _trickPoints = trickStat.trickPoints;
        notifyListeners();
      } else {
        logE('eror fetching trick points.');
      }
    } catch (e) {
      logE('error occurred while fetching trick points: $e');
    }
  }

  void _setPermission() async {
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 31) {
        _permission = Permission.storage;
      } else {
        _permission = Permission.photos;
      }
    } else {
      _permission = Permission.photos;
    }
  }

  void openedSettings() {
    _settingsOpened = true;
  }

  @override
  void dispose() {
    _submissionService.unsubscribe(_listenToSubmissionService);
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  String get className => 'TrickProgressProvider';
}
