part of '../main.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.controller,
    required this.initialContact,
  });

  final MessengerController controller;
  final ContactItem initialContact;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final FocusNode messageFocusNode = FocusNode();
  final AudioRecorder _voiceRecorder = AudioRecorder();
  final ItemScrollController _messageListController = ItemScrollController();
  late final Listenable _screenListenable;
  Timer? _voiceRecordingTimer;
  Timer? _videoNoteRecordingTimer;
  CameraController? _videoNoteCameraController;
  List<CameraDescription>? _videoNoteCameras;
  bool _isDisposingScreen = false;
  bool isSending = false;
  bool isForwardingMessage = false;
  bool _isPreparingVoiceRecording = false;
  bool _isRecordingVoice = false;
  Duration _voiceRecordingDuration = Duration.zero;
  String? _voiceRecordingPath;
  String? _voiceRecordingFileName;
  bool _isPreparingVideoNoteRecording = false;
  bool _isRecordingVideoNote = false;
  bool _isStoppingVideoNoteRecording = false;
  bool _isSwitchingVideoNoteCamera = false;
  int _videoNoteRecordingGeneration = 0;
  bool _isVideoNoteFrontCamera = true;
  bool _videoNoteRecordingUsedFrontCamera = false;
  bool _videoNoteRecordingUsedBackCamera = false;
  CameraLensDirection _videoNotePreferredCameraDirection =
      CameraLensDirection.front;
  Duration _videoNoteRecordingDuration = Duration.zero;
  String? _videoNoteRecordingPath;
  String? _videoNoteRecordingFileName;
  bool _pendingAttachmentUploadFailed = false;
  AttachmentUploadCancelToken? _pendingAttachmentUploadCancelToken;
  ChatMessage? editingMessage;
  ChatMessage? replyingMessage;
  int? _highlightedMessageId;
  int _highlightPulse = 0;
  _ComposerAttachmentDraft? pendingAttachment;

  ContactItem get contact =>
      widget.controller.contactById(widget.initialContact.userId) ??
      widget.initialContact;

  bool get _isVoiceRecordingBusy =>
      _isPreparingVoiceRecording || _isRecordingVoice;

  bool get _isVideoNoteRecordingBusy =>
      _isPreparingVideoNoteRecording ||
      _isRecordingVideoNote ||
      _isStoppingVideoNoteRecording ||
      _isSwitchingVideoNoteCamera;

  bool get _isMediaRecordingBusy =>
      _isVoiceRecordingBusy || _isVideoNoteRecordingBusy;

  Future<void> _deleteFileIfExists(String? path) async {
    final resolvedPath = path?.trim() ?? '';
    if (resolvedPath.isEmpty) {
      return;
    }
    try {
      final file = File(resolvedPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _disposeTemporaryAttachmentDraft(
    _ComposerAttachmentDraft? draft,
  ) async {
    if (draft == null || !draft.isTemporaryFile) {
      return;
    }
    await _deleteFileIfExists(draft.path);
  }

  void _replacePendingAttachment(_ComposerAttachmentDraft? nextDraft) {
    final previousDraft = pendingAttachment;
    setState(() {
      pendingAttachment = nextDraft;
      _pendingAttachmentUploadFailed = false;
    });
    if (nextDraft != null) {
      messageFocusNode.unfocus();
    }
    if (!identical(previousDraft, nextDraft)) {
      unawaited(_disposeTemporaryAttachmentDraft(previousDraft));
    }
  }

  Future<({String path, String fileName})>
  _buildVoiceRecordingDestination() async {
    final tempDirectory = await getTemporaryDirectory();
    final voiceDirectory = Directory(
      '${tempDirectory.path}${Platform.pathSeparator}voice_messages',
    );
    if (!await voiceDirectory.exists()) {
      await voiceDirectory.create(recursive: true);
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'voice_message_$stamp.m4a';
    return (
      path: '${voiceDirectory.path}${Platform.pathSeparator}$fileName',
      fileName: fileName,
    );
  }

  String _voiceRecordingUploadName(String fileName, Duration duration) {
    final extension = fileName.contains('.') ? fileName.split('.').last : 'm4a';
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final seconds = math.max(1, duration.inSeconds);
    return '${baseName}_dur${seconds}s.$extension';
  }

  String _mediaDimensionsUploadName(
    String fileName,
    MediaDimensions dimensions,
  ) {
    final extension = fileName.contains('.') ? fileName.split('.').last : '';
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    final suffix = 'dim${dimensions.width}x${dimensions.height}';
    if (extension.isEmpty) {
      return '${baseName}_$suffix';
    }
    return '${baseName}_$suffix.$extension';
  }

  String _videoNoteUploadName(String fileName, {required String cameraSuffix}) {
    final extension = fileName.contains('.') ? fileName.split('.').last : 'mp4';
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;
    return '${baseName}_$cameraSuffix.$extension';
  }

  Future<MediaDimensions?> _readMediaDimensions(
    String filePath,
    _ComposerAttachmentKind kind,
  ) async {
    try {
      if (kind == _ComposerAttachmentKind.image) {
        final bytes = await File(filePath).readAsBytes();
        final codec = await instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final dimensions = MediaDimensions(
          width: image.width,
          height: image.height,
        );
        image.dispose();
        codec.dispose();
        return dimensions;
      }
      if (kind == _ComposerAttachmentKind.video) {
        final controller = VideoPlayerController.file(File(filePath));
        try {
          await controller.initialize();
          return _displayVideoDimensions(controller.value);
        } finally {
          await controller.dispose();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<({String path, String fileName})>
  _buildVideoNoteRecordingDestination() async {
    final tempDirectory = await getTemporaryDirectory();
    final videoNoteDirectory = Directory(
      '${tempDirectory.path}${Platform.pathSeparator}video_notes',
    );
    if (!await videoNoteDirectory.exists()) {
      await videoNoteDirectory.create(recursive: true);
    }
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'video_note_$stamp.mp4';
    return (
      path: '${videoNoteDirectory.path}${Platform.pathSeparator}$fileName',
      fileName: fileName,
    );
  }

  Future<void> _ensureVideoNotePermissions() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw Exception('Нужен доступ к микрофону');
    }
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      throw Exception('Нужен доступ к камере');
    }
  }

  CameraDescription? _cameraForLensDirection(
    List<CameraDescription> cameras,
    CameraLensDirection lensDirection,
  ) {
    for (final camera in cameras) {
      if (camera.lensDirection == lensDirection) {
        return camera;
      }
    }
    return null;
  }

  Future<List<CameraDescription>> _availableVideoNoteCameras() async {
    final cameras = _videoNoteCameras ??= await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('Не удалось открыть камеру');
    }
    return cameras;
  }

  Future<CameraDescription> _resolveVideoNoteCamera([
    CameraLensDirection? preferredDirection,
  ]) async {
    final cameras = await _availableVideoNoteCameras();
    final preferredCamera = _cameraForLensDirection(
      cameras,
      preferredDirection ?? _videoNotePreferredCameraDirection,
    );
    if (preferredCamera != null) {
      return preferredCamera;
    }
    return _cameraForLensDirection(cameras, CameraLensDirection.front) ??
        cameras.first;
  }

  Future<CameraDescription?> _resolveNextVideoNoteCamera() async {
    final cameras = await _availableVideoNoteCameras();
    if (cameras.length < 2) {
      return null;
    }
    final currentDirection = _isVideoNoteFrontCamera
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final preferredDirection = currentDirection == CameraLensDirection.front
        ? CameraLensDirection.back
        : CameraLensDirection.front;
    final preferredCamera = _cameraForLensDirection(
      cameras,
      preferredDirection,
    );
    if (preferredCamera != null) {
      return preferredCamera;
    }
    for (final camera in cameras) {
      if (camera.lensDirection != currentDirection) {
        return camera;
      }
    }
    return cameras.first;
  }

  Future<CameraController> _createVideoNoteCameraController(
    CameraDescription camera,
  ) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      fps: 30,
      videoBitrate: 2400 * 1000,
      audioBitrate: 96 * 1000,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    try {
      await controller.initialize();
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {}
      try {
        await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      } catch (_) {}
      try {
        await controller.prepareForVideoRecording();
      } catch (_) {}
      return controller;
    } catch (_) {
      await _disposeVideoNoteCameraController(controller);
      rethrow;
    }
  }

  Future<void> _disposeVideoNoteCameraController([
    CameraController? controller,
  ]) async {
    final resolvedController = controller ?? _videoNoteCameraController;
    if (resolvedController == null) {
      return;
    }
    if (identical(_videoNoteCameraController, resolvedController)) {
      _videoNoteCameraController = null;
      if (mounted && !_isDisposingScreen) {
        setState(() {});
        await WidgetsBinding.instance.endOfFrame;
      }
    }
    try {
      await resolvedController.dispose();
    } catch (_) {}
  }

  Future<void> _deleteCameraRecordingFile(XFile? recording) async {
    final path = recording?.path.trim() ?? '';
    if (path.isEmpty) {
      return;
    }
    await _deleteFileIfExists(path);
  }

  void _resetVideoNoteCameraPreference() {
    _isVideoNoteFrontCamera = true;
    _videoNoteRecordingUsedFrontCamera = false;
    _videoNoteRecordingUsedBackCamera = false;
    _videoNotePreferredCameraDirection = CameraLensDirection.front;
  }

  void _markVideoNoteRecordingCamera(CameraDescription camera) {
    if (camera.lensDirection == CameraLensDirection.front) {
      _videoNoteRecordingUsedFrontCamera = true;
      return;
    }
    _videoNoteRecordingUsedBackCamera = true;
  }

  String _videoNoteRecordingCameraSuffix({required bool fallbackFrontCamera}) {
    if (_videoNoteRecordingUsedFrontCamera &&
        _videoNoteRecordingUsedBackCamera) {
      return 'cammixed';
    }
    if (_videoNoteRecordingUsedFrontCamera) {
      return 'camfront';
    }
    if (_videoNoteRecordingUsedBackCamera) {
      return 'camback';
    }
    return fallbackFrontCamera ? 'camfront' : 'camback';
  }

  void _startVoiceRecordingTicker() {
    _voiceRecordingTimer?.cancel();
    _voiceRecordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecordingVoice) {
        return;
      }
      setState(() {
        _voiceRecordingDuration = Duration(
          seconds: _voiceRecordingDuration.inSeconds + 1,
        );
      });
    });
  }

  Future<void> _startVoiceRecording() async {
    if (isSending ||
        editingMessage != null ||
        pendingAttachment != null ||
        _isMediaRecordingBusy) {
      return;
    }
    setState(() {
      _isPreparingVoiceRecording = true;
      _pendingAttachmentUploadFailed = false;
    });
    ({String path, String fileName})? destination;
    try {
      if (!await _voiceRecorder.hasPermission()) {
        throw Exception('Нужен доступ к микрофону');
      }
      if (!await _voiceRecorder.isEncoderSupported(AudioEncoder.aacLc)) {
        throw Exception('Запись аудио не поддерживается на этом устройстве');
      }
      destination = await _buildVoiceRecordingDestination();
      await _voiceRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
        path: destination.path,
      );
      if (!mounted) {
        await _voiceRecorder.stop();
        await _deleteFileIfExists(destination.path);
        return;
      }
      setState(() {
        _isPreparingVoiceRecording = false;
        _isRecordingVoice = true;
        _voiceRecordingDuration = Duration.zero;
        _voiceRecordingPath = destination?.path;
        _voiceRecordingFileName = destination?.fileName;
      });
      _startVoiceRecordingTicker();
    } catch (error) {
      if (destination != null) {
        await _deleteFileIfExists(destination.path);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingVoiceRecording = false;
        _isRecordingVoice = false;
        _voiceRecordingDuration = Duration.zero;
        _voiceRecordingPath = null;
        _voiceRecordingFileName = null;
      });
      showError(context, error, fallbackMessage: 'Не удалось начать запись');
    }
  }

  Future<void> _stopVoiceRecording() async {
    if (!_isRecordingVoice || _isPreparingVoiceRecording) {
      return;
    }
    final recordingPath = _voiceRecordingPath;
    final recordingFileName = _voiceRecordingFileName;
    _voiceRecordingTimer?.cancel();
    setState(() {
      _isPreparingVoiceRecording = true;
    });
    try {
      final stoppedPath = await _voiceRecorder.stop();
      final resolvedPath = (stoppedPath?.trim().isNotEmpty ?? false)
          ? stoppedPath!.trim()
          : (recordingPath ?? '');
      if (resolvedPath.isEmpty) {
        throw Exception('Не удалось сохранить голосовое сообщение');
      }
      final file = File(resolvedPath);
      if (!await file.exists()) {
        throw Exception('Не удалось открыть голосовое сообщение');
      }
      final nextDraft = _ComposerAttachmentDraft(
        path: resolvedPath,
        name: _voiceRecordingUploadName(
          (recordingFileName?.trim().isNotEmpty ?? false)
              ? recordingFileName!
              : file.uri.pathSegments.last,
          _voiceRecordingDuration,
        ),
        sizeBytes: await file.length(),
        kind: _ComposerAttachmentKind.audio,
        duration: _voiceRecordingDuration,
        isVoiceMessage: true,
        isTemporaryFile: true,
      );
      if (!mounted) {
        await _disposeTemporaryAttachmentDraft(nextDraft);
        return;
      }
      final previousDraft = pendingAttachment;
      setState(() {
        _isPreparingVoiceRecording = false;
        _isRecordingVoice = false;
        _voiceRecordingDuration = Duration.zero;
        _voiceRecordingPath = null;
        _voiceRecordingFileName = null;
        pendingAttachment = nextDraft;
        _pendingAttachmentUploadFailed = false;
      });
      unawaited(_disposeTemporaryAttachmentDraft(previousDraft));
      messageFocusNode.unfocus();
    } catch (error) {
      if (recordingPath != null) {
        await _deleteFileIfExists(recordingPath);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _isPreparingVoiceRecording = false;
        _isRecordingVoice = false;
        _voiceRecordingDuration = Duration.zero;
        _voiceRecordingPath = null;
        _voiceRecordingFileName = null;
      });
      showError(
        context,
        error,
        fallbackMessage: 'Не удалось сохранить голосовое сообщение',
      );
    }
  }

  Future<void> _cancelVoiceRecording() async {
    if (!_isVoiceRecordingBusy) {
      return;
    }
    final recordingPath = _voiceRecordingPath;
    _voiceRecordingTimer?.cancel();
    try {
      await _voiceRecorder.cancel();
    } catch (_) {
      await _deleteFileIfExists(recordingPath);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _isPreparingVoiceRecording = false;
      _isRecordingVoice = false;
      _voiceRecordingDuration = Duration.zero;
      _voiceRecordingPath = null;
      _voiceRecordingFileName = null;
    });
    await _deleteFileIfExists(recordingPath);
  }

  void _startVideoNoteRecordingTicker() {
    _videoNoteRecordingTimer?.cancel();
    _videoNoteRecordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_isRecordingVideoNote) {
        return;
      }
      setState(() {
        _videoNoteRecordingDuration = Duration(
          seconds: _videoNoteRecordingDuration.inSeconds + 1,
        );
      });
    });
  }

  Future<void> _startVideoNoteRecording() async {
    if (isSending ||
        editingMessage != null ||
        pendingAttachment != null ||
        _isMediaRecordingBusy ||
        widget.controller.activeCall != null) {
      return;
    }
    final generation = ++_videoNoteRecordingGeneration;
    setState(() {
      _resetVideoNoteCameraPreference();
      _isPreparingVideoNoteRecording = true;
      _isSwitchingVideoNoteCamera = false;
      _videoNoteRecordingDuration = Duration.zero;
      _pendingAttachmentUploadFailed = false;
    });
    ({String path, String fileName})? destination;
    CameraController? controller;
    XFile? stoppedRecording;
    try {
      await _ensureVideoNotePermissions();
      destination = await _buildVideoNoteRecordingDestination();
      await _deleteFileIfExists(destination.path);
      if (!mounted || generation != _videoNoteRecordingGeneration) {
        await _deleteFileIfExists(destination.path);
        return;
      }
      final camera = await _resolveVideoNoteCamera();
      controller = await _createVideoNoteCameraController(camera);
      _markVideoNoteRecordingCamera(camera);
      if (!mounted || generation != _videoNoteRecordingGeneration) {
        await _disposeVideoNoteCameraController(controller);
        await _deleteFileIfExists(destination.path);
        return;
      }
      await controller.startVideoRecording(enablePersistentRecording: true);
      if (!mounted || generation != _videoNoteRecordingGeneration) {
        try {
          stoppedRecording = await controller.stopVideoRecording();
        } catch (_) {}
        await _deleteCameraRecordingFile(stoppedRecording);
        await _disposeVideoNoteCameraController(controller);
        await _deleteFileIfExists(destination.path);
        return;
      }
      setState(() {
        _videoNoteCameraController = controller;
        _isVideoNoteFrontCamera =
            camera.lensDirection == CameraLensDirection.front;
        _videoNotePreferredCameraDirection = camera.lensDirection;
        _isPreparingVideoNoteRecording = false;
        _isRecordingVideoNote = true;
        _isStoppingVideoNoteRecording = false;
        _isSwitchingVideoNoteCamera = false;
        _videoNoteRecordingDuration = Duration.zero;
        _videoNoteRecordingPath = destination?.path;
        _videoNoteRecordingFileName = destination?.fileName;
      });
      _startVideoNoteRecordingTicker();
    } catch (error) {
      final wasCanceled = generation != _videoNoteRecordingGeneration;
      if (controller?.value.isRecordingVideo ?? false) {
        try {
          stoppedRecording = await controller?.stopVideoRecording();
        } catch (_) {}
      }
      await _deleteCameraRecordingFile(stoppedRecording);
      await _disposeVideoNoteCameraController(controller);
      if (destination != null) {
        await _deleteFileIfExists(destination.path);
      }
      if (!mounted || wasCanceled) {
        return;
      }
      setState(() {
        _resetVideoNoteCameraPreference();
        _isPreparingVideoNoteRecording = false;
        _isRecordingVideoNote = false;
        _isStoppingVideoNoteRecording = false;
        _isSwitchingVideoNoteCamera = false;
        _videoNoteRecordingDuration = Duration.zero;
        _videoNoteRecordingPath = null;
        _videoNoteRecordingFileName = null;
      });
      showError(
        context,
        error,
        fallbackMessage: 'Не удалось начать запись кружка',
      );
    }
  }

  Future<void> _switchVideoNoteCamera() async {
    if (!_isRecordingVideoNote ||
        _isStoppingVideoNoteRecording ||
        _isSwitchingVideoNoteCamera) {
      return;
    }
    final currentController = _videoNoteCameraController;
    if (currentController == null) {
      return;
    }
    final generation = _videoNoteRecordingGeneration;
    setState(() {
      _isSwitchingVideoNoteCamera = true;
    });
    try {
      final nextCamera = await _resolveNextVideoNoteCamera();
      if (nextCamera == null) {
        throw Exception('Не удалось повернуть камеру');
      }
      await currentController.setDescription(nextCamera);
      if (!mounted || generation != _videoNoteRecordingGeneration) {
        return;
      }
      _markVideoNoteRecordingCamera(nextCamera);
      setState(() {
        _isVideoNoteFrontCamera =
            nextCamera.lensDirection == CameraLensDirection.front;
        _isSwitchingVideoNoteCamera = false;
      });
    } catch (error) {
      if (!mounted || generation != _videoNoteRecordingGeneration) {
        return;
      }
      setState(() {
        _isSwitchingVideoNoteCamera = false;
      });
      showError(context, error, fallbackMessage: 'Не удалось повернуть камеру');
    }
  }

  Future<void> _stopVideoNoteRecording() async {
    if (!_isRecordingVideoNote || _isStoppingVideoNoteRecording) {
      return;
    }
    final recordingPath = _videoNoteRecordingPath;
    final recordingFileName = _videoNoteRecordingFileName;
    final controller = _videoNoteCameraController;
    final recordedWithFrontCamera = _isVideoNoteFrontCamera;
    final cameraSuffix = _videoNoteRecordingCameraSuffix(
      fallbackFrontCamera: recordedWithFrontCamera,
    );
    _videoNoteRecordingTimer?.cancel();
    setState(() {
      _isStoppingVideoNoteRecording = true;
    });
    try {
      if (controller == null || !controller.value.isRecordingVideo) {
        throw Exception('Не удалось остановить запись');
      }
      final stoppedRecording = await controller.stopVideoRecording();
      await _disposeVideoNoteCameraController(controller);
      final resolvedPath = recordingPath?.trim() ?? '';
      if (resolvedPath.isEmpty) {
        throw Exception('Не удалось сохранить видео кружок');
      }
      final sourceFile = File(stoppedRecording.path);
      if (!await sourceFile.exists() || await sourceFile.length() <= 0) {
        throw Exception('Не удалось открыть видео кружок');
      }
      final file = File(resolvedPath);
      await file.parent.create(recursive: true);
      if (sourceFile.path != file.path) {
        if (await file.exists()) {
          await file.delete();
        }
        await sourceFile.copy(file.path);
        await _deleteFileIfExists(sourceFile.path);
      }
      if (!await file.exists() || await file.length() <= 0) {
        throw Exception('Не удалось сохранить видео кружок');
      }
      final nextDraft = _ComposerAttachmentDraft(
        path: resolvedPath,
        name: _videoNoteUploadName(
          (recordingFileName?.trim().isNotEmpty ?? false)
              ? recordingFileName!
              : file.uri.pathSegments.last,
          cameraSuffix: cameraSuffix,
        ),
        sizeBytes: await file.length(),
        kind: _ComposerAttachmentKind.video,
        duration: _videoNoteRecordingDuration,
        isVideoNote: true,
        isTemporaryFile: true,
      );
      if (!mounted) {
        await _disposeTemporaryAttachmentDraft(nextDraft);
        return;
      }
      final previousDraft = pendingAttachment;
      setState(() {
        _resetVideoNoteCameraPreference();
        _isPreparingVideoNoteRecording = false;
        _isRecordingVideoNote = false;
        _isStoppingVideoNoteRecording = false;
        _isSwitchingVideoNoteCamera = false;
        _videoNoteRecordingDuration = Duration.zero;
        _videoNoteRecordingPath = null;
        _videoNoteRecordingFileName = null;
        pendingAttachment = nextDraft;
        _pendingAttachmentUploadFailed = false;
      });
      unawaited(_disposeTemporaryAttachmentDraft(previousDraft));
      messageFocusNode.unfocus();
    } catch (error) {
      await _disposeVideoNoteCameraController(controller);
      await _deleteFileIfExists(recordingPath);
      if (!mounted) {
        return;
      }
      setState(() {
        _resetVideoNoteCameraPreference();
        _isPreparingVideoNoteRecording = false;
        _isRecordingVideoNote = false;
        _isStoppingVideoNoteRecording = false;
        _isSwitchingVideoNoteCamera = false;
        _videoNoteRecordingDuration = Duration.zero;
        _videoNoteRecordingPath = null;
        _videoNoteRecordingFileName = null;
      });
      showError(
        context,
        error,
        fallbackMessage: 'Не удалось сохранить видео кружок',
      );
    }
  }

  Future<void> _cancelVideoNoteRecording() async {
    if (!_isVideoNoteRecordingBusy) {
      return;
    }
    _videoNoteRecordingGeneration++;
    final recordingPath = _videoNoteRecordingPath;
    final controller = _videoNoteCameraController;
    _videoNoteRecordingTimer?.cancel();
    XFile? stoppedRecording;
    try {
      if (controller?.value.isRecordingVideo ?? false) {
        stoppedRecording = await controller?.stopVideoRecording();
      }
    } catch (_) {}
    await _deleteCameraRecordingFile(stoppedRecording);
    await _disposeVideoNoteCameraController(controller);
    await _deleteFileIfExists(recordingPath);
    if (!mounted) {
      return;
    }
    setState(() {
      _resetVideoNoteCameraPreference();
      _isPreparingVideoNoteRecording = false;
      _isRecordingVideoNote = false;
      _isStoppingVideoNoteRecording = false;
      _isSwitchingVideoNoteCamera = false;
      _videoNoteRecordingDuration = Duration.zero;
      _videoNoteRecordingPath = null;
      _videoNoteRecordingFileName = null;
    });
  }

  Future<void> _disposeVideoNoteRecordingResources() async {
    _videoNoteRecordingGeneration++;
    _videoNoteRecordingTimer?.cancel();
    final controller = _videoNoteCameraController;
    final recordingPath = _videoNoteRecordingPath;
    XFile? stoppedRecording;
    try {
      if (controller?.value.isRecordingVideo ?? false) {
        stoppedRecording = await controller?.stopVideoRecording();
      }
    } catch (_) {}
    await _deleteCameraRecordingFile(stoppedRecording);
    await _disposeVideoNoteCameraController(controller);
    await _deleteFileIfExists(recordingPath);
  }

  @override
  void initState() {
    super.initState();
    _screenListenable = Listenable.merge(<Listenable>[
      widget.controller.sessionListenable,
      widget.controller.callListenable,
      widget.controller.contactListenable(widget.initialContact.userId),
      widget.controller.conversationListenable(widget.initialContact.userId),
    ]);
    final savedDraft = widget.controller.draftFor(widget.initialContact.userId);
    if (savedDraft.isNotEmpty) {
      messageController.text = savedDraft;
      messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: messageController.text.length),
      );
    }
    messageController.addListener(_handleComposerTextChanged);
    widget.controller.openConversation(widget.initialContact.userId);
  }

  @override
  void dispose() {
    _isDisposingScreen = true;
    messageController.removeListener(_handleComposerTextChanged);
    _voiceRecordingTimer?.cancel();
    _videoNoteRecordingTimer?.cancel();
    _pendingAttachmentUploadCancelToken?.cancel();
    unawaited(_voiceRecorder.cancel());
    _voiceRecorder.dispose();
    unawaited(_deleteFileIfExists(_voiceRecordingPath));
    unawaited(_disposeVideoNoteRecordingResources());
    unawaited(_disposeTemporaryAttachmentDraft(pendingAttachment));
    unawaited(
      widget.controller.updateTypingState(
        widget.initialContact.userId,
        isTyping: false,
      ),
    );
    if (editingMessage == null) {
      widget.controller.updateMessageDraft(
        widget.initialContact.userId,
        messageController.text,
      );
    }
    widget.controller.closeConversation(widget.initialContact.userId);
    messageController.dispose();
    messageFocusNode.dispose();
    super.dispose();
  }

  String _resolveForwardedFromName(ChatMessage message) {
    final forwardedFromName = sanitizeDisplayText(
      message.forwardedFromName ?? '',
      preserveLineBreaks: false,
    ).trim();
    if (forwardedFromName.isNotEmpty) {
      return forwardedFromName;
    }
    final senderName = sanitizeDisplayText(
      message.senderName ?? '',
      preserveLineBreaks: false,
    ).trim();
    if (senderName.isNotEmpty) {
      return senderName;
    }
    final currentUserId = widget.controller.user?.id;
    if (currentUserId != null && message.isMine(currentUserId)) {
      final currentUserName = sanitizeDisplayText(
        widget.controller.user?.name ?? '',
        preserveLineBreaks: false,
      ).trim();
      if (currentUserName.isNotEmpty) {
        return currentUserName;
      }
      return 'Вы';
    }
    if (message.isGroup) {
      return 'Участник';
    }
    final contactName = sanitizeDisplayText(
      contact.name,
      preserveLineBreaks: false,
    ).trim();
    return contactName.isEmpty ? 'Неизвестно' : contactName;
  }

  String _resolveReplyAuthorName(ChatMessage message) {
    final forwardedFromName = sanitizeDisplayText(
      message.forwardedFromName ?? '',
      preserveLineBreaks: false,
    ).trim();
    if (forwardedFromName.isNotEmpty) {
      return forwardedFromName;
    }
    return _resolveForwardedFromName(message);
  }

  String _replyPreviewText(ChatMessage message) {
    return message.replyPreviewText;
  }

  String _composeOutgoingText({
    required String text,
    ChatMessage? editingTarget,
    ChatMessage? replyTarget,
  }) {
    if (editingTarget != null) {
      return encodeStructuredMessage(
        text: text,
        forwardedFromName: editingTarget.forwardedFromName,
        replyToName: editingTarget.replyToName,
        replyToText: editingTarget.replyToText,
        replyToMessageId: editingTarget.replyToMessageId,
      );
    }
    if (replyTarget != null) {
      return encodeStructuredMessage(
        text: text,
        replyToName: _resolveReplyAuthorName(replyTarget),
        replyToText: _replyPreviewText(replyTarget),
        replyToMessageId: replyTarget.id,
      );
    }
    return text;
  }

  void _startReplyingToMessage(ChatMessage message) {
    setState(() {
      editingMessage = null;
      replyingMessage = message;
    });
    messageFocusNode.requestFocus();
  }

  void _cancelReplyingMessage() {
    setState(() {
      replyingMessage = null;
    });
  }

  Future<void> _jumpToMessage(int messageId) async {
    final messages = widget.controller.messagesFor(contact.userId);
    final sortedIndex = findSortedMessageIndex(messages, messageId);
    if (sortedIndex == -1) {
      return;
    }

    await Future<void>.delayed(Duration.zero);
    if (!mounted || !_messageListController.isAttached) {
      return;
    }
    final reverseIndex = messages.length - 1 - sortedIndex;
    await _messageListController.scrollTo(
      index: reverseIndex,
      alignment: 0.32,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _highlightedMessageId = messageId;
      _highlightPulse += 1;
    });
    Future<void>.delayed(const Duration(milliseconds: 1300), () {
      if (!mounted || _highlightedMessageId != messageId) {
        return;
      }
      setState(() {
        _highlightedMessageId = null;
      });
    });
  }

  void _cancelPendingAttachment() {
    final uploadCancelToken = _pendingAttachmentUploadCancelToken;
    if (uploadCancelToken != null) {
      uploadCancelToken.cancel();
      _pendingAttachmentUploadCancelToken = null;
      if (mounted) {
        setState(() {
          isSending = false;
          _pendingAttachmentUploadFailed = false;
        });
      }
    }
    _replacePendingAttachment(null);
  }

  void _handleComposerTextChanged() {
    if (editingMessage == null) {
      widget.controller.updateMessageDraft(
        widget.initialContact.userId,
        messageController.text,
      );
    }
    if (pendingAttachment != null) {
      unawaited(
        widget.controller.updateTypingState(
          widget.initialContact.userId,
          isTyping: false,
        ),
      );
      return;
    }
    unawaited(
      widget.controller.updateTypingState(
        widget.initialContact.userId,
        isTyping: messageController.text.trim().isNotEmpty,
      ),
    );
  }

  _ComposerAttachmentKind _attachmentKindFromFileName(String name) {
    final extension = _fileExtensionFromName(name);
    if (_imageAttachmentExtensions.contains(extension)) {
      return _ComposerAttachmentKind.image;
    }
    if (_videoAttachmentExtensions.contains(extension)) {
      return _ComposerAttachmentKind.video;
    }
    if (_audioAttachmentExtensions.contains(extension)) {
      return _ComposerAttachmentKind.audio;
    }
    return _ComposerAttachmentKind.file;
  }

  String _composerAttachmentKindValue(_ComposerAttachmentKind kind) {
    return switch (kind) {
      _ComposerAttachmentKind.image => 'image',
      _ComposerAttachmentKind.video => 'video',
      _ComposerAttachmentKind.audio => 'audio',
      _ComposerAttachmentKind.file => 'file',
    };
  }

  Future<void> _send() async {
    if (isSending || _isMediaRecordingBusy) {
      return;
    }
    final text = messageController.text;
    final currentPendingAttachment = pendingAttachment;
    if (text.trim().isEmpty && currentPendingAttachment == null) {
      return;
    }
    setState(() {
      isSending = true;
      _pendingAttachmentUploadFailed = false;
    });
    final currentEditingMessage = editingMessage;
    final currentReplyingMessage = replyingMessage;
    final payloadText = _composeOutgoingText(
      text: text,
      editingTarget: currentEditingMessage,
      replyTarget: currentReplyingMessage,
    );
    AttachmentUploadCancelToken? activeUploadCancelToken;
    try {
      if (currentEditingMessage != null) {
        await widget.controller.editMessage(
          contact.userId,
          currentEditingMessage.id,
          payloadText,
        );
      } else if (currentPendingAttachment != null) {
        final uploadCancelToken = AttachmentUploadCancelToken();
        activeUploadCancelToken = uploadCancelToken;
        _pendingAttachmentUploadCancelToken = uploadCancelToken;
        await widget.controller.sendAttachmentMessage(
          contact.userId,
          filePath: currentPendingAttachment.path,
          fileName: currentPendingAttachment.name,
          text: payloadText,
          attachmentKind: _composerAttachmentKindValue(
            currentPendingAttachment.kind,
          ),
          cancelToken: uploadCancelToken,
        );
      } else {
        await widget.controller.sendMessage(contact.userId, payloadText);
      }
      if (!mounted) {
        await _disposeTemporaryAttachmentDraft(currentPendingAttachment);
        return;
      }
      setState(() {
        editingMessage = null;
        replyingMessage = null;
      });
      _replacePendingAttachment(null);
      messageController.clear();
      widget.controller.updateMessageDraft(contact.userId, '');
    } on _AttachmentUploadCanceledException {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingAttachmentUploadFailed = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (currentPendingAttachment != null) {
        setState(() {
          _pendingAttachmentUploadFailed = true;
        });
        showError(context, error);
      } else {
        showError(context, error);
      }
    } finally {
      if (activeUploadCancelToken != null &&
          identical(
            _pendingAttachmentUploadCancelToken,
            activeUploadCancelToken,
          )) {
        _pendingAttachmentUploadCancelToken = null;
      }
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  PopupMenuItem<_ComposerMenuAction> _composerMenuItem({
    required _ComposerMenuAction action,
    required IconData icon,
    required String label,
    bool enabled = true,
  }) {
    final iconColor = enabled
        ? appPrimaryColor
        : appPrimaryColor.withValues(alpha: 0.42);
    final textColor = enabled
        ? appTextColor
        : appTextColor.withValues(alpha: 0.42);
    return PopupMenuItem<_ComposerMenuAction>(
      value: action,
      enabled: enabled,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showComposerActionsMenu(BuildContext buttonContext) async {
    final canUseMediaActions =
        !isSending &&
        editingMessage == null &&
        pendingAttachment == null &&
        !_isMediaRecordingBusy;
    if (!canUseMediaActions) {
      return;
    }
    final button = buttonContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.maybeOf(context)?.context.findRenderObject() as RenderBox?;
    if (button == null ||
        overlay == null ||
        !button.hasSize ||
        !overlay.hasSize) {
      return;
    }
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(Offset.zero, ancestor: overlay),
        button.localToGlobal(
          button.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );
    final action = await showMenu<_ComposerMenuAction>(
      context: context,
      position: position,
      items: [
        _composerMenuItem(
          action: _ComposerMenuAction.videoNote,
          icon: Icons.account_circle_rounded,
          label: 'Записать кружок',
          enabled: widget.controller.activeCall == null,
        ),
        _composerMenuItem(
          action: _ComposerMenuAction.voiceMessage,
          icon: Icons.mic_rounded,
          label: 'Голосовое сообщение',
        ),
        _composerMenuItem(
          action: _ComposerMenuAction.attachFile,
          icon: Icons.attach_file_rounded,
          label: 'Прикрепить файл',
        ),
      ],
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _ComposerMenuAction.videoNote:
        unawaited(_startVideoNoteRecording());
      case _ComposerMenuAction.voiceMessage:
        unawaited(_startVoiceRecording());
      case _ComposerMenuAction.attachFile:
        unawaited(_pickAttachmentFile());
    }
  }

  Future<void> _pickAttachmentFile() async {
    if (isSending ||
        editingMessage != null ||
        pendingAttachment != null ||
        _isMediaRecordingBusy) {
      return;
    }
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (!mounted || picked == null || picked.files.isEmpty) {
      return;
    }
    final selectedFile = picked.files.single;
    final filePath = selectedFile.path;
    if (filePath == null || filePath.trim().isEmpty) {
      showError(context, Exception('Не удалось открыть файл'));
      return;
    }
    final rawSelectedFileName = selectedFile.name.trim().isEmpty
        ? File(filePath).uri.pathSegments.last
        : selectedFile.name;
    final attachmentKind = _attachmentKindFromFileName(rawSelectedFileName);
    final mediaDimensions = await _readMediaDimensions(
      filePath,
      attachmentKind,
    );
    final selectedFileName = mediaDimensions == null
        ? rawSelectedFileName
        : _mediaDimensionsUploadName(rawSelectedFileName, mediaDimensions);
    _replacePendingAttachment(
      _ComposerAttachmentDraft(
        path: filePath,
        name: selectedFileName,
        sizeBytes: selectedFile.size,
        kind: attachmentKind,
      ),
    );
  }

  void _startEditingMessage(ChatMessage message) {
    if (message.attachment != null) {
      return;
    }
    final previousDraft = pendingAttachment;
    setState(() {
      replyingMessage = null;
      pendingAttachment = null;
      _pendingAttachmentUploadFailed = false;
      editingMessage = message;
      messageController.text = message.text;
      messageController.selection = TextSelection.fromPosition(
        TextPosition(offset: messageController.text.length),
      );
    });
    unawaited(_disposeTemporaryAttachmentDraft(previousDraft));
    messageFocusNode.requestFocus();
  }

  void _cancelEditingMessage() {
    setState(() {
      editingMessage = null;
      messageController.clear();
    });
  }

  Future<void> _copyMessageText(ChatMessage message) async {
    await Clipboard.setData(ClipboardData(text: message.text));
    if (!mounted) {
      return;
    }
    showSuccessToast(context, 'Скопировано');
  }

  Future<void> _openMessageLink(ChatMessage message) async {
    final rawUrl = message.firstLink;
    final uri = rawUrl == null ? null : normalizeLinkUri(rawUrl);
    if (uri == null) {
      return;
    }
    await openExternalLink(uri);
  }

  Future<void> _openDownloadedAttachmentFile(
    MessageAttachment attachment,
  ) async {
    final file = await _downloadAttachmentForForwarding(attachment);
    final result = await OpenFilex.open(
      file.path,
      type: attachment.mimeType.trim().isEmpty ? null : attachment.mimeType,
    );
    if (result.type != ResultType.done) {
      throw Exception(
        result.message.trim().isEmpty
            ? 'Не удалось открыть файл'
            : result.message,
      );
    }
  }

  List<PreviewableAttachmentItem> _previewableAttachments() {
    final items = <PreviewableAttachmentItem>[];
    for (final message in widget.controller.messagesFor(contact.userId)) {
      final attachment = message.attachment;
      if (attachment == null ||
          !attachment.isPreviewable ||
          attachment.isVideoNote) {
        continue;
      }
      items.add(
        PreviewableAttachmentItem(
          messageId: message.id,
          attachment: attachment,
        ),
      );
    }
    return items;
  }

  Future<void> _openAttachment(ChatMessage message) async {
    final attachment = message.attachment;
    if (attachment == null ||
        !attachment.isPreviewable ||
        attachment.isVideoNote) {
      return;
    }
    final uri = Uri.tryParse(attachment.url);
    if (uri == null) {
      return;
    }
    final items = _previewableAttachments();
    final initialIndex = items.indexWhere(
      (item) => item.messageId == message.id,
    );
    if (items.isEmpty || initialIndex < 0) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) {
          return MessageAttachmentViewerScreen(
            items: items,
            initialIndex: initialIndex,
          );
        },
      ),
    );
  }

  Future<void> _downloadAttachment(MessageAttachment attachment) async {
    final targetUrl = attachment.downloadUrl.trim().isEmpty
        ? attachment.url
        : attachment.downloadUrl;
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      throw Exception('Не удалось скачать файл');
    }
    await _openDownloadedAttachmentFile(attachment);
  }

  Future<File> _downloadAttachmentForForwarding(
    MessageAttachment attachment,
  ) async {
    final targetUrl = attachment.downloadUrl.trim().isEmpty
        ? attachment.url
        : attachment.downloadUrl;
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      throw Exception('Не удалось скачать файл');
    }

    late final http.Response response;
    try {
      response = await widget.controller._httpClient
          .get(uri, headers: serverMediaHttpHeadersFor(targetUrl))
          .timeout(networkTimeout);
    } on TimeoutException {
      throw Exception('Сервер не отвечает');
    } on SocketException {
      throw Exception('Нет соединения с сервером');
    } on http.ClientException {
      throw Exception('Соединение с сервером было неожиданно закрыто');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Не удалось скачать файл');
    }
    if (response.bodyBytes.isEmpty) {
      throw Exception('Не удалось скачать файл');
    }

    final tempDirectory = await getTemporaryDirectory();
    final rawFileName = attachment.name.trim().isNotEmpty
        ? attachment.name.trim()
        : (uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'attachment');
    final normalizedFileName = rawFileName
        .replaceAll(_invalidFileNameCharacterPattern, '_')
        .trim();
    final safeFileName = normalizedFileName.isEmpty
        ? 'attachment'
        : normalizedFileName;
    final targetFile = File(
      '${tempDirectory.path}${Platform.pathSeparator}'
      '${DateTime.now().microsecondsSinceEpoch}_$safeFileName',
    );
    await targetFile.writeAsBytes(response.bodyBytes, flush: true);
    return targetFile;
  }

  String _forwardedAttachmentFileName(MessageAttachment attachment) {
    final originalName = attachment.name.trim();
    final fallbackName = switch (attachment.kind) {
      'image' => 'image.jpg',
      'video' => 'video.mp4',
      'audio' => 'audio.m4a',
      _ => 'attachment',
    };
    if (attachment.isVoiceMessage) {
      final safeName = originalName.isEmpty
          ? 'voice_message_audio.m4a'
          : originalName;
      return safeName.toLowerCase().startsWith('voice_message_')
          ? safeName
          : 'voice_message_$safeName';
    }
    if (!attachment.isVideoNote) {
      return originalName.isEmpty ? fallbackName : originalName;
    }
    final safeName = originalName.isEmpty ? 'video_note.mp4' : originalName;
    return safeName.toLowerCase().startsWith('video_note')
        ? safeName
        : 'video_note_$safeName';
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      if (editingMessage?.id == message.id) {
        _cancelEditingMessage();
      }
      await widget.controller.deleteMessage(contact.userId, message.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    }
  }

  Future<void> _clearCurrentChat() async {
    try {
      await widget.controller.clearConversation(contact.userId);
      if (!mounted) {
        return;
      }
      showSuccessToast(context, 'Чат очищен');
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    }
  }

  void _handleChatMenuAction(String action) {
    switch (action) {
      case 'audio':
        unawaited(_startAudioCall());
        return;
      case 'video':
        unawaited(_startVideoCall());
        return;
      case 'group_settings':
        unawaited(_openGroupSettings());
        return;
      case 'participants':
        unawaited(_showGroupParticipantsSheet());
        return;
      case 'clear':
        unawaited(_clearCurrentChat());
        return;
    }
  }

  Future<void> _showMessageActions(ChatMessage message, bool isMine) async {
    final hasLink = extractFirstLink(message.text) != null;
    final isServiceMessage = message.isCallHistory;
    final canForward = !isServiceMessage;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) {
        return SafeArea(
          minimum: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isMine)
                ListTile(
                  leading: const Icon(
                    Icons.delete_rounded,
                    color: appPrimaryColor,
                  ),
                  title: const Text('Удалить сообщение'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_deleteMessage(message));
                  },
                ),
              if (isMine && !isServiceMessage && message.attachment == null)
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Изменить'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _startEditingMessage(message);
                  },
                ),
              if (!isServiceMessage)
                ListTile(
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('Ответить'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _startReplyingToMessage(message);
                  },
                ),
              if (canForward)
                ListTile(
                  leading: Transform.flip(
                    flipX: true,
                    child: const Icon(Icons.reply_rounded),
                  ),
                  title: const Text('Переслать'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_forwardMessage(message));
                  },
                ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Копировать'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_copyMessageText(message));
                },
              ),
              if (message.attachment != null)
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Скачать'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(
                      _downloadAttachment(message.attachment!).catchError((
                        Object error,
                      ) {
                        if (!mounted) {
                          return;
                        }
                        showError(context, error);
                      }),
                    );
                  },
                ),
              if (hasLink)
                ListTile(
                  leading: const Icon(Icons.open_in_browser_rounded),
                  title: const Text('Открыть'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    unawaited(_openMessageLink(message));
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _forwardMessage(ChatMessage message) async {
    if (isForwardingMessage) {
      return;
    }
    final selectedContact = await showForwardMessageTargetSheet(
      context: context,
      contacts: widget.controller.contacts,
      excludedConversationIds: {contact.userId},
    );
    if (!mounted || selectedContact == null) {
      return;
    }
    showToast(context, 'Пересылка...');
    setState(() {
      isForwardingMessage = true;
    });
    File? temporaryAttachmentFile;
    var didForward = false;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 420));
      if (!mounted) {
        return;
      }
      showToast(context, 'Отправка...');
      final forwardedText = encodeStructuredMessage(
        text: message.text,
        forwardedFromName: _resolveForwardedFromName(message),
      );
      final attachment = message.attachment;
      if (attachment != null) {
        temporaryAttachmentFile = await _downloadAttachmentForForwarding(
          attachment,
        );
        await widget.controller.sendAttachmentMessage(
          selectedContact.userId,
          filePath: temporaryAttachmentFile.path,
          fileName: _forwardedAttachmentFileName(attachment),
          text: forwardedText,
          attachmentKind: attachment.kind,
        );
      } else {
        await widget.controller.sendMessage(
          selectedContact.userId,
          forwardedText,
        );
      }
      didForward = true;
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error);
    } finally {
      final temporaryFile = temporaryAttachmentFile;
      if (temporaryFile != null) {
        unawaited(
          (() async {
            try {
              await temporaryFile.delete();
            } catch (_) {}
          })(),
        );
      }
      if (mounted) {
        setState(() {
          isForwardingMessage = false;
        });
      }
    }
    if (!mounted || !didForward) {
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChatScreen(
          controller: widget.controller,
          initialContact: selectedContact,
        ),
      ),
    );
  }

  Future<void> _startAudioCall() async {
    try {
      await widget.controller.startCall(contact, video: false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error, fallbackMessage: 'Ошибка аудио звонка');
    }
  }

  Future<void> _startVideoCall() async {
    try {
      await widget.controller.startCall(contact, video: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      showError(context, error, fallbackMessage: 'Ошибка видео звонка');
    }
  }

  Future<void> _openGroupSettings() async {
    final currentUserId = widget.controller.user?.id;
    if (!contact.isGroup ||
        currentUserId == null ||
        currentUserId != contact.ownerId) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupSettingsScreen(
          controller: widget.controller,
          initialGroup: contact,
        ),
      ),
    );
  }

  Future<void> _showGroupParticipantsSheet() async {
    if (!contact.isGroup) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: _GroupParticipantsSheet(
            detailsFuture: widget.controller.loadGroupDetails(contact.userId),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoNoteRecordingOverlay() {
    final mediaSize = MediaQuery.sizeOf(context);
    final circleSize = math
        .min(mediaSize.shortestSide * 0.64, 260.0)
        .clamp(180.0, 260.0)
        .toDouble();
    final isSaving = _isStoppingVideoNoteRecording;
    final isPreparing =
        _isPreparingVideoNoteRecording || _isSwitchingVideoNoteCamera;
    final canFinish =
        _isRecordingVideoNote &&
        !isPreparing &&
        !isSaving &&
        _videoNoteRecordingDuration >= const Duration(seconds: 1);
    final cameraController = _videoNoteCameraController;
    final hasCameraPreview =
        cameraController != null && cameraController.value.isInitialized;
    final canSwitchCamera =
        _isRecordingVideoNote &&
        !isPreparing &&
        !isSaving &&
        hasCameraPreview &&
        (_videoNoteCameras?.length ?? 0) > 1;
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.44)),
              ),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.28),
                                  blurRadius: 36,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: ColoredBox(
                                color: Colors.black,
                                child: SizedBox(
                                  width: circleSize,
                                  height: circleSize,
                                  child: hasCameraPreview
                                      ? _isSwitchingVideoNoteCamera
                                            ? ImageFiltered(
                                                imageFilter: ImageFilter.blur(
                                                  sigmaX: 12,
                                                  sigmaY: 12,
                                                ),
                                                child: _SafeCameraPreview(
                                                  cameraController,
                                                  mirror: false,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : _SafeCameraPreview(
                                                cameraController,
                                                mirror: false,
                                                fit: BoxFit.cover,
                                              )
                                      : Center(
                                          child: isPreparing
                                              ? const SizedBox(
                                                  width: 42,
                                                  height: 42,
                                                  child:
                                                      CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 3,
                                                      ),
                                                )
                                              : const Icon(
                                                  Icons.account_circle_rounded,
                                                  color: Colors.white,
                                                  size: 54,
                                                ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.34),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              formatAudioDuration(_videoNoteRecordingDuration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Tooltip(
                          message: 'Отмена',
                          child: FilledButton(
                            onPressed: isSaving
                                ? null
                                : () => unawaited(_cancelVideoNoteRecording()),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFB84040),
                              disabledBackgroundColor: const Color(
                                0xFFB84040,
                              ).withValues(alpha: 0.42),
                              foregroundColor: Colors.white,
                              fixedSize: const Size.square(54),
                              minimumSize: const Size.square(54),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: const Icon(Icons.close_rounded, size: 26),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Tooltip(
                          message: 'Повернуть камеру',
                          child: FilledButton(
                            onPressed: canSwitchCamera
                                ? () => unawaited(_switchVideoNoteCamera())
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white.withValues(
                                alpha: 0.18,
                              ),
                              disabledBackgroundColor: Colors.white.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white.withValues(
                                alpha: 0.42,
                              ),
                              fixedSize: const Size.square(54),
                              minimumSize: const Size.square(54),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: isPreparing && _isSwitchingVideoNoteCamera
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(
                                    Icons.flip_camera_ios_rounded,
                                    size: 25,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Tooltip(
                          message: 'Готово',
                          child: FilledButton(
                            onPressed: canFinish
                                ? () => unawaited(_stopVideoNoteRecording())
                                : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              disabledBackgroundColor: Colors.white.withValues(
                                alpha: 0.42,
                              ),
                              foregroundColor: const Color(0xFF172033),
                              disabledForegroundColor: const Color(
                                0xFF172033,
                              ).withValues(alpha: 0.54),
                              fixedSize: const Size.square(54),
                              minimumSize: const Size.square(54),
                              padding: EdgeInsets.zero,
                              shape: const CircleBorder(),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Color(0xFF172033),
                                    ),
                                  )
                                : const Icon(Icons.check_rounded, size: 26),
                          ),
                        ),
                      ],
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _screenListenable,
      builder: (context, _) {
        final currentContact = contact;
        final messages = widget.controller.messagesFor(currentContact.userId);
        final displayedMessages = messages;
        final activeEditingMessage = editingMessage;
        final activeReplyingMessage = replyingMessage;
        if (activeEditingMessage != null &&
            findSortedMessageIndex(messages, activeEditingMessage.id) == -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && editingMessage?.id == activeEditingMessage.id) {
              _cancelEditingMessage();
            }
          });
        }
        if (activeReplyingMessage != null &&
            findSortedMessageIndex(messages, activeReplyingMessage.id) == -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && replyingMessage?.id == activeReplyingMessage.id) {
              _cancelReplyingMessage();
            }
          });
        }
        final currentUser = widget.controller.user;
        final canOpenGroupSettings =
            currentContact.isGroup &&
            currentUser != null &&
            currentUser.id == currentContact.ownerId;
        final isLoading = widget.controller.conversationIsLoading(
          currentContact.userId,
        );
        final canStartCall =
            widget.controller.canStartCall && currentContact.isDirect;
        final chatMenuItems = <PopupMenuEntry<String>>[
          if (currentContact.isDirect) ...[
            PopupMenuItem<String>(
              value: 'audio',
              enabled: canStartCall,
              child: const _ChatMenuItem(
                icon: Icons.call_rounded,
                label: 'Аудиозвонок',
              ),
            ),
            PopupMenuItem<String>(
              value: 'video',
              enabled: canStartCall,
              child: const _ChatMenuItem(
                icon: Icons.videocam_rounded,
                label: 'Видеозвонок',
              ),
            ),
            const PopupMenuDivider(),
          ],
          if (canOpenGroupSettings)
            const PopupMenuItem<String>(
              value: 'group_settings',
              child: _ChatMenuItem(
                icon: Icons.settings_rounded,
                label: 'Настройки группы',
              ),
            ),
          if (currentContact.isGroup)
            const PopupMenuItem<String>(
              value: 'participants',
              child: _ChatMenuItem(
                icon: Icons.groups_rounded,
                label: '\u0423\u0447\u0430\u0441\u0442\u043d\u0438\u043a\u0438',
              ),
            ),
          if (currentContact.isGroup) const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'clear',
            child: _ChatMenuItem(
              icon: Icons.cleaning_services_rounded,
              label: 'Очистить чат',
            ),
          ),
        ];
        final isEditing = editingMessage != null;
        final replyTarget = replyingMessage;
        final attachmentDraft = pendingAttachment;
        final composerInputLocked =
            attachmentDraft != null || _isVoiceRecordingBusy;
        final composerOverlayPanel = _isVoiceRecordingBusy
            ? _ComposerVoiceRecordingPanel(
                isPreparing: _isPreparingVoiceRecording,
                duration: _voiceRecordingDuration,
                onSend: () => unawaited(_stopVoiceRecording()),
                onCancel: () => unawaited(_cancelVoiceRecording()),
              )
            : attachmentDraft == null
            ? null
            : _ComposerAttachmentPanel(
                draft: attachmentDraft,
                isSending: isSending,
                uploadFailed: _pendingAttachmentUploadFailed,
                onRetry: _send,
                onRemove: _cancelPendingAttachment,
                inline: true,
              );
        final canOpenComposerMenu =
            !isSending &&
            !isEditing &&
            attachmentDraft == null &&
            !_isMediaRecordingBusy;
        final typingStatusLabel = widget.controller.typingStatusLabelFor(
          currentContact.userId,
        );
        final titleAvatar = ProfileAvatar(
          name: currentContact.name,
          imageUrl: currentContact.avatarUrl,
          radius: 20,
          backgroundColor: currentContact.isGroup
              ? const Color(0xFF67B8D8)
              : appPrimaryColor,
          useNameGradient: !currentContact.isGroup,
        );
        final titleContent = Row(
          children: [
            titleAvatar,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currentContact.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (currentContact.isGroup)
                    Text(
                      typingStatusLabel ??
                          formatGroupOnlineCountLabel(
                            currentContact.onlineMemberCount,
                            currentContact.memberCount,
                          ),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    )
                  else
                    Text(
                      typingStatusLabel ??
                          (currentContact.isOnline
                              ? 'в сети'
                              : formatLastSeenLabel(currentContact.lastSeenAt)),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
        final chatTopInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final scaffold = Scaffold(
          resizeToAvoidBottomInset: false,
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            leading: buildPlainBackButton(context),
            titleSpacing: 0,
            title: titleContent,
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                tooltip: 'Меню чата',
                onSelected: _handleChatMenuAction,
                itemBuilder: (_) => chatMenuItems,
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(gradient: buildChatGradient()),
            child: SafeArea(
              top: false,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutQuart,
                padding: EdgeInsets.only(bottom: keyboardInset),
                child: Padding(
                  padding: EdgeInsets.only(top: chatTopInset),
                  child: Column(
                    children: [
                      Expanded(
                        child: isLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                ),
                              )
                            : displayedMessages.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 30),
                                  child: Text(
                                    'Переписка пока пустая. Напишите первое сообщение.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              )
                            : ScrollablePositionedList.builder(
                                itemScrollController: _messageListController,
                                addAutomaticKeepAlives: false,
                                addSemanticIndexes: false,
                                reverse: true,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  20,
                                  16,
                                  20,
                                ),
                                itemCount: displayedMessages.length,
                                itemBuilder: (context, index) {
                                  final message =
                                      displayedMessages[displayedMessages
                                              .length -
                                          1 -
                                          index];
                                  final olderMessage =
                                      index < displayedMessages.length - 1
                                      ? displayedMessages[displayedMessages
                                                .length -
                                            2 -
                                            index]
                                      : null;
                                  final showDayHeader =
                                      olderMessage == null ||
                                      !isSameChatDay(
                                        message.createdAt,
                                        olderMessage.createdAt,
                                      );
                                  final isMine =
                                      currentUser != null &&
                                      message.isMine(currentUser.id);
                                  final senderContact =
                                      message.isGroup && !isMine
                                      ? widget.controller.contactById(
                                          message.senderId,
                                        )
                                      : null;
                                  final bubbleName = message.isGroup && !isMine
                                      ? (senderContact?.name ??
                                            message.senderName ??
                                            currentContact.name)
                                      : currentContact.name;
                                  final bubbleAvatarUrl =
                                      message.isGroup && !isMine
                                      ? (senderContact?.avatarUrl ??
                                            message.senderAvatarUrl)
                                      : currentContact.avatarUrl;
                                  return RepaintBoundary(
                                    key: ValueKey('message_${message.id}'),
                                    child: Column(
                                      children: [
                                        if (showDayHeader)
                                          ChatDaySeparator(
                                            label: formatChatDayLabel(
                                              message.createdAt,
                                            ),
                                          ),
                                        _ReplySwipeWrapper(
                                          gestureId: 'reply_${message.id}',
                                          enabled: true,
                                          swipeLeftToReply: true,
                                          onReply: () =>
                                              _startReplyingToMessage(message),
                                          child: MessageBubble(
                                            message: message,
                                            isMine: isMine,
                                            currentUser: currentUser,
                                            contactName: bubbleName,
                                            contactAvatarUrl: bubbleAvatarUrl,
                                            onAvatarTap: null,
                                            onAttachmentTap:
                                                message.attachment == null ||
                                                    !message
                                                        .attachment!
                                                        .isPreviewable ||
                                                    message
                                                        .attachment!
                                                        .isVideoNote
                                                ? null
                                                : () =>
                                                      _openAttachment(message),
                                            onReplyTap:
                                                message.replyToMessageId == null
                                                ? null
                                                : () => unawaited(
                                                    _jumpToMessage(
                                                      message.replyToMessageId!,
                                                    ),
                                                  ),
                                            onTap: () => _showMessageActions(
                                              message,
                                              isMine,
                                            ),
                                            isHighlighted:
                                                _highlightedMessageId ==
                                                message.id,
                                            highlightPulse: _highlightPulse,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isEditing && activeEditingMessage != null ||
                                replyTarget != null)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isEditing &&
                                      activeEditingMessage != null) ...[
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        8,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFD5DEEA),
                                          width: 1.1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'Редактирование',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: appPrimaryColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _replyPreviewText(
                                                    activeEditingMessage,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF475569),
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ChatComposerActionButton(
                                            icon: Icons.close_rounded,
                                            onTap: _cancelEditingMessage,
                                            showBackground: false,
                                            foregroundColor: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else if (replyTarget != null) ...[
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.fromLTRB(
                                        12,
                                        10,
                                        8,
                                        10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFD5DEEA),
                                          width: 1.1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _resolveReplyAuthorName(
                                                    replyTarget,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: appPrimaryColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _replyPreviewText(
                                                    replyTarget,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF475569),
                                                    height: 1.3,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          ChatComposerActionButton(
                                            icon: Icons.close_rounded,
                                            onTap: _cancelReplyingMessage,
                                            showBackground: false,
                                            foregroundColor: Colors.black,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            Row(
                              children: [
                                Expanded(
                                  child: _ComposerInputSwitcher(
                                    hasAttachment: composerOverlayPanel != null,
                                    attachmentPanelKey: _isVoiceRecordingBusy
                                        ? 'composer_voice_recording'
                                        : 'composer_attachment',
                                    attachmentPanel: composerOverlayPanel,
                                    textInput: TextField(
                                      controller: messageController,
                                      focusNode: messageFocusNode,
                                      readOnly: composerInputLocked,
                                      canRequestFocus: !composerInputLocked,
                                      enableInteractiveSelection:
                                          !composerInputLocked,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      textInputAction: TextInputAction.send,
                                      minLines: 1,
                                      maxLines: 5,
                                      onSubmitted: (_) {
                                        if (!composerInputLocked) {
                                          _send();
                                        }
                                      },
                                      onTap: !composerInputLocked
                                          ? null
                                          : messageFocusNode.unfocus,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: !composerInputLocked
                                            ? Colors.white
                                            : const Color(0xFFF8FAFC),
                                        border: const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(18),
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFFD5DEEA),
                                            width: 1.2,
                                          ),
                                        ),
                                        enabledBorder: const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(18),
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFFD5DEEA),
                                            width: 1.2,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: const BorderRadius.all(
                                            Radius.circular(18),
                                          ),
                                          borderSide: const BorderSide(
                                            color: appPrimaryColor,
                                            width: 1.4,
                                          ),
                                        ),
                                        disabledBorder:
                                            const OutlineInputBorder(
                                              borderRadius: BorderRadius.all(
                                                Radius.circular(18),
                                              ),
                                              borderSide: BorderSide(
                                                color: Color(0xFFD5DEEA),
                                                width: 1.2,
                                              ),
                                            ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 18,
                                            ),
                                        prefixIconConstraints:
                                            const BoxConstraints(
                                              minWidth: 50,
                                              minHeight: 44,
                                            ),
                                        prefixIcon: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: Builder(
                                            builder: (menuButtonContext) {
                                              return _ComposerInlineButton(
                                                icon: Icons.more_vert_rounded,
                                                onTap: canOpenComposerMenu
                                                    ? () => unawaited(
                                                        _showComposerActionsMenu(
                                                          menuButtonContext,
                                                        ),
                                                      )
                                                    : null,
                                              );
                                            },
                                          ),
                                        ),
                                        suffixIconConstraints:
                                            const BoxConstraints(
                                              minWidth: 50,
                                              minHeight: 44,
                                            ),
                                        suffixIcon: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          child: isSending
                                              ? const _ComposerInlineButton(
                                                  isLoading: true,
                                                )
                                              : _ComposerInlineButton(
                                                  icon: isEditing
                                                      ? Icons.check_rounded
                                                      : Icons.send_rounded,
                                                  onTap: _isMediaRecordingBusy
                                                      ? null
                                                      : _send,
                                                ),
                                        ),
                                        hintText: isEditing
                                            ? 'Изменить сообщение'
                                            : 'Сообщение',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        return Stack(
          children: [
            scaffold,
            if (_isVideoNoteRecordingBusy) _buildVideoNoteRecordingOverlay(),
          ],
        );
      },
    );
  }
}

class _GroupParticipantsSheet extends StatelessWidget {
  const _GroupParticipantsSheet({required this.detailsFuture});

  final Future<GroupDetails> detailsFuture;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: buildSettingsGradient()),
        child: SafeArea(
          child: AppScreenSurface(
            child: FutureBuilder<GroupDetails>(
              future: detailsFuture,
              builder: (context, snapshot) {
                final details = snapshot.data;
                if (snapshot.connectionState != ConnectionState.done &&
                    details == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError && details == null) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    children: const [
                      AppSectionCard(
                        child: Text(
                          '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0443\u0447\u0430\u0441\u0442\u043d\u0438\u043a\u043e\u0432',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF5B6472),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                final members = details?.members ?? const <GroupMember>[];
                if (members.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                    children: const [
                      AppSectionCard(
                        child: Text(
                          '\u0421\u043f\u0438\u0441\u043e\u043a \u043f\u0443\u0441\u0442',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF5B6472),
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
                  children: [
                    AppSectionCard(
                      margin: EdgeInsets.zero,
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: members
                            .map((member) {
                              final memberName = sanitizeDisplayText(
                                member.name,
                                preserveLineBreaks: false,
                              );
                              return ContactStyleRow(
                                name: memberName,
                                subtitle: member.email,
                                imageUrl: member.avatarUrl,
                                trailing: member.isOwner
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: appSoftSurfaceColor,
                                          borderRadius: BorderRadius.circular(
                                            appCompactRadius,
                                          ),
                                        ),
                                        child: const Text(
                                          '\u0412\u043b\u0430\u0434\u0435\u043b\u0435\u0446',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: appPrimaryColor,
                                          ),
                                        ),
                                      )
                                    : null,
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMenuItem extends StatelessWidget {
  const _ChatMenuItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: appPrimaryColor),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}

class _ComposerInlineButton extends StatelessWidget {
  const _ComposerInlineButton({
    this.icon = Icons.send_rounded,
    this.onTap,
    this.isLoading = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || isLoading;
    final color = enabled ? Colors.black : Colors.black.withValues(alpha: 0.35);
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 40,
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : Icon(icon, color: color, size: 22),
          ),
        ),
      ),
    );
  }
}

class _SwipeGestureCoordinator extends ChangeNotifier {
  String? _activeGestureId;

  bool tryAcquire(String gestureId) {
    if (_activeGestureId == null) {
      _activeGestureId = gestureId;
      notifyListeners();
      return true;
    }
    return _activeGestureId == gestureId;
  }

  bool isLockedByAnother(String gestureId) =>
      _activeGestureId != null && _activeGestureId != gestureId;

  void release(String gestureId) {
    if (_activeGestureId != gestureId) {
      return;
    }
    _activeGestureId = null;
    notifyListeners();
  }
}

final _swipeGestureCoordinator = _SwipeGestureCoordinator();

class _ReplySwipeWrapper extends StatefulWidget {
  const _ReplySwipeWrapper({
    required this.gestureId,
    required this.child,
    required this.onReply,
    required this.swipeLeftToReply,
    this.enabled = true,
  });

  final String gestureId;
  final Widget child;
  final VoidCallback onReply;
  final bool swipeLeftToReply;
  final bool enabled;

  @override
  State<_ReplySwipeWrapper> createState() => _ReplySwipeWrapperState();
}

class _ReplySwipeWrapperState extends State<_ReplySwipeWrapper> {
  static const double _maxOffset = 72;
  static const double _triggerOffset = 52;

  double _dragOffset = 0;
  bool _isDragging = false;
  int? _activePointerId;
  bool _holdsGestureLock = false;

  double _clampOffset(double value) {
    if (widget.swipeLeftToReply) {
      return value.clamp(-_maxOffset, 0.0);
    }
    return value.clamp(0.0, _maxOffset);
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabled || _activePointerId != null || _holdsGestureLock) {
      return;
    }
    if (_swipeGestureCoordinator.tryAcquire(widget.gestureId)) {
      _activePointerId = event.pointer;
      _holdsGestureLock = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointerId != event.pointer) {
      return;
    }
    _activePointerId = null;
    if (!_isDragging) {
      _releaseGestureLock();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointerId != event.pointer) {
      return;
    }
    _activePointerId = null;
    if (!_isDragging) {
      _releaseGestureLock();
    }
  }

  void _releaseGestureLock() {
    if (!_holdsGestureLock) {
      return;
    }
    _holdsGestureLock = false;
    _swipeGestureCoordinator.release(widget.gestureId);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled || !_holdsGestureLock) {
      return;
    }
    final delta = details.primaryDelta ?? 0;
    final nextOffset = _clampOffset(_dragOffset + delta);
    if (nextOffset == _dragOffset) {
      return;
    }
    setState(() {
      _isDragging = true;
      _dragOffset = nextOffset;
    });
  }

  void _handleDragEnd([DragEndDetails? _]) {
    final shouldReply =
        widget.enabled &&
        _holdsGestureLock &&
        (widget.swipeLeftToReply
            ? _dragOffset <= -_triggerOffset
            : _dragOffset >= _triggerOffset);
    _activePointerId = null;
    setState(() {
      _isDragging = false;
      _dragOffset = 0;
    });
    _releaseGestureLock();
    if (shouldReply) {
      widget.onReply();
    }
  }

  @override
  void dispose() {
    _releaseGestureLock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragOffset.abs() / _triggerOffset).clamp(0.0, 1.0);
    final iconAlignment = widget.swipeLeftToReply
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final iconPadding = widget.swipeLeftToReply
        ? const EdgeInsets.only(right: 14)
        : const EdgeInsets.only(left: 14);
    return AnimatedBuilder(
      animation: _swipeGestureCoordinator,
      builder: (context, _) {
        final isLockedByAnother = _swipeGestureCoordinator.isLockedByAnother(
          widget.gestureId,
        );
        return IgnorePointer(
          ignoring: isLockedByAnother,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: widget.enabled ? _handleDragUpdate : null,
              onHorizontalDragEnd: widget.enabled ? _handleDragEnd : null,
              onHorizontalDragCancel: widget.enabled ? _handleDragEnd : null,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _dragOffset),
                duration: _isDragging
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                builder: (context, animatedOffset, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Align(
                            alignment: iconAlignment,
                            child: Padding(
                              padding: iconPadding,
                              child: Opacity(
                                opacity: progress,
                                child: Transform.scale(
                                  scale: 0.88 + (progress * 0.18),
                                  child: const Icon(
                                    Icons.reply_rounded,
                                    size: 22,
                                    color: appPrimaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(animatedOffset, 0),
                        child: child,
                      ),
                    ],
                  );
                },
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ArchiveSwipeWrapper extends StatefulWidget {
  const _ArchiveSwipeWrapper({
    super.key,
    required this.gestureId,
    required this.child,
    required this.background,
    required this.onAction,
  });

  final String gestureId;
  final Widget child;
  final Widget background;
  final Future<void> Function() onAction;

  @override
  State<_ArchiveSwipeWrapper> createState() => _ArchiveSwipeWrapperState();
}

class _ArchiveSwipeWrapperState extends State<_ArchiveSwipeWrapper> {
  static const double _triggerDragFraction = 0.5;
  static const double _dismissExtraOffset = 32;
  static const Duration _settleAnimationDuration = Duration(milliseconds: 180);
  static const Duration _dismissAnimationDuration = Duration(milliseconds: 260);

  double _dragOffset = 0;
  bool _isDragging = false;
  bool _isProcessing = false;
  int? _activePointerId;
  bool _holdsGestureLock = false;

  void _handlePointerDown(PointerDownEvent event) {
    if (_isProcessing || _activePointerId != null || _holdsGestureLock) {
      return;
    }
    if (_swipeGestureCoordinator.tryAcquire(widget.gestureId)) {
      _activePointerId = event.pointer;
      _holdsGestureLock = true;
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_activePointerId != event.pointer) {
      return;
    }
    _activePointerId = null;
    if (!_isDragging && !_isProcessing) {
      _releaseGestureLock();
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_activePointerId != event.pointer) {
      return;
    }
    _activePointerId = null;
    if (!_isDragging && !_isProcessing) {
      _releaseGestureLock();
    }
  }

  void _releaseGestureLock() {
    if (!_holdsGestureLock) {
      return;
    }
    _holdsGestureLock = false;
    _swipeGestureCoordinator.release(widget.gestureId);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    if (!_holdsGestureLock || _isProcessing) {
      return;
    }
    final delta = details.primaryDelta ?? 0;
    final nextOffset = (_dragOffset + delta).clamp(
      double.negativeInfinity,
      0.0,
    );
    if (nextOffset == _dragOffset) {
      return;
    }
    setState(() {
      _isDragging = true;
      _dragOffset = nextOffset;
    });
  }

  void _handleDragEnd([DragEndDetails? _]) {
    final shouldTrigger =
        !_isProcessing &&
        _holdsGestureLock &&
        _dragOffset <= -_resolveTriggerOffset();
    _activePointerId = null;
    if (!shouldTrigger) {
      setState(() {
        _isDragging = false;
        _dragOffset = 0;
      });
      _releaseGestureLock();
      return;
    }
    setState(() {
      _isDragging = false;
      _isProcessing = true;
      _dragOffset = _resolveDismissOffset();
    });
    unawaited(_runAction());
  }

  double _resolveTriggerOffset() => _resolveSwipeWidth() * _triggerDragFraction;

  double _resolveDismissOffset() {
    return -(_resolveSwipeWidth() + _dismissExtraOffset);
  }

  double _resolveSwipeWidth() {
    final renderObject = context.findRenderObject();
    return renderObject is RenderBox
        ? renderObject.size.width
        : MediaQuery.sizeOf(context).width;
  }

  Future<void> _runAction() async {
    try {
      await Future<void>.delayed(_dismissAnimationDuration);
      await widget.onAction();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _dragOffset = 0;
        });
      }
      _releaseGestureLock();
    }
  }

  @override
  void dispose() {
    _releaseGestureLock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _swipeGestureCoordinator,
      builder: (context, _) {
        final isLockedByAnother = _swipeGestureCoordinator.isLockedByAnother(
          widget.gestureId,
        );
        return IgnorePointer(
          ignoring: isLockedByAnother || _isProcessing,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _handlePointerDown,
            onPointerUp: _handlePointerUp,
            onPointerCancel: _handlePointerCancel,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragUpdate: _handleDragUpdate,
              onHorizontalDragEnd: _handleDragEnd,
              onHorizontalDragCancel: _handleDragEnd,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: _dragOffset),
                duration: _isDragging
                    ? Duration.zero
                    : _isProcessing
                    ? _dismissAnimationDuration
                    : _settleAnimationDuration,
                curve: Curves.easeOutCubic,
                builder: (context, animatedOffset, child) {
                  return ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(child: widget.background),
                        Transform.translate(
                          offset: Offset(animatedOffset, 0),
                          child: ColoredBox(
                            color: appSurfaceColor,
                            child: child,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MessageReferencePanel extends StatelessWidget {
  const _MessageReferencePanel({
    required this.title,
    this.subtitle,
    required this.isMine,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final normalizedTitle = sanitizeDisplayText(
      title,
      preserveLineBreaks: false,
    ).trim();
    final normalizedSubtitle = sanitizeDisplayText(
      subtitle ?? '',
      preserveLineBreaks: false,
    ).trim();
    final content = _MessageContextPanel(
      title: normalizedTitle.isEmpty
          ? '\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435'
          : normalizedTitle,
      subtitle: normalizedSubtitle,
      isMine: isMine,
    );
    if (onTap == null) {
      return content;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}

class _ForwardedMessageSideIndicator extends StatelessWidget {
  const _ForwardedMessageSideIndicator({
    required this.title,
    this.subtitle,
    required this.isMine,
  });

  final String title;
  final String? subtitle;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final forwardedFromName = sanitizeDisplayText(
      title,
      preserveLineBreaks: false,
    ).trim();
    final normalizedName = forwardedFromName.isEmpty
        ? '\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435'
        : forwardedFromName;
    return _MessageContextPanel(
      title:
          '\u041f\u0435\u0440\u0435\u0441\u043b\u0430\u043d\u043e \u043e\u0442',
      subtitle: normalizedName,
      isMine: isMine,
    );
  }
}

class _MessageContextPanel extends StatelessWidget {
  const _MessageContextPanel({
    required this.title,
    required this.subtitle,
    required this.isMine,
  });

  final String title;
  final String subtitle;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final indicator = Container(
      width: 3,
      decoration: BoxDecoration(
        color: appPrimaryColor,
        borderRadius: BorderRadius.circular(999),
      ),
    );
    final textColumn = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 248),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isMine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: isMine ? TextAlign.right : TextAlign.left,
            style: const TextStyle(
              fontSize: 12,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: appPrimaryColor,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: isMine ? TextAlign.right : TextAlign.left,
              style: const TextStyle(
                fontSize: 12,
                height: 1.2,
                color: appPrimaryColor,
              ),
            ),
          ],
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 2),
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: isMine
                ? [textColumn, const SizedBox(width: 10), indicator]
                : [indicator, const SizedBox(width: 10), textColumn],
          ),
        ),
      ),
    );
  }
}

class _ComposerAttachmentPanel extends StatelessWidget {
  const _ComposerAttachmentPanel({
    required this.draft,
    required this.isSending,
    required this.uploadFailed,
    required this.onRetry,
    required this.onRemove,
    this.inline = false,
  });

  final _ComposerAttachmentDraft draft;
  final bool isSending;
  final bool uploadFailed;
  final VoidCallback onRetry;
  final VoidCallback onRemove;
  final bool inline;

  @override
  Widget build(BuildContext context) {
    final sizeLabel = formatAttachmentSize(draft.sizeBytes);
    return Container(
      width: double.infinity,
      margin: inline ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5DEEA), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(draft.icon, color: appPrimaryColor, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  draft.previewTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: appTextColor,
                    height: 1.2,
                  ),
                ),
                if (sizeLabel.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sizeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      height: 1.2,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          ChatComposerActionButton(
            icon: Icons.close_rounded,
            onTap: isSending ? null : onRemove,
            showBackground: false,
            foregroundColor: Colors.black,
          ),
          const SizedBox(width: 2),
          ChatComposerActionButton(
            icon: uploadFailed ? Icons.refresh_rounded : Icons.send_rounded,
            onTap: isSending ? null : onRetry,
            isLoading: isSending,
            showBackground: false,
            foregroundColor: Colors.black,
          ),
        ],
      ),
    );
  }
}

class _ComposerVoiceRecordingPanel extends StatelessWidget {
  const _ComposerVoiceRecordingPanel({
    required this.isPreparing,
    required this.duration,
    required this.onSend,
    required this.onCancel,
  });

  final bool isPreparing;
  final Duration duration;
  final VoidCallback onSend;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5DEEA), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFFECEC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isPreparing
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.1,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFB84040),
                      ),
                    ),
                  )
                : const Icon(
                    Icons.mic_rounded,
                    color: Color(0xFFB84040),
                    size: 21,
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isPreparing ? 'Подготавливаю запись' : 'Идет запись',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFB84040),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatAudioDuration(duration),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          ChatComposerActionButton(
            icon: Icons.close_rounded,
            onTap: isPreparing ? null : onCancel,
            showBackground: false,
            foregroundColor: Colors.black,
          ),
          const SizedBox(width: 2),
          ChatComposerActionButton(
            icon: Icons.check_rounded,
            onTap: isPreparing ? null : onSend,
            showBackground: false,
            foregroundColor: Colors.black,
          ),
        ],
      ),
    );
  }
}

class _ComposerInputSwitcher extends StatelessWidget {
  const _ComposerInputSwitcher({
    required this.hasAttachment,
    required this.attachmentPanelKey,
    required this.textInput,
    required this.attachmentPanel,
  });

  final bool hasAttachment;
  final String attachmentPanelKey;
  final Widget textInput;
  final Widget? attachmentPanel;

  @override
  Widget build(BuildContext context) {
    return hasAttachment && attachmentPanel != null
        ? attachmentPanel!
        : textInput;
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.currentUser,
    required this.contactName,
    required this.contactAvatarUrl,
    this.onAvatarTap,
    this.onAttachmentTap,
    this.onReplyTap,
    this.isHighlighted = false,
    this.highlightPulse = 0,
    this.showMetadata = true,
    required this.onTap,
  });

  final ChatMessage message;
  final bool isMine;
  final UserProfile? currentUser;
  final String contactName;
  final String? contactAvatarUrl;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onAttachmentTap;
  final VoidCallback? onReplyTap;
  final bool isHighlighted;
  final int highlightPulse;
  final bool showMetadata;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const bubbleGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF79BFEA), Color(0xFF4A9FD8)],
    );
    const textColor = Colors.white;
    final messageText = message.text;
    final messageTextStyle = TextStyle(
      fontSize: 15,
      height: 1.42,
      color: textColor,
    );
    final firstUrl = message.firstLink;
    final attachment = message.attachment;
    final hasPreviewableMediaAttachment = attachment?.isPreviewable ?? false;
    final isStandaloneMediaMessage =
        hasPreviewableMediaAttachment &&
        messageText.isEmpty &&
        firstUrl == null;
    final isStandaloneVideoNoteMessage =
        isStandaloneMediaMessage && (attachment?.isVideoNote ?? false);
    final highlightColor = Colors.white.withValues(alpha: 0.92);
    const metadataColor = Color(0xFF64748B);
    final showBubbleChrome = !isStandaloneMediaMessage;
    final metadata = _MessageMetadataRow(
      message: message,
      isMine: isMine,
      color: metadataColor,
    );
    final contextPanels = <Widget>[
      if (message.isForwarded)
        _ForwardedMessageSideIndicator(
          title: (message.forwardedFromName?.trim().isNotEmpty ?? false)
              ? message.forwardedFromName!
              : '\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435',
          subtitle:
              '\u041f\u0435\u0440\u0435\u0441\u043b\u0430\u043d\u043d\u043e\u0435 \u0441\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435',
          isMine: isMine,
        ),
      if (message.isReply)
        _MessageReferencePanel(
          title:
              message.replyToName ??
              '\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435',
          subtitle: (message.replyToText?.trim().isNotEmpty ?? false)
              ? message.replyToText
              : '\u0421\u043e\u043e\u0431\u0449\u0435\u043d\u0438\u0435',
          isMine: isMine,
          onTap: onReplyTap,
        ),
    ];
    final bubbleContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (message.isGroup && !isMine) ...[
          Text(
            contactName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
        ],
        if (attachment != null) ...[
          MessageAttachmentPreviewCard(
            key: ValueKey<String>(
              'attachment_${message.id}_${attachment.url}_${attachment.kind}',
            ),
            attachment: attachment,
            isMine: isMine,
            onTap: onAttachmentTap,
          ),
          if (messageText.isNotEmpty) const SizedBox(height: 10),
        ],
        if (messageText.isNotEmpty)
          firstUrl == null
              ? Text(
                  messageText,
                  style: messageTextStyle,
                  textAlign: isMine ? TextAlign.right : TextAlign.left,
                  textWidthBasis: TextWidthBasis.longestLine,
                )
              : Text.rich(
                  TextSpan(
                    style: messageTextStyle,
                    children: message.buildTextSpans(
                      linkColor: const Color(0xFFE9F5FF),
                    ),
                  ),
                  textAlign: isMine ? TextAlign.right : TextAlign.left,
                  textWidthBasis: TextWidthBasis.longestLine,
                ),
      ],
    );
    final bubble = GestureDetector(
      onLongPress: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: isStandaloneVideoNoteMessage
            ? EdgeInsets.zero
            : isStandaloneMediaMessage
            ? EdgeInsets.zero
            : const EdgeInsets.fromLTRB(16, 12, 16, 10),
        decoration: !showBubbleChrome
            ? const BoxDecoration()
            : BoxDecoration(
                gradient: bubbleGradient,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMine ? 20 : 6),
                  bottomRight: Radius.circular(isMine ? 6 : 20),
                ),
                border: null,
                boxShadow: [
                  BoxShadow(
                    color: isHighlighted
                        ? highlightColor.withValues(alpha: 0.18)
                        : const Color(0x12000000),
                    blurRadius: isHighlighted ? 18 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
        child: contextPanels.isNotEmpty && attachment == null
            ? IntrinsicWidth(child: bubbleContent)
            : bubbleContent,
      ),
    );
    final messageStack = Column(
      crossAxisAlignment: isMine
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [...contextPanels, bubble],
    );
    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 310),
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [messageStack, if (showMetadata) metadata],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 2),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAvatarTap,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: ProfileAvatar(
                    name: contactName,
                    imageUrl: contactAvatarUrl,
                    radius: 16,
                    backgroundColor: appPrimaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 310),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [messageStack, if (showMetadata) metadata],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageMetadataRow extends StatelessWidget {
  const _MessageMetadataRow({
    required this.message,
    required this.isMine,
    required this.color,
  });

  final ChatMessage message;
  final bool isMine;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final timestamp = formatClock(message.createdAt.toLocal());
    final label = message.isEdited ? '$timestamp изменено' : timestamp;
    return Padding(
      padding: const EdgeInsets.only(top: 3, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              color: color.withValues(alpha: 0.84),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 4),
            Icon(
              message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
              size: 14,
              color: color.withValues(alpha: message.isRead ? 0.95 : 0.7),
            ),
          ],
        ],
      ),
    );
  }
}

class MessageAttachmentPreviewCard extends StatelessWidget {
  const MessageAttachmentPreviewCard({
    super.key,
    required this.attachment,
    required this.isMine,
    this.onTap,
  });

  final MessageAttachment attachment;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      return _ImageAttachmentPreview(
        attachment: attachment,
        isMine: isMine,
        onTap: onTap,
      );
    }
    if (attachment.isVideo) {
      return _VideoAttachmentPreview(
        key: ValueKey<String>('video_${attachment.url}'),
        attachment: attachment,
        isMine: isMine,
        isVideoNote: attachment.isVideoNote,
        onTap: onTap,
      );
    }
    if (attachment.isAudio) {
      return _InlineAudioAttachmentPlayer(
        source: attachment.downloadUrl.trim().isEmpty
            ? attachment.url
            : attachment.downloadUrl,
        sourceIsLocal: false,
        isMine: isMine,
        initialDuration: attachment.embeddedDuration,
      );
    }
    return _FileAttachmentTile(
      attachment: attachment,
      isMine: isMine,
      onTap: onTap,
    );
  }
}

const double _messageAttachmentPreviewFallbackWidth = 248;
const double _videoNoteAttachmentPreviewDiameter = 238;
const double _videoNoteAttachmentPlayingDiameter = 276;
const double _videoNoteMessageBubblePadding = 7;
const double _messageAttachmentPreviewBorderRadiusValue = 22;
const BorderRadius _messageAttachmentPreviewBorderRadius = BorderRadius.all(
  Radius.circular(_messageAttachmentPreviewBorderRadiusValue),
);
final Map<String, double> _messageAttachmentPreviewAspectRatioCache =
    <String, double>{};

double? _normalizedMediaAspectRatio(double? aspectRatio) {
  if (aspectRatio == null || !aspectRatio.isFinite || aspectRatio <= 0) {
    return null;
  }
  return aspectRatio;
}

double _messageAttachmentPreviewWidthFor(BoxConstraints constraints) {
  final maxWidth = constraints.maxWidth;
  if (maxWidth.isFinite && maxWidth > 0) {
    return math.min(maxWidth, _messageAttachmentPreviewFallbackWidth);
  }
  return _messageAttachmentPreviewFallbackWidth;
}

Widget _buildRoundedMessageAttachmentPreview({
  required Widget child,
  required VoidCallback? onTap,
}) {
  return ClipRRect(
    borderRadius: _messageAttachmentPreviewBorderRadius,
    clipBehavior: Clip.antiAliasWithSaveLayer,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: child,
    ),
  );
}

Widget _buildCircularMessageAttachmentPreview({
  required Widget child,
  required VoidCallback? onTap,
  required double diameter,
  required bool isMine,
  required bool showMessageBubble,
}) {
  final preview = ClipOval(
    clipBehavior: Clip.antiAliasWithSaveLayer,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox.expand(child: child),
    ),
  );
  if (!showMessageBubble) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: diameter,
      height: diameter,
      child: preview,
    );
  }
  const bubbleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF79BFEA), Color(0xFF4A9FD8)],
  );
  return AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOutCubic,
    width: diameter + (_videoNoteMessageBubblePadding * 2),
    height: diameter + (_videoNoteMessageBubblePadding * 2),
    padding: const EdgeInsets.all(_videoNoteMessageBubblePadding),
    decoration: BoxDecoration(
      gradient: bubbleGradient,
      shape: BoxShape.circle,
      boxShadow: const [
        BoxShadow(
          color: Color(0x16000000),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: preview,
  );
}

class _VideoNoteProgressRingPainter extends CustomPainter {
  const _VideoNoteProgressRingPainter({
    required this.progress,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final resolvedProgress = progress.clamp(0.0, 1.0);
    final inset = strokeWidth;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - (inset * 2),
      size.height - (inset * 2),
    );
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = progressColor;
    if (resolvedProgress > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * resolvedProgress,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_VideoNoteProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _AttachmentRetryIconButton extends StatelessWidget {
  const _AttachmentRetryIconButton({
    required this.onRetry,
    this.size = 54,
    this.iconSize = 28,
  });

  final VoidCallback onRetry;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Повторить загрузку',
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onRetry,
          child: SizedBox(
            width: size,
            height: size,
            child: Center(
              child: Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentRetryView extends StatelessWidget {
  const _AttachmentRetryView({
    required this.title,
    required this.description,
    required this.icon,
    required this.onRetry,
    this.width,
    this.height,
    this.dark = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onRetry;
  final double? width;
  final double? height;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final box = SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(child: _AttachmentRetryIconButton(onRetry: onRetry)),
      ),
    );
    return ClipRRect(borderRadius: BorderRadius.circular(18), child: box);
  }
}

class _MediaPreviewLoadingBox extends StatelessWidget {
  const _MediaPreviewLoadingBox({
    required this.width,
    required this.aspectRatio,
  });

  final double width;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: const ColoredBox(
          color: Colors.black,
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      ),
    );
  }
}

class _AttachmentDurationBadge extends StatelessWidget {
  const _AttachmentDurationBadge({required this.duration});

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (duration <= Duration.zero) {
      return const SizedBox.shrink();
    }
    return Positioned(
      right: 10,
      bottom: 10,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            formatAudioDuration(duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineAudioAttachmentPlayer extends StatefulWidget {
  const _InlineAudioAttachmentPlayer({
    required this.source,
    required this.sourceIsLocal,
    required this.isMine,
    this.initialDuration = Duration.zero,
  });

  final String source;
  final bool sourceIsLocal;
  final bool isMine;
  final Duration initialDuration;

  @override
  State<_InlineAudioAttachmentPlayer> createState() =>
      _InlineAudioAttachmentPlayerState();
}

class _MediaProgressBar extends StatefulWidget {
  const _MediaProgressBar({
    required this.position,
    required this.duration,
    required this.activeColor,
    required this.inactiveColor,
    required this.trackHeight,
  });

  final Duration position;
  final Duration duration;
  final Color activeColor;
  final Color inactiveColor;
  final double trackHeight;

  @override
  State<_MediaProgressBar> createState() => _MediaProgressBarState();
}

class _MediaProgressBarState extends State<_MediaProgressBar> {
  double get _resolvedFraction {
    final totalMs = widget.duration.inMilliseconds;
    if (totalMs <= 0) {
      return 0;
    }
    return (widget.position.inMilliseconds / totalMs).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final height = widget.trackHeight;
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final fraction = _resolvedFraction;
          final activeWidth = width * fraction;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.inactiveColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.linear,
                  width: activeWidth.clamp(0.0, width),
                  decoration: BoxDecoration(
                    color: widget.activeColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InlineAudioAttachmentPlayerState
    extends State<_InlineAudioAttachmentPlayer> {
  static _InlineAudioAttachmentPlayerState? _activePlayerState;

  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<PlayerState>? _playerStateSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerException>? _errorSubscription;

  PlayerState _playerState = PlayerState(false, ProcessingState.idle);
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _loadGeneration = 0;
  bool _isPreparing = false;
  bool _isLoaded = false;
  String? _loadErrorText;

  @override
  void initState() {
    super.initState();
    _duration = widget.initialDuration;
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playerState = state;
      });
    });
    _positionSubscription = _player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 120),
          maxPeriod: const Duration(milliseconds: 250),
        )
        .listen((position) {
          if (!mounted) {
            return;
          }
          setState(() {
            _position = position;
          });
        });
    _durationSubscription = _player.durationStream.listen((duration) {
      if (!mounted || duration == null) {
        return;
      }
      setState(() {
        _duration = duration;
      });
    });
    _errorSubscription = _player.errorStream.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadErrorText = 'Не удалось загрузить аудио';
        _isPreparing = false;
        _isLoaded = false;
        _playerState = PlayerState(false, ProcessingState.idle);
      });
    });
    if (widget.initialDuration <= Duration.zero) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_ensureLoaded());
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _InlineAudioAttachmentPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source ||
        oldWidget.sourceIsLocal != widget.sourceIsLocal ||
        oldWidget.initialDuration != widget.initialDuration) {
      unawaited(_resetPlayer());
      if (widget.initialDuration > Duration.zero) {
        setState(() {
          _duration = widget.initialDuration;
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_ensureLoaded());
          }
        });
      }
    }
  }

  Future<void> _resetPlayer() async {
    _loadGeneration++;
    if (_activePlayerState == this) {
      _activePlayerState = null;
    }
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    setState(() {
      _playerState = PlayerState(false, ProcessingState.idle);
      _position = Duration.zero;
      _duration = widget.initialDuration;
      _isPreparing = false;
      _isLoaded = false;
      _loadErrorText = null;
    });
  }

  Future<void> _ensureLoaded() async {
    if (_isPreparing || _isLoaded) {
      return;
    }
    final generation = ++_loadGeneration;
    setState(() {
      _isPreparing = true;
      _loadErrorText = null;
      _position = Duration.zero;
    });
    try {
      final duration = await _setAudioSource();
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _isLoaded = true;
        _duration = duration ?? _player.duration ?? Duration.zero;
      });
    } catch (_) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      setState(() {
        _isPreparing = false;
        _isLoaded = false;
        _loadErrorText = 'Не удалось загрузить аудио';
      });
    }
  }

  Future<Duration?> _setAudioSource() async {
    if (widget.sourceIsLocal) {
      return _player.setFilePath(widget.source);
    }
    final cachedAudio = await _downloadAudioAttachmentToCache(widget.source);
    return _player.setFilePath(cachedAudio.path);
  }

  Future<void> _pauseIfNeeded() async {
    if (_playerState.playing) {
      await _player.pause();
    }
  }

  Future<void> _togglePlayback() async {
    if (_isPreparing) {
      return;
    }
    if (_loadErrorText != null) {
      await _retryLoading();
      return;
    }
    if (!_isLoaded) {
      await _ensureLoaded();
      if (!_isLoaded) {
        return;
      }
    }
    if (_activePlayerState != null && _activePlayerState != this) {
      await _activePlayerState!._pauseIfNeeded();
    }
    _activePlayerState = this;
    if (_playerState.processingState == ProcessingState.completed) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }
    if (_playerState.playing) {
      await _player.pause();
      return;
    }
    await _player.play();
  }

  Future<void> _retryLoading() async {
    await _resetPlayer();
    await _ensureLoaded();
    if (_isLoaded) {
      await _togglePlayback();
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    if (_activePlayerState == this) {
      _activePlayerState = null;
    }
    _playerStateSubscription?.cancel();
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _errorSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeColor = Colors.white.withValues(alpha: 0.82);
    const buttonColor = Colors.white;
    final trackColor = Colors.white.withValues(alpha: 0.24);
    if (_loadErrorText != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Align(
          alignment: Alignment.centerLeft,
          child: _AttachmentRetryIconButton(
            onRetry: () => unawaited(_retryLoading()),
            size: 48,
            iconSize: 28,
          ),
        ),
      );
    }
    final trailingDuration = _duration > Duration.zero ? _duration : _position;
    final isPlaybackCompleted =
        _playerState.processingState == ProcessingState.completed;
    final buttonChild = _isPreparing
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.1,
              valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
            ),
          )
        : Icon(
            _loadErrorText != null
                ? Icons.refresh_rounded
                : isPlaybackCompleted
                ? Icons.replay_rounded
                : _playerState.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            color: buttonColor,
            size: 32,
          );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 280),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: _togglePlayback,
              child: Ink(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                ),
                child: Center(child: buttonChild),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MediaProgressBar(
                        position: _position,
                        duration: _duration,
                        activeColor: buttonColor,
                        inactiveColor: trackColor,
                        trackHeight: 5.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatAudioDuration(trailingDuration),
                      style: TextStyle(
                        color: timeColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_loadErrorText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _loadErrorText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: timeColor, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageAttachmentPreview extends StatefulWidget {
  const _ImageAttachmentPreview({
    required this.attachment,
    required this.isMine,
    this.onTap,
  });

  final MessageAttachment attachment;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  State<_ImageAttachmentPreview> createState() =>
      _ImageAttachmentPreviewState();
}

class _ImageAttachmentPreviewState extends State<_ImageAttachmentPreview> {
  int _reloadToken = 0;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;
  double? _resolvedAspectRatio;

  double? get _effectiveAspectRatio =>
      _normalizedMediaAspectRatio(widget.attachment.embeddedAspectRatio) ??
      _resolvedAspectRatio ??
      _messageAttachmentPreviewAspectRatioCache[widget.attachment.url];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncImageAspectRatio();
  }

  @override
  void didUpdateWidget(covariant _ImageAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.url != widget.attachment.url) {
      _resolvedAspectRatio =
          _messageAttachmentPreviewAspectRatioCache[widget.attachment.url];
      _unsubscribeImageAspectRatio();
      _syncImageAspectRatio();
    }
  }

  @override
  void dispose() {
    _unsubscribeImageAspectRatio();
    super.dispose();
  }

  void _unsubscribeImageAspectRatio() {
    final stream = _imageStream;
    final listener = _imageStreamListener;
    if (stream != null && listener != null) {
      stream.removeListener(listener);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  void _syncImageAspectRatio() {
    final url = widget.attachment.url.trim();
    if (url.isEmpty) {
      return;
    }
    final provider = NetworkImage(url, headers: serverMediaHttpHeadersFor(url));
    final stream = provider.resolve(createLocalImageConfiguration(context));
    _unsubscribeImageAspectRatio();
    final listener = ImageStreamListener((imageInfo, _) {
      final ratio = _normalizedMediaAspectRatio(
        imageInfo.image.width / imageInfo.image.height,
      );
      if (ratio == null) {
        return;
      }
      _messageAttachmentPreviewAspectRatioCache[widget.attachment.url] = ratio;
      if (!mounted || _resolvedAspectRatio == ratio) {
        return;
      }
      setState(() {
        _resolvedAspectRatio = ratio;
      });
    });
    _imageStream = stream;
    _imageStreamListener = listener;
    stream.addListener(listener);
  }

  void _retryLoadingPreview() {
    setState(() {
      _reloadToken += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewWidth = _messageAttachmentPreviewWidthFor(constraints);
        final effectiveAspectRatio = _effectiveAspectRatio;
        final cacheWidth = _targetImageCacheDimension(context, previewWidth);
        final image = Image.network(
          widget.attachment.url,
          headers: serverMediaHttpHeadersFor(widget.attachment.url),
          key: ValueKey('${widget.attachment.url}:$_reloadToken'),
          fit: BoxFit.contain,
          cacheWidth: cacheWidth,
          filterQuality: FilterQuality.low,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            if (effectiveAspectRatio != null) {
              return _MediaPreviewLoadingBox(
                width: previewWidth,
                aspectRatio: effectiveAspectRatio,
              );
            }
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(opacity: 0, child: child),
                const CircularProgressIndicator(color: Colors.white),
              ],
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _AttachmentRetryView(
              title: widget.attachment.previewTitle,
              description: 'Фото пока не загружается. Попробуйте еще раз.',
              icon: Icons.broken_image_rounded,
              onRetry: _retryLoadingPreview,
              width: previewWidth,
              height: effectiveAspectRatio == null
                  ? null
                  : previewWidth / effectiveAspectRatio,
            );
          },
        );
        final previewChild = ColoredBox(
          color: Colors.black,
          child: effectiveAspectRatio == null
              ? image
              : SizedBox(
                  width: previewWidth,
                  child: AspectRatio(
                    aspectRatio: effectiveAspectRatio,
                    child: SizedBox.expand(child: image),
                  ),
                ),
        );
        return _buildRoundedMessageAttachmentPreview(
          onTap: widget.onTap,
          child: previewChild,
        );
      },
    );
  }
}

class _VideoAttachmentPreview extends StatefulWidget {
  const _VideoAttachmentPreview({
    super.key,
    required this.attachment,
    required this.isMine,
    this.isVideoNote = false,
    this.onTap,
  });

  final MessageAttachment attachment;
  final bool isMine;
  final bool isVideoNote;
  final VoidCallback? onTap;

  @override
  State<_VideoAttachmentPreview> createState() =>
      _VideoAttachmentPreviewState();
}

class _VideoAttachmentPreviewState extends State<_VideoAttachmentPreview> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;
  int _controllerLoadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  @override
  void didUpdateWidget(covariant _VideoAttachmentPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.url != widget.attachment.url) {
      unawaited(_replaceController());
      return;
    }
    if (oldWidget.isVideoNote != widget.isVideoNote) {
      unawaited(_controller?.setVolume(0));
    }
  }

  void _createController() {
    final generation = ++_controllerLoadGeneration;
    _initializeFuture = _loadController(generation);
  }

  Future<void> _replaceController() async {
    final previous = _controller;
    final generation = ++_controllerLoadGeneration;
    final initializeFuture = _loadController(generation);
    setState(() {
      _controller = null;
      _initializeFuture = initializeFuture;
    });
    await previous?.dispose();
  }

  Future<void> _loadController(int generation) async {
    VideoPlayerController? controller;
    try {
      controller = await _createCompatibleVideoController(widget.attachment);
      if (!mounted || generation != _controllerLoadGeneration) {
        await controller.dispose();
        return;
      }
      await controller.pause();
      await controller.setLooping(false);
      await controller.setVolume(0);
      if (!mounted || generation != _controllerLoadGeneration) {
        await controller.dispose();
        return;
      }
      final aspectRatio = _normalizedMediaAspectRatio(
        _displayVideoAspectRatio(controller.value),
      );
      if (aspectRatio != null) {
        _messageAttachmentPreviewAspectRatioCache[widget.attachment.url] =
            aspectRatio;
      }
      setState(() {
        _controller = controller;
      });
    } catch (_) {
      try {
        await controller?.dispose();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  void dispose() {
    _controllerLoadGeneration++;
    _controller?.dispose();
    super.dispose();
  }

  bool _isCompleted(VideoPlayerValue value) {
    final duration = value.duration;
    if (duration <= Duration.zero) {
      return false;
    }
    final threshold = duration > const Duration(milliseconds: 180)
        ? duration - const Duration(milliseconds: 180)
        : duration;
    return !value.isPlaying && value.position >= threshold;
  }

  Future<void> _toggleVideoNotePlayback() async {
    if (_controller == null) {
      _createController();
      setState(() {});
      try {
        await _initializeFuture;
      } catch (_) {
        return;
      }
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final value = controller.value;
    if (_isCompleted(value)) {
      await controller.seekTo(Duration.zero);
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }
    await controller.setVolume(1);
    await controller.play();
  }

  Widget _buildMaybeMirroredVideoNotePlayer(VideoPlayerController controller) {
    return _buildFrontCameraPlaybackCorrection(
      recordedWithFrontCamera: widget.attachment.wasRecordedWithFrontCamera,
      child: VideoPlayer(controller),
    );
  }

  Widget _buildVideoNotePlayer(VideoPlayerController controller) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final isCompleted = _isCompleted(value);
        final buffering = value.isBuffering && !isCompleted;
        final durationMs = value.duration.inMilliseconds;
        final progress = durationMs <= 0
            ? 0.0
            : (value.position.inMilliseconds / durationMs).clamp(0.0, 1.0);
        final showProgressRing = progress > 0.0 && progress < 1.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            Builder(
              builder: (context) {
                final displaySize = _displayVideoSize(value);
                return ClipRect(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: displaySize.width,
                      height: displaySize.height,
                      child: _buildMaybeMirroredVideoNotePlayer(controller),
                    ),
                  ),
                );
              },
            ),
            if (showProgressRing)
              Positioned.fill(
                child: IgnorePointer(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: progress),
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.linear,
                    builder: (context, animatedProgress, _) {
                      return CustomPaint(
                        painter: _VideoNoteProgressRingPainter(
                          progress: animatedProgress,
                          progressColor: Colors.white,
                          strokeWidth: 4.4,
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (buffering)
              Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: buffering ? 1 : 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.48),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 58,
                      height: 58,
                      child: Center(
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPreviewContent(double previewWidth, {required bool circular}) {
    final controller = _controller;
    final controllerDisplayAspectRatio =
        controller != null && controller.value.isInitialized
        ? _displayVideoAspectRatio(controller.value)
        : null;
    final controllerAspectRatio =
        _normalizedMediaAspectRatio(controllerDisplayAspectRatio) ??
        _normalizedMediaAspectRatio(widget.attachment.embeddedAspectRatio) ??
        _messageAttachmentPreviewAspectRatioCache[widget.attachment.url] ??
        16 / 9;
    final previewHeight = circular
        ? previewWidth
        : previewWidth / controllerAspectRatio;
    final initializeFuture = _initializeFuture;
    if (initializeFuture == null) {
      if (widget.isVideoNote) {
        return SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: const ColoredBox(color: Colors.black),
        );
      }
      return _AttachmentRetryView(
        title: widget.attachment.previewTitle,
        description: 'Не удалось подготовить видео.',
        icon: Icons.videocam_off_rounded,
        onRetry: () => unawaited(_replaceController()),
        width: previewWidth,
        height: previewHeight,
      );
    }
    return Container(
      width: previewWidth,
      height: circular ? previewHeight : null,
      color: Colors.black,
      child: FutureBuilder<void>(
        future: initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return AspectRatio(
              aspectRatio: circular ? 1 : controllerAspectRatio,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }
          if (snapshot.hasError ||
              controller == null ||
              !controller.value.isInitialized) {
            return _AttachmentRetryView(
              title: widget.attachment.previewTitle,
              description: 'Видео пока не загружается. Попробуйте еще раз.',
              icon: Icons.videocam_off_rounded,
              onRetry: () => unawaited(_replaceController()),
              width: previewWidth,
              height: previewHeight,
            );
          }
          if (widget.isVideoNote) {
            return _buildVideoNotePlayer(controller);
          }
          return AspectRatio(
            aspectRatio: controllerAspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                VideoPlayer(controller),
                _AttachmentDurationBadge(duration: controller.value.duration),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final previewWidth = _messageAttachmentPreviewWidthFor(constraints);
        if (widget.isVideoNote) {
          Widget buildVideoNotePreview(double diameter) {
            final previewChild = _buildPreviewContent(diameter, circular: true);
            return SizedBox.square(
              dimension: diameter,
              child: _buildCircularMessageAttachmentPreview(
                onTap: () => unawaited(_toggleVideoNotePlayback()),
                diameter: diameter,
                isMine: widget.isMine,
                showMessageBubble: false,
                child: previewChild,
              ),
            );
          }

          final controller = _controller;
          if (controller == null) {
            return buildVideoNotePreview(_videoNoteAttachmentPreviewDiameter);
          }
          return ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final diameter = value.isPlaying
                  ? _videoNoteAttachmentPlayingDiameter
                  : _videoNoteAttachmentPreviewDiameter;
              return buildVideoNotePreview(diameter);
            },
          );
        }
        final previewChild = _buildPreviewContent(
          previewWidth,
          circular: false,
        );
        return _buildRoundedMessageAttachmentPreview(
          onTap: widget.onTap,
          child: previewChild,
        );
      },
    );
  }
}

class _FileAttachmentTile extends StatelessWidget {
  const _FileAttachmentTile({
    required this.attachment,
    required this.isMine,
    this.onTap,
  });

  final MessageAttachment attachment;
  final bool isMine;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const titleColor = Colors.white;
    final subtitleColor = Colors.white.withValues(alpha: 0.86);
    const iconColor = Colors.white;
    final subtitleText =
        attachment.hideOriginalNameInPreview || attachment.kind == 'file'
        ? null
        : attachment.summaryLabel;
    final icon = switch (attachment.kind) {
      'audio' => Icons.audiotrack_rounded,
      'video' => Icons.videocam_rounded,
      'image' => Icons.image_rounded,
      _ => Icons.insert_drive_file_rounded,
    };
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 228),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.previewTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                    ),
                  ),
                  if (subtitleText != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitleText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: subtitleColor),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: content,
      ),
    );
  }
}
