import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kendamanomics_mobile/extensions/custom_colors.dart';
import 'package:kendamanomics_mobile/extensions/custom_text_styles.dart';
import 'package:kendamanomics_mobile/widgets/custom_button.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionPermanentlyDeniedDialog extends StatelessWidget {
  final VoidCallback onSettingsOpened;
  const PermissionPermanentlyDeniedDialog({super.key, required this.onSettingsOpened});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CustomColors.of(context).permissionDialogBackground,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(5.0)),
        side: BorderSide(
          color: CustomColors.of(context).uploadInstructionsDialogBackground,
          width: 3,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8.0),
          Text(
            'dialogs.permissions',
            textAlign: TextAlign.center,
            style: CustomTextStyles.of(context).regular16.apply(color: CustomColors.of(context).timelineColor),
          ).tr(),
          const SizedBox(height: 40.0),
          CustomButton(
            onPressed: () => Navigator.of(context).pop(),
            buttonStyle: CustomButtonStyle.small,
            child: Text(
              'buttons.close'.tr(),
              style: CustomTextStyles.of(context).medium16.apply(color: CustomColors.of(context).primary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16.0),
          CustomButton(
            customBackgroundColor: CustomColors.of(context).primary,
            buttonStyle: CustomButtonStyle.small,
            onPressed: openSettings,
            child: Text(
              'buttons.open_settings'.tr(),
              style: CustomTextStyles.of(context).medium16.apply(color: CustomColors.of(context).secondary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40.0),
        ],
      ),
    );
  }

  void openSettings() {
    onSettingsOpened();
    openAppSettings();
  }
}
