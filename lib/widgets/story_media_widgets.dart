part of '../main.dart';

class _PureWhiteProgressIndicator extends StatelessWidget {
  const _PureWhiteProgressIndicator();

  @override
  Widget build(BuildContext context) {
    return CircularProgressIndicator(
      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFFFFF)),
      backgroundColor: Colors.transparent,
      strokeWidth: 4,
    );
  }
}

class _StoryTimeTicker extends ChangeNotifier {
  Timer? _timer;

  void start() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

Widget _buildFrontCameraPlaybackCorrection({
  required bool recordedWithFrontCamera,
  required Widget child,
}) {
  if (!recordedWithFrontCamera) {
    return child;
  }
  return Transform(
    alignment: Alignment.center,
    transform: Matrix4.diagonal3Values(-1.0, 1.0, 1.0),
    child: child,
  );
}

Size _displayVideoSize(
  VideoPlayerValue value, {
  Size fallback = const Size(1, 1),
}) {
  final size = value.size;
  if (size.width <= 0 || size.height <= 0) {
    return fallback;
  }
  return size;
}

double? _displayVideoAspectRatio(VideoPlayerValue value) {
  final size = _displayVideoSize(value, fallback: Size.zero);
  if (size.width <= 0 || size.height <= 0) {
    return null;
  }
  return size.width / size.height;
}

MediaDimensions? _displayVideoDimensions(VideoPlayerValue value) {
  final size = _displayVideoSize(value, fallback: Size.zero);
  if (size.width <= 0 || size.height <= 0) {
    return null;
  }
  return MediaDimensions(
    width: size.width.round(),
    height: size.height.round(),
  );
}

class _StoryVideoPreview extends StatefulWidget {
  const _StoryVideoPreview({
    required this.url,
    required this.onReady,
    required this.recordedWithFrontCamera,
  });

  final String url;
  final VoidCallback onReady;
  final bool recordedWithFrontCamera;

  @override
  State<_StoryVideoPreview> createState() => _StoryVideoPreviewState();
}

class _StoryVideoPreviewState extends State<_StoryVideoPreview> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  @override
  void didUpdateWidget(covariant _StoryVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      final oldController = _controller;
      _controller = null;
      if (oldController != null) {
        unawaited(oldController.dispose());
      }
      _initializePreview();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  void _initializePreview() {
    if (widget.url.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onReady();
        }
      });
      return;
    }
    _initializeFuture = _createStoryVideoController(widget.url)
        .then((controller) async {
          if (!mounted) {
            await controller.dispose();
            return;
          }
          _controller = controller;
          await controller.setVolume(0);
          await controller.pause();
          if (mounted) {
            widget.onReady();
            setState(() {});
          }
        })
        .catchError((Object error, StackTrace stackTrace) {
          if (mounted) {
            widget.onReady();
          }
          Error.throwWithStackTrace(error, stackTrace);
        });
  }

  @override
  Widget build(BuildContext context) {
    final future = _initializeFuture;
    if (future == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Icon(Icons.videocam_off_rounded, color: Colors.white),
        ),
      );
    }
    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        final controller = _controller;
        if (snapshot.hasError) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(
              child: Icon(Icons.videocam_off_rounded, color: Colors.white),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done ||
            controller == null ||
            !controller.value.isInitialized) {
          return const ColoredBox(color: Colors.black);
        }
        final displaySize = _displayVideoSize(controller.value);
        return FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: displaySize.width,
            height: displaySize.height,
            child: _buildFrontCameraPlaybackCorrection(
              recordedWithFrontCamera: widget.recordedWithFrontCamera,
              child: VideoPlayer(controller),
            ),
          ),
        );
      },
    );
  }
}

Future<VideoPlayerController> _createStoryVideoController(String rawUrl) async {
  final sourceUrl = rawUrl.trim();
  if (sourceUrl.isEmpty) {
    throw Exception('Story video URL is empty');
  }
  final networkController = VideoPlayerController.networkUrl(
    Uri.parse(sourceUrl),
    httpHeaders: serverMediaHttpHeadersFor(sourceUrl, forVideo: true),
  );
  try {
    await networkController.initialize();
    return networkController;
  } catch (_) {
    await networkController.dispose();
    final cachedVideo = await _downloadStoryVideoToCache(sourceUrl);
    final fileController = VideoPlayerController.file(cachedVideo);
    await fileController.initialize();
    return fileController;
  }
}

Future<File> _downloadStoryVideoToCache(String sourceUrl) async {
  final cacheDirectory = Directory(
    '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}story_video_cache',
  );
  if (!await cacheDirectory.exists()) {
    await cacheDirectory.create(recursive: true);
  }
  final extension = _videoCacheExtensionForUrl(sourceUrl);
  final cacheFile = File(
    '${cacheDirectory.path}${Platform.pathSeparator}story_${_stableVideoCacheHash(sourceUrl).toRadixString(16)}$extension',
  );
  if (await cacheFile.exists() && await cacheFile.length() > 0) {
    return cacheFile;
  }
  final partialCacheFile = File('${cacheFile.path}.part');
  try {
    if (await partialCacheFile.exists()) {
      await partialCacheFile.delete();
    }
  } catch (_) {}

  final request = http.Request('GET', Uri.parse(sourceUrl));
  request.headers.addAll(serverMediaHttpHeadersFor(sourceUrl, forVideo: true));
  final response = await _sharedUtilityHttpClient
      .send(request)
      .timeout(networkTimeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Story video download failed');
  }

  IOSink? sink;
  try {
    sink = partialCacheFile.openWrite();
    await for (final chunk in response.stream.timeout(networkTimeout)) {
      sink.add(chunk);
    }
    await sink.flush();
    await sink.close();
    sink = null;
    if (await partialCacheFile.length() <= 0) {
      throw Exception('Story video download failed');
    }
    if (await cacheFile.exists()) {
      await cacheFile.delete();
    }
    await partialCacheFile.rename(cacheFile.path);
    return cacheFile;
  } catch (_) {
    try {
      await sink?.close();
    } catch (_) {}
    try {
      if (await partialCacheFile.exists()) {
        await partialCacheFile.delete();
      }
    } catch (_) {}
    rethrow;
  }
}

Future<MediaDimensions?> _readStoryVideoDimensions(String filePath) async {
  try {
    final controller = VideoPlayerController.file(File(filePath));
    try {
      await controller.initialize();
      return _displayVideoDimensions(controller.value);
    } finally {
      await controller.dispose();
    }
  } catch (_) {
    return null;
  }
}

String _storyVideoUploadName(String fileName, MediaDimensions dimensions) {
  final extension = fileName.contains('.') ? fileName.split('.').last : 'mp4';
  final baseName = fileName.contains('.')
      ? fileName.substring(0, fileName.lastIndexOf('.'))
      : fileName;
  return '${baseName}_dim${dimensions.width}x${dimensions.height}.$extension';
}

Future<void> _deleteStoryTempFile(String path) async {
  final normalized = path.trim();
  if (normalized.isEmpty) {
    return;
  }
  try {
    final file = File(normalized);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {}
}

String formatStoryTime(DateTime value) {
  final localValue = value.toLocal();
  final now = DateTime.now();
  final difference = now.difference(localValue);
  if (difference.inMinutes < 1) {
    return 'Только что';
  }
  if (difference.inHours < 1) {
    return '${difference.inMinutes} мин назад';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} ч назад';
  }
  return formatChatDayLabel(localValue);
}

String formatCompactDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
