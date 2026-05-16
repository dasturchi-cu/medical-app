import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../http_request_timeouts.dart';
import '../models/ranking_models.dart';
import 'ranking_repository.dart';

class HttpRankingRepository implements RankingRepository {
  HttpRankingRepository({required this.baseUrl, this.client});

  final String baseUrl;
  final http.Client? client;

  http.Client get _client => client ?? http.Client();

  Duration get _timeout => homeAggregateHttpTimeoutForBaseUrl(baseUrl);

  String _errorMessage(String fallback, String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) {
        final detail = parsed['detail']?.toString().trim() ?? '';
        if (detail.isNotEmpty) {
          if (detail == 'Not Found') {
            return 'Serverda reyting API yo‘li topilmadi (404). Backend yangilang.';
          }
          return detail;
        }
      }
    } catch (_) {}
    return fallback;
  }

  dynamic _decodeJsonBody(String body, {required String label}) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      throw Exception('$label: bo‘sh javob.');
    }
    if (trimmed.startsWith('<')) {
      throw Exception(
        '$label: server HTML qaytardi. Backend yangilangan va ishlayotganini tekshiring.',
      );
    }
    try {
      return jsonDecode(trimmed);
    } catch (e) {
      debugPrint(
        '[RANKING] JSON parse failed ($label): $e body=${trimmed.length > 240 ? '${trimmed.substring(0, 240)}…' : trimmed}',
      );
      throw Exception('Reyting javobi JSON emas.');
    }
  }

  List<LeaderboardRowModel> _parseLeaderboardItems(dynamic body) {
    if (body is List) {
      return body
          .whereType<Map<String, dynamic>>()
          .map(_rowFromJson)
          .where((r) => r.totalSeconds > 0 || r.completedCount > 0)
          .toList(growable: false);
    }
    if (body is! Map<String, dynamic>) {
      throw Exception('Reyting javobi JSON emas.');
    }
    final raw = body['items'];
    if (raw == null) {
      return const [];
    }
    if (raw is! List) {
      throw Exception("Reyting ro'yxati topilmadi.");
    }
    return raw
        .whereType<Map<String, dynamic>>()
        .map(_rowFromJson)
        .toList(growable: false);
  }

  LeaderboardRowModel _rowFromJson(Map<String, dynamic> json) {
    if (json.containsKey('total_seconds')) {
      return LeaderboardRowModel.fromJson(json);
    }
    final focusSec = int.tryParse((json['focus_seconds'] ?? '0').toString()) ?? 0;
    final focusMin = int.tryParse((json['focus_minutes'] ?? '0').toString()) ?? 0;
    final totalSeconds = focusSec > 0 ? focusSec : focusMin * 60;
    return LeaderboardRowModel(
      rank: int.tryParse((json['rank'] ?? '0').toString()) ?? 0,
      userId: (json['user_id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'Foydalanuvchi').toString(),
      totalSeconds: totalSeconds,
      completedCount:
          int.tryParse((json['completed_cycles'] ?? json['completed_sessions'] ?? '0').toString()) ?? 0,
      isCurrentUser: json['is_current_user'] == true,
      rowType: (json['row_type'] ?? 'top').toString(),
    );
  }

  @override
  Future<List<LeaderboardRowModel>> fetchVideoLeaderboard({
    required RankingScope scope,
    String? currentUserId,
    int limit = 10,
  }) async {
    if (baseUrl.isEmpty) {
      throw Exception('API manzili topilmadi (ranking).');
    }
    final period = scope == RankingScope.daily ? 'daily' : 'overall';
    final query = <String, String>{
      'limit': '$limit',
      'period': period,
    };
    final uid = (currentUserId ?? '').trim();
    if (uid.isNotEmpty) {
      query['user_id'] = uid;
    }
    final uri = Uri.parse('$baseUrl/api/v1/ranking').replace(queryParameters: query);
    final scopeLabel = scope == RankingScope.daily ? 'daily' : 'overall';
    debugPrint('[RANKING] fetch $scopeLabel start $uri');
    final response = await _client
        .get(uri, headers: const {'Cache-Control': 'no-cache', 'Accept': 'application/json'})
        .timeout(_timeout);
    debugPrint('[RANKING] fetch $scopeLabel status=${response.statusCode}');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _errorMessage("Reytingni olishda xatolik (${response.statusCode}).", response.body),
      );
    }
    final decoded = _decodeJsonBody(response.body, label: scopeLabel);
    final items = _parseLeaderboardItems(decoded);
    debugPrint('[RANKING] fetch $scopeLabel result count=${items.length}');
    return items;
  }

  @override
  Future<List<LeaderboardRowModel>> fetchPomodoroLeaderboard({
    String? currentUserId,
    int limit = 10,
  }) async {
    if (baseUrl.isEmpty) {
      throw Exception('API manzili topilmadi (pomodoro ranking).');
    }
    final query = <String, String>{'limit': '$limit'};
    final uid = (currentUserId ?? '').trim();
    if (uid.isNotEmpty) {
      query['user_id'] = uid;
    }

    // Productionda ko‘pincha faqat /pomodoro/daily mavjud; /pomodoro keyinroq deploy qilinadi.
    final endpoints = [
      Uri.parse('$baseUrl/api/v1/ranking/pomodoro/daily').replace(queryParameters: query),
      Uri.parse('$baseUrl/api/v1/ranking/pomodoro').replace(queryParameters: query),
      Uri.parse('$baseUrl/api/v1/leaderboard/pomodoro/daily').replace(queryParameters: query),
    ];

    for (var i = 0; i < endpoints.length; i++) {
      final uri = endpoints[i];
      try {
        final response = await _client
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(_timeout);
        if (response.statusCode == 404) {
          if (kDebugMode) {
            debugPrint('[RANKING] fetch pomodoro 404 (skip) $uri');
          }
          continue;
        }
        debugPrint('[RANKING] fetch pomodoro ok $uri status=${response.statusCode}');
        if (response.statusCode < 200 || response.statusCode >= 300) {
          continue;
        }
        final decoded = _decodeJsonBody(response.body, label: 'pomodoro');
        return _parseLeaderboardItems(decoded);
      } on TimeoutException {
        debugPrint('[RANKING] fetch pomodoro timeout $uri');
      } catch (e) {
        debugPrint('[RANKING] fetch pomodoro skip $uri: $e');
      }
    }
    return const [];
  }
}
