import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../firebase_options.dart';
import '../config/api_config.dart';
import '../router/app_routes.dart';

/// Same key as [AuthService] session persistence — avoid importing AuthService (cycles).
const _authPrefsKey = 'auth_user_v1';

final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

bool _firebaseReady = false;
bool _localReady = false;
bool _permissionRequested = false;

/// Set from the app root ([NeuroscienceApp]) so push events refresh the notification feed / badge.
void Function()? onNotificationsFeedShouldRefresh;
bool _openHandlersAttached = false;
bool _foregroundOnMessageAttached = false;
bool _tokenRefreshAttached = false;
bool _deviceTokenEndpointMissing = false;
String? _lastKnownFcmToken;
GoRouter? _router;
String? _pendingRoute;

/// Android 8+: `Importance.max` — heads-up (ekran tepasidan chiqadigan) bildirishnomalar uchun.
const AndroidNotificationChannel _androidChannel = AndroidNotificationChannel(
  'neuroscience_push',
  'Bildirishnomalar',
  description: 'Admin va tizim bildirishnomalari',
  importance: Importance.max,
  enableVibration: true,
  playSound: true,
);

/// Firebase Core — [main] va foreground push sozlamalari uchun.
///
/// [FirebaseMessaging.onBackgroundMessage] faqat [main] ichida chaqiriladi: IDE Hot Restart
/// (`Restarted application`) yangi Dart isolate ochadi, lekin Android jarayoni bir xil qoladi;
/// handler takror ro‘yxatdan o‘tsa **Could not prepare isolate** xatosi chiqishi mumkin.
Future<bool> ensureFirebaseCoreInitialized() async {
  Object? lastError;
  StackTrace? lastStack;
  for (var attempt = 0; attempt < 12; attempt++) {
    if (attempt > 0) {
      await Future<void>.delayed(Duration(milliseconds: 60 * attempt));
    }
    try {
      if (Firebase.apps.isEmpty) {
        if (Platform.isAndroid) {
          try {
            await Firebase.initializeApp();
          } catch (_) {
            await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
          }
        } else {
          await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
        }
      }
      return true;
    } catch (e, st) {
      lastError = e;
      lastStack = st;
      debugPrint('Firebase.initializeApp urinish ${attempt + 1}/12: $e');
    }
  }

  if (lastError != null) {
    debugPrint(
      'Firebase.initializeApp yakunda xato (push o‘chiq): $lastError\n'
      '>>> Agar Hot Restart dan keyin bo‘lsa: ilovani to‘xtating, qayta Run qiling; kerak bo‘lsa flutter clean.\n'
      '$lastStack',
    );
  }
  return false;
}

Future<void> initializeFirebaseAppAndForegroundPush() async {
  final coreOk = await ensureFirebaseCoreInitialized();
  if (!coreOk || Firebase.apps.isEmpty) {
    return;
  }

  await _requestNotificationPermissionIfNeeded();

  // Android: mahalliy kanal + foregroundda heads-up. iOS hozircha minimal (keyinroq sozlash mumkin).
  if (Platform.isAndroid || Platform.isIOS) {
    await _initLocalNotificationsPlugin();
    if (!_foregroundOnMessageAttached) {
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
      _foregroundOnMessageAttached = true;
    }
  }

  if (!_tokenRefreshAttached) {
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _lastKnownFcmToken = token;
      unawaited(_syncTokenToBackend(token));
    });
    _tokenRefreshAttached = true;
  }

  final token = await FirebaseMessaging.instance.getToken();
  if (token != null && token.trim().isNotEmpty) {
    _lastKnownFcmToken = token;
    await _syncTokenToBackend(token);
  }

  _firebaseReady = true;

  await _tryBindFirebaseOpenHandlers();
}

Future<void> _requestNotificationPermissionIfNeeded() async {
  if (_permissionRequested) return;
  try {
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  } catch (e) {
    debugPrint('Notification permission request failed: $e');
  } finally {
    _permissionRequested = true;
  }
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
      unawaited(_delayedFirebaseBootstrap());
    });
  }

  Future<void> _delayedFirebaseBootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await initializeFirebaseAppAndForegroundPush();
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
  final bodyRaw = message.notification?.body ?? message.data['body']?.toString() ?? '';
  final body = bodyRaw.trim().isEmpty
      ? ''
      : (bodyRaw.contains('UZB Neuroscience') ? bodyRaw : '$bodyRaw\n— UZB Neuroscience');
  if (title.isEmpty && body.isEmpty) return;

  String route = AppRoutes.notifications;
  final routeRaw = message.data['route']?.toString().trim() ?? '';
  if (routeRaw.isNotEmpty) {
    route = routeRaw;
  } else if ((message.data['type']?.toString() ?? '') == 'book_granted') {
    final bid = message.data['book_id']?.toString().trim() ?? '';
    if (bid.isNotEmpty) {
      route = '${AppRoutes.bookReader}?id=$bid';
    }
  }

  final rawId = message.data['notification_id']?.toString();
  final nid = int.tryParse(rawId ?? '') ?? message.hashCode;
  final notificationId = nid.abs() % 0x7fffffff;

  final detail = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.max,
      priority: Priority.max,
      visibility: NotificationVisibility.public,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      subText: 'UZB Neuroscience',
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
  _showInAppBanner(title: title, body: bodyRaw);
  onNotificationsFeedShouldRefresh?.call();
}

void _showInAppBanner({required String title, required String body}) {
  final ctx = _router?.routerDelegate.navigatorKey.currentContext;
  if (ctx == null) return;
  final messenger = ScaffoldMessenger.maybeOf(ctx);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Text(
        [title.trim(), body.trim()].where((e) => e.isNotEmpty).join('\n'),
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

void _handleLocalNotificationPayload(String? payload) {
  if (payload == null || payload.trim().isEmpty) {
    _goRoute(AppRoutes.notifications);
    onNotificationsFeedShouldRefresh?.call();
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
      onNotificationsFeedShouldRefresh?.call();
      return;
    }
  } catch (_) {}
  _goRoute(payload);
  onNotificationsFeedShouldRefresh?.call();
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
  final routeRaw = (data['route'] ?? '').toString().trim();
  final type = (data['type'] ?? '').toString().trim();
  final bookId = (data['book_id'] ?? '').toString().trim();
  final route = routeRaw.isNotEmpty
      ? routeRaw
      : (type == 'book_granted' && bookId.isNotEmpty
            ? '${AppRoutes.bookReader}?id=$bookId'
            : AppRoutes.notifications);
  final path = route.startsWith('/') ? route : '/$route';
  _goRoute(path);
  final nid = data['notification_id']?.toString();
  if (nid != null && nid.isNotEmpty) {
    unawaited(_reportPushClick(nid));
  }
  onNotificationsFeedShouldRefresh?.call();
}

Future<void> _syncTokenToBackend(String token) async {
  final trimmed = token.trim();
  if (trimmed.isEmpty) return;
  if (_deviceTokenEndpointMissing) {
    debugPrint('[push] token sync skipped: endpoint previously reported missing');
    return;
  }
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_authPrefsKey);
    if (raw == null || raw.isEmpty) return;
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return;
    final userId = decoded['id']?.toString() ?? '';
    final sessionToken = decoded['session_token']?.toString() ?? '';
    if (userId.isEmpty || sessionToken.length < 8) return;
    final base = getApiBaseUrl();
    if (base.isEmpty) return;
    final uri = Uri.parse('$base/api/v1/auth/device-token');
    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'session_token': sessionToken,
        'fcm_token': trimmed,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (res.statusCode == 404) {
        _deviceTokenEndpointMissing = true;
        debugPrint('[push] token sync endpoint missing (404): $uri');
      } else {
        debugPrint('[push] token sync failed status=${res.statusCode} body=${res.body}');
      }
    } else {
      debugPrint('[push] token sync ok status=${res.statusCode}');
    }
  } catch (e) {
    debugPrint('[push] token sync error: $e');
  }
}

/// Session tayyor bo'lgandan keyin token syncni qo'lda qayta urinish.
Future<void> trySyncDeviceTokenNow() async {
  if (_deviceTokenEndpointMissing) return;
  if (!_firebaseReady) return;
  try {
    var token = _lastKnownFcmToken;
    if (token == null || token.trim().isEmpty) {
      token = await FirebaseMessaging.instance.getToken();
      _lastKnownFcmToken = token;
    }
    if (token == null || token.trim().isEmpty) {
      debugPrint('[push] token sync skipped: FCM token empty');
      return;
    }
    await _syncTokenToBackend(token);
  } catch (e) {
    debugPrint('[push] token sync retry error: $e');
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
