import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:kendamanomics_mobile/widgets/upload_trick/trick_stat_row.dart';

class TrickInformationFields extends StatelessWidget {
  final String? firstLace;
  final int? totalLaces;
  final int? trickPoints;
  final bool fetchedFirstLace;
  const TrickInformationFields({
    super.key,
    this.firstLace,
    this.totalLaces,
    this.trickPoints,
    this.fetchedFirstLace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        children: [
          TrickStatRow(
            trickInfoText: 'profile_page.points'.tr(),
            statistic: trickPoints?.toString(),
          ),
          const SizedBox(height: 8.0),
          TrickStatRow(
            trickInfoText: 'upload_trick.first_laced'.tr(),
            statistic: firstLace,
            loaded: fetchedFirstLace,
          ),
          const SizedBox(height: 8.0),
          TrickStatRow(
            trickInfoText: 'upload_trick.players_laced'.tr(),
            statistic: totalLaces?.toString(),
          ),
        ],
      ),
    );
  }
}
