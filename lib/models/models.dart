part of '../main.dart';

enum AppStage { loading, email, code, name, contacts }

enum CallStage {
  incoming,
  outgoing,
  connecting,
  connected,
  missed,
  canceled,
  ended,
  rejected,
  failed,
}

enum ChatType { direct, group }

int parseFlexibleIntId(dynamic value) {
  if (value is num) {
    return value.toInt();
  }
  final text = value?.toString().trim() ?? '';
  final parsed = int.tryParse(text);
  if (parsed != null) {
    return parsed;
  }
  var hash = 0;
  for (final codeUnit in text.codeUnits) {
    hash = ((hash * 31) + codeUnit) & 0x7fffffff;
  }
  return hash;
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.description,
    required this.avatarUrl,
  });

  final int id;
  final String email;
  final String name;
  final String description;
  final String? avatarUrl;

  UserProfile copyWith({
    String? email,
    String? name,
    String? description,
    String? avatarUrl,
  }) {
    return UserProfile(
      id: id,
      email: email ?? this.email,
      name: name ?? this.name,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: parseFlexibleIntId(json['id']),
      email: json['email'].toString(),
      name: sanitizeDisplayText(
        json['name']?.toString() ?? '',
        preserveLineBreaks: false,
      ),
      description: sanitizeDisplayText(json['description']?.toString() ?? ''),
      avatarUrl: resolveServerMediaUrl(json['avatar_url']?.toString()),
    );
  }
}

class UserProfileDetails {
  const UserProfileDetails({
    required this.user,
    required this.isOnline,
    required this.lastSeenAt,
    required this.isCurrentUser,
  });

  final UserProfile user;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final bool isCurrentUser;

  factory UserProfileDetails.fromJson(Map<String, dynamic> json) {
    return UserProfileDetails(
      user: UserProfile.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      isOnline: json['online'] == true,
      lastSeenAt: parseServerDateTime(json['last_seen_at']?.toString()),
      isCurrentUser: json['is_current_user'] == true,
    );
  }
}

class StoryItem {
  const StoryItem({
    required this.id,
    required this.userId,
    required this.authorName,
    required this.authorAvatarUrl,
    required this.mediaName,
    required this.mediaUrl,
    required this.mediaMimeType,
    required this.createdAt,
    required this.expiresAt,
  });

  final int id;
  final int userId;
  final String authorName;
  final String? authorAvatarUrl;
  final String mediaName;
  final String mediaUrl;
  final String mediaMimeType;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isMine(int? currentUserId) =>
      currentUserId != null && userId == currentUserId;
  bool get wasRecordedWithFrontCamera =>
      mediaName.trim().toLowerCase().contains('camfront');

  factory StoryItem.fromJson(Map<String, dynamic> json) {
    return StoryItem(
      id: parseFlexibleIntId(json['id']),
      userId: parseFlexibleIntId(json['user_id']),
      authorName: sanitizeDisplayText(
        json['author_name']?.toString() ?? '',
        preserveLineBreaks: false,
      ),
      authorAvatarUrl: resolveServerMediaUrl(
        json['author_avatar_url']?.toString(),
      ),
      mediaName: sanitizeDisplayText(
        json['media_name']?.toString() ?? '',
        preserveLineBreaks: false,
      ),
      mediaUrl: resolveServerMediaUrl(json['media_url']?.toString()) ?? '',
      mediaMimeType:
          json['media_mime_type']?.toString().trim().toLowerCase() ??
          'video/mp4',
      createdAt:
          parseServerDateTime(json['created_at']?.toString()) ?? DateTime.now(),
      expiresAt:
          parseServerDateTime(json['expires_at']?.toString()) ??
          DateTime.now().add(const Duration(hours: 24)),
    );
  }
}

class ContactItem {
  ContactItem({
    required this.userId,
    required this.remoteId,
    required this.chatType,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.lastMessageServiceKind,
    required this.lastMessageCallInitiatorId,
    required this.lastMessageCallStatus,
    required this.lastMessageCallIsVideo,
    required this.lastMessageSenderId,
    required this.lastMessageSenderName,
    this.lastMessageAttachmentName,
    this.lastMessageAttachmentKind,
    required this.lastMessageAt,
    required this.lastSeenAt,
    required this.isOnline,
    required this.ownerId,
    required this.memberCount,
    required this.onlineMemberCount,
    required this.unreadCount,
  });

  final int userId;
  final int remoteId;
  final ChatType chatType;
  final String email;
  final String name;
  final String? avatarUrl;
  final String lastMessage;
  final String? lastMessageServiceKind;
  final int? lastMessageCallInitiatorId;
  final String? lastMessageCallStatus;
  final bool? lastMessageCallIsVideo;
  final int? lastMessageSenderId;
  final String? lastMessageSenderName;
  final String? lastMessageAttachmentName;
  final String? lastMessageAttachmentKind;
  final DateTime? lastMessageAt;
  final DateTime? lastSeenAt;
  final bool isOnline;
  final int? ownerId;
  final int memberCount;
  final int onlineMemberCount;
  final int unreadCount;

  bool get isGroup => chatType == ChatType.group;

  bool get isDirect => chatType == ChatType.direct;

  bool get hasUnreadMessageIndicator =>
      unreadCount > 0 && lastMessageServiceKind != callHistoryServiceKind;

  late final String searchText =
      '${sanitizeDisplayText(name, preserveLineBreaks: false).toLowerCase()} ${email.trim().toLowerCase()}';

  bool matchesSearch(String normalizedQuery) {
    return normalizedQuery.isEmpty || searchText.contains(normalizedQuery);
  }

  ContactItem copyWith({
    String? name,
    String? email,
    Object? avatarUrl = _noFieldChange,
    String? lastMessage,
    Object? lastMessageServiceKind = _noFieldChange,
    Object? lastMessageCallInitiatorId = _noFieldChange,
    Object? lastMessageCallStatus = _noFieldChange,
    Object? lastMessageCallIsVideo = _noFieldChange,
    Object? lastMessageSenderId = _noFieldChange,
    Object? lastMessageSenderName = _noFieldChange,
    Object? lastMessageAttachmentName = _noFieldChange,
    Object? lastMessageAttachmentKind = _noFieldChange,
    Object? lastMessageAt = _noFieldChange,
    Object? lastSeenAt = _noFieldChange,
    bool? isOnline,
    Object? ownerId = _noFieldChange,
    int? memberCount,
    int? onlineMemberCount,
    int? unreadCount,
  }) {
    return ContactItem(
      userId: userId,
      remoteId: remoteId,
      chatType: chatType,
      email: email ?? this.email,
      name: name ?? this.name,
      avatarUrl: identical(avatarUrl, _noFieldChange)
          ? this.avatarUrl
          : avatarUrl as String?,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageServiceKind: identical(lastMessageServiceKind, _noFieldChange)
          ? this.lastMessageServiceKind
          : lastMessageServiceKind as String?,
      lastMessageCallInitiatorId:
          identical(lastMessageCallInitiatorId, _noFieldChange)
          ? this.lastMessageCallInitiatorId
          : lastMessageCallInitiatorId as int?,
      lastMessageCallStatus: identical(lastMessageCallStatus, _noFieldChange)
          ? this.lastMessageCallStatus
          : lastMessageCallStatus as String?,
      lastMessageCallIsVideo: identical(lastMessageCallIsVideo, _noFieldChange)
          ? this.lastMessageCallIsVideo
          : lastMessageCallIsVideo as bool?,
      lastMessageSenderId: identical(lastMessageSenderId, _noFieldChange)
          ? this.lastMessageSenderId
          : lastMessageSenderId as int?,
      lastMessageSenderName: identical(lastMessageSenderName, _noFieldChange)
          ? this.lastMessageSenderName
          : lastMessageSenderName as String?,
      lastMessageAttachmentName:
          identical(lastMessageAttachmentName, _noFieldChange)
          ? this.lastMessageAttachmentName
          : lastMessageAttachmentName as String?,
      lastMessageAttachmentKind:
          identical(lastMessageAttachmentKind, _noFieldChange)
          ? this.lastMessageAttachmentKind
          : lastMessageAttachmentKind as String?,
      lastMessageAt: identical(lastMessageAt, _noFieldChange)
          ? this.lastMessageAt
          : lastMessageAt as DateTime?,
      lastSeenAt: identical(lastSeenAt, _noFieldChange)
          ? this.lastSeenAt
          : lastSeenAt as DateTime?,
      isOnline: isOnline ?? this.isOnline,
      ownerId: identical(ownerId, _noFieldChange)
          ? this.ownerId
          : ownerId as int?,
      memberCount: memberCount ?? this.memberCount,
      onlineMemberCount: onlineMemberCount ?? this.onlineMemberCount,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  factory ContactItem.fromJson(Map<String, dynamic> json) {
    final chatType = parseChatType(json['chat_type']?.toString());
    final remoteId = (json['id'] as num).toInt();
    final rawTime = json['last_message_at']?.toString();
    final rawLastSeen = json['last_seen_at']?.toString();
    final parsedMemberCount =
        (json['member_count'] as num?)?.toInt() ??
        (chatType == ChatType.group ? 0 : 2);
    final safeMemberCount = parsedMemberCount < 0 ? 0 : parsedMemberCount;
    final parsedOnlineMemberCount = (json['online_member_count'] as num?)
        ?.toInt();
    final parsedLastMessage = parseStoredMessageText(
      json['last_message']?.toString() ?? '',
    );
    final lastMessageText =
        parsedLastMessage.serviceKind == callHistoryServiceKind
        ? ''
        : parsedLastMessage.text;
    return ContactItem(
      userId: chatType == ChatType.group ? -remoteId : remoteId,
      remoteId: remoteId,
      chatType: chatType,
      email: json['email']?.toString() ?? '',
      name: sanitizeDisplayText(
        json['name']?.toString() ?? '',
        preserveLineBreaks: false,
      ),
      avatarUrl: resolveServerMediaUrl(json['avatar_url']?.toString()),
      lastMessage: sanitizeDisplayText(
        lastMessageText,
        preserveLineBreaks: false,
      ),
      lastMessageServiceKind: parsedLastMessage.serviceKind,
      lastMessageCallInitiatorId: parsedLastMessage.callInitiatorId,
      lastMessageCallStatus: parsedLastMessage.callStatus,
      lastMessageCallIsVideo: parsedLastMessage.callIsVideo,
      lastMessageSenderId: (json['last_message_sender_id'] as num?)?.toInt(),
      lastMessageSenderName: emptyToNull(
        sanitizeDisplayText(
          json['last_message_sender_name']?.toString() ?? '',
          preserveLineBreaks: false,
        ),
      ),
      lastMessageAttachmentName: emptyToNull(
        sanitizeDisplayText(
          json['last_message_attachment_name']?.toString() ?? '',
          preserveLineBreaks: false,
        ),
      ),
      lastMessageAttachmentKind: emptyToNull(
        json['last_message_attachment_kind']?.toString().trim().toLowerCase() ??
            '',
      ),
      lastMessageAt: parseServerDateTime(rawTime),
      lastSeenAt: parseServerDateTime(rawLastSeen),
      isOnline: json['online'] == true,
      ownerId: (json['owner_id'] as num?)?.toInt(),
      memberCount: safeMemberCount,
      onlineMemberCount: parsedOnlineMemberCount != null
          ? parsedOnlineMemberCount.clamp(0, safeMemberCount)
          : (chatType == ChatType.direct && json['online'] == true ? 1 : 0),
      unreadCount: parsedLastMessage.serviceKind == callHistoryServiceKind
          ? 0
          : (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }
}

const String forwardedMessagePrefix = 'pgfwd:v1:';
const String callHistoryServiceKind = 'call_history';
const String callHistoryStatusStarted = 'started';
const String callHistoryStatusMissed = 'missed';
const String callHistoryStatusRejected = 'rejected';
const String callHistoryStatusCanceled = 'canceled';
const String callHistoryStatusEnded = 'ended';
const String callHistoryStatusFailed = 'failed';

class MessageReaderInfo {
  const MessageReaderInfo({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.readAt,
  });

  final int id;
  final String name;
  final String? avatarUrl;
  final DateTime? readAt;

  factory MessageReaderInfo.fromJson(Map<String, dynamic> json) {
    return MessageReaderInfo(
      id: (json['id'] as num).toInt(),
      name: sanitizeDisplayText(
        json['name']?.toString() ?? '',
        preserveLineBreaks: false,
      ),
      avatarUrl: resolveServerMediaUrl(json['avatar_url']?.toString()),
      readAt: parseServerDateTime(json['read_at']?.toString()),
    );
  }
}

class ParsedStoredMessageText {
  const ParsedStoredMessageText({
    required this.text,
    this.forwardedFromName,
    this.replyToName,
    this.replyToText,
    this.replyToMessageId,
    this.serviceKind,
    this.callInitiatorId,
    this.callStatus,
    this.callIsVideo,
  });

  final String text;
  final String? forwardedFromName;
  final String? replyToName;
  final String? replyToText;
  final int? replyToMessageId;
  final String? serviceKind;
  final int? callInitiatorId;
  final String? callStatus;
  final bool? callIsVideo;
}

class MediaDimensions {
  const MediaDimensions({required this.width, required this.height});

  final int width;
  final int height;

  double get aspectRatio => width / height;
}

class MessageAttachment {
  const MessageAttachment({
    required this.name,
    required this.url,
    required this.downloadUrl,
    required this.mimeType,
    required this.kind,
  });

  final String name;
  final String url;
  final String downloadUrl;
  final String mimeType;
  final String kind;

  String get _normalizedName => name.trim().toLowerCase();
  bool get _hasImageExtension =>
      _imageAttachmentExtensions.contains(_fileExtensionFromName(name)) ||
      _imageAttachmentExtensions.contains(_fileExtensionFromUrl(url)) ||
      _imageAttachmentExtensions.contains(_fileExtensionFromUrl(downloadUrl));
  bool get _hasVideoExtension =>
      _videoAttachmentExtensions.contains(_fileExtensionFromName(name)) ||
      _videoAttachmentExtensions.contains(_fileExtensionFromUrl(url)) ||
      _videoAttachmentExtensions.contains(_fileExtensionFromUrl(downloadUrl));
  bool get _hasAudioExtension =>
      _audioAttachmentExtensions.contains(_fileExtensionFromName(name)) ||
      _audioAttachmentExtensions.contains(_fileExtensionFromUrl(url)) ||
      _audioAttachmentExtensions.contains(_fileExtensionFromUrl(downloadUrl));
  bool get isImage =>
      kind == 'image' || mimeType.startsWith('image/') || _hasImageExtension;
  bool get isVideo =>
      kind == 'video' ||
      mimeType.startsWith('video/') ||
      _hasVideoExtension ||
      _normalizedName.startsWith('video_note');
  bool get isAudio =>
      kind == 'audio' ||
      mimeType.startsWith('audio/') ||
      _hasAudioExtension ||
      _normalizedName.startsWith('voice_message_');
  bool get isVideoNote => isVideo && _normalizedName.startsWith('video_note');
  bool get isVoiceMessage =>
      isAudio && _normalizedName.startsWith('voice_message_');
  bool get wasRecordedWithBackCamera => _normalizedName.contains('camback');
  bool get wasRecordedWithMixedCamera => _normalizedName.contains('cammixed');
  bool get wasRecordedWithFrontCamera =>
      _normalizedName.contains('camfront') ||
      (isVideoNote &&
          !wasRecordedWithBackCamera &&
          !wasRecordedWithMixedCamera);
  Duration get embeddedDuration {
    final match = RegExp(
      r'(?:^|_)dur(\d+)s(?:_|\.|$)',
    ).firstMatch(name.trim().toLowerCase());
    final seconds = int.tryParse(match?.group(1) ?? '');
    if (seconds == null || seconds <= 0) {
      return Duration.zero;
    }
    return Duration(seconds: seconds);
  }

  MediaDimensions? get embeddedDimensions {
    final match = RegExp(
      r'(?:^|_)dim(\d+)x(\d+)(?:_|\.|$)',
    ).firstMatch(name.trim().toLowerCase());
    final width = int.tryParse(match?.group(1) ?? '');
    final height = int.tryParse(match?.group(2) ?? '');
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    return MediaDimensions(width: width, height: height);
  }

  double? get embeddedAspectRatio {
    final dimensions = embeddedDimensions;
    if (dimensions == null) {
      return null;
    }
    return dimensions.aspectRatio;
  }

  bool get isPreviewable => isImage || isVideo;
  bool get hideOriginalNameInPreview =>
      isImage || isVideo || isVoiceMessage || isVideoNote;
  String get summaryLabel {
    if (isVideoNote) {
      return '\u0412\u0438\u0434\u0435\u043e \u043a\u0440\u0443\u0436\u043e\u043a';
    }
    if (isImage) {
      return '\u0424\u043e\u0442\u043e';
    }
    if (isVideo) {
      return '\u0412\u0438\u0434\u0435\u043e';
    }
    if (isAudio) {
      return '\u0410\u0443\u0434\u0438\u043e';
    }
    return name.trim().isEmpty ? '\u0424\u0430\u0439\u043b' : name;
  }

  String get previewTitle =>
      hideOriginalNameInPreview || name.trim().isEmpty ? summaryLabel : name;

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    final name = sanitizeDisplayText(
      json['name']?.toString() ?? '',
      preserveLineBreaks: false,
    );
    final url = resolveServerMediaUrl(json['url']?.toString()) ?? '';
    final downloadUrl =
        resolveServerMediaUrl(json['download_url']?.toString()) ?? '';
    final mimeType =
        json['mime_type']?.toString().trim().toLowerCase() ??
        'application/octet-stream';
    return MessageAttachment(
      name: name,
      url: url,
      downloadUrl: downloadUrl,
      mimeType: mimeType,
      kind: resolveAttachmentKind(
        rawKind: json['kind']?.toString() ?? 'file',
        mimeType: mimeType,
        name: name,
        url: url,
        downloadUrl: downloadUrl,
      ),
    );
  }
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.chatType,
    required this.senderId,
    required this.receiverId,
    required this.groupId,
    required this.text,
    required this.createdAt,
    required this.isRead,
    required this.isEdited,
    required this.senderName,
    required this.senderAvatarUrl,
    required this.forwardedFromName,
    required this.replyToName,
    required this.replyToText,
    required this.replyToMessageId,
    required this.serviceKind,
    required this.callInitiatorId,
    required this.callStatus,
    required this.callIsVideo,
    required this.attachment,
  });

  final int id;
  final ChatType chatType;
  final int senderId;
  final int receiverId;
  final int? groupId;
  final String text;
  final DateTime createdAt;
  final bool isRead;
  final bool isEdited;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? forwardedFromName;
  final String? replyToName;
  final String? replyToText;
  final int? replyToMessageId;
  final String? serviceKind;
  final int? callInitiatorId;
  final String? callStatus;
  final bool? callIsVideo;
  final MessageAttachment? attachment;
  late final List<_MessageTextSegment> _textSegments = _splitMessageText(text);
  late final String? firstLink = _extractFirstLinkFromSegments(_textSegments);

  bool get isGroup => chatType == ChatType.group;
  bool get isForwarded =>
      forwardedFromName != null && forwardedFromName!.trim().isNotEmpty;
  bool get isReply =>
      replyToMessageId != null ||
      (replyToName != null && replyToName!.trim().isNotEmpty) ||
      (replyToText != null && replyToText!.trim().isNotEmpty);
  bool get isCallHistory => serviceKind == callHistoryServiceKind;
  bool get hasAttachment => attachment != null;
  bool get hasText => text.trim().isNotEmpty;
  String get previewSummary => attachment?.summaryLabel ?? 'Сообщение';
  String get replyPreviewText => hasText ? text : previewSummary;
  List<InlineSpan> buildTextSpans({required Color linkColor}) =>
      _buildMessageTextSpansFromSegments(_textSegments, linkColor: linkColor);

  bool isMine(int currentUserId) => senderId == currentUserId;

  ChatMessage copyWith({
    String? text,
    bool? isRead,
    bool? isEdited,
    String? senderName,
    String? senderAvatarUrl,
    Object? forwardedFromName = _noFieldChange,
    Object? replyToName = _noFieldChange,
    Object? replyToText = _noFieldChange,
    Object? replyToMessageId = _noFieldChange,
    Object? serviceKind = _noFieldChange,
    Object? callInitiatorId = _noFieldChange,
    Object? callStatus = _noFieldChange,
    Object? callIsVideo = _noFieldChange,
    Object? attachment = _noFieldChange,
  }) {
    return ChatMessage(
      id: id,
      chatType: chatType,
      senderId: senderId,
      receiverId: receiverId,
      groupId: groupId,
      text: text ?? this.text,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      isEdited: isEdited ?? this.isEdited,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      forwardedFromName: identical(forwardedFromName, _noFieldChange)
          ? this.forwardedFromName
          : forwardedFromName as String?,
      replyToName: identical(replyToName, _noFieldChange)
          ? this.replyToName
          : replyToName as String?,
      replyToText: identical(replyToText, _noFieldChange)
          ? this.replyToText
          : replyToText as String?,
      replyToMessageId: identical(replyToMessageId, _noFieldChange)
          ? this.replyToMessageId
          : replyToMessageId as int?,
      serviceKind: identical(serviceKind, _noFieldChange)
          ? this.serviceKind
          : serviceKind as String?,
      callInitiatorId: identical(callInitiatorId, _noFieldChange)
          ? this.callInitiatorId
          : callInitiatorId as int?,
      callStatus: identical(callStatus, _noFieldChange)
          ? this.callStatus
          : callStatus as String?,
      callIsVideo: identical(callIsVideo, _noFieldChange)
          ? this.callIsVideo
          : callIsVideo as bool?,
      attachment: identical(attachment, _noFieldChange)
          ? this.attachment
          : attachment as MessageAttachment?,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final chatType = parseChatType(json['chat_type']?.toString());
    final parsedText = parseStoredMessageText(json['text']?.toString() ?? '');
    final rawAttachment = json['attachment'];
    final attachment = rawAttachment is Map
        ? MessageAttachment.fromJson(Map<String, dynamic>.from(rawAttachment))
        : null;
    final messageText = parsedText.serviceKind == callHistoryServiceKind
        ? normalizeKnownCallSystemText(
            parsedText.text,
            preserveLineBreaks: false,
          )
        : parsedText.text;
    return ChatMessage(
      id: (json['id'] as num).toInt(),
      chatType: chatType,
      senderId: (json['sender_id'] as num).toInt(),
      receiverId: (json['receiver_id'] as num?)?.toInt() ?? 0,
      groupId: (json['group_id'] as num?)?.toInt(),
      text: messageText,
      createdAt:
          parseServerDateTime(json['created_at']?.toString()) ?? DateTime.now(),
      isRead: json['is_read'] == true,
      isEdited: json['is_edited'] == true,
      senderName: emptyToNull(
        sanitizeDisplayText(
          json['sender_name']?.toString() ?? '',
          preserveLineBreaks: false,
        ),
      ),
      senderAvatarUrl: resolveServerMediaUrl(
        json['sender_avatar_url']?.toString(),
      ),
      forwardedFromName: parsedText.forwardedFromName,
      replyToName: parsedText.replyToName,
      replyToText: parsedText.replyToText,
      replyToMessageId: parsedText.replyToMessageId,
      serviceKind: parsedText.serviceKind,
      callInitiatorId: parsedText.callInitiatorId,
      callStatus: parsedText.callStatus,
      callIsVideo: parsedText.callIsVideo,
      attachment: attachment == null || attachment.url.trim().isEmpty
          ? null
          : attachment,
    );
  }
}

String _callMediaLabel(bool isVideo, {bool lowercase = false}) {
  if (isVideo) {
    return lowercase ? 'видеозвонок' : 'Видеозвонок';
  }
  return lowercase ? 'аудиозвонок' : 'Аудиозвонок';
}

String _callDirectionLabel(bool isIncoming, {bool lowercase = false}) {
  if (isIncoming) {
    return lowercase ? 'входящий' : 'Входящий';
  }
  return lowercase ? 'исходящий' : 'Исходящий';
}

String? _inferCallHistoryStatusFromText(String text) {
  final normalized = normalizeKnownCallSystemText(
    text,
    preserveLineBreaks: false,
  ).trim().toLowerCase();
  if (normalized.isEmpty) {
    return null;
  }
  if (normalized.contains('не удалось')) {
    return callHistoryStatusFailed;
  }
  if (normalized.contains('без ответа') || normalized.contains('пропущ')) {
    return callHistoryStatusMissed;
  }
  if (normalized.contains('отклон')) {
    return callHistoryStatusRejected;
  }
  if (normalized.contains('отмен')) {
    return callHistoryStatusCanceled;
  }
  if (normalized.contains('заверш')) {
    return callHistoryStatusEnded;
  }
  if (normalized.contains('звонок')) {
    return callHistoryStatusStarted;
  }
  return null;
}

bool? _inferCallHistoryIsVideoFromText(String text) {
  final normalized = normalizeKnownCallSystemText(
    text,
    preserveLineBreaks: false,
  ).trim().toLowerCase();
  if (normalized.contains('видео')) {
    return true;
  }
  if (normalized.contains('аудио')) {
    return false;
  }
  return null;
}

bool _resolveCallHistoryIncomingForUser({
  required int senderId,
  required int? currentUserId,
  int? callInitiatorId,
}) {
  if (currentUserId != null && callInitiatorId != null) {
    return callInitiatorId != currentUserId;
  }
  if (currentUserId != null) {
    return senderId != currentUserId;
  }
  return true;
}

String buildCallHistoryLabel({
  required bool isIncoming,
  required bool isVideo,
  required String callStatus,
}) {
  final mediaLabel = _callMediaLabel(isVideo, lowercase: true);
  final directionLabel = _callDirectionLabel(isIncoming);
  final directionLowerLabel = _callDirectionLabel(isIncoming, lowercase: true);
  switch (callStatus) {
    case callHistoryStatusMissed:
      return isIncoming
          ? 'Пропущенный $directionLowerLabel $mediaLabel'
          : '$directionLabel $mediaLabel без ответа';
    case callHistoryStatusRejected:
      return isIncoming
          ? 'Пропущенный $directionLowerLabel $mediaLabel'
          : '$directionLabel $mediaLabel отклонён';
    case callHistoryStatusCanceled:
      return '$directionLabel $mediaLabel отменён';
    case callHistoryStatusEnded:
      return '$directionLabel $mediaLabel завершён';
    case callHistoryStatusFailed:
      return 'Не удалось подключить $directionLowerLabel $mediaLabel';
    case callHistoryStatusStarted:
    default:
      return '$directionLabel $mediaLabel';
  }
}

String formatCallHistoryText({
  required String text,
  required int senderId,
  required int? currentUserId,
  int? callInitiatorId,
  String? callStatus,
  bool? callIsVideo,
}) {
  final normalizedText = normalizeKnownCallSystemText(
    text,
    preserveLineBreaks: false,
  ).trim();
  final resolvedStatus = callStatus ?? _inferCallHistoryStatusFromText(text);
  final resolvedIsVideo = callIsVideo ?? _inferCallHistoryIsVideoFromText(text);
  if (resolvedStatus == null || resolvedIsVideo == null) {
    return normalizedText;
  }
  final isIncoming = _resolveCallHistoryIncomingForUser(
    senderId: senderId,
    currentUserId: currentUserId,
    callInitiatorId: callInitiatorId,
  );
  return buildCallHistoryLabel(
    isIncoming: isIncoming,
    isVideo: resolvedIsVideo,
    callStatus: resolvedStatus,
  );
}

String summarizeMessageForPreviewText(
  ChatMessage? message, {
  int? currentUserId,
}) {
  if (message == null) {
    return '';
  }
  if (message.isCallHistory) {
    return '';
  }
  final rawText = sanitizeDisplayText(message.text, preserveLineBreaks: false);
  if (rawText.trim().isNotEmpty) {
    return rawText;
  }
  return message.previewSummary;
}

String? messageAttachmentPreviewName(ChatMessage? message) {
  final name = sanitizeDisplayText(
    message?.attachment?.name ?? '',
    preserveLineBreaks: false,
  ).trim();
  return name.isEmpty ? null : name;
}

String? messageAttachmentPreviewKind(ChatMessage? message) {
  final attachment = message?.attachment;
  if (attachment == null) {
    return null;
  }
  if (attachment.isVideoNote) {
    return 'video_note';
  }
  return attachment.kind.trim().toLowerCase();
}

class GroupMember {
  const GroupMember({
    required this.id,
    required this.email,
    required this.name,
    required this.avatarUrl,
    required this.isOwner,
  });

  final int id;
  final String email;
  final String name;
  final String? avatarUrl;
  final bool isOwner;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: (json['id'] as num).toInt(),
      email: json['email']?.toString() ?? '',
      name: sanitizeDisplayText(
        json['name']?.toString() ?? '',
        preserveLineBreaks: false,
      ),
      avatarUrl: resolveServerMediaUrl(json['avatar_url']?.toString()),
      isOwner: json['is_owner'] == true,
    );
  }
}

class GroupDetails {
  const GroupDetails({required this.group, required this.members});

  final ContactItem group;
  final List<GroupMember> members;
}

class ActiveCall {
  ActiveCall({
    required this.id,
    required this.contact,
    required this.isVideo,
    required this.isIncoming,
    required this.stage,
    this.remoteDescriptionSdp,
    this.remoteDescriptionType,
  });

  final String id;
  final ContactItem contact;
  final bool isVideo;
  final bool isIncoming;
  CallStage stage;
  String? remoteDescriptionSdp;
  String? remoteDescriptionType;
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  final List<RTCIceCandidate> pendingCandidates = [];
  bool renderersReady = false;
  bool remoteDescriptionApplied = false;
  bool isMuted = false;
  bool isSpeakerOn = true;
  bool isSoundOn = true;
  bool isCameraEnabled = true;
  bool remoteCameraEnabled = true;
  bool isFrontCamera = true;
  bool isClosing = false;
  String statusText = '';

  Future<void> ensureRenderers() async {
    if (renderersReady) {
      return;
    }
    await localRenderer.initialize();
    await remoteRenderer.initialize();
    renderersReady = true;
  }

  Future<void> dispose() async {
    final tracks = <MediaStreamTrack>[
      ...?localStream?.getTracks(),
      ...?remoteStream?.getTracks(),
    ];
    for (final track in tracks) {
      await track.stop();
    }
    await peerConnection?.close();
    await peerConnection?.dispose();
    if (renderersReady) {
      localRenderer.srcObject = null;
      remoteRenderer.srcObject = null;
      await localRenderer.dispose();
      await remoteRenderer.dispose();
      renderersReady = false;
    }
    await localStream?.dispose();
    await remoteStream?.dispose();
  }
}

class _RevisionNotifier extends ValueNotifier<int> {
  _RevisionNotifier() : super(0);

  void bump() {
    value = value + 1;
  }
}

class _AttachmentUploadCanceledException implements Exception {
  const _AttachmentUploadCanceledException();
}

class AttachmentUploadCancelToken {
  http.Client? _client;
  bool _isCanceled = false;

  bool get isCanceled => _isCanceled;

  void _attach(http.Client client) {
    if (_isCanceled) {
      client.close();
      return;
    }
    _client = client;
  }

  void _detach(http.Client client) {
    if (identical(_client, client)) {
      _client = null;
    }
  }

  void cancel() {
    _isCanceled = true;
    _client?.close();
  }
}

class MessengerController extends ChangeNotifier {
  MessengerController();

  static const MethodChannel _deviceChannel = MethodChannel(
    'ise_messenger/device',
  );
  AppStage stage = AppStage.loading;
  final http.Client _httpClient = http.Client();
  SharedPreferences? _prefs;
  String? _token;
  UserProfile? user;
  String pendingEmail = '';
  String? pendingSetupToken;
  final List<ContactItem> contacts = [];
  final List<StoryItem> stories = [];
  final Map<int, int> _contactIndexById = {};
  final Map<int, List<ChatMessage>> _messagesByContact = {};
  final Set<int> _loadingConversations = {};
  final Set<int> _markingReadConversations = {};
  final Set<int> _queuedReadConversations = {};
  final Set<int> _openConversationIds = {};
  final Set<int> _archivedContactIds = <int>{};
  final Map<int, String> _messageDrafts = <int, String>{};
  final List<ContactItem> _activeContacts = <ContactItem>[];
  final List<ContactItem> _archivedContacts = <ContactItem>[];
  late final UnmodifiableListView<ContactItem> _activeContactsView =
      UnmodifiableListView<ContactItem>(_activeContacts);
  late final UnmodifiableListView<ContactItem> _archivedContactsView =
      UnmodifiableListView<ContactItem>(_archivedContacts);
  bool _contactPartitionsDirty = true;
  List<Map<String, dynamic>> _iceServers = List<Map<String, dynamic>>.from(
    defaultIceServers,
  );
  String? _iceTransportPolicy;
  bool _rtcConfigLoaded = false;
  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _reconnectTimer;
  Future<void>? _socketConnectFuture;
  Future<void>? _loadContactsFuture;
  Future<void>? _loadStoriesFuture;
  final Map<int, Future<void>> _loadMessageFutures = {};
  bool _contactsRefreshQueued = false;
  bool _storiesRefreshQueued = false;
  bool _hasUnreadStories = false;
  int _lastSeenStoryId = 0;
  bool _hasStoredSeenStoryId = false;
  final Set<int> _queuedConversationReloads = {};
  final Map<int, int> _conversationLoadGenerations = {};
  bool _startingCall = false;
  bool _screenAwakeForCall = false;
  bool _disposed = false;
  bool _isAppInForeground = true;
  bool _skipReconnectOnce = false;
  ActiveCall? activeCall;
  static const Duration _typingHeartbeatInterval = Duration(seconds: 2);
  static const Duration _typingIndicatorTimeout = Duration(seconds: 6);
  final Map<int, Map<int, _TypingParticipant>>
  _typingParticipantsByConversation = {};
  final Map<String, Timer> _typingClearTimers = {};
  final Map<int, bool> _outgoingTypingStateByConversation = {};
  final Map<int, DateTime> _lastOutgoingTypingEventAt = {};
  String? _currentPushToken;
  String? _registeredPushToken;
  Map<String, dynamic>? _pendingPushTapPayload;
  final _RevisionNotifier _stageRevision = _RevisionNotifier();
  final _RevisionNotifier _sessionRevision = _RevisionNotifier();
  final _RevisionNotifier _contactsRevision = _RevisionNotifier();
  final _RevisionNotifier _storiesRevision = _RevisionNotifier();
  final _RevisionNotifier _callRevision = _RevisionNotifier();
  final Map<int, _RevisionNotifier> _contactRevisionById = {};
  final Map<int, _RevisionNotifier> _conversationRevisionById = {};
  bool _emitScheduled = false;

  bool get isAuthenticated => _token != null && user != null;
  bool get callActionInProgress => _startingCall;
  bool get canStartCall => !_startingCall && activeCall == null;
  List<ContactItem> get activeContacts {
    _ensureContactPartitions();
    return _activeContactsView;
  }

  List<ContactItem> get archivedContacts {
    _ensureContactPartitions();
    return _archivedContactsView;
  }

  List<StoryItem> get activeStories => stories;
  bool get hasUnreadStories => _hasUnreadStories;

  Listenable get stageListenable => _stageRevision;
  Listenable get sessionListenable => _sessionRevision;
  Listenable get contactsListenable => _contactsRevision;
  Listenable get storiesListenable => _storiesRevision;
  Listenable get callListenable => _callRevision;

  Listenable contactListenable(int contactId) {
    return _contactRevisionFor(contactId);
  }

  Listenable conversationListenable(int contactId) {
    return _conversationRevisionFor(contactId);
  }

  String draftFor(int contactId) {
    return _messageDrafts[contactId] ?? '';
  }

  List<ChatMessage> messagesFor(int contactId) {
    return _messagesByContact[contactId] ?? const <ChatMessage>[];
  }

  bool conversationIsLoading(int contactId) {
    return _loadingConversations.contains(contactId);
  }

  ContactItem? contactById(int userId) {
    final index = _contactIndexById[userId];
    if (index == null) {
      return null;
    }
    return contacts[index];
  }

  bool isContactArchived(int contactId) {
    return _archivedContactIds.contains(contactId);
  }

  String? typingStatusLabelFor(int contactId) {
    final participants = _typingParticipantsByConversation[contactId];
    if (participants == null || participants.isEmpty) {
      return null;
    }
    if (contactId >= 0) {
      return 'печатает...';
    }
    final names = participants.values
        .map((item) => item.displayName.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) {
      return participants.length == 1
          ? 'Кто-то печатает...'
          : 'Печатают ${participants.length} участников...';
    }
    if (names.length == 1) {
      return '${names.first} печатает...';
    }
    return 'Печатают ${names.length} участников...';
  }

  void _rebuildContactIndex() {
    _contactIndexById.clear();
    for (var index = 0; index < contacts.length; index++) {
      _contactIndexById[contacts[index].userId] = index;
    }
  }

  void _ensureContactPartitions() {
    if (!_contactPartitionsDirty) {
      return;
    }
    _activeContacts.clear();
    _archivedContacts.clear();
    for (final contact in contacts) {
      if (_archivedContactIds.contains(contact.userId)) {
        _archivedContacts.add(contact);
      } else {
        _activeContacts.add(contact);
      }
    }
    _contactPartitionsDirty = false;
  }

  String? _archivedContactsStorageKey() {
    final currentUserId = user?.id;
    if (currentUserId == null) {
      return null;
    }
    return 'archived_contacts_$currentUserId';
  }

  Future<void> _loadArchivedContacts() async {
    final storageKey = _archivedContactsStorageKey();
    final rawValues = storageKey == null
        ? const <String>[]
        : (_prefs?.getStringList(storageKey) ?? const <String>[]);
    final nextArchivedIds = rawValues
        .map((value) => int.tryParse(value))
        .whereType<int>()
        .toSet();
    if (_sameIntSet(_archivedContactIds, nextArchivedIds)) {
      return;
    }
    final changedContactIds = <int>{..._archivedContactIds, ...nextArchivedIds};
    _archivedContactIds
      ..clear()
      ..addAll(nextArchivedIds);
    _touchContacts(contactIds: changedContactIds);
    _emit();
  }

  String? _messageDraftsStorageKey() {
    final currentUserId = user?.id;
    if (currentUserId == null) {
      return null;
    }
    return 'message_drafts_$currentUserId';
  }

  Future<void> _loadMessageDrafts() async {
    final storageKey = _messageDraftsStorageKey();
    _messageDrafts.clear();
    final rawValue = storageKey == null ? null : _prefs?.getString(storageKey);
    if (rawValue == null || rawValue.trim().isEmpty) {
      return;
    }
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map) {
        return;
      }
      for (final entry in decoded.entries) {
        final contactId = int.tryParse(entry.key.toString());
        final text = sanitizeDisplayText(
          entry.value?.toString() ?? '',
          preserveLineBreaks: true,
        ).trim();
        if (contactId != null && contactId != 0 && text.isNotEmpty) {
          _messageDrafts[contactId] = text;
        }
      }
    } catch (_) {}
  }

  Future<void> _saveMessageDrafts() async {
    final storageKey = _messageDraftsStorageKey();
    if (storageKey == null) {
      return;
    }
    if (_messageDrafts.isEmpty) {
      await _prefs?.remove(storageKey);
      return;
    }
    final values = <String, String>{
      for (final entry in _messageDrafts.entries) '${entry.key}': entry.value,
    };
    await _prefs?.setString(storageKey, jsonEncode(values));
  }

  String? _seenStoriesStorageKey() {
    final currentUserId = user?.id;
    if (currentUserId == null) {
      return null;
    }
    return 'last_seen_story_id_$currentUserId';
  }

  Future<void> _loadSeenStoriesState() async {
    final storageKey = _seenStoriesStorageKey();
    final rawStoryId = storageKey == null
        ? null
        : _prefs?.getString(storageKey);
    _lastSeenStoryId = int.tryParse(rawStoryId ?? '') ?? 0;
    _hasStoredSeenStoryId = rawStoryId != null;
    _hasUnreadStories = false;
  }

  Future<void> _saveSeenStoriesState() async {
    final storageKey = _seenStoriesStorageKey();
    if (storageKey == null) {
      return;
    }
    await _prefs?.setString(storageKey, '$_lastSeenStoryId');
  }

  void updateMessageDraft(int contactId, String text) {
    final normalized = sanitizeDisplayText(
      text,
      preserveLineBreaks: true,
    ).trim();
    final previous = _messageDrafts[contactId] ?? '';
    if (previous == normalized) {
      return;
    }
    if (normalized.isEmpty) {
      _messageDrafts.remove(contactId);
    } else {
      _messageDrafts[contactId] = normalized;
    }
    unawaited(_saveMessageDrafts());
    _touchContacts(contactIds: <int>[contactId]);
    _emit();
  }

  Future<void> _saveArchivedContacts() async {
    final storageKey = _archivedContactsStorageKey();
    if (storageKey == null) {
      return;
    }
    final values =
        _archivedContactIds.map((value) => '$value').toList(growable: false)
          ..sort();
    await _prefs?.setStringList(storageKey, values);
  }

  int _findContactInsertIndex(ContactItem contact) {
    var left = 0;
    var right = contacts.length;
    while (left < right) {
      final middle = left + ((right - left) >> 1);
      if (compareContactsByActivity(contact, contacts[middle]) < 0) {
        right = middle;
      } else {
        left = middle + 1;
      }
    }
    return left;
  }

  _RevisionNotifier _contactRevisionFor(int contactId) {
    return _contactRevisionById.putIfAbsent(contactId, _RevisionNotifier.new);
  }

  _RevisionNotifier _conversationRevisionFor(int contactId) {
    return _conversationRevisionById.putIfAbsent(
      contactId,
      _RevisionNotifier.new,
    );
  }

  void _touchStage() {
    _stageRevision.bump();
  }

  void _touchSession() {
    _sessionRevision.bump();
  }

  void _touchContacts({Iterable<int> contactIds = const <int>[]}) {
    _contactPartitionsDirty = true;
    _contactsRevision.bump();
    for (final contactId in contactIds) {
      _touchContact(contactId);
    }
  }

  void _touchStories() {
    _storiesRevision.bump();
  }

  void _touchCall() {
    _syncCallSideEffects();
    _callRevision.bump();
  }

  void _touchContact(int contactId) {
    _contactRevisionFor(contactId).bump();
  }

  void _touchConversation(int contactId) {
    _conversationRevisionFor(contactId).bump();
  }

  void _disposeRevisionMap(Map<int, _RevisionNotifier> revisions) {
    for (final notifier in revisions.values) {
      notifier.dispose();
    }
    revisions.clear();
  }

  void _setContactUnreadCount(
    int contactId,
    int unreadCount, {
    bool emit = true,
  }) {
    final index = _contactIndexById[contactId];
    if (index == null) {
      return;
    }
    final normalizedCount = unreadCount < 0 ? 0 : unreadCount;
    final existing = contacts[index];
    if (existing.unreadCount == normalizedCount) {
      return;
    }
    contacts[index] = existing.copyWith(unreadCount: normalizedCount);
    _contactIndexById[contactId] = index;
    _touchContacts(contactIds: <int>[contactId]);
    if (emit) {
      _emit();
    }
  }

  void _upsertContact(ContactItem contact, {bool emit = true}) {
    final existingIndex = _contactIndexById[contact.userId];
    if (existingIndex != null &&
        _sameContactItem(contacts[existingIndex], contact)) {
      return;
    }
    if (existingIndex != null) {
      contacts.removeAt(existingIndex);
    }
    contacts.insert(_findContactInsertIndex(contact), contact);
    _rebuildContactIndex();
    _touchContacts(contactIds: <int>[contact.userId]);
    if (emit) {
      _emit();
    }
  }

  void _insertOrUpdateSortedMessage(
    List<ChatMessage> messages,
    ChatMessage message,
  ) {
    final existingIndex = findSortedMessageIndex(messages, message.id);
    if (existingIndex != -1) {
      messages[existingIndex] = message;
      return;
    }
    final insertIndex = findSortedMessageInsertIndex(messages, message.id);
    messages.insert(insertIndex, message);
  }

  void openConversation(int contactId) {
    unawaited(
      PushNotificationsService.instance.cancelConversationNotification(
        contactId,
      ),
    );
    final wasAdded = _openConversationIds.add(contactId);
    if (contactId != 0) {
      _setContactUnreadCount(contactId, 0);
    }
    if (!wasAdded && _loadingConversations.contains(contactId)) {
      unawaited(markConversationRead(contactId));
      return;
    }
    unawaited(markConversationRead(contactId));
    unawaited(_loadMessagesSilently(contactId));
  }

  void closeConversation(int contactId) {
    _openConversationIds.remove(contactId);
  }

  Future<void> updateTypingState(
    int contactId, {
    required bool isTyping,
  }) async {
    if (!isAuthenticated) {
      return;
    }
    final previousState =
        _outgoingTypingStateByConversation[contactId] ?? false;
    final now = DateTime.now();
    final lastSentAt = _lastOutgoingTypingEventAt[contactId];
    final shouldSendHeartbeat =
        isTyping &&
        lastSentAt != null &&
        now.difference(lastSentAt) >= _typingHeartbeatInterval;
    if (previousState == isTyping && !shouldSendHeartbeat) {
      return;
    }
    _outgoingTypingStateByConversation[contactId] = isTyping;
    if (isTyping) {
      _lastOutgoingTypingEventAt[contactId] = now;
    } else {
      _lastOutgoingTypingEventAt.remove(contactId);
    }
    final payload = <String, dynamic>{
      'type': 'typing_state',
      'is_typing': isTyping,
    };
    if (contactId < 0) {
      payload['group_id'] = contactId.abs();
    } else {
      payload['to_user_id'] = contactId;
    }
    try {
      await _sendSocket(payload);
    } catch (_) {}
  }

  Future<void> initialize() async {
    stage = AppStage.loading;
    _touchStage();
    _emit();
    final prefs = await _sharedPreferences();
    _prefs = prefs;
    _token = await _readStoredAuthToken(prefs);
    setServerMediaAuthToken(_token);
    if (_token == null) {
      stage = AppStage.email;
      _touchStage();
      _emit();
      return;
    }
    try {
      final payload = await _request('GET', '/me', authenticated: true);
      user = UserProfile.fromJson(
        Map<String, dynamic>.from(payload['user'] as Map),
      );
      _touchSession();
      await _bootstrapAuthenticatedSession();
    } catch (_) {
      await logout(clearOnly: true);
    }
  }

  Future<void> requestCode(String email) async {
    final normalized = normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      throw Exception('Введите корректную почту');
    }
    await _request('POST', '/auth/request-code', body: {'email': normalized});
    pendingEmail = normalized;
    stage = AppStage.code;
    _touchStage();
    _emit();
  }

  void goBackToEmail() {
    stage = AppStage.email;
    _touchStage();
    _emit();
  }

  Future<void> verifyCode(String code) async {
    final normalized = code.trim();
    if (normalized.isEmpty) {
      throw Exception('Введите код из письма');
    }
    final payload = await _request(
      'POST',
      '/auth/verify-code',
      body: {'email': pendingEmail, 'code': normalized},
    );
    final token = payload['token']?.toString();
    if (token != null && token.isNotEmpty) {
      await _applySessionPayload(payload);
      return;
    }
    final setupToken = payload['setup_token']?.toString();
    if (setupToken == null || setupToken.isEmpty) {
      throw Exception('Сервер не вернул данные для регистрации');
    }
    pendingSetupToken = setupToken;
    stage = AppStage.name;
    _touchStage();
    _emit();
  }

  Future<void> completeRegistration(String name) async {
    final rawName = name;
    if (rawName.trim().length < 2) {
      throw Exception('Имя должно содержать минимум 2 символа');
    }
    if (pendingSetupToken == null) {
      throw Exception('Сессия регистрации истекла');
    }
    final payload = await _request(
      'POST',
      '/auth/complete-registration',
      body: {'setup_token': pendingSetupToken, 'name': rawName},
    );
    await _applySessionPayload(payload);
  }

  Future<void> loadContacts() {
    if (!isAuthenticated) {
      return Future<void>.value();
    }
    final activeLoad = _loadContactsFuture;
    if (activeLoad != null) {
      _contactsRefreshQueued = true;
      return activeLoad;
    }
    final loadFuture = _loadContacts();
    _loadContactsFuture = loadFuture;
    return loadFuture.whenComplete(() {
      if (identical(_loadContactsFuture, loadFuture)) {
        _loadContactsFuture = null;
      }
      if (_contactsRefreshQueued && isAuthenticated && !_disposed) {
        _contactsRefreshQueued = false;
        unawaited(loadContacts());
      } else {
        _contactsRefreshQueued = false;
      }
    });
  }

  Future<void> _loadContacts() async {
    final responses = await Future.wait([
      _request('GET', '/contacts', authenticated: true),
      _request('GET', '/groups', authenticated: true),
    ]);
    final directContacts =
        (responses[0]['contacts'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (item) =>
                  ContactItem.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .map((contact) => _mergeContactWithExistingPreview(contact))
            .toList();
    final groupContacts =
        (responses[1]['groups'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (item) =>
                  ContactItem.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .map((contact) => _mergeContactWithExistingPreview(contact))
            .toList();
    if (!isAuthenticated) {
      return;
    }
    final nextContacts = [...directContacts, ...groupContacts]
      ..sort(compareContactsByActivity);
    final nextContactIds = nextContacts.map((item) => item.userId).toSet();
    final staleConversationIds = _messagesByContact.keys
        .where((contactId) => !nextContactIds.contains(contactId))
        .toList(growable: false);
    final staleArchivedIds = _archivedContactIds
        .where((contactId) => !nextContactIds.contains(contactId))
        .toList(growable: false);
    final contactsChanged = !_sameContactList(contacts, nextContacts);
    final archivesChanged = staleArchivedIds.isNotEmpty;
    if (!contactsChanged && staleConversationIds.isEmpty && !archivesChanged) {
      return;
    }
    for (final contactId in staleConversationIds) {
      _invalidateConversationLoads(contactId);
      _messagesByContact.remove(contactId);
      _loadingConversations.remove(contactId);
      _markingReadConversations.remove(contactId);
      _queuedReadConversations.remove(contactId);
      _openConversationIds.remove(contactId);
      _clearTypingParticipantsForConversation(contactId, emit: false);
      _outgoingTypingStateByConversation.remove(contactId);
      _lastOutgoingTypingEventAt.remove(contactId);
    }
    if (staleArchivedIds.isNotEmpty) {
      _archivedContactIds.removeAll(staleArchivedIds);
      await _saveArchivedContacts();
    }
    contacts
      ..clear()
      ..addAll(nextContacts);
    _rebuildContactIndex();
    _touchContacts(
      contactIds: <int>{
        ...nextContactIds,
        ...staleConversationIds,
        ...staleArchivedIds,
      },
    );
    for (final contactId in staleConversationIds) {
      _touchConversation(contactId);
    }
    _emit();
  }

  Future<void> loadStories() {
    if (!isAuthenticated) {
      return Future<void>.value();
    }
    final activeLoad = _loadStoriesFuture;
    if (activeLoad != null) {
      _storiesRefreshQueued = true;
      return activeLoad;
    }
    final loadFuture = _loadStories();
    _loadStoriesFuture = loadFuture;
    return loadFuture.whenComplete(() {
      if (identical(_loadStoriesFuture, loadFuture)) {
        _loadStoriesFuture = null;
      }
      if (_storiesRefreshQueued && isAuthenticated && !_disposed) {
        _storiesRefreshQueued = false;
        unawaited(loadStories());
      } else {
        _storiesRefreshQueued = false;
      }
    });
  }

  Future<void> _loadStories() async {
    final payload = await _request('GET', '/stories', authenticated: true);
    final nextStories =
        (payload['stories'] as List<dynamic>? ?? const <dynamic>[])
            .map(
              (item) =>
                  StoryItem.fromJson(Map<String, dynamic>.from(item as Map)),
            )
            .where((story) => story.mediaUrl.trim().isNotEmpty)
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    if (!isAuthenticated) {
      return;
    }
    final unreadChanged = _syncUnreadStoriesFrom(nextStories);
    if (_sameStoryList(stories, nextStories)) {
      if (unreadChanged) {
        _touchStories();
        _emit();
      }
      return;
    }
    stories
      ..clear()
      ..addAll(nextStories);
    _touchStories();
    _emit();
  }

  int _latestForeignStoryId(Iterable<StoryItem> storyItems) {
    final currentUserId = user?.id;
    var latestId = 0;
    for (final story in storyItems) {
      if (currentUserId != null && story.userId == currentUserId) {
        continue;
      }
      if (story.id > latestId) {
        latestId = story.id;
      }
    }
    return latestId;
  }

  int _latestStoryId(Iterable<StoryItem> storyItems) {
    var latestId = 0;
    for (final story in storyItems) {
      if (story.id > latestId) {
        latestId = story.id;
      }
    }
    return latestId;
  }

  bool _syncUnreadStoriesFrom(List<StoryItem> nextStories) {
    final latestForeignStoryId = _latestForeignStoryId(nextStories);
    if (!_hasStoredSeenStoryId && !_hasUnreadStories) {
      _lastSeenStoryId = _latestStoryId(nextStories);
      _hasStoredSeenStoryId = true;
      unawaited(_saveSeenStoriesState());
      return false;
    }
    final nextHasUnread = _lastSeenStoryId <= 0
        ? _hasUnreadStories && latestForeignStoryId > 0
        : latestForeignStoryId > _lastSeenStoryId;
    if (_hasUnreadStories == nextHasUnread) {
      return false;
    }
    _hasUnreadStories = nextHasUnread;
    return true;
  }

  Future<void> markStoriesSeen() async {
    final latestStoryId = _latestStoryId(stories);
    if (!_hasStoredSeenStoryId || latestStoryId > _lastSeenStoryId) {
      _lastSeenStoryId = latestStoryId;
      _hasStoredSeenStoryId = true;
      await _saveSeenStoriesState();
    }
    if (!_hasUnreadStories) {
      return;
    }
    _hasUnreadStories = false;
    _touchStories();
    _emit();
  }

  Future<void> archiveContact(int contactId) async {
    if (_archivedContactIds.contains(contactId)) {
      return;
    }
    _archivedContactIds.add(contactId);
    await _saveArchivedContacts();
    _touchContacts(contactIds: <int>[contactId]);
    _emit();
  }

  ContactItem _mergeContactWithExistingPreview(ContactItem contact) {
    final existing = contactById(contact.userId);
    if (existing == null) {
      return contact;
    }
    final serverPreviewIsEmpty = contact.lastMessage.trim().isEmpty;
    final existingPreviewIsNotEmpty = existing.lastMessage.trim().isNotEmpty;
    final serverTime = contact.lastMessageAt;
    final existingTime = existing.lastMessageAt;
    if (serverPreviewIsEmpty &&
        serverTime != null &&
        existingPreviewIsNotEmpty &&
        existingTime != null &&
        !serverTime.isAfter(existingTime)) {
      return contact.copyWith(
        lastMessage: existing.lastMessage,
        lastMessageServiceKind: existing.lastMessageServiceKind,
        lastMessageCallInitiatorId: existing.lastMessageCallInitiatorId,
        lastMessageCallStatus: existing.lastMessageCallStatus,
        lastMessageCallIsVideo: existing.lastMessageCallIsVideo,
        lastMessageSenderId: existing.lastMessageSenderId,
        lastMessageSenderName: existing.lastMessageSenderName,
        lastMessageAttachmentName: existing.lastMessageAttachmentName,
        lastMessageAttachmentKind: existing.lastMessageAttachmentKind,
        lastMessageAt: existing.lastMessageAt,
      );
    }
    final serverHasPreview =
        contact.lastMessage.trim().isNotEmpty || contact.lastMessageAt != null;
    if (serverHasPreview || existing.lastMessageAt == null) {
      return contact;
    }
    return contact.copyWith(
      lastMessage: existing.lastMessage,
      lastMessageServiceKind: existing.lastMessageServiceKind,
      lastMessageCallInitiatorId: existing.lastMessageCallInitiatorId,
      lastMessageCallStatus: existing.lastMessageCallStatus,
      lastMessageCallIsVideo: existing.lastMessageCallIsVideo,
      lastMessageSenderId: existing.lastMessageSenderId,
      lastMessageSenderName: existing.lastMessageSenderName,
      lastMessageAttachmentName: existing.lastMessageAttachmentName,
      lastMessageAttachmentKind: existing.lastMessageAttachmentKind,
      lastMessageAt: existing.lastMessageAt,
    );
  }

  Future<void> unarchiveContact(int contactId) async {
    if (!_archivedContactIds.remove(contactId)) {
      return;
    }
    await _saveArchivedContacts();
    _touchContacts(contactIds: <int>[contactId]);
    _emit();
  }

  Future<void> loadRtcConfig({bool force = false}) async {
    if (!isAuthenticated) {
      return;
    }
    if (_rtcConfigLoaded && !force) {
      return;
    }
    try {
      final payload = await _request('GET', '/rtc-config', authenticated: true);
      final rawServers = payload['ice_servers'];
      if (rawServers is List && rawServers.isNotEmpty) {
        _iceServers = rawServers
            .map(
              (item) =>
                  Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
            )
            .toList();
      } else {
        _iceServers = List<Map<String, dynamic>>.from(defaultIceServers);
      }
      final rawPolicy = payload['ice_transport_policy']?.toString().trim();
      _iceTransportPolicy = rawPolicy == null || rawPolicy.isEmpty
          ? null
          : rawPolicy;
      _rtcConfigLoaded = true;
    } catch (_) {
      _iceServers = List<Map<String, dynamic>>.from(defaultIceServers);
      _iceTransportPolicy = null;
    }
  }

  Future<void> addContactByEmail(String email) async {
    final normalized = normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      throw Exception('Введите корректную почту');
    }
    final payload = await _request(
      'POST',
      '/contacts/add',
      authenticated: true,
      body: {'email': normalized},
    );
    final contactPayload = payload['contact'];
    if (contactPayload is Map) {
      _upsertContact(
        ContactItem.fromJson(Map<String, dynamic>.from(contactPayload)),
      );
    }
  }

  Future<void> deleteContact(int contactId) async {
    await _request('POST', '/contacts/$contactId/delete', authenticated: true);
    _removeConversationLocally(contactId);
  }

  void _invalidateConversationLoads(int contactId) {
    _conversationLoadGenerations[contactId] =
        (_conversationLoadGenerations[contactId] ?? 0) + 1;
    _loadMessageFutures.remove(contactId);
    _queuedConversationReloads.remove(contactId);
  }

  void _removeConversationLocally(int contactId) {
    _invalidateConversationLoads(contactId);
    contacts.removeWhere((item) => item.userId == contactId);
    _rebuildContactIndex();
    _messagesByContact.remove(contactId);
    _messageDrafts.remove(contactId);
    unawaited(_saveMessageDrafts());
    _loadingConversations.remove(contactId);
    _markingReadConversations.remove(contactId);
    _queuedReadConversations.remove(contactId);
    _openConversationIds.remove(contactId);
    final archiveWasRemoved = _archivedContactIds.remove(contactId);
    _clearTypingParticipantsForConversation(contactId, emit: false);
    _outgoingTypingStateByConversation.remove(contactId);
    _lastOutgoingTypingEventAt.remove(contactId);
    if (archiveWasRemoved) {
      unawaited(_saveArchivedContacts());
    }
    unawaited(
      PushNotificationsService.instance.cancelConversationNotification(
        contactId,
      ),
    );
    _touchContacts(contactIds: <int>[contactId]);
    _touchConversation(contactId);
    _emit();
  }

  Future<void> leaveGroup(int conversationId) async {
    await _request(
      'POST',
      '/groups/${conversationId.abs()}/leave',
      authenticated: true,
    );
    _removeConversationLocally(conversationId);
  }

  Future<void> deleteGroup(int conversationId) async {
    await _request(
      'POST',
      '/groups/${conversationId.abs()}/delete',
      authenticated: true,
    );
    _removeConversationLocally(conversationId);
  }

  Future<void> clearConversation(int conversationId) async {
    final contact = contactById(conversationId);
    if (contact == null) {
      return;
    }
    await _request(
      'POST',
      contact.isGroup
          ? '/groups/${conversationId.abs()}/clear'
          : '/contacts/$conversationId/clear',
      authenticated: true,
    );
    _invalidateConversationLoads(conversationId);
    _messagesByContact[conversationId] = <ChatMessage>[];
    _upsertContact(
      contact.copyWith(
        lastMessage: '',
        lastMessageServiceKind: null,
        lastMessageCallInitiatorId: null,
        lastMessageCallStatus: null,
        lastMessageCallIsVideo: null,
        lastMessageSenderId: null,
        lastMessageSenderName: null,
        lastMessageAttachmentName: null,
        lastMessageAttachmentKind: null,
        lastMessageAt: null,
        unreadCount: 0,
      ),
      emit: false,
    );
    _touchConversation(conversationId);
    _touchContacts(contactIds: <int>[conversationId]);
    _emit();
  }

  Future<void> updateProfileName(String name) async {
    final rawName = name;
    if (rawName.trim().length < 2) {
      throw Exception('Имя должно содержать минимум 2 символа');
    }
    final payload = await _request(
      'POST',
      '/me/update-name',
      authenticated: true,
      body: {'name': rawName},
    );
    user = UserProfile.fromJson(
      Map<String, dynamic>.from(payload['user'] as Map),
    );
    _touchSession();
    _emit();
  }

  Future<void> updateProfileDetails({
    required String name,
    required String description,
  }) async {
    final rawName = name;
    if (rawName.trim().length < 2) {
      throw Exception('Имя должно содержать минимум 2 символа');
    }
    if (rawName.length > 40) {
      throw Exception('Имя слишком длинное');
    }
    final payload = await _request(
      'POST',
      '/me/update-profile',
      authenticated: true,
      body: {'name': rawName, 'description': description},
    );
    user = UserProfile.fromJson(
      Map<String, dynamic>.from(payload['user'] as Map),
    );
    _touchSession();
    _emit();
  }

  Future<UserProfileDetails> loadUserProfile(int userId) async {
    final payload = await _request(
      'GET',
      '/users/$userId/profile',
      authenticated: true,
    );
    return UserProfileDetails.fromJson(payload);
  }

  Future<Map<String, dynamic>> _buildAvatarRequestBody(
    String sourcePath,
  ) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('Не удалось открыть изображение');
    }
    final avatarBytes = await sourceFile.readAsBytes();
    if (avatarBytes.isEmpty) {
      throw Exception('Не удалось прочитать изображение');
    }
    if (avatarBytes.length > 5 * 1024 * 1024) {
      throw Exception('Размер файла не должен превышать 5 МБ');
    }
    return {
      'image_data': base64Encode(avatarBytes),
      'extension': _avatarExtensionFromPath(sourcePath),
    };
  }

  Future<void> setProfileAvatar(String sourcePath) async {
    if (user == null) {
      return;
    }
    final payload = await _request(
      'POST',
      '/me/avatar',
      authenticated: true,
      body: await _buildAvatarRequestBody(sourcePath),
    );
    user = UserProfile.fromJson(
      Map<String, dynamic>.from(payload['user'] as Map),
    );
    _touchSession();
    _emit();
  }

  Future<void> clearProfileAvatar() async {
    if (user == null) {
      return;
    }
    final payload = await _request(
      'POST',
      '/me/avatar/delete',
      authenticated: true,
    );
    user = UserProfile.fromJson(
      Map<String, dynamic>.from(payload['user'] as Map),
    );
    _touchSession();
    _emit();
  }

  Future<ContactItem> createGroup({
    required String name,
    required List<String> memberEmails,
    String? avatarPath,
  }) async {
    final rawName = name;
    if (rawName.trim().length < 2) {
      throw Exception('Название группы должно содержать минимум 2 символа');
    }
    final normalizedEmails = <String>[];
    final seenEmails = <String>{};
    for (final rawEmail in memberEmails) {
      final email = normalizeEmail(rawEmail);
      if (email.isEmpty) {
        continue;
      }
      if (!isValidEmail(email)) {
        throw Exception('Укажите корректную почту');
      }
      if (seenEmails.add(email)) {
        normalizedEmails.add(email);
      }
    }
    final body = <String, dynamic>{
      'name': rawName,
      'member_emails': normalizedEmails,
    };
    if (avatarPath != null && avatarPath.trim().isNotEmpty) {
      body.addAll(await _buildAvatarRequestBody(avatarPath));
    }
    final payload = await _request(
      'POST',
      '/groups/create',
      authenticated: true,
      body: body,
    );
    final group = ContactItem.fromJson(
      Map<String, dynamic>.from(payload['group'] as Map),
    );
    _upsertContact(group);
    return contactById(group.userId) ?? group;
  }

  Future<GroupDetails> loadGroupDetails(int conversationId) async {
    final payload = await _request(
      'GET',
      '/groups/${conversationId.abs()}',
      authenticated: true,
    );
    return GroupDetails(
      group: ContactItem.fromJson(
        Map<String, dynamic>.from(payload['group'] as Map),
      ),
      members: (payload['members'] as List<dynamic>? ?? const <dynamic>[])
          .map(
            (item) =>
                GroupMember.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(growable: false),
    );
  }

  Future<ContactItem> updateGroupName(int conversationId, String name) async {
    final rawName = name;
    if (rawName.trim().length < 2) {
      throw Exception('Название группы должно содержать минимум 2 символа');
    }
    final payload = await _request(
      'POST',
      '/groups/${conversationId.abs()}/update-name',
      authenticated: true,
      body: {'name': rawName},
    );
    final group = ContactItem.fromJson(
      Map<String, dynamic>.from(payload['group'] as Map),
    );
    _upsertContact(group);
    return group;
  }

  Future<ContactItem> setGroupAvatar(
    int conversationId,
    String sourcePath,
  ) async {
    final payload = await _request(
      'POST',
      '/groups/${conversationId.abs()}/avatar',
      authenticated: true,
      body: await _buildAvatarRequestBody(sourcePath),
    );
    final group = ContactItem.fromJson(
      Map<String, dynamic>.from(payload['group'] as Map),
    );
    _upsertContact(group);
    return group;
  }

  Future<ContactItem> clearGroupAvatar(int conversationId) async {
    final payload = await _request(
      'POST',
      '/groups/${conversationId.abs()}/avatar/delete',
      authenticated: true,
    );
    final group = ContactItem.fromJson(
      Map<String, dynamic>.from(payload['group'] as Map),
    );
    _upsertContact(group);
    return group;
  }

  Future<void> addGroupMembersByEmail(
    int conversationId,
    List<String> emails,
  ) async {
    final normalizedEmails = <String>[];
    final seenEmails = <String>{};
    for (final rawEmail in emails) {
      final email = normalizeEmail(rawEmail);
      if (email.isEmpty) {
        continue;
      }
      if (!isValidEmail(email)) {
        throw Exception('Укажите корректную почту');
      }
      if (seenEmails.add(email)) {
        normalizedEmails.add(email);
      }
    }
    if (normalizedEmails.isEmpty) {
      throw Exception('Выберите хотя бы одного участника');
    }
    final payload = await _request(
      'POST',
      '/groups/${conversationId.abs()}/members/add',
      authenticated: true,
      body: {'emails': normalizedEmails},
    );
    final groupPayload = payload['group'];
    if (groupPayload is Map) {
      _upsertContact(
        ContactItem.fromJson(Map<String, dynamic>.from(groupPayload)),
      );
    }
  }

  Future<void> removeGroupMembers(int conversationId, List<int> userIds) async {
    final normalizedIds = userIds.where((id) => id > 0).toSet().toList();
    if (normalizedIds.isEmpty) {
      throw Exception('Выберите участников для удаления');
    }
    final payload = await _request(
      'POST',
      '/groups/${conversationId.abs()}/members/remove',
      authenticated: true,
      body: {'user_ids': normalizedIds},
    );
    final groupPayload = payload['group'];
    if (groupPayload is Map) {
      _upsertContact(
        ContactItem.fromJson(Map<String, dynamic>.from(groupPayload)),
      );
    }
  }

  Future<void> deleteAccount() async {
    await _request('POST', '/me/delete', authenticated: true);
    await logout(clearOnly: true);
  }

  Future<void> handlePushTokenChanged(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }
    final previousToken = _currentPushToken;
    _currentPushToken = normalized;
    if (!isAuthenticated) {
      return;
    }
    try {
      if (previousToken != null && previousToken != normalized) {
        await _unregisterPushToken(
          token: previousToken,
          clearRegisteredToken: false,
        );
      }
      await _syncPushTokenRegistration();
    } catch (_) {}
  }

  Future<void> handlePushNotificationTap(Map<String, dynamic> payload) async {
    final normalizedPayload = Map<String, dynamic>.from(payload);
    if (!isAuthenticated || stage != AppStage.contacts) {
      _pendingPushTapPayload = normalizedPayload;
      return;
    }
    switch (normalizedPayload['push_type']?.toString()) {
      case pushTypeChatMessage:
      case pushTypeContactAdded:
      case pushTypeGroupAdded:
      case pushTypeMissedCall:
      case pushTypeRejectedCall:
      case pushTypeCanceledCall:
        await _openConversationFromPushPayload(normalizedPayload);
        return;
      case pushTypeStoryCreated:
        await _openStoriesFromPushPayload(normalizedPayload);
        return;
      case pushTypeIncomingCall:
        if (_socket == null) {
          await _connectSocket(syncState: true);
        } else {
          _sendPresenceStateIfConnected(true);
          unawaited(_syncRealtimeState());
        }
        await _syncPendingIncomingCall();
        return;
      case pushTypeAppUpdate:
        await PushNotificationsService.instance.cancelAppUpdateNotification();
        return;
      default:
        return;
    }
  }

  bool shouldDisplayNotification(Map<String, dynamic> payload) {
    final pushType = payload['push_type']?.toString().trim() ?? '';
    if (pushType != pushTypeChatMessage || !_isAppInForeground) {
      return true;
    }
    final conversationId =
        int.tryParse(payload['conversation_id']?.toString() ?? '') ?? 0;
    return conversationId == 0 ||
        !_openConversationIds.contains(conversationId);
  }

  Future<void> _syncPushTokenRegistration() async {
    final token = _currentPushToken?.trim();
    if (!isAuthenticated || token == null || token.isEmpty) {
      return;
    }
    if (_registeredPushToken == token) {
      return;
    }
    await _request(
      'POST',
      '/me/push-token',
      authenticated: true,
      body: {'platform': 'android', 'token': token},
    );
    _registeredPushToken = token;
  }

  Future<void> _unregisterPushToken({
    String? token,
    bool clearRegisteredToken = true,
  }) async {
    final tokenToRemove =
        token?.trim() ??
        _registeredPushToken?.trim() ??
        _currentPushToken?.trim();
    if (tokenToRemove == null || tokenToRemove.isEmpty) {
      if (clearRegisteredToken) {
        _registeredPushToken = null;
      }
      return;
    }
    if (_token != null) {
      try {
        await _request(
          'POST',
          '/me/push-token/delete',
          authenticated: true,
          body: {'platform': 'android', 'token': tokenToRemove},
        );
      } catch (_) {}
    }
    if (clearRegisteredToken && _registeredPushToken == tokenToRemove) {
      _registeredPushToken = null;
    }
  }

  Future<void> _drainPendingPushTapPayload() async {
    final payload = _pendingPushTapPayload;
    if (payload == null || !isAuthenticated || stage != AppStage.contacts) {
      return;
    }
    _pendingPushTapPayload = null;
    await handlePushNotificationTap(payload);
  }

  Future<void> _openConversationFromPushPayload(
    Map<String, dynamic> payload,
  ) async {
    final conversation = _conversationFromPushPayload(payload);
    if (conversation == null) {
      return;
    }
    final currentContact = contactById(conversation.userId);
    final resolvedContact = currentContact ?? conversation;
    if (currentContact == null) {
      _upsertContact(resolvedContact, emit: false);
      _emit();
    }
    await PushNotificationsService.instance.cancelConversationNotification(
      resolvedContact.userId,
    );
    if (_openConversationIds.contains(resolvedContact.userId)) {
      unawaited(markConversationRead(resolvedContact.userId));
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        _pendingPushTapPayload = Map<String, dynamic>.from(payload);
        return;
      }
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              ChatScreen(controller: this, initialContact: resolvedContact),
        ),
      );
    });
  }

  Future<void> _openStoriesFromPushPayload(Map<String, dynamic> payload) async {
    try {
      await loadStories();
    } catch (_) {}
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        _pendingPushTapPayload = Map<String, dynamic>.from(payload);
        return;
      }
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => StoriesScreen(controller: this),
        ),
      );
    });
  }

  ContactItem? _conversationFromPushPayload(Map<String, dynamic> payload) {
    final rawConversation = payload['conversation'];
    Map<String, dynamic>? conversationJson;
    if (rawConversation is String) {
      final normalized = rawConversation.trim();
      if (normalized.isEmpty) {
        return null;
      }
      try {
        final decoded = jsonDecode(normalized);
        if (decoded is Map) {
          conversationJson = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        return null;
      }
    } else if (rawConversation is Map) {
      conversationJson = Map<String, dynamic>.from(rawConversation);
    }
    if (conversationJson == null) {
      return null;
    }
    try {
      return ContactItem.fromJson(conversationJson);
    } catch (_) {
      return null;
    }
  }

  Future<void> loadMessages(int contactId) {
    if (!isAuthenticated) {
      return Future<void>.value();
    }
    final activeLoad = _loadMessageFutures[contactId];
    if (activeLoad != null) {
      _queuedConversationReloads.add(contactId);
      return activeLoad;
    }
    final loadFuture = _loadMessages(contactId);
    _loadMessageFutures[contactId] = loadFuture;
    return loadFuture.whenComplete(() {
      if (identical(_loadMessageFutures[contactId], loadFuture)) {
        _loadMessageFutures.remove(contactId);
      }
      if (_queuedConversationReloads.remove(contactId) &&
          isAuthenticated &&
          !_disposed &&
          _contactIndexById.containsKey(contactId)) {
        unawaited(loadMessages(contactId));
      }
    });
  }

  Future<void> _loadMessages(int contactId) async {
    final loadGeneration = _conversationLoadGenerations[contactId] ?? 0;
    _loadingConversations.add(contactId);
    _touchConversation(contactId);
    _emit();
    try {
      final payload = await _request(
        'GET',
        contactId < 0
            ? '/groups/${contactId.abs()}/messages'
            : '/messages/$contactId',
        authenticated: true,
      );
      final messages =
          (payload['messages'] as List<dynamic>? ?? const <dynamic>[])
              .map(
                (item) => ChatMessage.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .where((message) => !message.isCallHistory)
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      if (!isAuthenticated ||
          !_contactIndexById.containsKey(contactId) ||
          (_conversationLoadGenerations[contactId] ?? 0) != loadGeneration) {
        return;
      }
      _messagesByContact[contactId] = messages;
      _touchConversation(contactId);
      if (contactId != 0) {
        _setContactUnreadCount(contactId, 0, emit: false);
      }
    } finally {
      _loadingConversations.remove(contactId);
      _touchConversation(contactId);
      _emit();
    }
  }

  Future<void> markConversationRead(int contactId) async {
    if (!isAuthenticated) {
      return;
    }
    if (_markingReadConversations.contains(contactId)) {
      _queuedReadConversations.add(contactId);
      return;
    }
    _markingReadConversations.add(contactId);
    try {
      await _request(
        'POST',
        contactId < 0
            ? '/groups/${contactId.abs()}/read'
            : '/messages/$contactId/read',
        authenticated: true,
      );
      if (contactId != 0) {
        _setContactUnreadCount(contactId, 0);
      }
    } catch (_) {
    } finally {
      _markingReadConversations.remove(contactId);
      if (_queuedReadConversations.remove(contactId) &&
          isAuthenticated &&
          !_disposed) {
        unawaited(markConversationRead(contactId));
      }
    }
  }

  Future<List<MessageReaderInfo>> loadGroupMessageReaders(int messageId) async {
    final payload = await _request(
      'GET',
      '/group-messages/$messageId/readers',
      authenticated: true,
    );
    return (payload['readers'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (item) => MessageReaderInfo.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  String _avatarExtensionFromPath(String rawPath) {
    final dotIndex = rawPath.lastIndexOf('.');
    if (dotIndex <= -1 || dotIndex == rawPath.length - 1) {
      return '.jpg';
    }
    final extension = rawPath.substring(dotIndex).toLowerCase();
    if (!_safeFileExtensionPattern.hasMatch(extension)) {
      return '.jpg';
    }
    return extension;
  }

  Future<Map<String, dynamic>> _requestMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileField,
    required String filePath,
    required String fileName,
    bool authenticated = false,
    AttachmentUploadCancelToken? cancelToken,
  }) async {
    final uri = _buildApiUri(path);
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Не удалось открыть файл');
    }
    final uploadTimeout = attachmentUploadTimeoutForBytes(
      await sourceFile.length(),
    );
    final request = http.MultipartRequest('POST', uri);
    if (authenticated) {
      if (_token == null) {
        throw Exception('Нет активной сессии');
      }
      request.headers['Authorization'] = 'Bearer $_token';
    }
    request.fields.addAll(fields);
    final contentType = _multipartContentTypeForFile(
      filePath: filePath,
      fileName: fileName,
    );
    request.files.add(
      await http.MultipartFile.fromPath(
        fileField,
        filePath,
        filename: fileName,
        contentType: contentType,
      ),
    );
    if (cancelToken?.isCanceled ?? false) {
      throw const _AttachmentUploadCanceledException();
    }
    final requestClient = cancelToken == null ? _httpClient : http.Client();
    cancelToken?._attach(requestClient);
    late final http.Response response;
    try {
      if (cancelToken?.isCanceled ?? false) {
        throw const _AttachmentUploadCanceledException();
      }
      final streamedResponse = await requestClient
          .send(request)
          .timeout(uploadTimeout);
      if (cancelToken?.isCanceled ?? false) {
        throw const _AttachmentUploadCanceledException();
      }
      response = await http.Response.fromStream(
        streamedResponse,
      ).timeout(networkTimeout);
      if (cancelToken?.isCanceled ?? false) {
        throw const _AttachmentUploadCanceledException();
      }
    } on TimeoutException {
      if (cancelToken?.isCanceled ?? false) {
        throw const _AttachmentUploadCanceledException();
      }
      throw Exception('Сервер не отвечает');
    } on SocketException {
      if (cancelToken?.isCanceled ?? false) {
        throw const _AttachmentUploadCanceledException();
      }
      throw Exception('Нет соединения с сервером');
    } on http.ClientException {
      if (cancelToken?.isCanceled ?? false) {
        throw const _AttachmentUploadCanceledException();
      }
      throw Exception('Соединение с сервером было неожиданно закрыто');
    } catch (_) {
      if (cancelToken?.isCanceled ?? false) {
        throw const _AttachmentUploadCanceledException();
      }
      rethrow;
    } finally {
      if (cancelToken != null) {
        cancelToken._detach(requestClient);
        requestClient.close();
      }
    }
    final rawText = utf8.decode(response.bodyBytes);
    final decoded = _decodeResponseBody(rawText);
    if (response.statusCode >= 400) {
      throw Exception(_extractError(decoded));
    }
    return decoded;
  }

  Future<void> sendMessage(int contactId, String text) async {
    final rawText = text;
    if (rawText.trim().isEmpty) {
      return;
    }
    final payload = await _request(
      'POST',
      contactId < 0
          ? '/groups/${contactId.abs()}/messages/send'
          : '/messages/send',
      authenticated: true,
      body: contactId < 0
          ? {'text': rawText}
          : {'contact_id': contactId, 'text': rawText},
    );
    final message = ChatMessage.fromJson(
      Map<String, dynamic>.from(payload['message'] as Map),
    );
    _upsertMessage(message);
  }

  Future<void> sendAttachmentMessage(
    int contactId, {
    required String filePath,
    required String fileName,
    required String text,
    String? attachmentKind,
    AttachmentUploadCancelToken? cancelToken,
  }) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Не удалось открыть файл');
    }
    final payload = await _requestMultipart(
      contactId < 0
          ? '/groups/${contactId.abs()}/messages/send-file'
          : '/messages/send-file',
      authenticated: true,
      fileField: 'file',
      filePath: filePath,
      fileName: fileName.trim().isEmpty
          ? sourceFile.uri.pathSegments.last
          : fileName,
      fields: {
        if (contactId >= 0) 'contact_id': '$contactId',
        'text': text,
        if (attachmentKind != null && attachmentKind.trim().isNotEmpty)
          'attachment_kind': attachmentKind.trim(),
      },
      cancelToken: cancelToken,
    );
    if (cancelToken?.isCanceled ?? false) {
      throw const _AttachmentUploadCanceledException();
    }
    final message = ChatMessage.fromJson(
      Map<String, dynamic>.from(payload['message'] as Map),
    );
    _upsertMessage(message);
  }

  Future<StoryItem> createStoryVideo({
    required String filePath,
    required String fileName,
  }) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) {
      throw Exception('Не удалось открыть видео');
    }
    final payload = await _requestMultipart(
      '/stories/create',
      authenticated: true,
      fileField: 'file',
      filePath: filePath,
      fileName: fileName.trim().isEmpty
          ? sourceFile.uri.pathSegments.last
          : fileName,
      fields: const <String, String>{},
    );
    final story = StoryItem.fromJson(
      Map<String, dynamic>.from(payload['story'] as Map),
    );
    _upsertStory(story);
    unawaited(loadStories());
    return story;
  }

  Future<void> deleteStory(int storyId) async {
    await _request('POST', '/stories/$storyId/delete', authenticated: true);
    final removed = stories.any((story) => story.id == storyId);
    stories.removeWhere((story) => story.id == storyId);
    if (removed) {
      _touchStories();
      _emit();
    }
  }

  String _rejectedCallLabel(ActiveCall call) {
    return buildCallHistoryLabel(
      isIncoming: call.isIncoming,
      isVideo: call.isVideo,
      callStatus: callHistoryStatusRejected,
    );
  }

  String _canceledCallLabel(ActiveCall call) {
    return buildCallHistoryLabel(
      isIncoming: call.isIncoming,
      isVideo: call.isVideo,
      callStatus: callHistoryStatusCanceled,
    );
  }

  String _missedCallLabel(ActiveCall call) {
    return buildCallHistoryLabel(
      isIncoming: call.isIncoming,
      isVideo: call.isVideo,
      callStatus: callHistoryStatusMissed,
    );
  }

  String? _buildCallToastLabel(
    ActiveCall call,
    String status,
    CallStage nextStage,
  ) {
    if (nextStage == CallStage.missed) {
      return _missedCallLabel(call);
    }
    if (nextStage == CallStage.canceled) {
      return _canceledCallLabel(call);
    }
    if (nextStage != CallStage.rejected) {
      return null;
    }
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedStatus.contains('разговаривает')) {
      return 'Собеседник уже разговаривает';
    }
    return _rejectedCallLabel(call);
  }

  void _syncCallSideEffects() {
    _syncCallScreenAwakeState();
  }

  void _syncCallScreenAwakeState() {
    final shouldStayAwake = activeCall != null;
    if (_screenAwakeForCall == shouldStayAwake) {
      return;
    }
    _screenAwakeForCall = shouldStayAwake;
    unawaited(
      _deviceChannel.invokeMethod<void>(
        shouldStayAwake ? 'keepScreenOn' : 'allowScreenOff',
      ),
    );
  }

  Future<ChatMessage> editMessage(
    int contactId,
    int messageId,
    String text,
  ) async {
    final rawText = text;
    if (rawText.trim().isEmpty) {
      throw Exception('Сообщение не может быть пустым');
    }
    final payload = await _request(
      'POST',
      contactId < 0
          ? '/group-messages/$messageId/edit'
          : '/messages/$messageId/edit',
      authenticated: true,
      body: {'text': rawText},
    );
    final message = ChatMessage.fromJson(
      Map<String, dynamic>.from(payload['message'] as Map),
    );
    _upsertMessage(message);
    return message;
  }

  Future<void> deleteMessage(int contactId, int messageId) async {
    await _request(
      'POST',
      contactId < 0
          ? '/group-messages/$messageId/delete'
          : '/messages/$messageId/delete',
      authenticated: true,
    );
    unawaited(
      PushNotificationsService.instance
          .cancelConversationNotificationForMessage(contactId, messageId),
    );
    _removeMessage(contactId, messageId);
    unawaited(loadContacts());
  }

  Future<void> startCall(ContactItem contact, {required bool video}) async {
    if (_startingCall) {
      return;
    }
    if (contact.isGroup) {
      throw Exception('Групповые звонки пока не поддерживаются');
    }
    if (activeCall != null) {
      throw Exception('Звонок уже идет');
    }
    _startingCall = true;
    _touchCall();
    final call = ActiveCall(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      contact: contact,
      isVideo: video,
      isIncoming: false,
      stage: CallStage.outgoing,
    );
    activeCall = call;
    call.statusText = 'Подготовка звонка...';
    _touchCall();
    _emit();
    try {
      await loadRtcConfig();
      await _ensureCallPermissions(video);
      await _connectSocket(syncState: false);
      if (_socket == null) {
        throw Exception('Нет соединения с сервером');
      }
      await call.ensureRenderers();
      call.localStream = await _openUserMedia(video);
      call.localRenderer.srcObject = call.localStream;
      await _setSpeakerphoneSafely(call.isSpeakerOn);
      call.peerConnection = await _buildPeerConnection(call);
      for (final track in call.localStream!.getTracks()) {
        await call.peerConnection!.addTrack(track, call.localStream!);
      }
      final offer = await call.peerConnection!.createOffer({
        'offerToReceiveAudio': 1,
        'offerToReceiveVideo': video ? 1 : 0,
      });
      await call.peerConnection!.setLocalDescription(offer);
      call.statusText = 'Соединение...';
      _touchCall();
      _emit();
      await _sendSocket({
        'type': 'call_offer',
        'call_id': call.id,
        'to_user_id': contact.userId,
        'is_video': video,
        'sdp': offer.sdp,
        'sdp_type': offer.type,
      });
      call.statusText = 'Ожидание ответа';
      _touchCall();
      _emit();
    } catch (error) {
      if (activeCall?.id == call.id) {
        await _dropCallSilently(call);
        activeCall = null;
        _touchCall();
        _emit();
      }
      rethrow;
    } finally {
      _startingCall = false;
      _touchCall();
      _emit();
    }
  }

  Future<void> acceptIncomingCall() async {
    final call = activeCall;
    if (call == null || !call.isIncoming) {
      return;
    }
    await PushNotificationsService.instance.cancelIncomingCallNotification(
      call.id,
    );
    await loadRtcConfig();
    await _ensureCallPermissions(call.isVideo);
    await call.ensureRenderers();
    call.localStream = await _openUserMedia(call.isVideo);
    call.localRenderer.srcObject = call.localStream;
    await _setSpeakerphoneSafely(call.isSpeakerOn);
    call.peerConnection = await _buildPeerConnection(call);
    for (final track in call.localStream!.getTracks()) {
      await call.peerConnection!.addTrack(track, call.localStream!);
    }
    if (call.remoteDescriptionSdp == null ||
        call.remoteDescriptionType == null) {
      throw Exception('Сигнал вызова поврежден');
    }
    await call.peerConnection!.setRemoteDescription(
      RTCSessionDescription(
        call.remoteDescriptionSdp!,
        call.remoteDescriptionType!,
      ),
    );
    call.remoteDescriptionApplied = true;
    await _drainPendingCandidates(call);
    final answer = await call.peerConnection!.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': call.isVideo ? 1 : 0,
    });
    await call.peerConnection!.setLocalDescription(answer);
    await _sendSocket({
      'type': 'call_answer',
      'call_id': call.id,
      'to_user_id': call.contact.userId,
      'sdp': answer.sdp,
      'sdp_type': answer.type,
    });
    call.stage = CallStage.connecting;
    call.statusText = 'Подключение';
    _touchCall();
    _emit();
  }

  Future<void> rejectIncomingCall() async {
    final call = activeCall;
    if (call == null) {
      return;
    }
    await PushNotificationsService.instance.cancelIncomingCallNotification(
      call.id,
    );
    try {
      await _sendSocket({
        'type': 'call_reject',
        'call_id': call.id,
        'to_user_id': call.contact.userId,
        'reason': 'rejected',
        'is_video': call.isVideo,
      });
    } catch (_) {}
    await _closeCallWithStatus(
      _rejectedCallLabel(call),
      CallStage.rejected,
      showToast: false,
    );
  }

  Future<void> endCall() async {
    final call = activeCall;
    if (call == null) {
      return;
    }
    final isCanceledBeforeAnswer =
        !call.isIncoming && call.stage == CallStage.outgoing;
    await PushNotificationsService.instance.cancelIncomingCallNotification(
      call.id,
    );
    try {
      await _sendSocket({
        'type': 'call_end',
        'call_id': call.id,
        'to_user_id': call.contact.userId,
        'reason': isCanceledBeforeAnswer ? 'canceled' : 'ended',
      });
    } catch (_) {}
    await _closeCallWithStatus(
      isCanceledBeforeAnswer ? _canceledCallLabel(call) : 'Звонок завершён',
      isCanceledBeforeAnswer ? CallStage.canceled : CallStage.ended,
      showToast: false,
    );
  }

  Future<void> toggleMute() async {
    final call = activeCall;
    if (call?.localStream == null) {
      return;
    }
    call!.isMuted = !call.isMuted;
    for (final track in call.localStream!.getAudioTracks()) {
      track.enabled = !call.isMuted;
    }
    _touchCall();
    _emit();
  }

  Future<void> toggleSound() async {
    final call = activeCall;
    if (call == null) {
      return;
    }
    call.isSoundOn = !call.isSoundOn;
    await _applyRemoteSoundState(call);
    _touchCall();
    _emit();
  }

  Future<void> toggleSpeaker() async {
    final call = activeCall;
    if (call == null) {
      return;
    }
    call.isSpeakerOn = !call.isSpeakerOn;
    await _setSpeakerphoneSafely(call.isSpeakerOn);
    _touchCall();
    _emit();
  }

  Future<void> toggleCamera() async {
    final call = activeCall;
    if (call?.localStream == null) {
      return;
    }
    call!.isCameraEnabled = !call.isCameraEnabled;
    for (final track in call.localStream!.getVideoTracks()) {
      track.enabled = call.isCameraEnabled;
    }
    unawaited(
      _sendSocket({
        'type': 'call_media_state',
        'call_id': call.id,
        'to_user_id': call.contact.userId,
        'camera_enabled': call.isCameraEnabled,
      }),
    );
    _touchCall();
    _emit();
  }

  Future<void> switchCamera() async {
    final call = activeCall;
    if (call?.localStream == null) {
      return;
    }
    final tracks = call!.localStream!.getVideoTracks();
    if (tracks.isEmpty) {
      return;
    }
    await Helper.switchCamera(tracks.first);
    call.isFrontCamera = !call.isFrontCamera;
    _touchCall();
    _emit();
  }

  Future<void> _applyRemoteSoundState(ActiveCall call) async {
    final audioTracks =
        call.remoteStream?.getAudioTracks() ?? <MediaStreamTrack>[];
    for (final track in audioTracks) {
      track.enabled = call.isSoundOn;
    }
  }

  Future<void> _setSpeakerphoneSafely(bool enabled) async {
    try {
      await Helper.setSpeakerphoneOn(enabled);
    } catch (_) {}
  }

  Future<void> logout({bool clearOnly = false}) async {
    final draftKey = _messageDraftsStorageKey();
    final clearedContactIds = <int>{
      ...contacts.map((item) => item.userId),
      ..._messagesByContact.keys,
      ..._archivedContactIds,
    };
    if (!clearOnly) {
      await _unregisterPushToken();
      await _revokeCurrentSession();
    } else {
      _registeredPushToken = null;
    }
    _reconnectTimer?.cancel();
    if (activeCall != null) {
      if (clearOnly) {
        final call = activeCall;
        activeCall = null;
        _touchCall();
        _emit();
        if (call != null) {
          await _dropCallSilently(call);
        }
      } else {
        await _dropCurrentCall();
      }
    }
    await _closeSocketConnection();
    await Future.wait<void>([
      for (final contactId in clearedContactIds)
        PushNotificationsService.instance.cancelConversationNotification(
          contactId,
        ),
      PushNotificationsService.instance.cancelAppUpdateNotification(),
    ]);
    _token = null;
    user = null;
    pendingEmail = '';
    pendingSetupToken = null;
    _iceServers = List<Map<String, dynamic>>.from(defaultIceServers);
    _iceTransportPolicy = null;
    _rtcConfigLoaded = false;
    contacts.clear();
    stories.clear();
    _hasUnreadStories = false;
    _lastSeenStoryId = 0;
    _hasStoredSeenStoryId = false;
    _contactIndexById.clear();
    _messagesByContact.clear();
    _messageDrafts.clear();
    _loadingConversations.clear();
    _markingReadConversations.clear();
    _queuedReadConversations.clear();
    _loadContactsFuture = null;
    _contactsRefreshQueued = false;
    _loadStoriesFuture = null;
    _storiesRefreshQueued = false;
    _loadMessageFutures.clear();
    _queuedConversationReloads.clear();
    _conversationLoadGenerations.clear();
    _openConversationIds.clear();
    _archivedContactIds.clear();
    for (final timer in _typingClearTimers.values) {
      timer.cancel();
    }
    _typingClearTimers.clear();
    _typingParticipantsByConversation.clear();
    _outgoingTypingStateByConversation.clear();
    _lastOutgoingTypingEventAt.clear();
    _pendingPushTapPayload = null;
    await _deleteStoredAuthToken(_prefs);
    setServerMediaAuthToken(null);
    if (draftKey != null) {
      await _prefs?.remove(draftKey);
    }
    stage = AppStage.email;
    _touchCall();
    _touchSession();
    _touchStage();
    _touchContacts(contactIds: clearedContactIds);
    _touchStories();
    for (final contactId in clearedContactIds) {
      _touchConversation(contactId);
    }
    _emit();
  }

  Future<void> _revokeCurrentSession() async {
    if (_token == null) {
      return;
    }
    try {
      await _request('POST', '/auth/logout', authenticated: true);
    } catch (_) {}
  }

  Future<void> _applySessionPayload(Map<String, dynamic> payload) async {
    final token = payload['token']?.toString();
    if (token == null || token.isEmpty) {
      throw Exception('Сервер не вернул токен');
    }
    _token = token;
    setServerMediaAuthToken(token);
    user = UserProfile.fromJson(
      Map<String, dynamic>.from(payload['user'] as Map),
    );
    _touchSession();
    pendingSetupToken = null;
    await _writeStoredAuthToken(_prefs, token);
    await _bootstrapAuthenticatedSession(forceRtcConfig: true);
  }

  Future<void> _bootstrapAuthenticatedSession({
    bool forceRtcConfig = false,
  }) async {
    stage = AppStage.contacts;
    _touchStage();
    _emit();
    await _loadArchivedContacts();
    await _loadMessageDrafts();
    await _loadSeenStoriesState();
    await Future.wait<void>([
      loadRtcConfig(force: forceRtcConfig),
      loadContacts(),
      loadStories(),
      _connectSocket(syncState: false),
    ]);
    await PushNotificationsService.instance.syncCurrentToken();
    try {
      await _syncPushTokenRegistration();
    } catch (_) {}
    await _syncPendingIncomingCall();
    await _drainPendingPushTapPayload();
  }

  Future<void> _loadMessagesSilently(int contactId) async {
    try {
      await loadMessages(contactId);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    bool authenticated = false,
    Map<String, dynamic>? body,
  }) async {
    final uri = _buildApiUri(path);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      if (_token == null) {
        throw Exception('Нет активной сессии');
      }
      headers['Authorization'] = 'Bearer $_token';
    }
    late final http.Response response;
    try {
      if (method == 'GET') {
        response = await _httpClient
            .get(uri, headers: headers)
            .timeout(networkTimeout);
      } else {
        response = await _httpClient
            .post(
              uri,
              headers: headers,
              body: jsonEncode(body ?? const <String, dynamic>{}),
            )
            .timeout(networkTimeout);
      }
    } on TimeoutException {
      throw Exception('Сервер не отвечает');
    } on SocketException {
      throw Exception('Нет соединения с сервером');
    } on http.ClientException {
      throw Exception('Соединение с сервером было неожиданно закрыто');
    }
    final rawText = utf8.decode(response.bodyBytes);
    final decoded = _decodeResponseBody(rawText);
    if (response.statusCode >= 400) {
      throw Exception(_extractError(decoded));
    }
    return decoded;
  }

  Map<String, dynamic> _decodeResponseBody(String rawText) {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map) {
        return Map<String, dynamic>.from(parsed);
      }
      return <String, dynamic>{'detail': parsed.toString()};
    } on FormatException {
      return <String, dynamic>{'detail': trimmed};
    }
  }

  String _extractError(Map<String, dynamic> payload) {
    final detail = payload['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    if (detail is List && detail.isNotEmpty) {
      return detail.first.toString();
    }
    return 'Не удалось выполнить запрос';
  }

  Uri _buildApiUri(String path) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return apiBaseUri.resolve(normalizedPath);
  }

  Uri _buildWebSocketUri() {
    final httpUri = _buildApiUri('/ws');
    final scheme = httpUri.scheme == 'https' ? 'wss' : 'ws';
    return httpUri.replace(scheme: scheme, queryParameters: const {});
  }

  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    final nextIsForeground = switch (state) {
      AppLifecycleState.resumed => true,
      AppLifecycleState.inactive => true,
      AppLifecycleState.hidden => false,
      AppLifecycleState.paused => false,
      AppLifecycleState.detached => false,
    };
    if (_isAppInForeground == nextIsForeground) {
      return;
    }
    _isAppInForeground = nextIsForeground;
    _reconnectTimer?.cancel();
    if (!isAuthenticated) {
      return;
    }
    if (_isAppInForeground) {
      if (_socket == null) {
        await _connectSocket();
      } else {
        _sendPresenceStateIfConnected(true);
        unawaited(_syncRealtimeState());
      }
      return;
    }
    if (activeCall != null) {
      _sendPresenceStateIfConnected(false);
      return;
    }
    await _closeSocketConnection();
  }

  bool get _shouldKeepSocketConnected =>
      _isAppInForeground || activeCall != null;

  void _sendPresenceStateIfConnected(bool isActive) {
    final socket = _socket;
    if (socket == null) {
      return;
    }
    try {
      socket.add(jsonEncode({'type': 'presence_state', 'active': isActive}));
    } catch (_) {}
  }

  Future<void> _closeSocketConnection() async {
    _reconnectTimer?.cancel();
    final subscription = _socketSubscription;
    final socket = _socket;
    _socketSubscription = null;
    _socket = null;
    if (subscription == null && socket == null) {
      return;
    }
    _skipReconnectOnce = true;
    if (subscription != null) {
      await subscription.cancel();
    }
    if (socket != null) {
      await socket.close();
    }
  }

  Future<void> _connectSocket({bool syncState = true}) async {
    if (!isAuthenticated || _socket != null || !_shouldKeepSocketConnected) {
      return;
    }
    _skipReconnectOnce = false;
    if (_socketConnectFuture != null) {
      return _socketConnectFuture!;
    }
    final completer = Completer<void>();
    _socketConnectFuture = completer.future;
    try {
      final socket = await WebSocket.connect(
        _buildWebSocketUri().toString(),
        headers: {'Authorization': 'Bearer $_token'},
      ).timeout(networkTimeout);
      socket.pingInterval = const Duration(seconds: 20);
      _socket = socket;
      _socketSubscription = socket.listen(
        _handleSocketData,
        onDone: _handleSocketClosed,
        onError: (_) => _handleSocketClosed(),
        cancelOnError: true,
      );
      _sendPresenceStateIfConnected(_isAppInForeground);
      if (syncState) {
        unawaited(_syncRealtimeState());
      }
    } catch (_) {
      _socket = null;
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _socketConnectFuture = null;
      if (_socket == null && isAuthenticated && _shouldKeepSocketConnected) {
        _scheduleReconnect();
      }
    }
  }

  void _handleSocketData(dynamic rawData) {
    if (rawData is! String) {
      return;
    }
    late final Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(rawData) as Map);
    } catch (_) {
      return;
    }
    final type = payload['type']?.toString() ?? '';
    switch (type) {
      case 'message_new':
      case 'group_message_new':
        final message = ChatMessage.fromJson(
          Map<String, dynamic>.from(payload['message'] as Map),
        );
        if (message.isCallHistory) {
          break;
        }
        _upsertMessage(message);
        _markIncomingMessageReadIfNeeded(message);
        break;
      case 'message_updated':
      case 'group_message_updated':
        final message = ChatMessage.fromJson(
          Map<String, dynamic>.from(payload['message'] as Map),
        );
        if (message.isCallHistory) {
          break;
        }
        _upsertMessage(message);
        break;
      case 'message_deleted':
      case 'group_message_deleted':
        _handleMessageDeleted(payload);
        break;
      case 'conversation_cleared':
        _handleConversationCleared(payload);
        break;
      case 'conversation_deleted':
        _handleConversationDeleted(payload);
        break;
      case 'contact_upserted':
        _handleContactUpserted(payload);
        break;
      case 'group_upserted':
        _handleGroupUpserted(payload);
        break;
      case 'contacts_updated':
      case 'groups_updated':
        unawaited(loadContacts());
        break;
      case 'stories_updated':
        _handleStoriesUpdated(payload);
        break;
      case 'story_deleted':
        _handleStoryDeleted(payload);
        break;
      case 'messages_read':
        _handleMessagesRead(payload);
        break;
      case 'group_messages_read':
        _handleGroupMessagesRead(payload);
        break;
      case 'presence_updated':
        _updateContactPresence(payload);
        break;
      case 'group_presence_updated':
        _updateGroupPresence(payload);
        break;
      case 'typing_state':
        _handleTypingState(payload);
        break;
      case 'call_waiting':
        _updateOutgoingCallStatus(
          payload['call_id']?.toString(),
          payload['status']?.toString() ?? 'Ожидание пользователя в сети',
        );
        break;
      case 'call_delivered':
        _updateOutgoingCallStatus(
          payload['call_id']?.toString(),
          'Ожидание ответа',
        );
        break;
      case 'call_offer':
        _handleIncomingCall(payload);
        break;
      case 'call_answer':
        unawaited(_handleCallAnswer(payload));
        break;
      case 'call_candidate':
        unawaited(_handleCallCandidate(payload));
        break;
      case 'call_media_state':
        _handleCallMediaState(payload);
        break;
      case 'call_reject':
        final rejectedCall = activeCall;
        if (rejectedCall == null ||
            rejectedCall.id != payload['call_id']?.toString()) {
          break;
        }
        unawaited(
          _closeCallWithStatus(
            payload['reason']?.toString() == 'busy'
                ? 'Собеседник уже разговаривает'
                : _rejectedCallLabel(rejectedCall),
            CallStage.rejected,
          ),
        );
        break;
      case 'call_busy':
        if (activeCall?.id != payload['call_id']?.toString()) {
          break;
        }
        unawaited(
          _closeCallWithStatus(
            'Собеседник уже разговаривает',
            CallStage.rejected,
          ),
        );
        break;
      case 'call_unavailable':
        _updateOutgoingCallStatus(
          payload['call_id']?.toString(),
          'Ожидание пользователя в сети',
        );
        break;
      case 'call_end':
        final call = activeCall;
        final reason = payload['reason']?.toString().trim().toLowerCase() ?? '';
        final callId = payload['call_id']?.toString();
        if (call == null || call.id != callId) {
          break;
        }
        if (call.isClosing && reason != 'canceled') {
          call.stage = CallStage.ended;
          call.statusText = 'Звонок завершён';
          _touchCall();
          _emit();
          break;
        }
        if (call.stage == CallStage.incoming ||
            call.stage == CallStage.outgoing) {
          unawaited(
            _closeCallWithStatus(
              reason == 'canceled'
                  ? _canceledCallLabel(call)
                  : _missedCallLabel(call),
              reason == 'canceled' ? CallStage.canceled : CallStage.missed,
            ),
          );
        } else {
          unawaited(
            _closeCallWithStatus(
              reason == 'canceled'
                  ? _canceledCallLabel(call)
                  : 'Звонок завершён',
              reason == 'canceled' ? CallStage.canceled : CallStage.ended,
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  void _handleIncomingCall(Map<String, dynamic> payload) {
    unawaited(
      PushNotificationsService.instance.cancelIncomingCallNotification(
        payload['call_id']?.toString(),
      ),
    );
    final fromPayload = Map<String, dynamic>.from(payload['from'] as Map);
    final contact = _ensureContactFromUserPayload(fromPayload);
    if (activeCall != null) {
      unawaited(
        _sendSocket({
          'type': 'call_busy',
          'call_id': payload['call_id'],
          'to_user_id': contact.userId,
          'reason': 'busy',
        }),
      );
      return;
    }
    activeCall = ActiveCall(
      id: payload['call_id'].toString(),
      contact: contact,
      isVideo: payload['is_video'] == true,
      isIncoming: true,
      stage: CallStage.incoming,
      remoteDescriptionSdp: payload['sdp']?.toString(),
      remoteDescriptionType: payload['sdp_type']?.toString(),
    );
    activeCall!.statusText = 'Входящий звонок';
    _touchCall();
    _emit();
  }

  Future<void> _handleCallAnswer(Map<String, dynamic> payload) async {
    final call = activeCall;
    if (call == null || call.id != payload['call_id']?.toString()) {
      return;
    }
    if (call.peerConnection == null) {
      return;
    }
    final sdp = payload['sdp']?.toString();
    final type = payload['sdp_type']?.toString();
    if (sdp == null || type == null) {
      return;
    }
    await call.peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdp, type),
    );
    call.remoteDescriptionApplied = true;
    call.stage = CallStage.connecting;
    call.statusText = 'Подключение';
    await _drainPendingCandidates(call);
    _touchCall();
    _emit();
  }

  Future<void> _handleCallCandidate(Map<String, dynamic> payload) async {
    final call = activeCall;
    if (call == null || call.id != payload['call_id']?.toString()) {
      return;
    }
    final candidatePayload = Map<String, dynamic>.from(
      payload['candidate'] as Map,
    );
    final candidate = RTCIceCandidate(
      candidatePayload['candidate']?.toString(),
      candidatePayload['sdp_mid']?.toString(),
      (candidatePayload['sdp_m_line_index'] as num?)?.toInt(),
    );
    if (call.peerConnection == null || !call.remoteDescriptionApplied) {
      call.pendingCandidates.add(candidate);
      return;
    }
    await call.peerConnection!.addCandidate(candidate);
  }

  void _handleCallMediaState(Map<String, dynamic> payload) {
    final call = activeCall;
    if (call == null || call.id != payload['call_id']?.toString()) {
      return;
    }
    final cameraEnabled = payload['camera_enabled'];
    if (cameraEnabled is bool) {
      call.remoteCameraEnabled = cameraEnabled;
      _touchCall();
      _emit();
    }
  }

  Future<RTCPeerConnection> _buildPeerConnection(ActiveCall call) async {
    final configuration = <String, dynamic>{'iceServers': _iceServers};
    if (_iceTransportPolicy != null) {
      configuration['iceTransportPolicy'] = _iceTransportPolicy;
    }
    final peer = await createPeerConnection(configuration);
    peer.onIceCandidate = (candidate) {
      if (candidate.candidate == null || activeCall?.id != call.id) {
        return;
      }
      unawaited(
        _sendSocket({
          'type': 'call_candidate',
          'call_id': call.id,
          'to_user_id': call.contact.userId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdp_mid': candidate.sdpMid,
            'sdp_m_line_index': candidate.sdpMLineIndex,
          },
        }),
      );
    };
    peer.onTrack = (event) {
      if (activeCall?.id != call.id) {
        return;
      }
      if (event.track.kind == 'video') {
        event.track.onMute = () {
          if (activeCall?.id != call.id) {
            return;
          }
          call.remoteCameraEnabled = false;
          _touchCall();
          _emit();
        };
        event.track.onUnMute = () {
          if (activeCall?.id != call.id) {
            return;
          }
          call.remoteCameraEnabled = true;
          _touchCall();
          _emit();
        };
      }
      if (event.streams.isNotEmpty) {
        call.remoteStream = event.streams.first;
        call.remoteRenderer.srcObject = event.streams.first;
        final remoteVideoTracks = event.streams.first.getVideoTracks();
        if (call.isVideo && remoteVideoTracks.isNotEmpty) {
          call.remoteCameraEnabled = remoteVideoTracks.any(
            (track) => track.enabled && track.muted != true,
          );
        }
        unawaited(_applyRemoteSoundState(call));
      }
      call.stage = CallStage.connected;
      call.statusText = call.isVideo ? 'Видео подключено' : 'Аудио подключено';
      _touchCall();
      _emit();
    };
    peer.onConnectionState = (state) {
      if (activeCall?.id != call.id) {
        return;
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        call.stage = CallStage.connected;
        call.statusText = call.isVideo
            ? 'Видео подключено'
            : 'Аудио подключено';
        _touchCall();
        _emit();
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        unawaited(
          _closeCallWithStatus('Соединение прервано', CallStage.failed),
        );
      }
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        unawaited(_closeInterruptedCallAfterGrace(call));
      }
    };
    return peer;
  }

  Future<void> _closeInterruptedCallAfterGrace(ActiveCall call) async {
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (activeCall?.id != call.id || call.isClosing) {
      return;
    }
    await _closeCallWithStatus('Соединение прервано', CallStage.failed);
  }

  Future<void> _drainPendingCandidates(ActiveCall call) async {
    if (call.pendingCandidates.isEmpty) {
      return;
    }
    final pendingCandidates = List<RTCIceCandidate>.from(
      call.pendingCandidates,
    );
    call.pendingCandidates.clear();
    for (final candidate in pendingCandidates) {
      await call.peerConnection?.addCandidate(candidate);
    }
  }

  Future<MediaStream> _openUserMedia(bool video) async {
    final baseAudio = <String, dynamic>{
      'echoCancellation': true,
      'noiseSuppression': true,
      'autoGainControl': true,
    };
    if (!video) {
      return navigator.mediaDevices.getUserMedia({
        'audio': baseAudio,
        'video': false,
      });
    }
    try {
      return await navigator.mediaDevices.getUserMedia({
        'audio': baseAudio,
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
      });
    } catch (_) {
      return navigator.mediaDevices.getUserMedia({
        'audio': baseAudio,
        'video': {'facingMode': 'user'},
      });
    }
  }

  Future<void> _ensureCallPermissions(bool video) async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw Exception('Нужен доступ к микрофону');
    }
    if (video) {
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        throw Exception('Нужен доступ к камере');
      }
    }
  }

  Future<void> _sendSocket(Map<String, dynamic> payload) async {
    if (_socket == null) {
      await _connectSocket();
    }
    if (_socket == null) {
      throw Exception('Нет соединения с сервером');
    }
    _socket!.add(jsonEncode(payload));
  }

  void _handleSocketClosed() {
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket = null;
    if (_skipReconnectOnce) {
      _skipReconnectOnce = false;
      return;
    }
    if (isAuthenticated && _shouldKeepSocketConnected) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldKeepSocketConnected) {
      return;
    }
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      const Duration(seconds: 3),
      () => unawaited(_connectSocket()),
    );
  }

  int _contactIdForMessage(ChatMessage message, int currentUserId) {
    if (message.isGroup) {
      final groupId = message.groupId;
      return groupId == null ? 0 : -groupId;
    }
    return message.senderId == currentUserId
        ? message.receiverId
        : message.senderId;
  }

  Future<void> _syncRealtimeState() async {
    if (!isAuthenticated) {
      return;
    }
    try {
      final conversationIds = _openConversationIds.toList(growable: false);
      await Future.wait<void>([
        loadContacts(),
        loadStories(),
        ...conversationIds.map(loadMessages),
      ]);
      await Future.wait<void>(conversationIds.map(markConversationRead));
      await _syncPendingIncomingCall();
    } catch (_) {}
  }

  Future<void> _syncPendingIncomingCall() async {
    if (!isAuthenticated || activeCall != null) {
      return;
    }
    if (_socket == null && _shouldKeepSocketConnected) {
      await _connectSocket(syncState: false);
    }
    try {
      final payload = await _request(
        'GET',
        '/calls/pending',
        authenticated: true,
      );
      if (activeCall != null) {
        return;
      }
      final rawCall = payload['call'];
      if (rawCall is Map) {
        _handleIncomingCall(Map<String, dynamic>.from(rawCall));
      }
    } catch (_) {}
  }

  void _handleMessagesRead(Map<String, dynamic> payload) {
    final readerUserId = (payload['reader_user_id'] as num?)?.toInt();
    if (readerUserId == null || readerUserId <= 0) {
      return;
    }
    _markMessagesReadForContact(readerUserId);
  }

  void _handleGroupMessagesRead(Map<String, dynamic> payload) {
    final groupId = (payload['group_id'] as num?)?.toInt();
    if (groupId == null || groupId <= 0) {
      return;
    }
    final rawMessageIds =
        payload['message_ids'] as List<dynamic>? ?? const <dynamic>[];
    final messageIds = rawMessageIds
        .map((item) => (item as num?)?.toInt() ?? 0)
        .where((item) => item > 0)
        .toSet();
    if (messageIds.isEmpty) {
      return;
    }
    final messages = _messagesByContact[-groupId];
    if (messages == null || messages.isEmpty) {
      return;
    }
    var hasChanges = false;
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      if (messageIds.contains(message.id) && !message.isRead) {
        messages[index] = message.copyWith(isRead: true);
        hasChanges = true;
      }
    }
    if (hasChanges) {
      _touchConversation(-groupId);
      _emit();
    }
  }

  void _handleTypingState(Map<String, dynamic> payload) {
    final currentUser = user;
    if (currentUser == null) {
      return;
    }
    final fromUserId = (payload['from_user_id'] as num?)?.toInt();
    if (fromUserId == null || fromUserId <= 0 || fromUserId == currentUser.id) {
      return;
    }
    final groupId = (payload['group_id'] as num?)?.toInt();
    final contactId = groupId != null && groupId > 0 ? -groupId : fromUserId;
    if (payload['is_typing'] != true) {
      _removeTypingParticipant(contactId, fromUserId);
      return;
    }
    final senderName = sanitizeDisplayText(
      payload['from_user_name']?.toString() ?? '',
      preserveLineBreaks: false,
    ).trim();
    _setTypingParticipant(
      contactId,
      fromUserId,
      senderName.isEmpty
          ? (contactById(fromUserId)?.name ?? 'Собеседник')
          : senderName,
    );
  }

  void _setTypingParticipant(int contactId, int userId, String displayName) {
    final participants = _typingParticipantsByConversation.putIfAbsent(
      contactId,
      () => <int, _TypingParticipant>{},
    );
    final previous = participants[userId];
    participants[userId] = _TypingParticipant(displayName: displayName);
    _scheduleTypingParticipantClear(contactId, userId);
    if (previous == null || previous.displayName != displayName) {
      _touchConversation(contactId);
      _emit();
    }
  }

  void _scheduleTypingParticipantClear(int contactId, int userId) {
    final timerKey = '$contactId:$userId';
    _typingClearTimers.remove(timerKey)?.cancel();
    _typingClearTimers[timerKey] = Timer(_typingIndicatorTimeout, () {
      _typingClearTimers.remove(timerKey);
      _removeTypingParticipant(contactId, userId);
    });
  }

  void _removeTypingParticipant(int contactId, int userId, {bool emit = true}) {
    final timerKey = '$contactId:$userId';
    _typingClearTimers.remove(timerKey)?.cancel();
    final participants = _typingParticipantsByConversation[contactId];
    if (participants == null) {
      return;
    }
    if (participants.remove(userId) == null) {
      return;
    }
    if (participants.isEmpty) {
      _typingParticipantsByConversation.remove(contactId);
    }
    if (emit) {
      _touchConversation(contactId);
      _emit();
    }
  }

  void _clearTypingParticipantsForConversation(
    int contactId, {
    bool emit = true,
  }) {
    final participants = _typingParticipantsByConversation.remove(contactId);
    if (participants == null || participants.isEmpty) {
      return;
    }
    for (final userId in participants.keys) {
      _typingClearTimers.remove('$contactId:$userId')?.cancel();
    }
    if (emit) {
      _touchConversation(contactId);
      _emit();
    }
  }

  void _updateContactPresence(Map<String, dynamic> payload) {
    final userId = (payload['user_id'] as num?)?.toInt();
    if (userId == null || userId <= 0) {
      return;
    }
    final index = _contactIndexById[userId];
    if (index == null) {
      return;
    }
    final current = contacts[index];
    final nextIsOnline = payload['online'] == true;
    final nextLastSeenAt = parseServerDateTime(
      payload['last_seen_at']?.toString(),
    );
    if (current.isOnline == nextIsOnline &&
        _sameDateTime(current.lastSeenAt, nextLastSeenAt)) {
      return;
    }
    contacts[index] = current.copyWith(
      isOnline: nextIsOnline,
      lastSeenAt: nextLastSeenAt,
    );
    _touchContacts(contactIds: <int>[userId]);
    _emit();
  }

  void _updateGroupPresence(Map<String, dynamic> payload) {
    final groupId = (payload['group_id'] as num?)?.toInt();
    if (groupId == null || groupId <= 0) {
      return;
    }
    final contactId = -groupId;
    final index = _contactIndexById[contactId];
    if (index == null) {
      return;
    }
    final current = contacts[index];
    final onlineMemberCount = (payload['online_member_count'] as num?)?.toInt();
    final memberCount = (payload['member_count'] as num?)?.toInt();
    final nextMemberCount = memberCount ?? current.memberCount;
    final nextOnlineMemberCount = onlineMemberCount == null
        ? current.onlineMemberCount
        : onlineMemberCount.clamp(0, nextMemberCount).toInt();
    if (current.onlineMemberCount == nextOnlineMemberCount &&
        current.memberCount == nextMemberCount) {
      return;
    }
    contacts[index] = current.copyWith(
      onlineMemberCount: nextOnlineMemberCount,
      memberCount: nextMemberCount,
    );
    _touchContacts(contactIds: <int>[contactId]);
    _emit();
  }

  void _handleContactUpserted(Map<String, dynamic> payload) {
    final rawContact = payload['contact'];
    if (rawContact is! Map) {
      unawaited(loadContacts());
      return;
    }
    try {
      _upsertContact(
        ContactItem.fromJson(Map<String, dynamic>.from(rawContact)),
      );
    } catch (_) {
      unawaited(loadContacts());
    }
  }

  void _handleGroupUpserted(Map<String, dynamic> payload) {
    final rawGroup = payload['group'];
    if (rawGroup is! Map) {
      unawaited(loadContacts());
      return;
    }
    try {
      _upsertContact(ContactItem.fromJson(Map<String, dynamic>.from(rawGroup)));
    } catch (_) {
      unawaited(loadContacts());
    }
  }

  void _handleStoriesUpdated(Map<String, dynamic> payload) {
    final currentUserId = user?.id;
    final rawAuthorId = payload['user_id'];
    final authorId = rawAuthorId is num
        ? rawAuthorId.toInt()
        : int.tryParse(rawAuthorId?.toString() ?? '');
    if (currentUserId != null &&
        authorId != null &&
        authorId > 0 &&
        authorId != currentUserId &&
        !_hasUnreadStories) {
      _hasUnreadStories = true;
      _touchStories();
      _emit();
    }
    unawaited(loadStories());
  }

  void _handleStoryDeleted(Map<String, dynamic> payload) {
    final rawStoryId = payload['story_id'];
    final storyId = rawStoryId is num
        ? rawStoryId.toInt()
        : int.tryParse(rawStoryId?.toString() ?? '');
    if (storyId != null && storyId > 0) {
      unawaited(
        PushNotificationsService.instance.cancelStoryNotification('$storyId'),
      );
      final removed = stories.any((story) => story.id == storyId);
      stories.removeWhere((story) => story.id == storyId);
      if (removed) {
        _touchStories();
        _emit();
      }
    }
    unawaited(loadStories());
  }

  void _upsertStory(StoryItem story) {
    final existingIndex = stories.indexWhere((item) => item.id == story.id);
    if (existingIndex == -1) {
      stories.add(story);
    } else {
      stories[existingIndex] = story;
    }
    stories.sort((left, right) => right.createdAt.compareTo(left.createdAt));
    _touchStories();
    _emit();
  }

  void _markIncomingMessageReadIfNeeded(ChatMessage message) {
    final currentUser = user;
    if (!_isAppInForeground ||
        currentUser == null ||
        message.isMine(currentUser.id)) {
      return;
    }
    final contactId = _contactIdForMessage(message, currentUser.id);
    if (contactId != 0 && _openConversationIds.contains(contactId)) {
      unawaited(markConversationRead(contactId));
    }
  }

  void _markMessagesReadForContact(int contactId) {
    final currentUser = user;
    final messages = _messagesByContact[contactId];
    if (currentUser == null || messages == null || messages.isEmpty) {
      return;
    }
    var hasChanges = false;
    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      if (message.senderId == currentUser.id &&
          message.receiverId == contactId &&
          !message.isRead) {
        messages[index] = message.copyWith(isRead: true);
        hasChanges = true;
      }
    }
    if (hasChanges) {
      _touchConversation(contactId);
      _emit();
    }
  }

  void _handleMessageDeleted(Map<String, dynamic> payload) {
    final currentUser = user;
    if (currentUser == null) {
      return;
    }
    final messageId = (payload['message_id'] as num?)?.toInt();
    final groupId = (payload['group_id'] as num?)?.toInt();
    if (messageId != null && groupId != null && groupId > 0) {
      unawaited(
        PushNotificationsService.instance
            .cancelConversationNotificationForMessage(-groupId, messageId),
      );
      _removeMessage(-groupId, messageId);
      unawaited(loadContacts());
      return;
    }
    final senderId = (payload['sender_id'] as num?)?.toInt();
    final receiverId = (payload['receiver_id'] as num?)?.toInt();
    if (messageId == null || senderId == null || receiverId == null) {
      return;
    }
    final contactId = senderId == currentUser.id ? receiverId : senderId;
    unawaited(
      PushNotificationsService.instance
          .cancelConversationNotificationForMessage(contactId, messageId),
    );
    _removeMessage(contactId, messageId);
    unawaited(loadContacts());
  }

  void _handleConversationCleared(Map<String, dynamic> payload) {
    final groupId = (payload['group_id'] as num?)?.toInt();
    final contactId = groupId != null && groupId > 0
        ? -groupId
        : (payload['contact_id'] as num?)?.toInt();
    if (contactId == null || contactId == 0) {
      unawaited(loadContacts());
      return;
    }
    _invalidateConversationLoads(contactId);
    _messagesByContact[contactId] = <ChatMessage>[];
    final contact = contactById(contactId);
    if (contact != null) {
      _upsertContact(
        contact.copyWith(
          lastMessage: '',
          lastMessageServiceKind: null,
          lastMessageCallInitiatorId: null,
          lastMessageCallStatus: null,
          lastMessageCallIsVideo: null,
          lastMessageSenderId: null,
          lastMessageSenderName: null,
          lastMessageAttachmentName: null,
          lastMessageAttachmentKind: null,
          lastMessageAt: null,
          unreadCount: 0,
        ),
        emit: false,
      );
      _touchContacts(contactIds: <int>[contactId]);
    } else {
      unawaited(loadContacts());
    }
    _touchConversation(contactId);
    _emit();
  }

  void _handleConversationDeleted(Map<String, dynamic> payload) {
    final groupId = (payload['group_id'] as num?)?.toInt();
    final contactId = groupId != null && groupId > 0
        ? -groupId
        : (payload['contact_id'] as num?)?.toInt();
    if (contactId == null || contactId == 0) {
      unawaited(loadContacts());
      return;
    }
    _removeConversationLocally(contactId);
  }

  void _upsertMessage(ChatMessage message) {
    final currentUser = user;
    if (currentUser == null) {
      return;
    }
    final contactId = _contactIdForMessage(message, currentUser.id);
    if (contactId == 0) {
      return;
    }
    if (!message.isMine(currentUser.id)) {
      _removeTypingParticipant(contactId, message.senderId, emit: false);
    }
    final currentList = _messagesByContact.putIfAbsent(
      contactId,
      () => <ChatMessage>[],
    );
    final existingIndex = findSortedMessageIndex(currentList, message.id);
    final isNewMessage = existingIndex == -1;
    _insertOrUpdateSortedMessage(currentList, message);
    final latestMessage = currentList.isEmpty ? null : currentList.last;
    final contactIndex = _contactIndexById[contactId];
    if (contactIndex != null) {
      final existingContact = contacts[contactIndex];
      final shouldIncreaseUnread =
          isNewMessage &&
          !message.isMine(currentUser.id) &&
          !_openConversationIds.contains(contactId);
      _upsertContact(
        existingContact.copyWith(
          lastMessage: latestMessage == null
              ? existingContact.lastMessage
              : summarizeMessageForPreviewText(
                  latestMessage,
                  currentUserId: currentUser.id,
                ),
          lastMessageServiceKind: latestMessage?.serviceKind,
          lastMessageCallInitiatorId: latestMessage?.callInitiatorId,
          lastMessageCallStatus: latestMessage?.callStatus,
          lastMessageCallIsVideo: latestMessage?.callIsVideo,
          lastMessageSenderId: latestMessage?.senderId,
          lastMessageSenderName: latestMessage == null
              ? existingContact.lastMessageSenderName
              : (latestMessage.isMine(currentUser.id)
                    ? currentUser.name
                    : latestMessage.senderName),
          lastMessageAttachmentName: latestMessage == null
              ? existingContact.lastMessageAttachmentName
              : messageAttachmentPreviewName(latestMessage),
          lastMessageAttachmentKind: latestMessage == null
              ? existingContact.lastMessageAttachmentKind
              : messageAttachmentPreviewKind(latestMessage),
          lastMessageAt:
              latestMessage?.createdAt ?? existingContact.lastMessageAt,
          unreadCount: shouldIncreaseUnread
              ? existingContact.unreadCount + 1
              : existingContact.unreadCount,
        ),
        emit: false,
      );
      if (_openConversationIds.contains(contactId)) {
        _setContactUnreadCount(contactId, 0, emit: false);
      }
      _touchConversation(contactId);
      _emit();
      return;
    }
    if (!message.isGroup && !message.isMine(currentUser.id)) {
      _ensureContactFromUserPayload({
        'id': message.senderId,
        'email': '',
        'name': message.senderName ?? '',
        'avatar_url': message.senderAvatarUrl,
      }, emit: false);
      _touchConversation(contactId);
      _emit();
      return;
    }
    unawaited(loadContacts());
    _touchConversation(contactId);
    _emit();
  }

  void _removeMessage(int contactId, int messageId) {
    final currentUser = user;
    final currentList = _messagesByContact[contactId];
    if (currentList == null) {
      return;
    }
    currentList.removeWhere((item) => item.id == messageId);
    final contact = contactById(contactId);
    if (contact != null) {
      final latestMessage = currentList.isEmpty ? null : currentList.last;
      final latestPreview = latestMessage == null
          ? ''
          : summarizeMessageForPreviewText(
              latestMessage,
              currentUserId: currentUser?.id,
            );
      _upsertContact(
        contact.copyWith(
          lastMessage: latestMessage == null
              ? contact.lastMessage
              : latestPreview,
          lastMessageServiceKind: latestMessage?.serviceKind,
          lastMessageCallInitiatorId: latestMessage?.callInitiatorId,
          lastMessageCallStatus: latestMessage?.callStatus,
          lastMessageCallIsVideo: latestMessage?.callIsVideo,
          lastMessageSenderId: latestMessage?.senderId,
          lastMessageSenderName: latestMessage == null
              ? null
              : (currentUser != null && latestMessage.isMine(currentUser.id)
                    ? currentUser.name
                    : latestMessage.senderName),
          lastMessageAttachmentName: latestMessage == null
              ? null
              : messageAttachmentPreviewName(latestMessage),
          lastMessageAttachmentKind: latestMessage == null
              ? null
              : messageAttachmentPreviewKind(latestMessage),
          lastMessageAt: latestMessage?.createdAt ?? contact.lastMessageAt,
        ),
        emit: false,
      );
      _touchConversation(contactId);
      _emit();
      return;
    }
    _touchConversation(contactId);
    _emit();
  }

  ContactItem _ensureContactFromUserPayload(
    Map<String, dynamic> payload, {
    bool emit = true,
  }) {
    final userId = (payload['id'] as num).toInt();
    final existing = contactById(userId);
    if (existing != null) {
      return existing;
    }
    final created = ContactItem(
      userId: userId,
      remoteId: userId,
      chatType: ChatType.direct,
      email: payload['email'].toString(),
      name: payload['name'].toString(),
      avatarUrl: resolveServerMediaUrl(payload['avatar_url']?.toString()),
      lastMessage: '',
      lastMessageServiceKind: null,
      lastMessageCallInitiatorId: null,
      lastMessageCallStatus: null,
      lastMessageCallIsVideo: null,
      lastMessageSenderId: null,
      lastMessageSenderName: null,
      lastMessageAt: null,
      lastSeenAt: null,
      isOnline: true,
      ownerId: null,
      memberCount: 2,
      onlineMemberCount: 1,
      unreadCount: 0,
    );
    _upsertContact(created, emit: emit);
    return created;
  }

  void _updateOutgoingCallStatus(String? callId, String status) {
    final call = activeCall;
    if (call == null || call.id != callId || call.isIncoming) {
      return;
    }
    call.stage = CallStage.outgoing;
    call.statusText = normalizeKnownCallSystemText(
      status,
      preserveLineBreaks: false,
    );
    _touchCall();
    _emit();
  }

  Future<void> _closeCallWithStatus(
    String status,
    CallStage nextStage, {
    bool showToast = true,
  }) async {
    final call = activeCall;
    if (call == null) {
      return;
    }
    if (call.isClosing) {
      return;
    }
    call.isClosing = true;
    await PushNotificationsService.instance.cancelIncomingCallNotification(
      call.id,
    );
    final normalizedStatus = normalizeKnownCallSystemText(
      status,
      preserveLineBreaks: false,
    );
    call.stage = nextStage;
    call.statusText = normalizedStatus;
    _touchCall();
    _emit();
    unawaited(_releaseClosedCallMedia(call));
    if (nextStage == CallStage.missed && !_isAppInForeground) {
      await PushNotificationsService.instance.showMissedCallNotification(
        contact: call.contact,
        isVideo: call.isVideo,
        isIncoming: call.isIncoming,
        callId: call.id,
      );
    } else if (nextStage == CallStage.rejected &&
        !call.isIncoming &&
        !_isAppInForeground) {
      await PushNotificationsService.instance.showRejectedCallNotification(
        contact: call.contact,
        isVideo: call.isVideo,
        isIncoming: call.isIncoming,
        callId: call.id,
      );
    } else if (nextStage == CallStage.canceled &&
        call.isIncoming &&
        !_isAppInForeground) {
      await PushNotificationsService.instance.showCanceledCallNotification(
        contact: call.contact,
        isVideo: call.isVideo,
        isIncoming: call.isIncoming,
        callId: call.id,
      );
    }
    _touchCall();
    _emit();
    final toastLabel = showToast
        ? _buildCallToastLabel(call, normalizedStatus, nextStage)
        : null;
    if (toastLabel != null) {
      showGlobalToast(toastLabel, isError: true);
    }
    final closeDelay = nextStage == CallStage.canceled
        ? const Duration(milliseconds: 800)
        : const Duration(milliseconds: 1200);
    await Future<void>.delayed(closeDelay);
    if (activeCall?.id == call.id) {
      await _dropCurrentCall();
    }
  }

  Future<void> _releaseClosedCallMedia(ActiveCall call) async {
    final localStream = call.localStream;
    final remoteStream = call.remoteStream;
    final peerConnection = call.peerConnection;
    final tracks = <MediaStreamTrack>[
      ...?localStream?.getTracks(),
      ...?remoteStream?.getTracks(),
    ];
    call.localStream = null;
    call.remoteStream = null;
    call.peerConnection = null;
    call.localRenderer.srcObject = null;
    call.remoteRenderer.srcObject = null;
    for (final track in tracks) {
      try {
        track.enabled = false;
        await track.stop();
      } catch (_) {}
    }
    try {
      await peerConnection?.close();
    } catch (_) {}
    try {
      await localStream?.dispose();
    } catch (_) {}
    try {
      await remoteStream?.dispose();
    } catch (_) {}
  }

  Future<void> _dropCurrentCall() async {
    final call = activeCall;
    if (call == null) {
      return;
    }
    activeCall = null;
    _touchCall();
    _emit();
    await _dropCallSilently(call);
    if (!_isAppInForeground) {
      await _closeSocketConnection();
    }
  }

  Future<void> _dropCallSilently(ActiveCall call) async {
    await call.dispose();
  }

  void _emit() {
    if (_disposed || _emitScheduled) {
      return;
    }
    _emitScheduled = true;
    scheduleMicrotask(() {
      _emitScheduled = false;
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    if (_screenAwakeForCall) {
      _screenAwakeForCall = false;
      unawaited(_deviceChannel.invokeMethod<void>('allowScreenOff'));
    }
    for (final timer in _typingClearTimers.values) {
      timer.cancel();
    }
    _typingClearTimers.clear();
    _typingParticipantsByConversation.clear();
    _outgoingTypingStateByConversation.clear();
    _lastOutgoingTypingEventAt.clear();
    _loadContactsFuture = null;
    _contactsRefreshQueued = false;
    _loadStoriesFuture = null;
    _storiesRefreshQueued = false;
    _loadMessageFutures.clear();
    _queuedConversationReloads.clear();
    _queuedReadConversations.clear();
    _conversationLoadGenerations.clear();
    final subscription = _socketSubscription;
    _socketSubscription = null;
    final socket = _socket;
    _socket = null;
    if (subscription != null || socket != null) {
      _skipReconnectOnce = true;
    }
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    if (socket != null) {
      unawaited(socket.close());
    }
    if (activeCall != null) {
      unawaited(activeCall!.dispose());
      activeCall = null;
    }
    _stageRevision.dispose();
    _sessionRevision.dispose();
    _contactsRevision.dispose();
    _storiesRevision.dispose();
    _callRevision.dispose();
    _disposeRevisionMap(_contactRevisionById);
    _disposeRevisionMap(_conversationRevisionById);
    _httpClient.close();
    super.dispose();
  }
}

class _TypingParticipant {
  const _TypingParticipant({required this.displayName});

  final String displayName;
}

bool _sameStoryList(List<StoryItem> left, List<StoryItem> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    final a = left[index];
    final b = right[index];
    if (a.id != b.id ||
        a.userId != b.userId ||
        a.authorName != b.authorName ||
        a.authorAvatarUrl != b.authorAvatarUrl ||
        a.mediaName != b.mediaName ||
        a.mediaUrl != b.mediaUrl ||
        a.mediaMimeType != b.mediaMimeType ||
        !a.createdAt.isAtSameMomentAs(b.createdAt) ||
        !a.expiresAt.isAtSameMomentAs(b.expiresAt)) {
      return false;
    }
  }
  return true;
}

bool _sameDateTime(DateTime? left, DateTime? right) {
  if (left == null || right == null) {
    return left == right;
  }
  return left.isAtSameMomentAs(right);
}

bool _sameContactItem(ContactItem left, ContactItem right) {
  return left.userId == right.userId &&
      left.remoteId == right.remoteId &&
      left.chatType == right.chatType &&
      left.email == right.email &&
      left.name == right.name &&
      left.avatarUrl == right.avatarUrl &&
      left.lastMessage == right.lastMessage &&
      left.lastMessageServiceKind == right.lastMessageServiceKind &&
      left.lastMessageCallInitiatorId == right.lastMessageCallInitiatorId &&
      left.lastMessageCallStatus == right.lastMessageCallStatus &&
      left.lastMessageCallIsVideo == right.lastMessageCallIsVideo &&
      left.lastMessageSenderId == right.lastMessageSenderId &&
      left.lastMessageSenderName == right.lastMessageSenderName &&
      left.lastMessageAttachmentName == right.lastMessageAttachmentName &&
      left.lastMessageAttachmentKind == right.lastMessageAttachmentKind &&
      _sameDateTime(left.lastMessageAt, right.lastMessageAt) &&
      _sameDateTime(left.lastSeenAt, right.lastSeenAt) &&
      left.isOnline == right.isOnline &&
      left.ownerId == right.ownerId &&
      left.memberCount == right.memberCount &&
      left.onlineMemberCount == right.onlineMemberCount &&
      left.unreadCount == right.unreadCount;
}

bool _sameContactList(List<ContactItem> left, List<ContactItem> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (!_sameContactItem(left[index], right[index])) {
      return false;
    }
  }
  return true;
}

bool _sameIntSet(Set<int> left, Set<int> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final value in left) {
    if (!right.contains(value)) {
      return false;
    }
  }
  return true;
}

int findSortedMessageIndex(List<ChatMessage> messages, int messageId) {
  var left = 0;
  var right = messages.length - 1;
  while (left <= right) {
    final middle = left + ((right - left) >> 1);
    final currentId = messages[middle].id;
    if (currentId == messageId) {
      return middle;
    }
    if (currentId < messageId) {
      left = middle + 1;
    } else {
      right = middle - 1;
    }
  }
  return -1;
}

int findSortedMessageInsertIndex(List<ChatMessage> messages, int messageId) {
  var left = 0;
  var right = messages.length;
  while (left < right) {
    final middle = left + ((right - left) >> 1);
    if (messages[middle].id < messageId) {
      left = middle + 1;
    } else {
      right = middle;
    }
  }
  return left;
}
