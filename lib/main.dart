import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, instantiateImageCodec;
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

part 'models/models.dart';
part 'core/config.dart';
part 'widgets/app_widgets.dart';
part 'services/push_notifications.dart';
part 'screens/splash_screen.dart';
part 'screens/email_screen.dart';
part 'screens/code_entry_screen.dart';
part 'screens/name_entry_screen.dart';
part 'screens/chat_list_screen.dart';
part 'screens/chat_screen.dart';
part 'screens/archive_screen.dart';
part 'screens/settings_screen.dart';
part 'screens/add_chat_screen.dart';
part 'screens/group_creation_screen.dart';
part 'screens/forward_message_target_screen.dart';
part 'screens/group_contact_picker_screen.dart';
part 'screens/group_settings_screen.dart';
part 'screens/stories_screen.dart';
part 'screens/story_create_screen.dart';
part 'screens/story_viewer_screen.dart';
part 'widgets/story_media_widgets.dart';
part 'screens/my_stories_screen.dart';
part 'screens/preview_screen.dart';
part 'screens/audio_call_screen.dart';
part 'screens/video_call_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 160;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 72 << 20;
  if (Platform.isAndroid) {
    final firebaseReady =
        await PushNotificationsService._ensureFirebaseInitialized();
    if (firebaseReady) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  }
  SystemChrome.setSystemUIOverlayStyle(appDarkSurfaceOverlayStyle);
  runApp(const IseMessengerApp());
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key, required this.controller});

  final MessengerController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.stageListenable,
      builder: (context, _) {
        final screen = switch (controller.stage) {
          AppStage.loading => const SplashScreen(),
          AppStage.email => EmailScreen(controller: controller),
          AppStage.code => CodeScreen(controller: controller),
          AppStage.name => NameScreen(controller: controller),
          AppStage.contacts => ContactsScreen(controller: controller),
        };
        return KeyedSubtree(key: ValueKey(controller.stage), child: screen);
      },
    );
  }
}

class IseMessengerApp extends StatefulWidget {
  const IseMessengerApp({super.key});

  @override
  State<IseMessengerApp> createState() => _IseMessengerAppState();
}

class _IseMessengerAppState extends State<IseMessengerApp>
    with WidgetsBindingObserver {
  late final MessengerController controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller = MessengerController();
    unawaited(
      PushNotificationsService.instance.initialize(
        onNotificationTap: controller.handlePushNotificationTap,
        onPushTokenChanged: controller.handlePushTokenChanged,
        shouldDisplayNotification: controller.shouldDisplayNotification,
      ),
    );
    unawaited(controller.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(controller.handleAppLifecycleState(state));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(PushNotificationsService.instance.dispose());
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Ise Messenger',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: RootScreen(controller: controller),
      builder: (context, child) {
        return AnimatedBuilder(
          animation: controller.callListenable,
          builder: (context, _) {
            return TooltipVisibility(
              visible: false,
              child: Stack(
                children: [
                  child ?? const SizedBox.shrink(),
                  if (controller.activeCall != null)
                    CallOverlay(
                      controller: controller,
                      call: controller.activeCall!,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
