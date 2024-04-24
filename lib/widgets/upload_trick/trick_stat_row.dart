import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:kendamanomics_mobile/extensions/custom_colors.dart';
import 'package:kendamanomics_mobile/extensions/custom_text_styles.dart';

class TrickStatRow extends StatelessWidget {
  final String trickInfoText;
  final String? statistic;
  final bool? loaded;

  const TrickStatRow({super.key, required this.trickInfoText, this.statistic, this.loaded});

  String get statText {
    if (loaded == true && statistic == null) {
      return '';
    }

    if (statistic == null) {
      return 'upload_trick.loading'.tr();
    }

    return statistic!;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            SizedBox(
              width: MediaQuery.sizeOf(context).width / 3 - 20.0,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  trickInfoText,
                  textAlign: TextAlign.right,
                  style: CustomTextStyles.of(context).regular16.apply(color: CustomColors.of(context).timelineColor),
                ),
              ),
            ),
          ],
        ),
        Container(
          height: 50,
          width: MediaQuery.of(context).size.width / 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: CustomColors.of(context).timelineColor, width: 2),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
              child: Text(
                statText,
                style: CustomTextStyles.of(context).regular20.apply(color: CustomColors.of(context).timelineColor),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
