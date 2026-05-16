import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../../http_request_timeouts.dart';
import '../models/purchase_models.dart';
import 'purchases_repository.dart';

class HttpPurchasesRepository implements PurchasesRepository {
  HttpPurchasesRepository({required this.baseUrl, this.client, this.realtimeClient});

  final String baseUrl;
  final http.Client? client;
  final SupabaseClient? realtimeClient;

  http.Client get _client => client ?? http.Client();

  Future<List<UserEntitlementItem>>? _fetchInFlight;
  String? _fetchInFlightUserId;
  DateTime? _lastFetchAt;
  List<UserEntitlementItem>? _lastFetchResult;

  String _errorMessage(String fallback, String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        final detail = parsed['detail']?.toString().trim() ?? '';
        if (detail.isNotEmpty) return detail;
      }
    } catch (_) {}
    return fallback;
  }

  @override
  Future<void> createPurchase({
    required String userId,
    String? courseId,
    String? sectionId,
    double amountUzs = 0,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty) {
      throw Exception('API manzili yoki userId topilmadi (purchase.create).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/purchases');
    debugPrint('[API][purchases.create][request] $uri userId=$userId courseId=${courseId ?? ''} sectionId=${sectionId ?? ''}');
    final response = await _client
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'user_id': userId,
            'course_id': courseId,
            'section_id': sectionId,
            'amount_uzs': amountUzs,
            'provider': 'telegram',
          }),
        )
        .timeout(purchasesFetchTimeoutForBaseUrl(baseUrl));
    debugPrint('[API][purchases.create][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage("Xarid yaratishda xatolik (${response.statusCode}).", response.body),
      );
    }
    _lastFetchAt = null;
  }

  @override
  Future<List<UserEntitlementItem>> fetchUserEntitlements({
    required String userId,
    bool force = false,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty) {
      throw Exception('API manzili yoki userId topilmadi (purchase.entitlements).');
    }

    if (!force &&
        _lastFetchAt != null &&
        _lastFetchResult != null &&
        _fetchInFlightUserId == userId &&
        DateTime.now().difference(_lastFetchAt!) < const Duration(seconds: 8)) {
      return _lastFetchResult!;
    }

    if (_fetchInFlight != null && _fetchInFlightUserId == userId) {
      return _fetchInFlight!;
    }

    _fetchInFlightUserId = userId;
    _fetchInFlight = _fetchUserEntitlementsOnce(userId);
    try {
      return await _fetchInFlight!;
    } finally {
      _fetchInFlight = null;
    }
  }

  Future<List<UserEntitlementItem>> _fetchUserEntitlementsOnce(String userId) async {
    final uri = Uri.parse('$baseUrl/api/v1/purchases/user?user_id=$userId');
    debugPrint('[API][purchases.entitlements][request] $uri');
    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(purchasesFetchTimeoutForBaseUrl(baseUrl));
      debugPrint('[API][purchases.entitlements][response] status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          _errorMessage(
            "Xarid huquqlarini olishda xatolik (${response.statusCode}).",
            response.body,
          ),
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('Xarid huquqlari javobi JSON emas.');
      }
      final raw = body['items'];
      if (raw is! List) {
        throw Exception("Xarid huquqlari ro'yxati topilmadi.");
      }
      final items = raw
          .whereType<Map<String, dynamic>>()
          .map(UserEntitlementItem.fromJson)
          .toList(growable: false);
      _lastFetchAt = DateTime.now();
      _lastFetchResult = items;
      return items;
    } on TimeoutException {
      debugPrint('[API][purchases.entitlements][timeout] $uri');
      if (_lastFetchResult != null) {
        return _lastFetchResult!;
      }
      rethrow;
    } on http.ClientException catch (e) {
      debugPrint('[API][purchases.entitlements][network] $e');
      if (_lastFetchResult != null) {
        return _lastFetchResult!;
      }
      rethrow;
    }
  }

  @override
  Stream<List<UserEntitlementItem>> watchUserEntitlements({
    required String userId,
    Duration pollInterval = const Duration(seconds: 60),
  }) {
    if (userId.isEmpty) return Stream.value(const []);
    final controller = StreamController<List<UserEntitlementItem>>();
    RealtimeChannel? channel;
    Timer? poller;
    Timer? pushDebounce;
    var disposed = false;
    var pushInFlight = false;

    Future<void> push({bool force = false}) async {
      if (disposed || pushInFlight) return;
      pushInFlight = true;
      try {
        final items = await fetchUserEntitlements(userId: userId, force: force);
        if (!disposed) controller.add(items);
      } catch (error) {
        if (!disposed && _lastFetchResult != null) {
          controller.add(_lastFetchResult!);
        } else if (kDebugMode) {
          debugPrint('[API][purchases.watch][error] $error');
        }
      } finally {
        pushInFlight = false;
      }
    }

    void schedulePush({bool force = false}) {
      if (disposed) return;
      pushDebounce?.cancel();
      pushDebounce = Timer(const Duration(milliseconds: 900), () {
        unawaited(push(force: force));
      });
    }

    Future<void> boot() async {
      await push(force: true);
      final client = realtimeClient;
      if (client != null) {
        channel = client
            .channel('app-entitlements-$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'user_entitlements',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (_) => schedulePush(),
            )
            .subscribe();
        poller = Timer.periodic(const Duration(seconds: 90), (_) => schedulePush());
      } else {
        poller = Timer.periodic(pollInterval, (_) => schedulePush());
      }
    }

    unawaited(boot());
    controller.onCancel = () async {
      disposed = true;
      pushDebounce?.cancel();
      poller?.cancel();
      if (channel != null) await realtimeClient?.removeChannel(channel!);
      await controller.close();
    };
    return controller.stream;
  }
}
