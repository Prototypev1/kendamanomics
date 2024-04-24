import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:kendamanomics_mobile/dialogs/permission_permanently_denied_dialog.dart';
import 'package:kendamanomics_mobile/dialogs/upload_instructions_dialog.dart';
import 'package:kendamanomics_mobile/dialogs/video_player_dialog.dart';
import 'package:kendamanomics_mobile/extensions/custom_colors.dart';
import 'package:kendamanomics_mobile/extensions/custom_text_styles.dart';
import 'package:kendamanomics_mobile/models/submission.dart';
import 'package:kendamanomics_mobile/models/trick.dart';
import 'package:kendamanomics_mobile/providers/trick_progress_provider.dart';
import 'package:kendamanomics_mobile/providers/upload_trick_provider.dart';
import 'package:kendamanomics_mobile/widgets/custom_button.dart';
import 'package:kendamanomics_mobile/widgets/text_icon_link.dart';
import 'package:kendamanomics_mobile/widgets/upload_trick/trick_information_fields.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

class TrickProgress extends StatelessWidget {
  final Trick? trick;
  final Submission submission;
  final VoidCallback onTimelinePressed;
  const TrickProgress({super.key, required this.submission, required this.trick, required this.onTimelinePressed});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => TrickProgressProvider(submission: submission, trick: trick),
      builder: (context, child) => Consumer<TrickProgressProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              Expanded(child: _getChild(context, provider)),
              ..._getBottomWidget(provider, context),
            ],
          );
        },
      ),
    );
  }

  Widget _getChild(BuildContext context, TrickProgressProvider provider) {
    final widgets = <Widget>[
      Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: TrickInformationFields(
          firstLace: provider.firstLacedPlayer,
          totalLaces: provider.totalLacedCount,
          trickPoints: provider.trickPoints,
          fetchedFirstLace: provider.fetchedFirstLaced,
        ),
      ),
      const Spacer(),
    ];

    switch (submission.status) {
      case SubmissionStatus.waitingForSubmission:
        widgets.addAll([
          ..._getWarningWidgetList(context, provider.state),
          Center(
            child: CustomButton(
              isLoading: provider.isUploading,
              text: 'buttons.upload'.tr(),
              onPressed: () async {
                if (!provider.getUploadInstructionsDialogShown) {
                  provider.uploadInstructionsDialogShown();
                  await showDialog(
                    context: context,
                    builder: (_) => UploadInstructionsDialog(data: provider.uploadInstructionsMD),
                  );
                }

                await provider.resolvePermissions();

                if (provider.permissionStatus == PermissionStatus.permanentlyDenied && context.mounted ||
                    provider.permissionStatus == PermissionStatus.denied && context.mounted) {
                  await showDialog(
                    context: context,
                    builder: (_) => PermissionPermanentlyDeniedDialog(
                      onSettingsOpened: () => provider.openedSettings(),
                    ),
                  );
                  return;
                }

                await provider.uploadTrickSubmission();
              },
            ),
          ),
          TextIconLink(
            title: 'upload_trick.info'.tr(),
            tintColor: CustomColors.of(context).primary,
            onPressed: () => showDialog(
              context: context,
              builder: (_) => UploadInstructionsDialog(data: provider.uploadInstructionsMD),
            ),
          ),
          const Spacer(),
        ]);

        break;
      case SubmissionStatus.inReview:
      case SubmissionStatus.denied:
      case SubmissionStatus.deniedOutOfFrame:
      case SubmissionStatus.deniedTooLong:
      case SubmissionStatus.deniedInappropriateBehaviour:
      case SubmissionStatus.deniedIncorrectTrick:
      case SubmissionStatus.awarded:
      case SubmissionStatus.laced:
        widgets.addAll([
          ..._getWarningWidgetList(context, provider.state),
          Center(
            child: CustomButton(
              customBigFontSize: 20,
              isLoading: provider.isUploading,
              text: 'buttons.watch_uploaded'.tr(),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => VideoPlayerDialog(submission: submission),
                );
              },
            ),
          ),
          const Spacer(),
        ]);
        break;
      case SubmissionStatus.revoked:
        return const SizedBox.shrink();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: widgets,
    );
  }

  List<Widget> _getBottomWidget(TrickProgressProvider provider, BuildContext context) {
    switch (provider.submission.status) {
      case SubmissionStatus.waitingForSubmission:
        return [
          if (provider.trick?.trickTutorialUrl != null && provider.trick!.trickTutorialUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextIconLink(
              title: 'upload_trick.example'.tr(),
              onPressed: context.read<UploadTrickProvider>().goToExample,
            ),
          ],
          if (provider.hasLogs) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onTimelinePressed,
              behavior: HitTestBehavior.translucent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'upload_trick.timeline',
                    style: CustomTextStyles.of(context).regular20,
                  ).tr(),
                  const SizedBox(height: 2),
                  Image.asset(
                    'assets/icon/icon_arrow.png',
                    height: 18,
                    width: 18,
                    color: CustomColors.of(context).primaryText,
                  ),
                ],
              ),
            ),
          ],
        ];
      case SubmissionStatus.inReview:
      case SubmissionStatus.denied:
      case SubmissionStatus.deniedOutOfFrame:
      case SubmissionStatus.deniedTooLong:
      case SubmissionStatus.deniedInappropriateBehaviour:
      case SubmissionStatus.deniedIncorrectTrick:
        return [
          CustomButton(
            text: 'buttons.revoke'.tr(),
            isLoading: provider.state == TrickProgressProviderState.revokingSubmission,
            buttonStyle: CustomButtonStyle.small,
            onPressed: () async {
              await provider.revokeSubmission();
            },
          ),
          const SizedBox(height: 12),
        ];
      case SubmissionStatus.laced:
        return [
          GestureDetector(
            onTap: onTimelinePressed,
            behavior: HitTestBehavior.translucent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'upload_trick.timeline',
                  style: CustomTextStyles.of(context).medium24.apply(color: CustomColors.of(context).timelineColor),
                ).tr(),
                const SizedBox(height: 2),
                Image.asset('assets/icon/icon_arrow.png', height: 18, width: 18),
              ],
            ),
          ),
        ];
      case SubmissionStatus.awarded:
      case SubmissionStatus.revoked:
        return const [SizedBox.shrink()];
    }
  }

  List<SizedBox> _getWarningWidgetList(BuildContext context, TrickProgressProviderState state) {
    final ret = <SizedBox>[];
    final style = CustomTextStyles.of(context).regular14.apply(color: CustomColors.of(context).uploadStatusMessagesRed);

    if (state == TrickProgressProviderState.errorUnknownVideoUpload) {
      ret.add(
        SizedBox(
          width: CustomButton.bigWidth,
          child: Text(
            'upload_trick.error_unknown',
            textAlign: TextAlign.center,
            style: style,
          ).tr(),
        ),
      );
    }
    if (state == TrickProgressProviderState.errorVideoTooLarge) {
      ret.add(
        SizedBox(
          width: CustomButton.bigWidth,
          child: Text(
            'upload_trick.error_video_too_large',
            textAlign: TextAlign.center,
            style: style,
          ).tr(),
        ),
      );
    }

    if (state == TrickProgressProviderState.uploadingVideoExceeds40mb) {
      ret.add(
        SizedBox(
          width: CustomButton.bigWidth,
          child: Text(
            'upload_trick.exceeds_40_mb',
            textAlign: TextAlign.center,
            style: style,
          ).tr(),
        ),
      );
    }

    if (state == TrickProgressProviderState.uploadingVideoMoreThan5s) {
      ret.add(
        SizedBox(
          width: CustomButton.bigWidth,
          child: Text(
            'upload_trick.video_uploading_5s',
            textAlign: TextAlign.center,
            style: style,
          ).tr(),
        ),
      );
    }

    if (ret.isNotEmpty) {
      ret.add(const SizedBox(height: 4));
    }

    return ret;
  }
}
