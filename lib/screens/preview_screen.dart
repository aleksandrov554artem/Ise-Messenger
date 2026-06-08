part of '../main.dart';

class MessageAttachmentViewerScreen extends StatefulWidget {
  const MessageAttachmentViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  final List<PreviewableAttachmentItem> items;
  final int initialIndex;

  @override
  State<MessageAttachmentViewerScreen> createState() =>
      _MessageAttachmentViewerScreenState();
}

class _MessageAttachmentViewerScreenState
    extends State<MessageAttachmentViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  PreviewableAttachmentItem get _currentItem => widget.items[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentAttachment = _currentItem.attachment;
    final counterLabel = '${_currentIndex + 1}/${widget.items.length}';
    final topPadding = MediaQuery.paddingOf(context).top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appDarkSurfaceOverlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                if (item.attachment.isVideo) {
                  return _VideoAttachmentViewerPage(
                    item: item,
                    isActive: index == _currentIndex,
                  );
                }
                return _ImageAttachmentViewerPage(item: item);
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(12, topPadding + 8, 16, 22),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.72),
                      Colors.black.withValues(alpha: 0),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              currentAttachment.previewTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              counterLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageAttachmentViewerPage extends StatelessWidget {
  const _ImageAttachmentViewerPage({required this.item});

  final PreviewableAttachmentItem item;

  @override
  Widget build(BuildContext context) {
    final attachment = item.attachment;
    final mediaSize = MediaQuery.sizeOf(context);
    final cacheWidth = _targetImageCacheDimension(context, mediaSize.width);
    final cacheHeight = _targetImageCacheDimension(context, mediaSize.height);
    return SizedBox.expand(
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: mediaSize.height,
          child: Material(
            color: Colors.transparent,
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: _RetryableViewerImage(
                attachment.url,
                fit: BoxFit.scaleDown,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
                filterQuality: FilterQuality.low,
                errorBuilder: (context, error, stackTrace) {
                  return const Text(
                    'Не удалось открыть изображение',
                    style: TextStyle(color: Colors.white),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetryableViewerImage extends StatefulWidget {
  const _RetryableViewerImage(
    this.url, {
    this.fit = BoxFit.scaleDown,
    this.cacheWidth,
    this.cacheHeight,
    this.filterQuality = FilterQuality.low,
    this.errorBuilder,
  });

  final String url;
  final BoxFit fit;
  final int? cacheWidth;
  final int? cacheHeight;
  final FilterQuality filterQuality;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  State<_RetryableViewerImage> createState() => _RetryableViewerImageState();
}

class _RetryableViewerImageState extends State<_RetryableViewerImage> {
  int _reloadToken = 0;

  void _retryLoading() {
    setState(() {
      _reloadToken += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      widget.url,
      headers: serverMediaHttpHeadersFor(widget.url),
      key: ValueKey('${widget.url}:viewer:$_reloadToken'),
      fit: widget.fit,
      cacheWidth: widget.cacheWidth,
      cacheHeight: widget.cacheHeight,
      filterQuality: widget.filterQuality,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _AttachmentRetryView(
          title: 'Фото',
          description: 'Не удалось загрузить изображение. Попробуйте еще раз.',
          icon: Icons.broken_image_rounded,
          onRetry: _retryLoading,
          dark: true,
        );
      },
    );
  }
}

class _VideoAttachmentViewerPage extends StatefulWidget {
  const _VideoAttachmentViewerPage({
    required this.item,
    required this.isActive,
  });

  final PreviewableAttachmentItem item;
  final bool isActive;

  @override
  State<_VideoAttachmentViewerPage> createState() =>
      _VideoAttachmentViewerPageState();
}

class _VideoAttachmentViewerPageState
    extends State<_VideoAttachmentViewerPage> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  Timer? _controlsHideTimer;
  int _controllerLoadGeneration = 0;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  void _createController() {
    final generation = ++_controllerLoadGeneration;
    _initializeFuture = _loadController(generation);
  }

  @override
  void didUpdateWidget(covariant _VideoAttachmentViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.attachment.url != widget.item.attachment.url) {
      unawaited(_replaceController());
      return;
    }
    final controller = _controller;
    if (oldWidget.isActive == widget.isActive ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }
    if (widget.isActive) {
      unawaited(controller.play());
      _scheduleControlsHide();
    } else {
      unawaited(controller.pause());
      _cancelControlsHide();
      _showControlsNow();
    }
  }

  @override
  void dispose() {
    _controllerLoadGeneration++;
    _controlsHideTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _replaceController() async {
    final previous = _controller;
    final generation = ++_controllerLoadGeneration;
    final initializeFuture = _loadController(generation);
    setState(() {
      _controller = null;
      _initializeFuture = initializeFuture;
      _showControls = true;
    });
    await previous?.dispose();
  }

  Future<void> _loadController(int generation) async {
    VideoPlayerController? controller;
    try {
      controller = await _createCompatibleVideoController(
        widget.item.attachment,
      );
      if (!mounted || generation != _controllerLoadGeneration) {
        await controller.dispose();
        return;
      }
      await controller.setVolume(1);
      if (widget.isActive) {
        await controller.play();
      } else {
        await controller.pause();
      }
      if (!mounted || generation != _controllerLoadGeneration) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
      });
      if (widget.isActive) {
        _scheduleControlsHide();
      } else {
        _cancelControlsHide();
      }
    } catch (_) {
      try {
        await controller?.dispose();
      } catch (_) {}
      rethrow;
    }
  }

  void _cancelControlsHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  void _scheduleControlsHide() {
    _cancelControlsHide();
    final controller = _controller;
    if (!widget.isActive ||
        controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying) {
      return;
    }
    _controlsHideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showControls = false;
      });
    });
  }

  void _showControlsNow() {
    _cancelControlsHide();
    if (!mounted) {
      return;
    }
    setState(() {
      _showControls = true;
    });
  }

  void _toggleControlsVisibility() {
    final shouldShow = !_showControls;
    _cancelControlsHide();
    setState(() {
      _showControls = shouldShow;
    });
    if (shouldShow) {
      _scheduleControlsHide();
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.position >= controller.value.duration &&
        controller.value.duration > Duration.zero) {
      await controller.seekTo(Duration.zero);
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      _showControlsNow();
      return;
    }
    await controller.play();
    _showControlsNow();
    _scheduleControlsHide();
  }

  Duration _clampPosition(Duration position, Duration duration) {
    if (duration <= Duration.zero) {
      return Duration.zero;
    }
    if (position <= Duration.zero) {
      return Duration.zero;
    }
    if (position >= duration) {
      return duration;
    }
    return position;
  }

  @override
  Widget build(BuildContext context) {
    final initializeFuture = _initializeFuture;
    final mediaSize = MediaQuery.sizeOf(context);
    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        final controller = _controller;
        return SizedBox.expand(
          child: Center(
            child: SizedBox(
              width: double.infinity,
              height: mediaSize.height,
              child: Material(
                color: Colors.transparent,
                child: Center(
                  child: initializeFuture == null
                      ? _AttachmentRetryView(
                          title: 'Видео',
                          description: 'Не удалось подготовить видео.',
                          icon: Icons.videocam_off_rounded,
                          onRetry: () => unawaited(_replaceController()),
                          dark: true,
                        )
                      : snapshot.connectionState != ConnectionState.done
                      ? const CircularProgressIndicator(color: Colors.white)
                      : snapshot.hasError ||
                            controller == null ||
                            !controller.value.isInitialized
                      ? _AttachmentRetryView(
                          title: 'Видео',
                          description:
                              'Не удалось загрузить видео. Попробуйте еще раз.',
                          icon: Icons.videocam_off_rounded,
                          onRetry: () => unawaited(_replaceController()),
                          dark: true,
                        )
                      : ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, _) {
                            final duration = value.duration;
                            final resolvedPosition = _clampPosition(
                              value.position,
                              duration,
                            );
                            final effectiveDuration = duration > Duration.zero
                                ? duration
                                : resolvedPosition;
                            final completionThreshold =
                                duration > const Duration(milliseconds: 200)
                                ? duration - const Duration(milliseconds: 200)
                                : duration;
                            final isCompleted =
                                duration > Duration.zero &&
                                !value.isPlaying &&
                                value.position >= completionThreshold;
                            final playButtonIcon = isCompleted
                                ? Icons.replay_rounded
                                : value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded;
                            final buffering =
                                value.isBuffering &&
                                snapshot.connectionState ==
                                    ConnectionState.done &&
                                !isCompleted;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleControlsVisibility,
                              child: Stack(
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final displaySize = _displayVideoSize(
                                        value,
                                      );
                                      return Center(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: SizedBox(
                                            width: displaySize.width,
                                            height: displaySize.height,
                                            child: VideoPlayer(controller),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  if (buffering)
                                    const Center(
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      ),
                                    ),
                                  AnimatedOpacity(
                                    duration: const Duration(milliseconds: 180),
                                    opacity: _showControls ? 1 : 0,
                                    child: IgnorePointer(
                                      ignoring: !_showControls,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.black.withValues(
                                                      alpha: 0.18,
                                                    ),
                                                    Colors.black.withValues(
                                                      alpha: 0.08,
                                                    ),
                                                    Colors.black.withValues(
                                                      alpha: 0.62,
                                                    ),
                                                  ],
                                                  stops: const [0, 0.45, 1],
                                                ),
                                              ),
                                            ),
                                          ),
                                          Center(
                                            child: _buildVideoControlButton(
                                              icon: playButtonIcon,
                                              size: 34,
                                              diameter: 74,
                                              onTap: () =>
                                                  unawaited(_togglePlayback()),
                                            ),
                                          ),
                                          Positioned(
                                            left: 18,
                                            right: 18,
                                            bottom: 18,
                                            child: Row(
                                              children: [
                                                Text(
                                                  formatAudioDuration(
                                                    resolvedPosition,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: _MediaProgressBar(
                                                    position: resolvedPosition,
                                                    duration: effectiveDuration,
                                                    activeColor: Colors.white,
                                                    inactiveColor: Colors.white
                                                        .withValues(
                                                          alpha: 0.24,
                                                        ),
                                                    trackHeight: 5,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  formatAudioDuration(
                                                    effectiveDuration,
                                                  ),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoControlButton({
    required IconData icon,
    required VoidCallback? onTap,
    double diameter = 56,
    double size = 28,
  }) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: size),
        ),
      ),
    );
  }
}

enum _ComposerAttachmentKind { image, video, audio, file }
