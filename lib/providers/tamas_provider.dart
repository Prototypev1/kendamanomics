import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:kendamanomics_mobile/mixins/logger_mixin.dart';
import 'package:kendamanomics_mobile/models/player_tama.dart';
import 'package:kendamanomics_mobile/models/premium_tamas_group.dart';
import 'package:kendamanomics_mobile/models/tamas_group.dart';
import 'package:kendamanomics_mobile/services/appearance_service.dart';
import 'package:kendamanomics_mobile/services/auth_service.dart';
import 'package:kendamanomics_mobile/services/in_app_purchase_service.dart';
import 'package:kendamanomics_mobile/services/persistent_data_service.dart';
import 'package:kendamanomics_mobile/services/purchase_service.dart';
import 'package:kendamanomics_mobile/services/tama_service.dart';
import 'package:kendamanomics_mobile/services/tamas_group_service.dart';
import 'package:kiwi/kiwi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum TamasProviderState { loading, none, success, errorFetchingProgress }

class TamasProvider extends ChangeNotifier with LoggerMixin {
  final _persistentDataService = KiwiContainer().resolve<PersistentDataService>();
  final _purchaseService = KiwiContainer().resolve<PurchaseService>();
  final _inAppPurchaseService = KiwiContainer().resolve<InAppPurchaseService>();
  final _tamasService = KiwiContainer().resolve<TamaService>();
  final _tamaGroupService = KiwiContainer().resolve<TamasGroupService>();
  final _appearanceService = KiwiContainer().resolve<AppearanceService>();

  final _tamasGroups = <TamasGroup>[];
  final _progressData = <String, int>{};

  final _purchasedGroupIds = <String>[];
  PageController? _controller;
  int _initialPageIndex = 0;
  int _arrowPageIndex = 0;
  TamasProviderState _state = TamasProviderState.loading;
  bool _isDisposed = false;
  bool _purchaseInProgress = false;

  List<TamasGroup> get tamasGroup => _tamasGroups;
  int get currentPage {
    if (_controller != null && _controller!.hasClients) {
      if (_controller!.page != null) return _controller!.page!.round();
    }

    return _initialPageIndex;
  }

  PageController? get controller => _controller;
  TamasProviderState get state => _state;
  int get initialPageIndex => _initialPageIndex;
  int get arrowPageIndex => _arrowPageIndex;
  bool get purchaseInProgress => _purchaseInProgress;

  TamasProvider({String? initialGroupID}) {
    _populateGroups(initialGroupID);
    _initPurchases();
    _updatePlayerTamasData();
    _fetchTamaGroups();
    _fetchTamas();
    _fetchPurchasedGroupIds();
  }

  void _listenToInAppPurchaseService(InAppPurchaseEvents event, dynamic params) {
    switch (event) {
      case InAppPurchaseEvents.purchased:
        _purchasedGroupIds.add(params.first);
        break;
      case InAppPurchaseEvents.startedPurchase:
        _purchaseInProgress = true;
      case InAppPurchaseEvents.failed:
        _purchaseInProgress = false;
    }
    notifyListeners();
  }

  void pageUpdated() {
    _fillCurrentPageTamas();
    _checkBackgroundColor();
    notifyListeners();
  }

  void _populateGroups(String? initialGroupID) {
    _tamasGroups.clear();
    final groupData = _persistentDataService.readTamaGroups();
    _tamasGroups.addAll(groupData.item1);
    if (initialGroupID != null) {
      _initialPageIndex = _tamasGroups.indexWhere((element) => element.id == initialGroupID);
    } else {
      _initialPageIndex = groupData.item2;
    }
    _arrowPageIndex = groupData.item2;
    _controller = PageController(initialPage: _initialPageIndex);
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      _checkBackgroundColor();
    });
  }

  void _updatePlayerTamasData({int retry = 2}) async {
    logI('fetching tama progress data for player ${KiwiContainer().resolve<AuthService>().player?.id}');
    try {
      _progressData.clear();
      final ret = await _tamasService.getTamasProgress();
      _progressData.addAll(ret);

      _fillCurrentPageTamas(useInitialPage: true);

      // in compute fill the tricks for other tamas?
      _state = TamasProviderState.success;
      logI('tama progress data successfully fetched and filled for page ${_tamasGroups[currentPage].name}');
      _notify();
    } on PostgrestException catch (e) {
      logE('error updating tamas data: ${e.toString()}');
      if (retry > 0) {
        logI('retrying: attempts left: $retry');
        return _updatePlayerTamasData(retry: --retry);
      }

      _state = TamasProviderState.errorFetchingProgress;
      _notify();
    }
  }

  /// we added useInitialPage because when calling this function while the ui still hasn't built, we get an Assertion error -
  /// we tried to use the PageController before a PageView was built with it. this way we force the function to use the
  /// _initialPage field which is set properly before this function is called
  void _fillCurrentPageTamas({bool useInitialPage = false}) {
    final page = useInitialPage ? _initialPageIndex : currentPage;
    for (int i = 0; i < _tamasGroups[page].playerTamas.length; i++) {
      final playerTama = _tamasGroups[page].playerTamas[i];
      final tamaID = playerTama.tama.id;
      if (_progressData.containsKey(tamaID)) {
        _tamasGroups[page].playerTamas[i] = playerTama.copyWith(
          completedTricks: _progressData[tamaID],
          badgeType: _progressData[tamaID] == playerTama.tama.numOfTricks ? BadgeType.completedTama : BadgeType.none,
        );
      } else {
        _tamasGroups[page].playerTamas[i] = playerTama.copyWith(completedTricks: 0);
      }
    }

    logI(
      'filled tamas for current pin: ${_tamasGroups[page].name}, number of tamas is ${_tamasGroups[page].playerTamas.length}',
    );
  }

  void _fetchTamas({int retry = 2}) async {
    try {
      final newTamas = await _tamasService.fetchTamas();
      if (newTamas == null) return;
      _persistentDataService.updateTamas(tamas: newTamas);
    } on PostgrestException catch (e) {
      logE('error fetching tamas: ${e.toString()}');
      if (retry > 0) {
        logI('retrying: attempts left: $retry');
        return _fetchTamas(retry: --retry);
      }
    }
  }

  // this should be called if we know there are differing tamas
  void _fetchTamaGroups({int retry = 2}) async {
    try {
      final newTamasGroups = await _tamaGroupService.fetchTamaGroups();
      if (newTamasGroups == null) return;

      _persistentDataService.updateTamasGroups(tamasGroups: newTamasGroups);
    } on PostgrestException catch (e) {
      logE('error fetching tamas groups: ${e.toString()}');
      if (retry > 0) {
        logI('retrying: attempts left: $retry');
        return _fetchTamaGroups(retry: --retry);
      }

      _state = TamasProviderState.errorFetchingProgress;
      _notify();
    }
  }

  void _fetchPurchasedGroupIds() async {
    try {
      final data = await _purchaseService.fetchPurchasedGroupsData();
      _purchasedGroupIds.addAll(data);

      /// _initialPage is always the first FREE tama group. when swiping left we swipe into premium tamas
      if (currentPage < _initialPageIndex) {
        notifyListeners();
      }
      logI('purchased group ids fetched successfully');

      _persistentDataService.updatePurchasedGroups(_purchasedGroupIds);
      _inAppPurchaseService.queryProducts();
    } catch (e) {
      logE('error fetching purchased group ids');
    }
  }

  bool shouldShowPromotionOverlay(String groupID) {
    final currentGroups = _tamasGroups.where((element) => element.id == groupID).toList();
    if (currentGroups.isEmpty) return false;
    final currentGroup = currentGroups.first;
    if (currentGroup is! PremiumTamasGroup) return false;
    if (_purchasedGroupIds.contains(currentGroup.id)) return false;
    return true;
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  void _checkBackgroundColor() {
    final currentGroup = _tamasGroups[currentPage];
    if (currentGroup is PremiumTamasGroup) {
      _appearanceService.notifyTamaPageSwiped(currentGroup.backgroundColor, false);
    } else {
      _appearanceService.notifyTamaPageSwiped(null, false);
    }
  }

  void purchaseGroup(String? id) async {
    if (id == null) return;
    if (!_inAppPurchaseService.available) {
      logE('error purchasing group: purchasing unavailable on device');
      return;
    }

    try {
      await _inAppPurchaseService.purchasePremiumTamasGroup(premiumTamasGroupID: id);
    } catch (e) {
      logE('error purchasing premium group, ${e.toString()}');
    }
  }

  void goToNextPage() {
    _controller?.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
  }

  void goToPreviousPage() {
    _controller?.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeIn);
  }

  void _initPurchases() {
    _inAppPurchaseService.init();
    _inAppPurchaseService.subscribe(_listenToInAppPurchaseService);
  }

  void _disposePurchases() {
    _inAppPurchaseService.unsubscribe(_listenToInAppPurchaseService);
    _inAppPurchaseService.dispose();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _disposePurchases();
    _appearanceService.notifyTamaPageSwiped(null, true);
    super.dispose();
  }

  @override
  String get className => 'TamasProvider';
}
