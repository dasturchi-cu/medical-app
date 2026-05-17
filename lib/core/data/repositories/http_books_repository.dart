import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase/supabase.dart';

import '../../http_request_timeouts.dart';
import '../../services/home_feeds_disk_cache.dart';
import '../models/content_asset_models.dart';
import 'books_repository.dart';

class HttpBooksRepository implements BooksRepository {
  HttpBooksRepository({
    required this.baseUrl,
    this.client,
    this.realtimeClient,
  });

  final String baseUrl;
  final http.Client? client;
  final SupabaseClient? realtimeClient;

  http.Client get _client => client ?? http.Client();
  List<BookItemModel> _cached = const [];
  DateTime? _cachedAt;
  Future<List<BookItemModel>>? _inFlight;
  static const Duration _cacheTtl = Duration(minutes: 5);
  bool _entitlementsEndpointUnsupported = false;

  @override
  Future<List<BookItemModel>> fetchBooks({bool forceRefresh = false}) async {
    if (baseUrl.isEmpty) return const [];
    if (_cached.isEmpty) {
      final disk = HomeFeedsDiskCache.books;
      if (disk.isNotEmpty) {
        _cached = disk;
        _cachedAt = DateTime.now();
      }
    }
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedAt != null &&
        now.difference(_cachedAt!) <= _cacheTtl &&
        _cached.isNotEmpty) {
      return _cached;
    }
    final pending = _inFlight;
    if (pending != null) return pending;
    final future = _fetchBooksNetwork();
    _inFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlight, future)) _inFlight = null;
    }
  }

  Future<List<BookItemModel>> _fetchBooksNetwork() async {
    if (baseUrl.isEmpty) return _cached;
    try {
      debugPrint('[API][books.fetch] baseUrl=$baseUrl');
      final uri = Uri.parse('$baseUrl/api/v1/content/books').replace(
        queryParameters: {'_cb': DateTime.now().millisecondsSinceEpoch.toString()},
      );
      final response = await _client
          .get(
            uri,
            headers: const {
              'Cache-Control': 'no-cache',
              'Pragma': 'no-cache',
            },
          )
          .timeout(apiListFetchTimeoutForBaseUrl(baseUrl));
      if (response.statusCode < 200 || response.statusCode >= 300) return const [];
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const [];
      final raw = body['items'];
      if (raw is! List) return const [];
      final rawMaps = raw.whereType<Map<String, dynamic>>().toList(growable: false);
      final items = rawMaps.map(BookItemModel.fromJson).toList(growable: false);
      _cached = items;
      _cachedAt = DateTime.now();
      if (rawMaps.isNotEmpty) {
        unawaited(HomeFeedsDiskCache.saveBooksRaw(rawMaps));
      }
      if (raw.isNotEmpty && raw.first is Map<String, dynamic>) {
        final firstRaw = raw.first as Map<String, dynamic>;
        final firstParsed = items.isNotEmpty ? items.first : null;
        debugPrint(
          '[API][books.fetch] count=${raw.length}; '
          'firstRawPrice=${firstRaw['price_uzs'] ?? firstRaw['price'] ?? firstRaw['narx_uzs']}; '
          'firstParsedPrice=${firstParsed?.priceUzs}; '
          'firstParsedPaid=${firstParsed?.isPaid}',
        );
      } else {
        debugPrint('[API][books.fetch] count=0');
      }
      return items;
    } catch (e, st) {
      debugPrint('[API][books.fetch][error] $e\n$st');
      return _cached;
    }
  }

  @override
  Stream<List<BookItemModel>> watchBooks({Duration pollInterval = const Duration(seconds: 10)}) {
    final controller = StreamController<List<BookItemModel>>();
    RealtimeChannel? channel;
    Timer? poller;
    var disposed = false;

    Future<void> push() async {
      if (disposed) return;
      final items = await fetchBooks();
      if (disposed || controller.isClosed) return;
      controller.add(items);
    }

    Future<void> boot() async {
      await push();
      final client = realtimeClient;
      if (client != null) {
        channel = client
            .channel('app-books-live')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'book_items',
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
  Future<List<BookProgressModel>> fetchProgress({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) return const [];
    final response = await _client.get(Uri.parse('$baseUrl/api/v1/content/books/progress?user_id=$userId'));
    if (response.statusCode < 200 || response.statusCode >= 300) return const [];
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return const [];
    final raw = body['items'];
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(BookProgressModel.fromJson).toList(growable: false);
  }

  Set<String> _parseEntitlementBookIds(Map<String, dynamic> body) {
    final ids = <String>{};
    void addId(dynamic value) {
      final id = value?.toString().trim() ?? '';
      if (id.isNotEmpty) ids.add(id);
    }

    final bookIds = body['book_ids'];
    if (bookIds is List) {
      for (final entry in bookIds) {
        addId(entry);
      }
    }

    final flatIds = body['ids'];
    if (flatIds is List) {
      for (final entry in flatIds) {
        addId(entry);
      }
    }

    final items = body['items'];
    if (items is List) {
      for (final entry in items) {
        if (entry is Map<String, dynamic>) {
          addId(entry['book_id'] ?? entry['id']);
        } else {
          addId(entry);
        }
      }
    }

    return ids;
  }

  Future<Set<String>> _fetchEntitlementBookIds({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) return const <String>{};
    if (_entitlementsEndpointUnsupported) return const <String>{};
    try {
      final uri = Uri.parse('$baseUrl/api/v1/content/books/entitlements').replace(
        queryParameters: {'user_id': userId},
      );
      final response =
          await _client.get(uri).timeout(apiListFetchTimeoutForBaseUrl(baseUrl));
      if (response.statusCode == 405) {
        _entitlementsEndpointUnsupported = true;
        debugPrint('[API][books.entitlements][unsupported] status=405, fallback to /access only');
        return const <String>{};
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[API][books.entitlements][response] status=${response.statusCode}');
        return const <String>{};
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const <String>{};
      return _parseEntitlementBookIds(body);
    } catch (e, st) {
      debugPrint('[API][books.entitlements][error] $e\n$st');
      return const <String>{};
    }
  }

  @override
  Future<Set<String>> fetchPaidBookIds({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) return const <String>{};
    debugPrint('[API][books.paidIds][start] userId=$userId');

    final books = await fetchBooks();
    final paidBooks = books.where((b) => b.isPaid).toList(growable: false);
    if (paidBooks.isEmpty) return const <String>{};

    final granted = <String>{...await _fetchEntitlementBookIds(userId: userId)};

    // Reader `/access` bilan bir xil manba — entitlements bo'sh/noto'g'ri bo'lsa ham qulf ochiladi.
    for (final book in paidBooks) {
      if (granted.contains(book.id)) continue;
      if (await hasPaidBookAccess(userId: userId, bookId: book.id)) {
        granted.add(book.id);
      }
    }

    if (granted.isNotEmpty) {
      debugPrint('[API][books.entitlements][resolved] count=${granted.length}');
    }
    return granted;
  }

  @override
  Future<bool> hasPaidBookAccess({
    required String userId,
    required String bookId,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty || bookId.isEmpty) return false;
    try {
      final uri = Uri.parse('$baseUrl/api/v1/content/books/access').replace(
        queryParameters: {'user_id': userId, 'book_id': bookId},
      );
      debugPrint('[API][books.access][request] bookId=$bookId');
      final response =
          await _client.get(uri).timeout(apiListFetchTimeoutForBaseUrl(baseUrl));
      debugPrint('[API][books.access][response] bookId=$bookId status=${response.statusCode}');
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return false;
      return body['granted'] == true;
    } catch (e, st) {
      debugPrint('[API][books.access][error] $e\n$st');
      return false;
    }
  }

  @override
  Future<void> upsertProgress({
    required String userId,
    required String bookId,
    required int pageNo,
    required double progressPercent,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty || bookId.isEmpty) return;
    await _client.post(
      Uri.parse('$baseUrl/api/v1/content/books/$bookId/progress'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'page_no': pageNo,
        'progress_percent': progressPercent,
      }),
    );
  }
}
