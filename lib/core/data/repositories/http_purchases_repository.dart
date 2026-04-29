import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/purchase_models.dart';
import 'purchases_repository.dart';

class HttpPurchasesRepository implements PurchasesRepository {
  HttpPurchasesRepository({required this.baseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  @override
  Future<void> createPurchase({
    required String userId,
    String? courseId,
    String? sectionId,
    double amountUzs = 0,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty) return;
    await _client.post(
      Uri.parse('$baseUrl/api/v1/purchases'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'course_id': courseId,
        'section_id': sectionId,
        'amount_uzs': amountUzs,
        'provider': 'telegram',
      }),
    );
  }

  @override
  Future<List<UserEntitlementItem>> fetchUserEntitlements({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) return const [];
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/purchases/user?user_id=$userId'),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final raw = body['items'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(UserEntitlementItem.fromJson)
        .toList(growable: false);
  }
}
