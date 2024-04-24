import 'package:flutter/material.dart';
import 'package:kendamanomics_mobile/extensions/custom_colors.dart';
import 'package:kendamanomics_mobile/models/submission.dart';
import 'package:kendamanomics_mobile/widgets/upload_trick/trick_video_player.dart';

class VideoPlayerDialog extends StatelessWidget {
  final Submission submission;
  const VideoPlayerDialog({super.key, required this.submission});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: CustomColors.of(context).videoDialogBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0.0),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.of(context).size.width * 0.15,
        vertical: MediaQuery.of(context).size.width * 0.205,
      ),
      child: TrickVideoPlayer(submission: submission),
    );
  }
}
