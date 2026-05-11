import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../models/purchase_models.dart';
import 'purchases_repository.dart';

class HttpPurchasesRepository implements PurchasesRepository {
  HttpPurchasesRepository({required this.baseUrl, this.client, this.realtimeClient});

  final String baseUrl;
  final http.Client? client;
  final SupabaseClient? realtimeClient;

  http.Client get _client => client ?? http.Client();

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
    final response = await _client.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'course_id': courseId,
        'section_id': sectionId,
        'amount_uzs': amountUzs,
        'provider': 'telegram',
      }),
    );
    debugPrint('[API][purchases.create][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage("Xarid yaratishda xatolik (${response.statusCode}).", response.body),
      );
    }
  }

  @override
  Future<List<UserEntitlementItem>> fetchUserEntitlements({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) {
      throw Exception('API manzili yoki userId topilmadi (purchase.entitlements).');
    }
    final uri = Uri.parse('$baseUrl/api/v1/purchases/user?user_id=$userId');
    debugPrint('[API][purchases.entitlements][request] $uri');
    final response = await _client.get(
      uri,
    );
    debugPrint('[API][purchases.entitlements][response] status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage("Xarid huquqlarini olishda xatolik (${response.statusCode}).", response.body),
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
    return raw
        .whereType<Map<String, dynamic>>()
        .map(UserEntitlementItem.fromJson)
        .toList(growable: false);
  }

  @override
  Stream<List<UserEntitlementItem>> watchUserEntitlements({
    required String userId,
    Duration pollInterval = const Duration(seconds: 12),
  }) {
    if (userId.isEmpty) return Stream.value(const []);
    final controller = StreamController<List<UserEntitlementItem>>();
    RealtimeChannel? channel;
    Timer? poller;
    var disposed = false;

    Future<void> push() async {
      if (disposed) return;
      try {
        controller.add(await fetchUserEntitlements(userId: userId));
      } catch (_) {}
    }

    Future<void> boot() async {
      await push();
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
              callback: (_) => unawaited(push()),
            )
            .subscribe();
      }
      poller = Timer.periodic(pollInterval, (_) => unawaited(push()));
    }

    unawaited(boot());
    controller.onCancel = () async {
      disposed = true;
      poller?.cancel();
      if (channel != null) await realtimeClient?.removeChannel(channel!);
      await controller.close();
    };
    return controller.stream;
  }
}
