part of '../main.dart';

class StoryViewerScreen extends StatefulWidget {
  const StoryViewerScreen({
    super.key,
    required this.controller,
    required this.story,
  });

  final MessengerController controller;
  final StoryItem story;

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  late final PageController _pageController;
  late final _StoryTimeTicker _storyTimeTicker;
  late final Listenable _screenListenable;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final initialStories = _viewerStories();
    _currentIndex = _storyIndex(initialStories, widget.story);
    _pageController = PageController(initialPage: _currentIndex);
    _storyTimeTicker = _StoryTimeTicker()..start();
    _screenListenable = Listenable.merge(<Listenable>[
      widget.controller.storiesListenable,
      widget.controller.sessionListenable,
      _storyTimeTicker,
    ]);
    unawaited(widget.controller.markStoriesSeen());
  }

  @override
  void dispose() {
    _pageController.dispose();
    _storyTimeTicker.dispose();
    super.dispose();
  }

  List<StoryItem> _viewerStories() {
    final stories = widget.controller.activeStories;
    if (stories.isEmpty) {
      return <StoryItem>[widget.story];
    }
    if (stories.any((story) => story.id == widget.story.id)) {
      return stories;
    }
    return <StoryItem>[widget.story, ...stories];
  }

  int _storyIndex(List<StoryItem> stories, StoryItem story) {
    final index = stories.indexWhere((item) => item.id == story.id);
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenListenable,
      builder: (context, _) {
        final stories = _viewerStories();
        if (stories.isEmpty) {
          return const Scaffold(backgroundColor: Colors.black);
        }
        final currentIndex = _currentIndex.clamp(0, stories.length - 1).toInt();
        if (currentIndex != _currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentIndex = currentIndex;
            });
            if (_pageController.hasClients) {
              _pageController.jumpToPage(currentIndex);
            }
          });
        }
        return Scaffold(
          backgroundColor: Colors.black,
          body: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: stories.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
              unawaited(widget.controller.markStoriesSeen());
            },
            itemBuilder: (context, index) {
              final story = stories[index];
              return _StoryViewerPage(
                key: ValueKey<int>(story.id),
                controller: widget.controller,
                story: story,
                isActive: index == currentIndex,
                onClose: () => Navigator.of(context).maybePop(),
              );
            },
          ),
        );
      },
    );
  }
}

class _StoryViewerPage extends StatefulWidget {
  const _StoryViewerPage({
    super.key,
    required this.controller,
    required this.story,
    required this.isActive,
    required this.onClose,
  });

  final MessengerController controller;
  final StoryItem story;
  final bool isActive;
  final VoidCallback onClose;

  @override
  State<_StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<_StoryViewerPage> {
  VideoPlayerController? _videoController;
  Future<void>? _initializeFuture;
  Timer? _controlsHideTimer;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(covariant _StoryViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.id != widget.story.id ||
        oldWidget.story.mediaUrl != widget.story.mediaUrl) {
      final oldController = _videoController;
      _videoController = null;
      if (oldController != null) {
        unawaited(oldController.dispose());
      }
      _initializeVideo();
      return;
    }
    if (oldWidget.isActive != widget.isActive) {
      unawaited(_syncPlaybackState());
    }
  }

  @override
  void dispose() {
    final controller = _videoController;
    _videoController = null;
    _controlsHideTimer?.cancel();
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  void _initializeVideo() {
    _initializeFuture = _createStoryVideoController(widget.story.mediaUrl).then(
      (controller) async {
        if (!mounted) {
          await controller.dispose();
          return;
        }
        _videoController = controller;
        await controller.setLooping(false);
        await _syncPlaybackState();
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Future<void> _syncPlaybackState() async {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (widget.isActive) {
      await controller.play();
      _scheduleControlsHide();
    } else {
      await controller.pause();
      _cancelControlsHide();
      _showControlsNow();
    }
  }

  void _cancelControlsHide() {
    _controlsHideTimer?.cancel();
    _controlsHideTimer = null;
  }

  void _scheduleControlsHide() {
    final controller = _videoController;
    _cancelControlsHide();
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
    final controller = _videoController;
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
    } else {
      await controller.play();
      _showControlsNow();
      _scheduleControlsHide();
    }
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
    return FutureBuilder<void>(
      future: _initializeFuture,
      builder: (context, snapshot) {
        final controller = _videoController;
        final isReady =
            snapshot.connectionState == ConnectionState.done &&
            controller != null &&
            controller.value.isInitialized;
        return Stack(
          fit: StackFit.expand,
          children: [
            if (snapshot.hasError)
              const Center(
                child: Icon(
                  Icons.videocam_off_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              )
            else if (!isReady)
              const Center(child: _PureWhiteProgressIndicator())
            else
              ValueListenableBuilder<VideoPlayerValue>(
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
                      snapshot.connectionState == ConnectionState.done &&
                      !isCompleted;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleControlsVisibility,
                    child: Stack(
                      children: [
                        _StoryVideoPlayer(
                          controller: controller,
                          recordedWithFrontCamera:
                              widget.story.wasRecordedWithFrontCamera,
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
                            child: _StoryViewerControls(
                              icon: playButtonIcon,
                              position: resolvedPosition,
                              duration: effectiveDuration,
                              onTogglePlayback: () =>
                                  unawaited(_togglePlayback()),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            _StoryViewerHeader(story: widget.story, onClose: widget.onClose),
          ],
        );
      },
    );
  }
}

class _StoryVideoPlayer extends StatelessWidget {
  const _StoryVideoPlayer({
    required this.controller,
    required this.recordedWithFrontCamera,
  });

  final VideoPlayerController controller;
  final bool recordedWithFrontCamera;

  @override
  Widget build(BuildContext context) {
    final size = _displayVideoSize(controller.value, fallback: Size.zero);
    if (size.width <= 0 || size.height <= 0) {
      return const Center(child: _PureWhiteProgressIndicator());
    }
    final mediaSize = MediaQuery.sizeOf(context);
    return SizedBox.expand(
      child: Center(
        child: SizedBox(
          width: double.infinity,
          height: mediaSize.height,
          child: Material(
            color: Colors.transparent,
            child: Center(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: _buildFrontCameraPlaybackCorrection(
                    recordedWithFrontCamera: recordedWithFrontCamera,
                    child: VideoPlayer(controller),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StoryViewerHeader extends StatelessWidget {
  const _StoryViewerHeader({required this.story, required this.onClose});

  final StoryItem story;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top;
    return Positioned(
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
              onPressed: onClose,
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            ProfileAvatar(
              name: story.authorName,
              imageUrl: story.authorAvatarUrl,
              radius: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    story.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    formatStoryTime(story.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryViewerControls extends StatelessWidget {
  const _StoryViewerControls({
    required this.icon,
    required this.position,
    required this.duration,
    required this.onTogglePlayback,
  });

  final IconData icon;
  final Duration position;
  final Duration duration;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.62),
                ],
                stops: const [0, 0.45, 1],
              ),
            ),
          ),
        ),
        Center(
          child: _StoryVideoControlButton(
            icon: icon,
            size: 34,
            diameter: 74,
            onTap: onTogglePlayback,
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 18 + MediaQuery.paddingOf(context).bottom,
          child: Row(
            children: [
              Text(
                formatAudioDuration(position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MediaProgressBar(
                  position: position,
                  duration: duration,
                  activeColor: Colors.white,
                  inactiveColor: Colors.white.withValues(alpha: 0.24),
                  trackHeight: 5,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                formatAudioDuration(duration),
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
    );
  }
}

class _StoryVideoControlButton extends StatelessWidget {
  const _StoryVideoControlButton({
    required this.icon,
    required this.onTap,
    this.diameter = 56,
    this.size = 28,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double diameter;
  final double size;

  @override
  Widget build(BuildContext context) {
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
