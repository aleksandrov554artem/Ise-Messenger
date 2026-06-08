part of '../main.dart';

const String pushTypeChatMessage = 'chat_message';
const String pushTypeIncomingCall = 'incoming_call';
const String pushTypeMissedCall = 'missed_call';
const String pushTypeRejectedCall = 'rejected_call';
const String pushTypeCanceledCall = 'canceled_call';
const String pushTypeContactAdded = 'contact_added';
const String pushTypeGroupAdded = 'group_added';
const String pushTypeGroupMemberAdded = 'group_member_added';
const String pushTypeGroupMemberRemoved = 'group_member_removed';
const String pushTypeMessageDeleted = 'message_deleted';
const String pushTypeAppUpdate = 'app_update';
const String pushTypeStoryCreated = 'story_created';
const String pushTypeStoryDeleted = 'story_deleted';
const String _pendingNotificationTapStorageKey =
    'pending_push_notification_tap';
const String _settledCallNotificationStorageKey =
    'settled_call_notification_ids';
const String _messageNotificationStateStorageKey = 'message_notification_state';
const String _appUpdateNotificationVersionStorageKey =
    'app_update_notification_version';
const String _messageChannelId = 'ise_messages_alerts_v1';
const String _callChannelId = 'ise_calls_alerts_v1';
const String _updateChannelId = 'ise_updates';
const String _notificationIconName = '@drawable/ic_stat_notification';
const int _appUpdateNotificationId = 400001;
const Duration _settledCallNotificationRetention = Duration(hours: 12);

const AndroidNotificationChannel _messageNotificationChannel =
    AndroidNotificationChannel(
      _messageChannelId,
      'Ise Messenger messages',
      description: 'Уведомления о новых сообщениях',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

const AndroidNotificationChannel _callNotificationChannel =
    AndroidNotificationChannel(
      _callChannelId,
      'Ise Messenger calls',
      description: 'Уведомления о входящих звонках',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

const AndroidNotificationChannel _updateNotificationChannel =
    AndroidNotificationChannel(
      _updateChannelId,
      'Ise Messenger updates',
      description: 'Уведомления о новых версиях приложения',
      importance: Importance.high,
      playSound: true,
      enableVibration: false,
    );

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin _backgroundNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await PushNotificationsService.showBackgroundRemoteMessage(message);
}

@pragma('vm:entry-point')
void backgroundNotificationTapHandler(NotificationResponse response) {
  unawaited(_storePendingNotificationTapPayload(response.payload));
}

Future<void> _storePendingNotificationTapPayload(String? payload) async {
  final normalized = payload?.trim();
  if (normalized == null || normalized.isEmpty) {
    return;
  }
  try {
    final prefs = await _sharedPreferences();
    await prefs.setString(_pendingNotificationTapStorageKey, normalized);
  } catch (_) {}
}

Future<String?> _consumePendingNotificationTapPayload() async {
  try {
    final prefs = await _sharedPreferences();
    final payload = prefs.getString(_pendingNotificationTapStorageKey)?.trim();
    if (payload == null || payload.isEmpty) {
      return null;
    }
    await prefs.remove(_pendingNotificationTapStorageKey);
    return payload;
  } catch (_) {
    return null;
  }
}

Future<Map<String, int>> _loadSettledCallNotificationState() async {
  final prefs = await _sharedPreferences();
  final rawEntries =
      prefs.getStringList(_settledCallNotificationStorageKey) ??
      const <String>[];
  final cutoff = DateTime.now()
      .subtract(_settledCallNotificationRetention)
      .millisecondsSinceEpoch;
  final state = <String, int>{};
  var needsCleanup = false;
  for (final entry in rawEntries) {
    final separatorIndex = entry.indexOf('|');
    if (separatorIndex <= 0 || separatorIndex >= entry.length - 1) {
      needsCleanup = true;
      continue;
    }
    final callId = entry.substring(0, separatorIndex).trim();
    final timestamp = int.tryParse(entry.substring(separatorIndex + 1));
    if (callId.isEmpty || timestamp == null || timestamp < cutoff) {
      needsCleanup = true;
      continue;
    }
    state[callId] = timestamp;
  }
  if (needsCleanup) {
    final normalizedEntries = state.entries
        .map((entry) => '${entry.key}|${entry.value}')
        .toList(growable: false);
    await prefs.setStringList(
      _settledCallNotificationStorageKey,
      normalizedEntries,
    );
  }
  return state;
}

Future<void> _rememberSettledCallNotification(String? callId) async {
  final normalized = callId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return;
  }
  final prefs = await _sharedPreferences();
  final state = await _loadSettledCallNotificationState();
  state[normalized] = DateTime.now().millisecondsSinceEpoch;
  final entries = state.entries
      .map((entry) => '${entry.key}|${entry.value}')
      .toList(growable: false);
  await prefs.setStringList(_settledCallNotificationStorageKey, entries);
}

Future<bool> _isSettledCallNotification(String? callId) async {
  final normalized = callId?.trim();
  if (normalized == null || normalized.isEmpty) {
    return false;
  }
  final state = await _loadSettledCallNotificationState();
  return state.containsKey(normalized);
}

Future<Map<int, int>> _loadMessageNotificationState() async {
  final prefs = await _sharedPreferences();
  final rawEntries =
      prefs.getStringList(_messageNotificationStateStorageKey) ??
      const <String>[];
  final state = <int, int>{};
  var needsCleanup = false;
  for (final entry in rawEntries) {
    final separatorIndex = entry.indexOf('|');
    if (separatorIndex <= 0 || separatorIndex >= entry.length - 1) {
      needsCleanup = true;
      continue;
    }
    final conversationId = int.tryParse(entry.substring(0, separatorIndex));
    final messageId = int.tryParse(entry.substring(separatorIndex + 1));
    if (conversationId == null || messageId == null || messageId <= 0) {
      needsCleanup = true;
      continue;
    }
    state[conversationId] = messageId;
  }
  if (needsCleanup) {
    await _persistMessageNotificationState(state);
  }
  return state;
}

Future<void> _persistMessageNotificationState(Map<int, int> state) async {
  final prefs = await _sharedPreferences();
  final entries = state.entries
      .map((entry) => '${entry.key}|${entry.value}')
      .toList(growable: false);
  await prefs.setStringList(_messageNotificationStateStorageKey, entries);
}

Future<void> _rememberMessageNotificationState(
  int conversationId,
  int messageId,
) async {
  final state = await _loadMessageNotificationState();
  state[conversationId] = messageId;
  await _persistMessageNotificationState(state);
}

Future<void> _clearMessageNotificationState(int conversationId) async {
  final state = await _loadMessageNotificationState();
  if (state.remove(conversationId) == null) {
    return;
  }
  await _persistMessageNotificationState(state);
}

Future<bool> _clearMessageNotificationStateIfMatches(
  int conversationId,
  int messageId,
) async {
  final state = await _loadMessageNotificationState();
  if (state[conversationId] != messageId) {
    return false;
  }
  state.remove(conversationId);
  await _persistMessageNotificationState(state);
  return true;
}

Future<String?> _loadNotifiedAppUpdateVersion() async {
  final prefs = await _sharedPreferences();
  final value = prefs.getString(_appUpdateNotificationVersionStorageKey);
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

Future<void> _rememberNotifiedAppUpdateVersion(String versionLabel) async {
  final normalized = versionLabel.trim();
  if (normalized.isEmpty) {
    return;
  }
  final prefs = await _sharedPreferences();
  await prefs.setString(_appUpdateNotificationVersionStorageKey, normalized);
}

Future<void> _clearNotifiedAppUpdateVersion() async {
  final prefs = await _sharedPreferences();
  await prefs.remove(_appUpdateNotificationVersionStorageKey);
}

class PushNotificationsService {
  PushNotificationsService._();

  static final PushNotificationsService instance = PushNotificationsService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initializeFuture;
  StreamSubscription<RemoteMessage>? _foregroundMessagesSubscription;
  StreamSubscription<RemoteMessage>? _openedMessagesSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  Future<void> Function(Map<String, dynamic> payload)? _notificationTapHandler;
  Future<void> Function(String token)? _pushTokenHandler;
  bool Function(Map<String, dynamic> payload)? _shouldDisplayNotification;
  String? _lastDeliveredTapPayload;

  Future<void> initialize({
    required Future<void> Function(Map<String, dynamic> payload)
    onNotificationTap,
    required Future<void> Function(String token) onPushTokenChanged,
    bool Function(Map<String, dynamic> payload)? shouldDisplayNotification,
  }) {
    _notificationTapHandler = onNotificationTap;
    _pushTokenHandler = onPushTokenChanged;
    _shouldDisplayNotification = shouldDisplayNotification;
    return _initializeFuture ??= _initialize();
  }

  Future<void> syncCurrentToken() async {
    if (!Platform.isAndroid) {
      return;
    }
    final firebaseReady = await _ensureFirebaseInitialized();
    if (!firebaseReady) {
      return;
    }
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.trim().isNotEmpty) {
        await _notifyPushTokenChanged(token);
      }
    } catch (_) {}
  }

  Future<void> _initialize() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _initializeNotificationsPlugin(_notificationsPlugin);
    await _requestNotificationPermissions();
    await _deliverStoredLaunchPayloads();
    final firebaseReady = await _ensureFirebaseInitialized();
    if (!firebaseReady) {
      return;
    }
    final messaging = FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true);
    } catch (_) {}
    _foregroundMessagesSubscription?.cancel();
    _foregroundMessagesSubscription = FirebaseMessaging.onMessage.listen(
      (message) => unawaited(_showNotificationForRemoteMessage(message)),
    );
    _openedMessagesSubscription?.cancel();
    _openedMessagesSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => unawaited(
        _handleNotificationPayload(_payloadFromRemoteMessage(message)),
      ),
    );
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription = messaging.onTokenRefresh.listen(
      (token) => unawaited(_notifyPushTokenChanged(token)),
    );
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      await _handleNotificationPayload(
        _payloadFromRemoteMessage(initialMessage),
      );
    }
    final token = await messaging.getToken();
    if (token != null && token.trim().isNotEmpty) {
      await _notifyPushTokenChanged(token);
    }
  }

  Future<void> dispose() async {
    await _foregroundMessagesSubscription?.cancel();
    await _openedMessagesSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    _foregroundMessagesSubscription = null;
    _openedMessagesSubscription = null;
    _tokenRefreshSubscription = null;
    _initializeFuture = null;
  }

  Future<void> cancelConversationNotification(int conversationId) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _clearMessageNotificationState(conversationId);
    await _notificationsPlugin.cancel(
      id: _conversationNotificationId(conversationId),
    );
  }

  Future<void> cancelConversationNotificationForMessage(
    int conversationId,
    int messageId,
  ) async {
    if (!Platform.isAndroid || messageId <= 0) {
      return;
    }
    final wasCleared = await _clearMessageNotificationStateIfMatches(
      conversationId,
      messageId,
    );
    if (!wasCleared) {
      return;
    }
    await _notificationsPlugin.cancel(
      id: _conversationNotificationId(conversationId),
    );
  }

  Future<void> cancelIncomingCallNotification(String? callId) async {
    final normalized = callId?.trim();
    if (!Platform.isAndroid || normalized == null || normalized.isEmpty) {
      return;
    }
    await _notificationsPlugin.cancel(id: _callNotificationId(normalized));
  }

  Future<void> cancelStoryNotification(String? storyId) async {
    final normalized = storyId?.trim();
    if (!Platform.isAndroid || normalized == null || normalized.isEmpty) {
      return;
    }
    await _notificationsPlugin.cancel(id: _storyNotificationId(normalized));
  }

  Future<void> showMissedCallNotification({
    required ContactItem contact,
    required bool isVideo,
    required bool isIncoming,
    required String callId,
  }) async {
    await _showCallStatusNotification(
      contact: contact,
      isVideo: isVideo,
      callId: callId,
      pushType: pushTypeMissedCall,
      statusText: buildCallHistoryLabel(
        isIncoming: isIncoming,
        isVideo: isVideo,
        callStatus: callHistoryStatusMissed,
      ),
      bodyFallback: 'Откройте чат, чтобы перезвонить',
    );
  }

  Future<void> showRejectedCallNotification({
    required ContactItem contact,
    required bool isVideo,
    required bool isIncoming,
    required String callId,
  }) async {
    await _showCallStatusNotification(
      contact: contact,
      isVideo: isVideo,
      callId: callId,
      pushType: pushTypeRejectedCall,
      statusText: buildCallHistoryLabel(
        isIncoming: isIncoming,
        isVideo: isVideo,
        callStatus: callHistoryStatusRejected,
      ),
      bodyFallback: 'Откройте чат, чтобы связаться позже',
    );
  }

  Future<void> showCanceledCallNotification({
    required ContactItem contact,
    required bool isVideo,
    required bool isIncoming,
    required String callId,
  }) async {
    await _showCallStatusNotification(
      contact: contact,
      isVideo: isVideo,
      callId: callId,
      pushType: pushTypeCanceledCall,
      statusText: buildCallHistoryLabel(
        isIncoming: isIncoming,
        isVideo: isVideo,
        callStatus: callHistoryStatusCanceled,
      ),
      bodyFallback: 'Откройте чат, чтобы перезвонить',
    );
  }

  Future<void> _showCallStatusNotification({
    required ContactItem contact,
    required bool isVideo,
    required String callId,
    required String pushType,
    required String statusText,
    required String bodyFallback,
  }) async {
    if (!Platform.isAndroid) {
      return;
    }
    final contactName = sanitizeDisplayText(
      contact.name,
      preserveLineBreaks: false,
    ).trim();
    final contactEmail = sanitizeDisplayText(
      contact.email,
      preserveLineBreaks: false,
    ).trim();
    final notificationTitle = contactName.isNotEmpty
        ? contactName
        : contactEmail.isNotEmpty
        ? contactEmail
        : 'Контакт';
    final payload = <String, dynamic>{
      'push_type': pushType,
      'call_id': callId,
      'conversation_id': '${contact.userId}',
      'conversation': jsonEncode(<String, dynamic>{
        'id': contact.remoteId,
        'chat_type': 'direct',
        'email': contact.email,
        'name': contact.name,
        'avatar_url': contact.avatarUrl,
      }),
      'title': notificationTitle,
      'body': statusText.trim().isEmpty ? bodyFallback : statusText,
    };
    await _showLocalNotification(_notificationsPlugin, payload);
  }

  Future<void> showAppUpdateNotification({required String versionLabel}) async {
    if (!Platform.isAndroid) {
      return;
    }
    await _initializeNotificationsPlugin(_notificationsPlugin);
    final normalizedVersion = versionLabel.trim();
    await _showLocalNotification(_notificationsPlugin, <String, dynamic>{
      'push_type': pushTypeAppUpdate,
      'version_label': normalizedVersion,
      'title': 'Новое обновление',
      'body': '',
    });
  }

  Future<void> cancelAppUpdateNotification() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _notificationsPlugin.cancel(id: _appUpdateNotificationId);
  }

  Future<void> _requestNotificationPermissions() async {
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    try {
      await androidImplementation?.requestNotificationsPermission();
    } catch (_) {}
    try {
      await androidImplementation?.requestFullScreenIntentPermission();
    } catch (_) {}
  }

  Future<void> _deliverStoredLaunchPayloads() async {
    final pendingPayloads = <String>{};
    final storedPayload = await _consumePendingNotificationTapPayload();
    if (storedPayload != null) {
      pendingPayloads.add(storedPayload);
    }
    final launchDetails = await _notificationsPlugin
        .getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload?.trim();
    if (launchPayload != null && launchPayload.isNotEmpty) {
      pendingPayloads.add(launchPayload);
    }
    for (final payload in pendingPayloads) {
      await _handleNotificationPayloadString(payload);
    }
  }

  Future<void> _notifyPushTokenChanged(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      return;
    }
    await _pushTokenHandler?.call(normalized);
  }

  Future<void> _handleNotificationPayload(Map<String, dynamic> payload) async {
    await _notificationTapHandler?.call(payload);
  }

  Future<void> _handleNotificationPayloadString(String rawPayload) async {
    final normalized = rawPayload.trim();
    if (normalized.isEmpty || _lastDeliveredTapPayload == normalized) {
      return;
    }
    late final Map<String, dynamic> payload;
    try {
      payload = Map<String, dynamic>.from(jsonDecode(normalized) as Map);
    } catch (_) {
      return;
    }
    _lastDeliveredTapPayload = normalized;
    await _handleNotificationPayload(payload);
  }

  Future<void> _showNotificationForRemoteMessage(RemoteMessage message) async {
    final data = _payloadFromRemoteMessage(message);
    if (data.isEmpty) {
      return;
    }
    if (_shouldDisplayNotification != null &&
        !_shouldDisplayNotification!(data)) {
      return;
    }
    await _showLocalNotification(_notificationsPlugin, data);
  }

  static Future<void> showBackgroundRemoteMessage(RemoteMessage message) async {
    if (!Platform.isAndroid) {
      return;
    }
    final firebaseReady = await _ensureFirebaseInitialized();
    if (!firebaseReady) {
      return;
    }
    await _initializeNotificationsPlugin(_backgroundNotificationsPlugin);
    final data = _payloadFromRemoteMessage(message);
    if (data.isEmpty) {
      return;
    }
    await _showLocalNotification(_backgroundNotificationsPlugin, data);
  }

  static Future<bool> _ensureFirebaseInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}

Map<String, dynamic> _payloadFromRemoteMessage(RemoteMessage message) {
  if (message.data.isEmpty) {
    return <String, dynamic>{};
  }
  final payload = Map<String, dynamic>.from(message.data);
  final notification = message.notification;
  final title = payload['title']?.toString().trim() ?? '';
  final body = payload['body']?.toString().trim() ?? '';
  if (title.isEmpty && notification?.title != null) {
    payload['title'] = notification!.title!;
  }
  if (body.isEmpty && notification?.body != null) {
    payload['body'] = notification!.body!;
  }
  return payload;
}

Future<void> _initializeNotificationsPlugin(
  FlutterLocalNotificationsPlugin plugin,
) async {
  final initializationSettings = const InitializationSettings(
    android: AndroidInitializationSettings(_notificationIconName),
  );
  await plugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (response) {
      unawaited(
        PushNotificationsService.instance._handleNotificationPayloadString(
          response.payload?.trim() ?? '',
        ),
      );
    },
    onDidReceiveBackgroundNotificationResponse:
        backgroundNotificationTapHandler,
  );
  final androidImplementation = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await androidImplementation?.createNotificationChannel(
    _messageNotificationChannel,
  );
  await androidImplementation?.createNotificationChannel(
    _callNotificationChannel,
  );
  await androidImplementation?.createNotificationChannel(
    _updateNotificationChannel,
  );
}

Future<void> _showLocalNotification(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, dynamic> payload,
) async {
  final pushType = payload['push_type']?.toString().trim() ?? '';
  final callId = _trimmedValue(payload['call_id']);
  if (pushType == pushTypeIncomingCall &&
      callId != null &&
      await _isSettledCallNotification(callId)) {
    await plugin.cancel(id: _callNotificationId(callId));
    return;
  }
  if (pushType == pushTypeMissedCall ||
      pushType == pushTypeRejectedCall ||
      pushType == pushTypeCanceledCall) {
    if (callId != null) {
      await _rememberSettledCallNotification(callId);
      await plugin.cancel(id: _callNotificationId(callId));
    }
  }
  if (pushType == pushTypeMessageDeleted) {
    final conversationId =
        int.tryParse(payload['conversation_id']?.toString() ?? '') ?? 0;
    final messageId =
        int.tryParse(payload['message_id']?.toString() ?? '') ?? 0;
    if (conversationId != 0 && messageId > 0) {
      final wasCleared = await _clearMessageNotificationStateIfMatches(
        conversationId,
        messageId,
      );
      if (wasCleared) {
        await plugin.cancel(id: _conversationNotificationId(conversationId));
      }
    }
    return;
  }
  if (pushType == pushTypeStoryDeleted) {
    final storyId = _trimmedValue(payload['story_id']);
    if (storyId != null) {
      await plugin.cancel(id: _storyNotificationId(storyId));
    }
    return;
  }
  final notification = _buildLocalNotification(payload);
  if (notification == null) {
    return;
  }
  if (pushType == pushTypeChatMessage) {
    final conversationId =
        int.tryParse(payload['conversation_id']?.toString() ?? '') ?? 0;
    final messageId =
        int.tryParse(payload['message_id']?.toString() ?? '') ?? 0;
    if (conversationId != 0 && messageId > 0) {
      await _rememberMessageNotificationState(conversationId, messageId);
    }
  }
  await plugin.show(
    id: notification.id,
    title: notification.title,
    body: notification.body,
    notificationDetails: notification.details,
    payload: notification.payloadJson,
  );
}

_LocalPushNotification? _buildLocalNotification(Map<String, dynamic> payload) {
  final pushType = payload['push_type']?.toString().trim() ?? '';
  final isCallStatusPush =
      pushType == pushTypeMissedCall ||
      pushType == pushTypeRejectedCall ||
      pushType == pushTypeCanceledCall;
  if (pushType != pushTypeChatMessage &&
      pushType != pushTypeIncomingCall &&
      !isCallStatusPush &&
      pushType != pushTypeContactAdded &&
      pushType != pushTypeGroupAdded &&
      pushType != pushTypeGroupMemberAdded &&
      pushType != pushTypeGroupMemberRemoved &&
      pushType != pushTypeAppUpdate &&
      pushType != pushTypeStoryCreated) {
    return null;
  }
  final conversationName = _notificationConversationName(payload);
  final isVideoCall = _trimmedValue(payload['is_video']) == '1';
  final rawTitle = normalizeKnownCallSystemText(
    _trimmedValue(payload['title']) ?? '',
    preserveLineBreaks: false,
  );
  final rawBody = normalizeKnownCallSystemText(
    _trimmedValue(payload['body']) ?? '',
    preserveLineBreaks: false,
  );
  final fallbackTitle = switch (pushType) {
    pushTypeIncomingCall =>
      conversationName == null
          ? (isVideoCall ? 'Видео звонок' : 'Аудио звонок')
          : '${isVideoCall ? 'Видео' : 'Аудио'} звонок от $conversationName',
    pushTypeMissedCall ||
    pushTypeRejectedCall ||
    pushTypeCanceledCall => conversationName ?? 'Ise Messenger',
    pushTypeContactAdded =>
      conversationName == null
          ? 'Вас добавили в чаты'
          : '$conversationName добавил вас в чаты',
    pushTypeGroupAdded =>
      conversationName == null
          ? 'Добавили в группу'
          : 'Добавили в группу $conversationName',
    pushTypeGroupMemberAdded =>
      conversationName == null
          ? 'Вас добавили в группу'
          : 'Вас добавили в группу $conversationName',
    pushTypeGroupMemberRemoved =>
      conversationName == null
          ? 'Вас удалили из группы'
          : 'Вас удалили из группы $conversationName',
    pushTypeAppUpdate => 'Новое обновление',
    pushTypeStoryCreated => 'Новая история',
    _ => 'Новое сообщение',
  };
  final title = switch (pushType) {
    pushTypeChatMessage =>
      rawTitle.isNotEmpty && rawTitle != 'Новое сообщение'
          ? rawTitle
          : rawBody.isNotEmpty
          ? rawBody
          : fallbackTitle,
    pushTypeContactAdded =>
      rawTitle.isNotEmpty && rawTitle != 'Новый чат'
          ? rawTitle
          : rawBody.isNotEmpty
          ? rawBody
          : fallbackTitle,
    pushTypeGroupAdded =>
      rawTitle.contains('добавил в группу')
          ? rawTitle
          : rawBody.contains('добавил в группу')
          ? rawBody
          : fallbackTitle,
    pushTypeGroupMemberAdded || pushTypeGroupMemberRemoved =>
      rawTitle.isNotEmpty ? rawTitle : fallbackTitle,
    pushTypeIncomingCall =>
      rawTitle.contains('звонок от')
          ? rawTitle
          : rawBody.contains('звонок от')
          ? rawBody
          : fallbackTitle,
    pushTypeMissedCall ||
    pushTypeRejectedCall ||
    pushTypeCanceledCall => rawTitle.isNotEmpty ? rawTitle : fallbackTitle,
    pushTypeAppUpdate => 'Новое обновление',
    pushTypeStoryCreated => 'Новая история',
    _ => fallbackTitle,
  };
  final body = switch (pushType) {
    pushTypeChatMessage => rawBody,
    pushTypeContactAdded ||
    pushTypeGroupAdded ||
    pushTypeGroupMemberAdded ||
    pushTypeGroupMemberRemoved => rawBody,
    pushTypeAppUpdate => rawBody,
    pushTypeStoryCreated => rawBody.isNotEmpty ? rawBody : rawTitle,
    _ => isCallStatusPush ? rawBody : '',
  };
  final payloadJson = jsonEncode(payload);
  if (pushType == pushTypeIncomingCall) {
    final callId = _trimmedValue(payload['call_id']) ?? payloadJson;
    final androidDetails = AndroidNotificationDetails(
      _callNotificationChannel.id,
      _callNotificationChannel.name,
      channelDescription: _callNotificationChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      timeoutAfter: 45000,
      icon: _notificationIconName,
      playSound: true,
      enableVibration: true,
    );
    return _LocalPushNotification(
      id: _callNotificationId(callId),
      title: title,
      body: body,
      payloadJson: payloadJson,
      details: NotificationDetails(android: androidDetails),
    );
  }
  if (pushType == pushTypeAppUpdate) {
    final androidDetails = AndroidNotificationDetails(
      _updateNotificationChannel.id,
      _updateNotificationChannel.name,
      channelDescription: _updateNotificationChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.status,
      icon: _notificationIconName,
      playSound: true,
      enableVibration: true,
    );
    return _LocalPushNotification(
      id: _appUpdateNotificationId,
      title: title,
      body: body,
      payloadJson: payloadJson,
      details: NotificationDetails(android: androidDetails),
    );
  }
  if (pushType == pushTypeStoryCreated) {
    final storyId = _trimmedValue(payload['story_id']) ?? payloadJson;
    final androidDetails = AndroidNotificationDetails(
      _messageNotificationChannel.id,
      _messageNotificationChannel.name,
      channelDescription: _messageNotificationChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.status,
      icon: _notificationIconName,
      playSound: true,
      enableVibration: true,
    );
    return _LocalPushNotification(
      id: _storyNotificationId(storyId),
      title: title,
      body: body,
      payloadJson: payloadJson,
      details: NotificationDetails(android: androidDetails),
    );
  }
  if (isCallStatusPush) {
    final conversationId =
        int.tryParse(payload['conversation_id']?.toString() ?? '') ?? 0;
    if (conversationId == 0) {
      return null;
    }
    final androidDetails = AndroidNotificationDetails(
      _messageNotificationChannel.id,
      _messageNotificationChannel.name,
      channelDescription: _messageNotificationChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.status,
      icon: _notificationIconName,
      playSound: true,
      enableVibration: true,
    );
    return _LocalPushNotification(
      id: _conversationNotificationId(conversationId),
      title: title,
      body: body,
      payloadJson: payloadJson,
      details: NotificationDetails(android: androidDetails),
    );
  }
  final conversationId =
      int.tryParse(payload['conversation_id']?.toString() ?? '') ?? 0;
  if (conversationId == 0) {
    return null;
  }
  final androidDetails = AndroidNotificationDetails(
    _messageNotificationChannel.id,
    _messageNotificationChannel.name,
    channelDescription: _messageNotificationChannel.description,
    importance: Importance.max,
    priority: Priority.max,
    category: AndroidNotificationCategory.message,
    icon: _notificationIconName,
    playSound: true,
    enableVibration: true,
  );
  return _LocalPushNotification(
    id: _conversationNotificationId(conversationId),
    title: title,
    body: body,
    payloadJson: payloadJson,
    details: NotificationDetails(android: androidDetails),
  );
}

String? _trimmedValue(dynamic value) {
  final normalized = value?.toString().trim() ?? '';
  return normalized.isEmpty ? null : normalized;
}

String? _notificationConversationName(Map<String, dynamic> payload) {
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
  final name = sanitizeDisplayText(
    conversationJson['name']?.toString() ?? '',
    preserveLineBreaks: false,
  ).trim();
  if (name.isNotEmpty) {
    return name;
  }
  final email = sanitizeDisplayText(
    conversationJson['email']?.toString() ?? '',
    preserveLineBreaks: false,
  ).trim();
  return email.isEmpty ? null : email;
}

int _conversationNotificationId(int conversationId) {
  if (conversationId < 0) {
    return 200000 + conversationId.abs();
  }
  return 100000 + conversationId.abs();
}

int _callNotificationId(String callId) {
  var hash = 0;
  for (final code in callId.codeUnits) {
    hash = ((hash * 31) + code) & 0x3fffffff;
  }
  return 300000 + (hash % 100000);
}

int _storyNotificationId(String storyId) {
  var hash = 0;
  for (final code in storyId.codeUnits) {
    hash = ((hash * 31) + code) & 0x3fffffff;
  }
  return 500000 + (hash % 100000);
}

class _LocalPushNotification {
  const _LocalPushNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.payloadJson,
    required this.details,
  });

  final int id;
  final String title;
  final String body;
  final String payloadJson;
  final NotificationDetails details;
}
