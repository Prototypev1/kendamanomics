import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kendamanomics_mobile/extensions/custom_colors.dart';
import 'package:kendamanomics_mobile/extensions/custom_text_styles.dart';

enum TitleWidgetArrowPositioning { leading, trailing, symmetric }

class TitleWidget extends StatelessWidget {
  final String title;
  final TitleWidgetArrowPositioning _arrowPositioning;
  final VoidCallback? onLeadingPressed;
  final VoidCallback? onTrailingPressed;

  const TitleWidget.leading({
    super.key,
    required this.title,
    required this.onLeadingPressed,
  })  : _arrowPositioning = TitleWidgetArrowPositioning.leading,
        onTrailingPressed = null;

  const TitleWidget.trailing({
    super.key,
    required this.title,
    required this.onTrailingPressed,
  })  : _arrowPositioning = TitleWidgetArrowPositioning.trailing,
        onLeadingPressed = null;

  const TitleWidget.symmetric({
    super.key,
    required this.title,
    required this.onLeadingPressed,
    required this.onTrailingPressed,
  }) : _arrowPositioning = TitleWidgetArrowPositioning.symmetric;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (![TitleWidgetArrowPositioning.leading, TitleWidgetArrowPositioning.symmetric].contains(_arrowPositioning))
          const SizedBox(width: 24),
        if ([TitleWidgetArrowPositioning.leading, TitleWidgetArrowPositioning.symmetric].contains(_arrowPositioning))
          InkWell(
            onTap: () => onLeadingPressed?.call(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Transform.rotate(
                angle: pi / 2,
                child: Image.asset(
                  'assets/icon/icon_arrow.png',
                  alignment: Alignment.topLeft,
                  height: 16.0,
                  width: 16.0,
                ),
              ),
            ),
          ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: CustomTextStyles.of(context).regular20.apply(color: CustomColors.of(context).primary),
          ),
        ),
        const SizedBox(width: 8),
        if (![TitleWidgetArrowPositioning.trailing, TitleWidgetArrowPositioning.symmetric].contains(_arrowPositioning))
          const SizedBox(width: 24),
        if ([TitleWidgetArrowPositioning.trailing, TitleWidgetArrowPositioning.symmetric].contains(_arrowPositioning))
          InkWell(
            onTap: () => onTrailingPressed?.call(),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Transform.rotate(
                angle: -pi / 2,
                child: Image.asset(
                  'assets/icon/icon_arrow.png',
                  alignment: Alignment.topLeft,
                  height: 16.0,
                  width: 16.0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
