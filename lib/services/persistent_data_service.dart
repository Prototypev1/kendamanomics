import 'dart:convert';
import 'dart:io';

import 'package:app_group_directory/app_group_directory.dart';
import 'package:flutter/services.dart';
import 'package:kendamanomics_mobile/constants.dart';
import 'package:kendamanomics_mobile/extensions/color_extension.dart';
import 'package:kendamanomics_mobile/mixins/logger_mixin.dart';
import 'package:kendamanomics_mobile/models/player_tama.dart';
import 'package:kendamanomics_mobile/models/premium_tamas_group.dart';
import 'package:kendamanomics_mobile/models/tama.dart';
import 'package:kendamanomics_mobile/models/tama_trick_progress.dart';
import 'package:kendamanomics_mobile/models/tamas_group.dart';
import 'package:kendamanomics_mobile/models/trick.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tuple/tuple.dart';

class PersistentDataService with LoggerMixin {
  static const _localDataJsonName = 'localDataJson';
  static const _dataTableFileName = 'data_table';
  static const _tamasFileName = 'tamas';
  static const _groupsFileName = 'groups';
  static const _premiumTamaGroups = 'premium_tama_groups';
  static const _tamaTricksRelationFileName = 'tama_tricks_relation';
  static const _tricksFileName = 'tricks';

  late final Directory appGroupDir;
  String? tamasGroupValue;
  final _premiumTamasGroup = <PremiumTamasGroup>[];
  final _tamaGroups = <TamasGroup>[];
  String? tamaValue;
  final _tamas = <String, Tama>{};
  String? trickValue;
  final _tricks = <Trick>[];
  final _tamaTricksRelation = <Map<String, dynamic>>[];
  Map<String, dynamic> _localDataJson = {};
  final _premiumTamasGroupIDs = <String>{};
  final _purchasedPremiumGroupIDs = <String>{};
  bool _loaded = false;

  Map<String, Tama> get tamas => _tamas;
  Set<String> get premiumTamasGroupIDs => _premiumTamasGroupIDs;
  Set<String> get purchasedPremiumGroupIDs => _purchasedPremiumGroupIDs;

  // order is important: first load the connection between tricks and tamas, then load tamas, then load tricks and upon
  // creation add them to their tama
  Future<void> init() async {
    if (_loaded) return;
    await _updateAppGroupDir();

    final shouldReadFromAssets = await _readCachedData();

    if (shouldReadFromAssets) {
      logI('reading data from assets');
      await _loadDataTable();
      await _loadTamaTricksRelation();
      await _loadTamas();
      await _loadTricks();
      await _loadGroups();
      await _loadPremiumGroups();

      writeData();
    }
    _loaded = true;
  }

  Tuple2<List<TamasGroup>, int> readTamaGroups() {
    final items = <TamasGroup>[];
    items.addAll(_premiumTamasGroup.reversed);
    final regularTamaFirstIndex = items.length;
    items.addAll(_tamaGroups);
    return Tuple2(items, regularTamaFirstIndex);
  }

  List<TamaTrickProgress> filterTricksByTamaId(String? tamaId) {
    if (tamaId == null || tamaId.isEmpty) {
      return [];
    }
    return _tamas[tamaId]!.tricks ?? [];
  }

  Trick? getTrickByID(String? trickID) {
    if (trickID == null || trickID.isEmpty) {
      return null;
    }

    final trick = _tricks.where((element) => element.id == trickID);
    if (trick.isEmpty) return null;
    return trick.first;
  }

  String? fetchTamaNameById(String? tamaId) {
    if (tamaId == null || tamaId.isEmpty) {
      return null;
    }
    final tama = _tamas[tamaId];
    return tama?.name;
  }

  String? fetchTamaGroupName(String? tamaId) {
    if (tamaId == null || tamaId.isEmpty) {
      return null;
    }
    final tama = _tamas[tamaId];
    if (tama != null) {
      final tamaGroups = _tamaGroups.where((element) => element.id == tama.tamasGroupID);
      if (tamaGroups.isEmpty) {
        final premTamaGroup = _premiumTamasGroup.firstWhere((element) => element.id == tama.tamasGroupID);
        return premTamaGroup.name;
      }

      return tamaGroups.first.name;
    }
    return null;
  }

  Future<void> _updateAppGroupDir() async {
    if (Platform.isIOS) {
      logI('setting iOS app group to $kAppleAppGroup');
      Directory? directory = await AppGroupDirectory.getAppGroupDirectory(kAppleAppGroup);
      if (directory != null) {
        appGroupDir = directory;
      } else {
        appGroupDir = await getApplicationDocumentsDirectory();
      }
    } else {
      appGroupDir = await getApplicationDocumentsDirectory();
    }
  }

  void updateTamas({required List<Tama> tamas}) {
    _tamas.clear();

    final groupCopy = List<TamasGroup>.from([..._tamaGroups, ..._premiumTamasGroup]);

    for (final group in _tamaGroups) {
      group.playerTamas.clear();
    }

    for (final group in _premiumTamasGroup) {
      group.playerTamas.clear();
    }

    for (final tama in tamas) {
      if (tama.id == null) continue;

      _tamas[tama.id!] = tama;

      int numberOfCompleted = 0;
      final tamaGroup = groupCopy.where((element) => element.id == tama.tamasGroupID);
      if (tamaGroup.isNotEmpty) {
        final group = tamaGroup.first;
        final previousTama = group.playerTamas.where((element) => element.tama.id == tama.id);
        if (previousTama.isNotEmpty) {
          numberOfCompleted = previousTama.first.completedTricks ?? 0;
        }
      }

      final tamaTricks = _tricks.where((element) => element.tamaID == tama.id);
      for (final trick in tamaTricks) {
        final position = _tamaTricksRelation
            .where((element) => element['tama_id'] == tama.id && element['trick_id'] == trick.id)
            .singleOrNull;

        if (position != null) {
          tama.tricks?.add(TamaTrickProgress.fromTrick(trick: trick));
        }
      }

      final tamaGroupsData = _tamaGroups.where((element) => element.id == tama.tamasGroupID);
      if (tamaGroupsData.isNotEmpty) {
        tamaGroupsData.first.addTama(tama: tama, numOfCompletedTricks: numberOfCompleted);
      } else {
        final premiumTamaGroupsData = _premiumTamasGroup.where((element) => element.id == tama.tamasGroupID);
        if (premiumTamaGroupsData.isNotEmpty) {
          premiumTamaGroupsData.first.addTama(tama: tama, numOfCompletedTricks: numberOfCompleted);
        }
      }
    }

    writeData();
  }

  void updateTricks({required List<Trick> newTricks, required String tamaID}) {
    _tricks.removeWhere((element) => element.tamaID == tamaID);
    _tricks.addAll(newTricks);
    _tamas[tamaID]?.tricks?.clear();

    for (int i = 0; i < newTricks.length; i++) {
      final trick = newTricks[i];
      if (_tamas.containsKey(trick.tamaID)) {
        _tamas[trick.tamaID]!.tricks!.add(TamaTrickProgress.fromTrick(trick: trick));
        _tamaTricksRelation.add({
          'tama_id': trick.tamaID,
          'trick_id': trick.id,
          'trick_points': 1,
          'trick_order': i,
        });
      }
    }

    // TODO refactor code, extract to func
    final tamaGroupID = _tamas[tamaID]!.tamasGroupID;
    final groupIndex = _tamaGroups.indexWhere((element) => element.id == tamaGroupID);
    final tamas = _tamas.values;
    if (groupIndex != -1) {
      _tamaGroups[groupIndex].playerTamas.clear();
      final tamasForGroup = tamas.where((element) => element.tamasGroupID == tamaGroupID).toList();
      for (final tama in tamasForGroup) {
        _tamaGroups[groupIndex].playerTamas.add(PlayerTama.fromTama(tama: tama));
        _tamaGroups[groupIndex].playerTamas.last.tama.tricks!.clear();
        _tamaGroups[groupIndex].playerTamas.last.tama.tricks!.addAll(tama.tricks!);
      }
    }

    writeData();
  }

  void updateTamasGroups({required Map<String, List<TamasGroup>> tamasGroups}) {
    _tamaGroups.clear();
    _premiumTamasGroup.clear();
    final tamas = _tamas.values.toList();
    final regularTamasGroups = tamasGroups[kRegularTamasGroups]!;
    final premiumTamasGroups = tamasGroups[kPremiumTamasGroups]! as List<PremiumTamasGroup>;
    for (final group in regularTamasGroups) {
      final tamasForGroup =
          tamas.where((element) => element.tamasGroupID == group.id).toList().map((e) => PlayerTama.fromTama(tama: e)).toList();

      final newGroup = TamasGroup(id: group.id, name: group.name, playerTamas: tamasForGroup);
      if (group.id != null) {
        _tamaGroups.add(newGroup);
      }
    }

    for (final group in premiumTamasGroups) {
      final tamasForGroup =
          tamas.where((element) => element.tamasGroupID == group.id).toList().map((e) => PlayerTama.fromTama(tama: e)).toList();

      final newGroup = TamasGroup(id: group.id, name: group.name, playerTamas: tamasForGroup);
      final newPremiumGroup = PremiumTamasGroup(
        tamasGroup: newGroup,
        backgroundColor: group.backgroundColor,
        textColor: group.textColor,
        price: group.price,
        videoUrl: group.videoUrl,
      );
      if (group.id != null) {
        _premiumTamasGroupIDs.add(newPremiumGroup.id!);
        _premiumTamasGroup.add(newPremiumGroup);
      }
    }

    writeData();
  }

  Future<void> _loadDataTable() async {
    final data = await rootBundle.loadString('assets/statics/$_dataTableFileName.json');
    try {
      Map<String, dynamic> jsonResult = json.decode(data);
      tamaValue = jsonResult['tama'];
      trickValue = jsonResult['trick'];
      tamasGroupValue = jsonResult['tama_group'];
    } catch (e) {
      logE('error loading tama table data: ${e.toString()}');
    }
  }

  Future<void> _loadTamaTricksRelation() async {
    final data = await rootBundle.loadString('assets/statics/$_tamaTricksRelationFileName.json');
    try {
      Map<String, dynamic> jsonResult = json.decode(data);
      for (var tamaJson in jsonResult['data']) {
        _tamaTricksRelation.add({
          'tama_id': tamaJson['tama_id'],
          'trick_id': tamaJson['trick_id'],
          'trick_points': tamaJson['trick_points'],
          'trick_order': tamaJson['trick_order'],
        });
      }
    } catch (e) {
      logE('error loading tama tricks relation: ${e.toString()}');
    }
  }

  Future<void> _loadTamas() async {
    final data = await rootBundle.loadString('assets/statics/$_tamasFileName.json');
    try {
      Map<String, dynamic> jsonResult = json.decode(data);
      _tamas.clear();
      for (var tamaJson in jsonResult['data']) {
        if (tamaJson == null) continue;
        final tama = Tama.fromJson(json: tamaJson);
        if (tama.id != null) {
          _tamas[tama.id!] = tama;
        }
      }
    } catch (e) {
      logE('error loading tamas: ${e.toString()}');
    }
  }

  Future<void> _loadTricks() async {
    final data = await rootBundle.loadString('assets/statics/$_tricksFileName.json');
    try {
      Map<String, dynamic> jsonResult = json.decode(data);
      _tricks.clear();
      for (var tricksJson in jsonResult['data']) {
        if (tricksJson == null) continue;

        final tamaIDs = _tamaTricksRelation
            .where((element) => element['trick_id'] == tricksJson['trick_id'])
            .toList()
            .map((e) => e['tama_id']);

        if (tamaIDs.isEmpty) continue;

        final trick = Trick.fromJson(json: tricksJson, tamaID: tamaIDs.firstOrNull);
        if (trick.id != null) {
          _tricks.add(trick);

          if (_tamas.containsKey(trick.tamaID)) {
            _tamas[trick.tamaID]!.tricks!.add(TamaTrickProgress.fromTrick(trick: trick));
          }
        }
      }
    } catch (e) {
      logE('error loading tricks: ${e.toString()}');
    }
  }

  Future<void> _loadGroups() async {
    final data = await rootBundle.loadString('assets/statics/$_groupsFileName.json');
    try {
      Map<String, dynamic> jsonResult = json.decode(data);
      _tamaGroups.clear();
      for (var groupsJson in jsonResult['data']) {
        if (groupsJson == null) continue;

        final tamas = _tamas.values.toList();
        final tamasForGroup = tamas.where((element) => element.tamasGroupID == groupsJson['tamas_group_id']).toList();

        final group = TamasGroup.fromJson(json: groupsJson, tamas: tamasForGroup);
        if (group.id != null) {
          _tamaGroups.add(group);
        }
      }
    } catch (e) {
      logE('error loading tama groups: ${e.toString()}');
    }
  }

  Future<void> _loadPremiumGroups() async {
    final data = await rootBundle.loadString('assets/statics/$_premiumTamaGroups.json');
    try {
      Map<String, dynamic> jsonResult = json.decode(data);
      _premiumTamasGroupIDs.clear();
      _premiumTamasGroup.clear();
      for (var premiumGroupsJson in jsonResult['data']) {
        final tamaCandidates = _tamaGroups.where((element) => element.id == premiumGroupsJson['id']);
        if (tamaCandidates.isEmpty) continue;

        final bgColor = Color(ColorExtension.formatStringForColorConstructor(premiumGroupsJson['background_color']));
        Color? textColor;
        if (premiumGroupsJson['text_color'] != null) {
          textColor = Color(ColorExtension.formatStringForColorConstructor(premiumGroupsJson['text_color']));
        }

        final premiumGroup = PremiumTamasGroup(
          tamasGroup: tamaCandidates.first,
          backgroundColor: bgColor,
          textColor: textColor,
          price: premiumGroupsJson['price'],
          videoUrl: premiumGroupsJson['video_url'],
        );

        _premiumTamasGroup.add(premiumGroup);
        _premiumTamasGroupIDs.add(premiumGroup.id!);
        _tamaGroups.removeWhere((element) => element.id == premiumGroup.id);
      }
    } catch (e) {
      logE('error loading tama groups: ${e.toString()}');
    }
  }

  Future<bool> _readCachedData() async {
    File tmpFile = File('${appGroupDir.path}/$_localDataJsonName.json');

    if (await tmpFile.exists()) {
      var jsonString = await tmpFile.readAsString();
      try {
        _localDataJson = jsonDecode(jsonString);
      } catch (e) {
        logE('error decoding cached data: ${e.toString()}');
        return true;
      }
    } else {
      return true;
    }

    try {
      _tamaTricksRelation.clear();
      if (_localDataJson['tama_tricks_relation'] != null) {
        for (final map in _localDataJson['tama_tricks_relation']) {
          _tamaTricksRelation.add(map);
        }
      }
    } catch (e) {
      logE('error loading tama trick relation from cached json, ${e.toString()}');
      return true;
    }

    try {
      if (_localDataJson['tamas'] != null) {
        tamaValue = _localDataJson['data_tama_value'] ?? '';
        for (var tm in _localDataJson['tamas']) {
          final tmp = Tama.fromJson(json: tm);
          if (tmp.id != null) {
            _tamas[tmp.id!] = tmp;
          }
        }
      }
    } catch (e) {
      logE('error loading tricks from cached json, ${e.toString()}');
      return true;
    }

    try {
      if (_localDataJson['tricks'] != null) {
        trickValue = _localDataJson['data_trick_value'] ?? '';
        for (var tr in _localDataJson['tricks']) {
          final tmp = Trick.fromJson(json: tr, tamaID: tr['tama_id']);
          if (tmp.id != null) {
            _tricks.add(tmp);

            if (tmp.tamaID != null && _tamas.containsKey(tmp.tamaID)) {
              _tamas[tmp.tamaID]!.tricks!.add(TamaTrickProgress.fromTrick(trick: tmp));
            }
          }
        }
      }
    } catch (e) {
      logE('error loading tamas from cached json, ${e.toString()}');
      return true;
    }

    try {
      if (_localDataJson['tama_groups'] != null) {
        final tamaValues = _tamas.values;
        tamasGroupValue = _localDataJson['data_tamas_group_value'] ?? '';
        for (var tg in _localDataJson['tama_groups']) {
          final tamasForGroup = tamaValues.where((element) => element.tamasGroupID == tg['tamas_group_id']).toList();
          final tmp = TamasGroup.fromJson(json: tg, tamas: tamasForGroup);
          if (tmp.id != null) {
            _tamaGroups.add(tmp);
          }
        }
      }
    } catch (e) {
      logE('error loading tama groups from cached json, ${e.toString()}');
      return true;
    }

    try {
      if (_localDataJson['premium_tamas_groups'] != null) {
        final tamaValues = _tamas.values;
        for (var tg in _localDataJson['premium_tamas_groups']) {
          final tamasForGroup = tamaValues.where((element) => element.tamasGroupID == tg['tamas_group_id']).toList();
          final tmp = PremiumTamasGroup.fromJson(json: tg, tamas: tamasForGroup);
          if (tmp.id != null) {
            _premiumTamasGroupIDs.add(tmp.id!);
            _premiumTamasGroup.add(tmp);
          }
        }
      }
    } catch (e) {
      logE('error loading tama groups from cached json, ${e.toString()}');
      return true;
    }

    logI('reading from cached json succeeded');
    return false;
  }

  void writeData() {
    _localDataJson.clear();

    List<Map<String, dynamic>> trickJsonData = [];
    for (var t in _tricks) {
      trickJsonData.add(t.toJson());
    }

    List<Map<String, dynamic>> tamaJsonData = [];
    for (var tama in _tamas.values) {
      tamaJsonData.add(tama.toJson());
    }

    List<Map<String, dynamic>> tamaGroupsJsonData = [];
    for (var tamaGroup in _tamaGroups) {
      tamaGroupsJsonData.add(tamaGroup.toJson());
    }

    List<Map<String, dynamic>> premiumTamasGroupsJsonData = [];
    for (var premiumTamasGroup in _premiumTamasGroup) {
      premiumTamasGroupsJsonData.add(premiumTamasGroup.toJson());
    }

    _localDataJson['tama_tricks_relation'] = _tamaTricksRelation;
    _localDataJson['tricks'] = trickJsonData;
    _localDataJson['data_trick_value'] = trickValue;
    _localDataJson['tamas'] = tamaJsonData;
    _localDataJson['data_tama_value'] = tamaValue;
    _localDataJson['tama_groups'] = tamaGroupsJsonData;
    _localDataJson['premium_tamas_groups'] = premiumTamasGroupsJsonData;
    _localDataJson['data_tamas_group_value'] = tamasGroupValue;

    File tmpFile = File('${appGroupDir.path}/$_localDataJsonName.json');
    String dataJson = jsonEncode(_localDataJson);
    tmpFile.writeAsStringSync(dataJson, flush: true);
  }

  void updatePurchasedGroups(List<String> ids) {
    _purchasedPremiumGroupIDs.clear();
    _purchasedPremiumGroupIDs.addAll(ids);
  }

  @override
  String get className => 'PersistentDataService';
}
