part of '../main.dart';

class StoryCreateScreen extends StatefulWidget {
  const StoryCreateScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  State<StoryCreateScreen> createState() => _StoryCreateScreenState();
}

class _StoryCreateScreenState extends State<StoryCreateScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  bool _isPreparingCamera = false;
  bool _isRecording = false;
  bool _isUploading = false;
  bool _isSwitchingCamera = false;
  bool _isKeepingScreenAwake = false;
  bool _recordingUsedFrontCamera = false;
  bool _recordingUsedBackCamera = false;
  int _cameraIndex = 0;

  bool get _isBusy =>
      _isPreparingCamera || _isRecording || _isUploading || _isSwitchingCamera;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_prepareCamera());
      }
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    final controller = _cameraController;
    _cameraController = null;
    unawaited(_setStoryScreenAwake(false));
    if (controller != null) {
      unawaited(_disposeCamera(controller));
    }
    super.dispose();
  }

  Future<void> _setStoryScreenAwake(bool enabled) async {
    if (_isKeepingScreenAwake == enabled) {
      return;
    }
    _isKeepingScreenAwake = enabled;
    try {
      await MessengerController._deviceChannel.invokeMethod<void>(
        enabled ? 'keepScreenOn' : 'allowScreenOff',
      );
    } catch (_) {}
  }

  Future<void> _disposeCamera(CameraController controller) async {
    try {
      if (controller.value.isRecordingVideo) {
        final recording = await controller.stopVideoRecording();
        await _deleteStoryTempFile(recording.path);
      }
    } catch (_) {}
    try {
      await controller.unlockCaptureOrientation();
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _ensureStoryRecordingPermissions() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      throw Exception('Разрешите доступ к камере');
    }
    final microphoneStatus = await Permission.microphone.request();
    if (!microphoneStatus.isGranted) {
      throw Exception('Разрешите доступ к микрофону');
    }
  }

  Future<void> _prepareCamera() async {
    if (_isBusy || _cameraController != null) {
      return;
    }
    setState(() {
      _isPreparingCamera = true;
    });
    var shouldStartRecording = false;
    try {
      await _ensureStoryRecordingPermissions();
      final cameras = _cameras ??= await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('Камера не найдена');
      }
      final backIndex = cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      _cameraIndex = backIndex >= 0 ? backIndex : 0;
      final controller = CameraController(
        cameras[_cameraIndex],
        ResolutionPreset.medium,
        enableAudio: true,
        fps: 30,
        videoBitrate: 2600 * 1000,
        audioBitrate: 96 * 1000,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {}
      try {
        await controller.prepareForVideoRecording();
      } catch (_) {}
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _setStoryScreenAwake(true);
      setState(() {
        _cameraController = controller;
      });
      shouldStartRecording = true;
    } catch (error) {
      if (mounted) {
        showError(context, error, fallbackMessage: 'Не удалось открыть камеру');
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingCamera = false;
        });
      }
      if (shouldStartRecording && mounted) {
        unawaited(_startRecording());
      }
    }
  }

  int _nextCameraIndex(
    List<CameraDescription> cameras,
    CameraLensDirection currentDirection,
  ) {
    final preferredDirection = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final preferredIndex = cameras.indexWhere(
      (camera) => camera.lensDirection == preferredDirection,
    );
    if (preferredIndex >= 0) {
      return preferredIndex;
    }
    final differentDirectionIndex = cameras.indexWhere(
      (camera) => camera.lensDirection != currentDirection,
    );
    if (differentDirectionIndex >= 0) {
      return differentDirectionIndex;
    }
    return (_cameraIndex + 1) % cameras.length;
  }

  Future<void> _switchCamera() async {
    final cameras = _cameras;
    final controller = _cameraController;
    if (_isPreparingCamera ||
        _isUploading ||
        _isSwitchingCamera ||
        cameras == null ||
        cameras.length < 2 ||
        controller == null) {
      return;
    }
    setState(() {
      _isSwitchingCamera = true;
    });
    try {
      final nextIndex = _nextCameraIndex(
        cameras,
        controller.description.lensDirection,
      );
      await controller.setDescription(cameras[nextIndex]);
      _cameraIndex = nextIndex;
      if (controller.value.isRecordingVideo) {
        _markStoryRecordingCamera(cameras[nextIndex]);
      }
      if (!controller.value.isRecordingVideo) {
        try {
          await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
        } catch (_) {}
        try {
          await controller.prepareForVideoRecording();
        } catch (_) {}
      }
      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      if (mounted) {
        showError(context, error, fallbackMessage: 'Не удалось сменить камеру');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Future<void> _exitRecording() async {
    if (_isUploading) {
      return;
    }
    _recordingTimer?.cancel();
    final controller = _cameraController;
    if (mounted) {
      setState(() {
        _cameraController = null;
        _isRecording = false;
        _isSwitchingCamera = false;
        _resetStoryRecordingCameras();
        _recordingDuration = Duration.zero;
      });
    } else {
      _cameraController = null;
      _isRecording = false;
      _isSwitchingCamera = false;
      _resetStoryRecordingCameras();
      _recordingDuration = Duration.zero;
    }
    await _setStoryScreenAwake(false);
    if (controller != null) {
      await _disposeCamera(controller);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _startRecording() async {
    final controller = _cameraController;
    if (_isBusy || controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      _resetStoryRecordingCameras();
      _markStoryRecordingCamera(controller.description);
      await controller.startVideoRecording(enablePersistentRecording: true);
      if (!mounted) {
        return;
      }
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecording) {
          return;
        }
        setState(() {
          _recordingDuration = Duration(
            seconds: _recordingDuration.inSeconds + 1,
          );
        });
      });
    } catch (error) {
      _resetStoryRecordingCameras();
      if (mounted) {
        showError(context, error, fallbackMessage: 'Не удалось начать запись');
      }
    }
  }

  Future<void> _stopRecording() async {
    final controller = _cameraController;
    if (!_isRecording || controller == null) {
      return;
    }
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _isUploading = true;
    });
    String? recordedPath;
    try {
      final recordedWithFrontCamera =
          controller.description.lensDirection == CameraLensDirection.front;
      final cameraSuffix = _storyRecordingCameraSuffix(
        fallbackFrontCamera: recordedWithFrontCamera,
      );
      final recording = await controller.stopVideoRecording();
      recordedPath = recording.path;
      await _uploadVideo(
        recording.path,
        _storyRecordedFileName(cameraSuffix: cameraSuffix),
      );
    } catch (error) {
      if (mounted) {
        showError(
          context,
          error,
          fallbackMessage: 'Не удалось создать историю',
        );
      }
    } finally {
      if (recordedPath != null) {
        await _deleteStoryTempFile(recordedPath);
      }
      if (mounted) {
        setState(() {
          _isUploading = false;
          _resetStoryRecordingCameras();
          _recordingDuration = Duration.zero;
        });
      } else {
        _resetStoryRecordingCameras();
      }
    }
  }

  Future<void> _uploadVideo(String path, String fileName) async {
    final dimensions = await _readStoryVideoDimensions(path);
    final uploadName = dimensions == null
        ? fileName
        : _storyVideoUploadName(fileName, dimensions);
    await widget.controller.createStoryVideo(
      filePath: path,
      fileName: uploadName,
    );
    if (!mounted) {
      return;
    }
    await _setStoryScreenAwake(false);
    if (!mounted) {
      return;
    }
    showSuccessToast(context, 'История создана');
    Navigator.of(context).pop();
  }

  void _resetStoryRecordingCameras() {
    _recordingUsedFrontCamera = false;
    _recordingUsedBackCamera = false;
  }

  void _markStoryRecordingCamera(CameraDescription camera) {
    if (camera.lensDirection == CameraLensDirection.front) {
      _recordingUsedFrontCamera = true;
      return;
    }
    _recordingUsedBackCamera = true;
  }

  String _storyRecordingCameraSuffix({required bool fallbackFrontCamera}) {
    if (_recordingUsedFrontCamera && _recordingUsedBackCamera) {
      return 'cammixed';
    }
    if (_recordingUsedFrontCamera) {
      return 'camfront';
    }
    if (_recordingUsedBackCamera) {
      return 'camback';
    }
    return fallbackFrontCamera ? 'camfront' : 'camback';
  }

  String _storyRecordedFileName({required String cameraSuffix}) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    return 'story_${stamp}_$cameraSuffix.mp4';
  }

  Widget _buildCameraContent() {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    final hasMultipleCameras = (_cameras?.length ?? 0) > 1;
    final isSaving = _isUploading;
    final isPreparing = _isPreparingCamera || _isSwitchingCamera;
    final canFinish =
        _isRecording &&
        !isPreparing &&
        !isSaving &&
        _recordingDuration >= const Duration(seconds: 1);
    final canSwitchCamera = !isSaving && !isPreparing && hasMultipleCameras;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: SizedBox.expand(
            child: _SafeCameraPreview(
              controller,
              mirror: false,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 28 + MediaQuery.paddingOf(context).bottom,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.52),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  formatCompactDuration(_recordingDuration),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _StoryCameraControlButton(
                    tooltip: 'Отмена',
                    backgroundColor: const Color(0xFFB84040),
                    disabledBackgroundColor: const Color(
                      0xFFB84040,
                    ).withValues(alpha: 0.42),
                    onPressed: isSaving
                        ? null
                        : () => unawaited(_exitRecording()),
                    child: const Icon(Icons.close_rounded, size: 26),
                  ),
                  const SizedBox(width: 12),
                  _StoryCameraControlButton(
                    tooltip: 'Повернуть камеру',
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.1,
                    ),
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.42,
                    ),
                    onPressed: canSwitchCamera ? _switchCamera : null,
                    child: _isSwitchingCamera
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Icon(Icons.flip_camera_ios_rounded, size: 25),
                  ),
                  const SizedBox(width: 12),
                  _StoryCameraControlButton(
                    tooltip: 'Готово',
                    backgroundColor: Colors.white,
                    disabledBackgroundColor: Colors.white.withValues(
                      alpha: 0.42,
                    ),
                    foregroundColor: const Color(0xFF172033),
                    disabledForegroundColor: const Color(
                      0xFF172033,
                    ).withValues(alpha: 0.54),
                    onPressed: canFinish
                        ? () => unawaited(_stopRecording())
                        : null,
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Color(0xFF172033),
                              strokeWidth: 2.2,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 26),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: appDarkSurfaceOverlayStyle,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _buildCameraContent(),
      ),
    );
  }
}

class _StoryCameraControlButton extends StatelessWidget {
  const _StoryCameraControlButton({
    required this.tooltip,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.disabledBackgroundColor,
    this.foregroundColor,
    this.disabledForegroundColor,
  });

  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? disabledBackgroundColor;
  final Color? foregroundColor;
  final Color? disabledForegroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor:
              backgroundColor ?? Colors.black.withValues(alpha: 0.38),
          disabledBackgroundColor:
              disabledBackgroundColor ?? Colors.black.withValues(alpha: 0.2),
          foregroundColor: foregroundColor ?? Colors.white,
          disabledForegroundColor:
              disabledForegroundColor ?? Colors.white.withValues(alpha: 0.42),
          fixedSize: const Size.square(54),
          minimumSize: const Size.square(54),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: child,
      ),
    );
  }
}
