import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:kendamanomics_mobile/extensions/custom_colors.dart';
import 'package:kendamanomics_mobile/extensions/custom_text_styles.dart';
import 'package:kendamanomics_mobile/models/player_tama.dart';
import 'package:kendamanomics_mobile/models/premium_tamas_group.dart';
import 'package:kendamanomics_mobile/models/tamas_group.dart';
import 'package:kendamanomics_mobile/providers/tamas_provider.dart';
import 'package:kendamanomics_mobile/widgets/tama_widget.dart';
import 'package:kendamanomics_mobile/widgets/title_widget.dart';
import 'package:video_player/video_player.dart';

class TamaPageGroup extends StatefulWidget {
  final TamasGroup group;
  final TamasProviderState state;
  final bool showPromotionOverlay;
  final void Function(String? tamaID) onTamaPressed;
  final void Function(String? tamaID) onBuyPressed;
  final VoidCallback onNextPage;
  final VoidCallback onPreviousPage;
  final bool isFirst;
  final bool purchaseInProgress;
  const TamaPageGroup({
    super.key,
    required this.group,
    required this.state,
    required this.showPromotionOverlay,
    required this.onTamaPressed,
    required this.onBuyPressed,
    required this.onNextPage,
    required this.onPreviousPage,
    this.isFirst = false,
    required this.purchaseInProgress,
  });

  @override
  State<TamaPageGroup> createState() => _TamaPageGroupState();
}

class _TamaPageGroupState extends State<TamaPageGroup> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.group is PremiumTamasGroup && widget.showPromotionOverlay) {
      _initVideoController();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _resolveTitle(context),
        Expanded(
          child: Stack(
            children: [
              if (!widget.showPromotionOverlay)
                Positioned.fill(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        for (PlayerTama playerTama in widget.group.playerTamas) ...[
                          TamaWidget(
                            playerTama: playerTama,
                            state: widget.state,
                            onTap: () {
                              widget.onTamaPressed(playerTama.tama.id);
                            },
                          ),
                          if (widget.group.playerTamas.indexOf(playerTama) != widget.group.playerTamas.length - 1)
                            const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              if (widget.showPromotionOverlay) ...[
                Positioned.fill(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: Column(
                    children: [
                      if (_initialized)
                        Expanded(
                          child: GestureDetector(
                            onTap: _playPauseVideo,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: _controller!.value.aspectRatio,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                          ),
                        ),
                      if (!_initialized) const Expanded(child: CupertinoActivityIndicator(animating: true, radius: 20)),
                      if (!widget.purchaseInProgress)
                        InkWell(
                          onTap: () => widget.onBuyPressed(widget.group.formatIdForPayment),
                          child: Image.asset('assets/icon/icon_buy_premium.png'),
                        ),
                      if (widget.purchaseInProgress) ...[
                        const SizedBox(height: 8),
                        const CupertinoActivityIndicator(animating: true, radius: 20),
                        const SizedBox(height: 8),
                        Text(
                          'tama_page.purchase_pending',
                          style: CustomTextStyles.of(context).medium16,
                        ).tr(),
                        const SizedBox(height: 8),
                      ]
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _resolveTitle(
    BuildContext context,
  ) {
    if (widget.isFirst) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        child: TitleWidget.symmetric(
          title: widget.group.name ?? 'default_titles.tama_group'.tr(),
          onTrailingPressed: () => widget.onNextPage(),
          onLeadingPressed: () => widget.onPreviousPage(),
        ),
      );
    }
    return Center(
      child: Text(
        widget.group.name ?? 'default_titles.tama_group'.tr(),
        style: CustomTextStyles.of(context).regular25.apply(color: CustomColors.of(context).primary),
      ),
    );
  }

  void _initVideoController() async {
    final group = widget.group as PremiumTamasGroup;
    _controller = VideoPlayerController.networkUrl(Uri.parse(group.videoUrl));
    _controller!.initialize().then((value) {
      _initialized = true;
      setState(() {});
      _playPauseVideo();
    }).onError((error, stackTrace) {
      _initVideoController();
    });
  }

  void _playPauseVideo() async {
    if (_controller == null) return;
    if (_isPlaying) {
      _isPlaying = false;
      _controller!.pause();
    } else {
      _isPlaying = true;
      _controller!.play();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
