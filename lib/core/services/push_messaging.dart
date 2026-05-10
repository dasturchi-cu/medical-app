import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_background_handler.dart';
import '../../firebase_options.dart';
import '../config/api_config.dart';
import '../router/app_routes.dart';

/// Same key as [AuthService] session persistence — avoid importing AuthService (cycles).
const _authPrefsKey = 'auth_user_v1';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

bool _firebaseReady = false;
bool _localReady = false;
bool _openHandlersAttached = false;
GoRouter? _router;
String? _pendingRoute;

const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'neuroscience_push',
  'Bildirishnomalar',
  description: 'Admin va tizim bildirishnomalari',
  importance: Importance.high,
);

/// Birinchi frame dan keyin chaqiring — `main()` ichida chaqirish baʼzan channel-error beradi.
/// Hot Restart (`Restarted application`) Firebase ni buzadi: ilovani to‘xtating va qayta Run qiling.
Future<void> initializeFirebaseAppAndForegroundPush() async {
  if (_firebaseReady) return;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e, st) {
    debugPrint(
      'Firebase.initializeApp xatolik (push o‘chiq): $e\n'
      '>>> Agar logda "Restarted application" bo‘lsa: Stop ▶ yangidan Run (Hot Restart emas).\n'
      '$st',
    );
    return;
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  _firebaseReady = true;

  if (Platform.isAndroid || Platform.isIOS) {
    await _initLocalNotificationsPlugin();
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((_) {
    debugPrint('FCM token refreshed (sign in again to sync)');
  });

  await _tryBindFirebaseOpenHandlers();
}

/// [WidgetsFlutterBinding] tayyor bo‘lgach — [runApp] dan oldin emas, widget daraxti ostida.
class FirebasePushBootstrap extends StatefulWidget {
  const FirebasePushBootstrap({super.key, required this.child});

  final Widget child;

  @override
  State<FirebasePushBootstrap> createState() => _FirebasePushBootstrapState();
}

class _FirebasePushBootstrapState extends State<FirebasePushBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(initializeFirebaseAppAndForegroundPush());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

Future<void> _tryBindFirebaseOpenHandlers() async {
  if (!_firebaseReady || _openHandlersAttached) return;
  _openHandlersAttached = true;

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _navigateFromData(message.data);
  });

  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateFromData(initial.data);
    });
  }
}

Future<void> _initLocalNotificationsPlugin() async {
  if (_localReady) return;
  const init = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _local.initialize(
    init,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      _handleLocalNotificationPayload(response.payload);
    },
  );
  final androidPlugin = _local.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_androidChannel);
  _localReady = true;
}

void _showForegroundNotification(RemoteMessage message) {
  if (!_localReady) return;
  final title = message.notification?.title ?? message.data['title']?.toString() ?? '';
  final body = message.notification?.body ?? message.data['body']?.toString() ?? '';
  if (title.isEmpty && body.isEmpty) return;

  final route =
      message.data['route']?.toString().trim().isNotEmpty == true
          ? message.data['route'].toString()
          : AppRoutes.notifications;

  final rawId = message.data['notification_id']?.toString();
  final nid = int.tryParse(rawId ?? '') ?? message.hashCode;
  final notificationId = nid.abs() % 0x7fffffff;

  final detail = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    ),
    iOS: const DarwinNotificationDetails(),
  );
  _local.show(
    notificationId,
    title.isEmpty ? ' ' : title,
    body,
    detail,
    payload: jsonEncode({
      'route': route,
      if (message.data['notification_id'] != null)
        'notification_id': message.data['notification_id'].toString(),
    }),
  );
}

void _handleLocalNotificationPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    _goRoute(AppRoutes.notifications);
    return;
  }
  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map<String, dynamic>) {
      final route = (decoded['route'] ?? AppRoutes.notifications).toString();
      final path = route.startsWith('/') ? route : '/$route';
      _goRoute(path);
      final nid = decoded['notification_id']?.toString();
      if (nid != null && nid.isNotEmpty) {
        unawaited(_reportPushClick(nid));
      }
      return;
    }
  } catch (_) {}
  _goRoute(payload);
}

Future<void> _reportPushClick(String notificationId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authPrefsKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    final userId = decoded['id']?.toString();
    if (userId == null || userId.isEmpty) return;
    final base = getApiBaseUrl();
    if (base.isEmpty) return;
    final uri = Uri.parse('$base/api/v1/notifications/$notificationId/click');
    await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
  } catch (_) {}
}

/// Attach tap handlers once [GoRouter] is available (shell / post-login routes).
Future<void> attachPushNavigation(GoRouter router) async {
  _router = router;

  if (_pendingRoute != null) {
    final pending = _pendingRoute!;
    _pendingRoute = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _goRoute(pending));
  }

  await _tryBindFirebaseOpenHandlers();
}

void _navigateFromData(Map<String, dynamic> data) {
  final route = (data['route'] ?? AppRoutes.notifications).toString();
  final path = route.startsWith('/') ? route : '/$route';
  _goRoute(path);
  final nid = data['notification_id']?.toString();
  if (nid != null && nid.isNotEmpty) {
    unawaited(_reportPushClick(nid));
  }
}

void _goRoute(String route) {
  final path = route.startsWith('/') ? route : '/$route';
  final r = _router;
  if (r == null) {
    _pendingRoute = path;
    return;
  }
  try {
    r.go(path);
  } catch (e) {
    debugPrint('Push navigation failed: $e');
  }
}

/// Keeps [GoRouter] in sync for notification taps (replace when auth rebuilds router).
class PushRouterScope extends StatefulWidget {
  const PushRouterScope({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<PushRouterScope> createState() => _PushRouterScopeState();
}

class _PushRouterScopeState extends State<PushRouterScope> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      attachPushNavigation(widget.router);
    });
  }

  @override
  void didUpdateWidget(covariant PushRouterScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        attachPushNavigation(widget.router);
      });
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Returns null if Firebase failed to initialize or permission denied.
Future<String?> getFcmTokenForLogin() async {
  if (!_firebaseReady) return null;
  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }
    return FirebaseMessaging.instance.getToken();
  } catch (e) {
    debugPrint('getFcmTokenForLogin: $e');
    return null;
  }
}
