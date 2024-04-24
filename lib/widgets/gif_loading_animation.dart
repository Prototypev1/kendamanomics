import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

class GifLoadingAnimation extends StatefulWidget {
  const GifLoadingAnimation({super.key});

  @override
  State<GifLoadingAnimation> createState() => _GifLoadingAnimationState();
}

class _GifLoadingAnimationState extends State<GifLoadingAnimation> with SingleTickerProviderStateMixin {
  late GifController _controller;
  final int _fps = 30;

  @override
  void initState() {
    super.initState();
    _controller = GifController(vsync: this);
    _controller.repeat(min: 0, max: 1, period: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {},
      child: Gif(
        fps: _fps,
        controller: _controller,
        image: const AssetImage('assets/gif/loading_animation.gif'),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
