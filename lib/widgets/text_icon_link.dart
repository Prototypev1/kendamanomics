import 'package:flutter/material.dart';
import 'package:kendamanomics_mobile/extensions/custom_text_styles.dart';

enum IconPosition { leading, trailing }

class TextIconLink extends StatelessWidget {
  final String title;
  final Widget? icon;
  final VoidCallback onPressed;
  final IconPosition iconPosition;
  final Color? tintColor;
  const TextIconLink({
    super.key,
    required this.title,
    required this.onPressed,
    this.icon,
    this.tintColor,
    this.iconPosition = IconPosition.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconPosition == IconPosition.leading && icon != null) ...[
              icon!,
              const SizedBox(width: 8),
            ],
            Text(title, style: CustomTextStyles.of(context).regular20.apply(color: tintColor)),
            if (iconPosition == IconPosition.trailing && icon != null) ...[
              const SizedBox(width: 8),
              icon!,
            ],
          ],
        ),
      ),
    );
  }
}
