import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:kendamanomics_mobile/extensions/custom_colors.dart';
import 'package:kendamanomics_mobile/extensions/custom_text_styles.dart';

class UploadInstructionsDialog extends StatelessWidget {
  final String data;
  const UploadInstructionsDialog({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final normalTextStyle = CustomTextStyles.of(context).medium16.apply(
          color: CustomColors.of(context).uploadInstructionsDialogText,
        );
    final titleTextStyle = CustomTextStyles.of(context).medium24.apply(
          color: CustomColors.of(context).uploadInstructionsDialogText,
        );
    final boldTextStyle = CustomTextStyles.of(context).bold18.apply(
          color: CustomColors.of(context).uploadInstructionsDialogText,
        );
    return Dialog(
      backgroundColor: CustomColors.of(context).uploadInstructionsDialogBackground,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(5.0)),
        side: BorderSide(color: CustomColors.of(context).primary, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 300,
            height: 570,
            child: Markdown(
              data: data,
              styleSheet: MarkdownStyleSheet(
                p: normalTextStyle,
                strong: boldTextStyle,
                listBullet: normalTextStyle,
                h1: titleTextStyle,
              ),
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: CustomColors.of(context).logBorder,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'buttons.continue',
                style: CustomTextStyles.of(context).regular18.copyWith(height: 1.5),
              ).tr(),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
