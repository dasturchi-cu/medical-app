import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../models/content_asset_models.dart';
import 'lesson_assets_repository.dart';

class HttpLessonAssetsRepository implements LessonAssetsRepository {
  HttpLessonAssetsRepository({
    required this.baseUrl,
    this.client,
    this.realtimeClient,
  });

  final String baseUrl;
  final http.Client? client;
  final SupabaseClient? realtimeClient;

  http.Client get _client => client ?? http.Client();

  @override
  Future<List<LessonAssetModel>> fetchAssets({required String lessonId}) async {
    if (baseUrl.isEmpty || lessonId.isEmpty) return const [];
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/content/assets?lesson_id=$lessonId'));
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final raw = body['items'];
    if (raw is! List) return const [];
    final result = raw.whereType<Map<String, dynamic>>().map(LessonAssetModel.fromJson).toList(growable: false);
    result.sort((a, b) => a.orderNo.compareTo(b.orderNo));
    return result;
  }

  @override
  Stream<List<LessonAssetModel>> watchAssets({
    required String lessonId,
    Duration pollInterval = const Duration(seconds: 10),
  }) {
    if (lessonId.isEmpty) return Stream.value(const []);
    final controller = StreamController<List<LessonAssetModel>>();
    RealtimeChannel? channel;
    Timer? poller;
    var disposed = false;

    Future<void> push() async {
      if (disposed) return;
      controller.add(await fetchAssets(lessonId: lessonId));
    }

    Future<void> boot() async {
      await push();
      final client = realtimeClient;
      if (client != null) {
        channel = client
            .channel('app-lesson-assets-$lessonId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'lesson_assets',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'lesson_id',
                value: lessonId,
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

  @override
  Future<void> upsertProgress({
    required String userId,
    required String assetId,
    required int pageNo,
    required double progressPercent,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty || assetId.isEmpty) return;
    await _client.post(
      Uri.parse('$baseUrl/api/v1/content/assets/$assetId/progress'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'page_no': pageNo,
        'progress_percent': progressPercent,
      }),
    );
  }
}
