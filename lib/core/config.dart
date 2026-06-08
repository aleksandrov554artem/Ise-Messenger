part of '../main.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://5.35.89.147:8000',
);
const Duration networkTimeout = Duration(seconds: 15);
const Duration attachmentUploadBaseTimeout = Duration(seconds: 30);
const Duration attachmentUploadMaxTimeout = Duration(minutes: 10);
const int attachmentUploadTimeoutBytesPerSecond = 128 * 1024;

abstract final class AppColors {
  static const Color primary = Color(0xFF4A9FD8);
  static const Color danger = Color(0xFFC45B6A);
  static const Color success = Color(0xFF6BCB98);
  static const Color surface = Colors.white;
  static const Color softSurface = Color(0xFFF7FAFD);
  static const Color outline = Color(0xFFDDE8F2);
  static const Color text = Color(0xFF172033);
  static const Color mutedText = Color(0xFF64748B);
  static const Color subtleTrack = Color(0xFFE3EDF6);
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double emptyStateTop = 84;
}

abstract final class AppRadius {
  static const double compact = 12;
  static const double control = 16;
  static const double pill = 999;
}

abstract final class AppDurations {
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 320);
}

const Color appPrimaryColor = AppColors.primary;
const Color appDangerColor = AppColors.danger;
const Color appSurfaceColor = AppColors.surface;
const Color appSoftSurfaceColor = AppColors.softSurface;
const Color appOutlineColor = AppColors.outline;
const Color appTextColor = AppColors.text;
const Color appMutedTextColor = AppColors.mutedText;
const double appControlRadius = AppRadius.control;
const double appCompactRadius = AppRadius.compact;
const double appEmptyStateTopSpacing = AppSpacing.emptyStateTop;
const SystemUiOverlayStyle appLightSurfaceOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemStatusBarContrastEnforced: false,
);
const SystemUiOverlayStyle appDarkSurfaceOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemStatusBarContrastEnforced: false,
);
const Object _noFieldChange = Object();
const String _legacyAuthTokenPreferenceKey = 'auth_token';
const String _secureAuthTokenStorageKey = 'auth_token';
const Duration appUpdateCheckCooldown = Duration(seconds: 45);
const List<Map<String, dynamic>> defaultIceServers = [
  {'urls': 'stun:stun.l.google.com:19302'},
  {'urls': 'stun:stun1.l.google.com:19302'},
];
final Uri apiBaseUri = Uri.parse(
  apiBaseUrl.endsWith('/') ? apiBaseUrl : '$apiBaseUrl/',
);
final Uri githubLatestReleaseUri = Uri.https(
  'api.github.com',
  '/repos/aleksandrov554artem/Ise-Messenger/releases/latest',
);
final ThemeData appTheme = buildAppTheme();
Future<SharedPreferences>? _sharedPreferencesFuture;
const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
final http.Client _sharedUtilityHttpClient = http.Client();
final RegExp _versionPartPattern = RegExp(r'\d+');
final RegExp _invalidFileNameCharacterPattern = RegExp(r'[\\/:*?"<>|]');
final RegExp _safeFileExtensionPattern = RegExp(r'^\.[a-z0-9]{1,8}$');
final RegExp _emailValidationPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final RegExp _serverDateTimezonePattern = RegExp(r'(Z|[+-]\d{2}:\d{2})$');
OverlayEntry? _activeToastEntry;
Timer? _activeToastTimer;
String? _serverMediaBearerToken;

Future<SharedPreferences> _sharedPreferences() =>
    _sharedPreferencesFuture ??= SharedPreferences.getInstance();

Future<String?> _readStoredAuthToken(SharedPreferences prefs) async {
  final legacyToken = prefs.getString(_legacyAuthTokenPreferenceKey)?.trim();
  try {
    final secureToken = (await _secureStorage.read(
      key: _secureAuthTokenStorageKey,
    ))?.trim();
    if (secureToken != null && secureToken.isNotEmpty) {
      if (legacyToken != null && legacyToken.isNotEmpty) {
        await prefs.remove(_legacyAuthTokenPreferenceKey);
      }
      return secureToken;
    }
    if (legacyToken != null && legacyToken.isNotEmpty) {
      await _secureStorage.write(
        key: _secureAuthTokenStorageKey,
        value: legacyToken,
      );
      await prefs.remove(_legacyAuthTokenPreferenceKey);
      return legacyToken;
    }
  } catch (_) {
    if (legacyToken != null && legacyToken.isNotEmpty) {
      return legacyToken;
    }
  }
  return null;
}

Future<void> _writeStoredAuthToken(
  SharedPreferences? prefs,
  String token,
) async {
  final normalized = token.trim();
  if (normalized.isEmpty) {
    await _deleteStoredAuthToken(prefs);
    return;
  }
  try {
    await _secureStorage.write(
      key: _secureAuthTokenStorageKey,
      value: normalized,
    );
    await prefs?.remove(_legacyAuthTokenPreferenceKey);
  } catch (_) {
    await prefs?.setString(_legacyAuthTokenPreferenceKey, normalized);
  }
}

Future<void> _deleteStoredAuthToken(SharedPreferences? prefs) async {
  try {
    await _secureStorage.delete(key: _secureAuthTokenStorageKey);
  } catch (_) {}
  await prefs?.remove(_legacyAuthTokenPreferenceKey);
}

void setServerMediaAuthToken(String? token) {
  final normalized = token?.trim();
  _serverMediaBearerToken = normalized == null || normalized.isEmpty
      ? null
      : normalized;
}

bool _isServerMediaUrl(String value) {
  final cleaned = value.trim();
  if (cleaned.isEmpty) {
    return false;
  }
  final parsed = Uri.tryParse(cleaned);
  if (parsed == null) {
    return false;
  }
  final uri = parsed.hasScheme ? parsed : apiBaseUri.resolveUri(parsed);
  final apiPort = apiBaseUri.hasPort ? apiBaseUri.port : null;
  final uriPort = uri.hasPort ? uri.port : null;
  return uri.scheme.toLowerCase() == apiBaseUri.scheme.toLowerCase() &&
      uri.host.toLowerCase() == apiBaseUri.host.toLowerCase() &&
      uriPort == apiPort &&
      uri.path.startsWith('/media/');
}

Map<String, String> serverMediaHttpHeadersFor(
  String url, {
  bool forVideo = false,
}) {
  final headers = <String, String>{};
  if (forVideo) {
    headers['Accept-Encoding'] = 'identity';
  }
  final token = _serverMediaBearerToken;
  if (token != null && _isServerMediaUrl(url)) {
    headers['Authorization'] = 'Bearer $token';
  }
  return headers;
}

Duration attachmentUploadTimeoutForBytes(int byteCount) {
  final normalizedByteCount = byteCount < 0 ? 0 : byteCount;
  final transferSeconds =
      (normalizedByteCount / attachmentUploadTimeoutBytesPerSecond).ceil();
  final timeout =
      attachmentUploadBaseTimeout + Duration(seconds: transferSeconds);
  return timeout > attachmentUploadMaxTimeout
      ? attachmentUploadMaxTimeout
      : timeout;
}

class _AvailableAppUpdate {
  const _AvailableAppUpdate({
    required this.versionLabel,
    required this.assetName,
    required this.downloadUrl,
  });

  final String versionLabel;
  final String assetName;
  final String downloadUrl;
}

List<int> _extractComparableVersionParts(String rawValue) {
  return _versionPartPattern
      .allMatches(rawValue)
      .map((match) => int.parse(match.group(0)!))
      .toList();
}

int _compareVersionLabels(String left, String right) {
  final leftParts = _extractComparableVersionParts(left);
  final rightParts = _extractComparableVersionParts(right);
  final maxLength = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < maxLength; index++) {
    final leftValue = index < leftParts.length ? leftParts[index] : 0;
    final rightValue = index < rightParts.length ? rightParts[index] : 0;
    if (leftValue != rightValue) {
      return leftValue.compareTo(rightValue);
    }
  }
  return 0;
}

String _installedAppVersionLabel(PackageInfo packageInfo) {
  return packageInfo.version.trim();
}

String _sanitizeUpdateFileName(String rawValue) {
  final trimmed = rawValue.trim();
  final fallback = trimmed.isEmpty ? 'ise_messenger_update.apk' : trimmed;
  return fallback.replaceAll(_invalidFileNameCharacterPattern, '_');
}

Future<_AvailableAppUpdate?> _fetchLatestGitHubAppUpdate() async {
  final response = await _sharedUtilityHttpClient
      .get(
        githubLatestReleaseUri,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'Ise Messenger Updater',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      )
      .timeout(networkTimeout);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    return null;
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map<String, dynamic>) {
    return null;
  }
  final rawAssets = decoded['assets'] as List<dynamic>? ?? const <dynamic>[];
  Map<String, dynamic>? apkAsset;
  for (final rawAsset in rawAssets) {
    if (rawAsset is! Map) {
      continue;
    }
    final asset = Map<String, dynamic>.from(rawAsset);
    final state = asset['state']?.toString().trim().toLowerCase() ?? '';
    final name = asset['name']?.toString().trim() ?? '';
    final contentType =
        asset['content_type']?.toString().trim().toLowerCase() ?? '';
    final downloadUrl = asset['browser_download_url']?.toString().trim() ?? '';
    final isApk =
        name.toLowerCase().endsWith('.apk') ||
        contentType == 'application/vnd.android.package-archive';
    if (state == 'uploaded' && isApk && downloadUrl.isNotEmpty) {
      apkAsset = asset;
      break;
    }
  }
  if (apkAsset == null) {
    return null;
  }
  final assetName = apkAsset['name']?.toString().trim() ?? '';
  final versionCandidates = <String>[
    decoded['tag_name']?.toString().trim() ?? '',
    decoded['name']?.toString().trim() ?? '',
    assetName,
  ];
  String versionLabel = '';
  for (final candidate in versionCandidates) {
    if (_extractComparableVersionParts(candidate).isNotEmpty) {
      versionLabel = candidate;
      break;
    }
  }
  if (versionLabel.isEmpty) {
    return null;
  }
  return _AvailableAppUpdate(
    versionLabel: versionLabel,
    assetName: assetName.isEmpty
        ? 'ise_messenger_$versionLabel.apk'
        : assetName,
    downloadUrl: apkAsset['browser_download_url']!.toString().trim(),
  );
}

String? resolveServerMediaUrl(String? rawValue) {
  final cleaned = rawValue?.trim() ?? '';
  if (cleaned.isEmpty) {
    return null;
  }
  final parsedUri = Uri.tryParse(cleaned);
  if (parsedUri == null) {
    return apiBaseUri.resolve(cleaned).toString();
  }
  if (parsedUri.hasScheme) {
    return parsedUri.toString();
  }
  return apiBaseUri.resolveUri(parsedUri).toString();
}

const Set<String> _imageAttachmentExtensions = {
  'jpg',
  'jpeg',
  'png',
  'gif',
  'webp',
  'bmp',
  'heic',
  'heif',
};
const Set<String> _videoAttachmentExtensions = {
  'mp4',
  'mov',
  'avi',
  'mkv',
  'webm',
  'm4v',
  '3gp',
  '3g2',
  'mpeg',
  'mpg',
  'ts',
  'm2ts',
  'wmv',
};
const Set<String> _audioAttachmentExtensions = {
  'mp3',
  'wav',
  'ogg',
  'aac',
  'm4a',
  'flac',
  'opus',
  'weba',
};
const Map<String, String> _knownMimeTypesByExtension = {
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'bmp': 'image/bmp',
  'heic': 'image/heic',
  'heif': 'image/heif',
  'mp4': 'video/mp4',
  'm4v': 'video/mp4',
  'mov': 'video/quicktime',
  'avi': 'video/x-msvideo',
  'mkv': 'video/x-matroska',
  'webm': 'video/webm',
  '3gp': 'video/3gpp',
  '3g2': 'video/3gpp2',
  'mpeg': 'video/mpeg',
  'mpg': 'video/mpeg',
  'ts': 'video/mp2t',
  'm2ts': 'video/mp2t',
  'wmv': 'video/x-ms-wmv',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'aac': 'audio/aac',
  'm4a': 'audio/mp4',
  'flac': 'audio/flac',
  'opus': 'audio/opus',
  'weba': 'audio/webm',
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'json': 'application/json',
  'zip': 'application/zip',
  'apk': 'application/vnd.android.package-archive',
};

String _fileExtensionFromName(String rawName) {
  final normalizedName = rawName.trim().toLowerCase();
  final dotIndex = normalizedName.lastIndexOf('.');
  if (dotIndex <= -1 || dotIndex == normalizedName.length - 1) {
    return '';
  }
  return normalizedName.substring(dotIndex + 1);
}

String _fileExtensionFromUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl.trim());
  if (uri == null || uri.pathSegments.isEmpty) {
    return '';
  }
  return _fileExtensionFromName(uri.pathSegments.last);
}

String? _mimeTypeForFileName(String rawName) {
  final extension = _fileExtensionFromName(rawName);
  if (extension.isEmpty) {
    return null;
  }
  return _knownMimeTypesByExtension[extension];
}

MediaType? _multipartContentTypeForFile({
  required String filePath,
  required String fileName,
}) {
  final mimeType =
      _mimeTypeForFileName(fileName) ?? _mimeTypeForFileName(filePath);
  return mimeType == null ? null : MediaType.parse(mimeType);
}

String _attachmentKindFromMimeType(String rawMimeType) {
  final mimeType = rawMimeType.trim().toLowerCase();
  if (mimeType.startsWith('image/')) {
    return 'image';
  }
  if (mimeType.startsWith('video/')) {
    return 'video';
  }
  if (mimeType.startsWith('audio/')) {
    return 'audio';
  }
  return 'file';
}

String _attachmentKindFromExtension(String extension) {
  if (_imageAttachmentExtensions.contains(extension)) {
    return 'image';
  }
  if (_videoAttachmentExtensions.contains(extension)) {
    return 'video';
  }
  if (_audioAttachmentExtensions.contains(extension)) {
    return 'audio';
  }
  return 'file';
}

String resolveAttachmentKind({
  required String rawKind,
  required String mimeType,
  required String name,
  required String url,
  required String downloadUrl,
}) {
  final serverKind = rawKind.trim().toLowerCase();
  final normalizedName = name.trim().toLowerCase();
  if (normalizedName.startsWith('video_note')) {
    return 'video';
  }
  if (normalizedName.startsWith('voice_message_')) {
    return 'audio';
  }
  if (serverKind == 'image' || serverKind == 'video' || serverKind == 'audio') {
    return serverKind;
  }
  final mimeKind = _attachmentKindFromMimeType(mimeType);
  if (mimeKind != 'file') {
    return mimeKind;
  }
  final extensionCandidates = <String>[
    _fileExtensionFromName(name),
    _fileExtensionFromUrl(url),
    _fileExtensionFromUrl(downloadUrl),
  ];
  for (final extension in extensionCandidates) {
    final extensionKind = _attachmentKindFromExtension(extension);
    if (extensionKind != 'file') {
      return extensionKind;
    }
  }
  return 'file';
}

int _stableVideoCacheHash(String value) {
  var hash = 0x811C9DC5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

String _videoCacheExtensionForUrl(String url) {
  final uri = Uri.tryParse(url);
  final lastSegment = uri?.pathSegments.isNotEmpty ?? false
      ? uri!.pathSegments.last
      : '';
  final dotIndex = lastSegment.lastIndexOf('.');
  if (dotIndex <= -1 || dotIndex == lastSegment.length - 1) {
    return '.mp4';
  }
  final extension = lastSegment.substring(dotIndex).toLowerCase();
  return _safeFileExtensionPattern.hasMatch(extension) ? extension : '.mp4';
}

String _audioCacheExtensionForUrl(String url) {
  final uri = Uri.tryParse(url);
  final lastSegment = uri?.pathSegments.isNotEmpty ?? false
      ? uri!.pathSegments.last
      : '';
  final dotIndex = lastSegment.lastIndexOf('.');
  if (dotIndex <= -1 || dotIndex == lastSegment.length - 1) {
    return '.m4a';
  }
  final extension = lastSegment.substring(dotIndex).toLowerCase();
  return _safeFileExtensionPattern.hasMatch(extension) ? extension : '.m4a';
}

Future<File> _downloadAudioAttachmentToCache(String rawUrl) async {
  final sourceUrl = rawUrl.trim();
  if (sourceUrl.isEmpty) {
    throw Exception('Audio URL is empty');
  }
  final cacheDirectory = Directory(
    '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}audio_cache',
  );
  if (!await cacheDirectory.exists()) {
    await cacheDirectory.create(recursive: true);
  }
  final extension = _audioCacheExtensionForUrl(sourceUrl);
  final cacheFile = File(
    '${cacheDirectory.path}${Platform.pathSeparator}audio_${_stableVideoCacheHash(sourceUrl).toRadixString(16)}$extension',
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
    throw Exception('Audio download failed');
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
      throw Exception('Audio download failed');
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

Future<File> _downloadVideoAttachmentToCache(
  MessageAttachment attachment,
) async {
  final sourceUrl = attachment.downloadUrl.trim().isEmpty
      ? attachment.url.trim()
      : attachment.downloadUrl.trim();
  if (sourceUrl.isEmpty) {
    throw Exception('Video URL is empty');
  }
  final cacheDirectory = Directory(
    '${(await getTemporaryDirectory()).path}${Platform.pathSeparator}video_cache',
  );
  if (!await cacheDirectory.exists()) {
    await cacheDirectory.create(recursive: true);
  }
  final extension = _videoCacheExtensionForUrl(sourceUrl);
  final cacheFile = File(
    '${cacheDirectory.path}${Platform.pathSeparator}video_${_stableVideoCacheHash(sourceUrl).toRadixString(16)}$extension',
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
    throw Exception('Video download failed');
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
      throw Exception('Video download failed');
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

Future<VideoPlayerController> _createCompatibleVideoController(
  MessageAttachment attachment,
) async {
  final sourceUrl = attachment.downloadUrl.trim().isEmpty
      ? attachment.url.trim()
      : attachment.downloadUrl.trim();
  if (sourceUrl.isEmpty) {
    throw Exception('Video URL is empty');
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
    final cachedVideo = await _downloadVideoAttachmentToCache(attachment);
    final fileController = VideoPlayerController.file(cachedVideo);
    await fileController.initialize();
    return fileController;
  }
}
