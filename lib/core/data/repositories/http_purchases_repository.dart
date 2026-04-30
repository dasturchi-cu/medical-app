import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/purchase_models.dart';
import 'purchases_repository.dart';

class HttpPurchasesRepository implements PurchasesRepository {
  HttpPurchasesRepository({required this.baseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

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
}
