import 'package:kendamanomics_mobile/mixins/logger_mixin.dart';
import 'package:kendamanomics_mobile/models/submission.dart';
import 'package:kendamanomics_mobile/models/trick.dart';
import 'package:kendamanomics_mobile/models/trick_stat.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tuple/tuple.dart';

class TrickService with LoggerMixin {
  final _supabase = Supabase.instance.client;

  Future<Map<String, SubmissionStatus>> fetchTrickProgress({required String tamaID}) async {
    final playerID = _supabase.auth.currentUser?.id;
    final data = await _supabase.rpc('fetch_trick_progress', params: {'player_id': playerID, 'tama_id': tamaID});

    final progress = <String, SubmissionStatus>{};

    for (final item in data) {
      final info = item['data'];
      progress[info['submission_trick_id']] = SubmissionStatus.fromString(info['submission_status']);
    }

    return progress;
  }

  // fix the check below, issue is if it gets the tricks for one tama it wont fetch tricks for other tama
  Future<List<Trick>?> fetchTricksByTamaID({required String tamaID}) async {
    // final uuid = await _supabase.rpc('fetch_data_tracking', params: {'filter_tracking_name': 'trick'});
    // if (uuid == _persistantDataService.trickValue) return null;
    // _persistantDataService.trickValue = uuid;
    final data = await _supabase.rpc('fetch_tricks_by_tama_id', params: {'filter_tama_id': tamaID});
    if (data == null) return null;

    final newTricks = <Tuple2<Trick, int?>>[];
    for (final item in data) {
      newTricks.add(Tuple2(Trick.fromJson(json: item, tamaID: tamaID), item['trick_order']));
    }

    if (newTricks.isNotEmpty && newTricks[0].item2 != null) {
      newTricks.sort((a, b) => a.item2!.compareTo(b.item2!));
    }

    return newTricks.map((e) => e.item1).toList();
  }

  Future<TrickStat?> getFirstLacedPlayer({required String trickId}) async {
    try {
      final data = await _supabase.rpc('get_first_laced_player_for_trick', params: {'trick_id': trickId});
      if (data != null) {
        final firstPlayer = data[0];
        final firstLacedPlayerFirstname = firstPlayer['player_firstname'];
        final firstLacedPlayerLastname = firstPlayer['player_lastname'];
        return TrickStat(
          firstLacedPlayerFirstname: firstLacedPlayerFirstname,
          firstLacedPlayerLastname: firstLacedPlayerLastname,
          trickId: trickId,
        );
      } else {
        logE('No data returned from the rpc call');
      }
    } catch (e) {
      logE('Error while getting first laced player: $e');
    }
    return null;
  }

  Future<TrickStat?> getTotalLacedCountForTrick({required String trickId}) async {
    try {
      final data = await _supabase.rpc('get_total_laced_count_for_trick', params: {'trick_id': trickId});
      if (data != null && data is int) {
        return TrickStat(totalLacedCount: data, trickId: trickId);
      } else {
        logE('Data not in expected format');
      }
    } catch (e) {
      logE('Error while getting total laced count $e');
    }
    return null;
  }

  Future<TrickStat?> getTrickPoints({required String trickId}) async {
    try {
      final data = await _supabase.rpc('get_trick_points', params: {'p_trick_id': trickId});
      if (data != null) {
        return TrickStat(trickPoints: data, trickId: trickId);
      } else {
        logE('No data returned from the rpc call');
      }
    } catch (e) {
      logE('Error while getting trick points $e');
    }
    return null;
  }

  @override
  String get className => 'TrickService';
}
