import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kendamanomics_mobile/extensions/custom_colors.dart';
import 'package:kendamanomics_mobile/providers/main_page_container_provider.dart';
import 'package:kendamanomics_mobile/providers/upload_trick_provider.dart';
import 'package:kendamanomics_mobile/widgets/title_widget.dart';
import 'package:kendamanomics_mobile/widgets/upload_trick/submission_progress.dart';
import 'package:kendamanomics_mobile/widgets/upload_trick/trick_tutorial.dart';
import 'package:provider/provider.dart';

class UploadTrick extends StatelessWidget {
  static const pageName = 'upload-trick';
  final String? trickID;
  const UploadTrick({super.key, this.trickID});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => UploadTrickProvider(
        trickID: trickID,
        calculateViewportHeight: () => context.read<MainPageContainerProvider>().calculateContentHeight(),
      ),
      builder: (context, child) {
        return Consumer<UploadTrickProvider>(
          builder: (context, provider, child) {
            return ColoredBox(
              color: provider.customBackgroundColor ?? CustomColors.of(context).backgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0),
                    child: TitleWidget.leading(
                      title: provider.trick?.name ?? 'default_titles.trick'.tr(),
                      onLeadingPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: PageView(
                      controller: provider.controller,
                      onPageChanged: (index) {
                        provider.pageIndex = index;
                      },
                      children: [
                        SubmissionProgress(trickID: trickID),
                        // TODO improve this condition
                        if (provider.trick?.trickTutorialUrl != null && provider.trick!.trickTutorialUrl!.isNotEmpty)
                          TrickTutorial(trickTutorialUrl: provider.trick?.trickTutorialUrl),
                      ],
                    ),
                  ),
                  if (provider.trick?.trickTutorialUrl != null && provider.trick!.trickTutorialUrl!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    buildIndicator(context, provider.pageIndex),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget buildIndicator(BuildContext context, int currentPage) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 450),
      curve: Curves.linearToEaseOut,
      padding: EdgeInsets.only(left: (MediaQuery.of(context).size.width / 2) * currentPage),
      child: Container(
        height: 4.0,
        width: MediaQuery.of(context).size.width / 2,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(80.0),
          shape: BoxShape.rectangle,
          color: CustomColors.of(context).activeIndicatorColor,
        ),
      ),
    );
  }
}
