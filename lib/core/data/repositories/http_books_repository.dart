import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
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
  static const Duration _paidIdsCacheTtl = Duration(minutes: 5);
  static const String _paidIdsDiskKeyPrefix = 'books_paid_ids_v1_';
  bool _entitlementsEndpointUnsupported = false;
  Set<String>? _paidIdsCache;
  String? _paidIdsCacheUserId;
  DateTime? _paidIdsCacheAt;
  Future<Set<String>>? _paidIdsInFlight;

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
  Stream<List<BookItemModel>> watchBooks({Duration pollInterval = const Duration(seconds: 45)}) {
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

  /// `null` — endpoint yo‘q yoki xato; `/access` fallback kerak.
  Future<Set<String>?> _fetchEntitlementBookIds({required String userId}) async {
    if (baseUrl.isEmpty || userId.isEmpty) return const <String>{};
    if (_entitlementsEndpointUnsupported) return null;
    try {
      final uri = Uri.parse('$baseUrl/api/v1/content/books/entitlements').replace(
        queryParameters: {'user_id': userId},
      );
      final response = await _client
          .get(uri)
          .timeout(apiListFetchTimeoutForBaseUrl(baseUrl));
      if (response.statusCode == 405) {
        _entitlementsEndpointUnsupported = true;
        debugPrint('[API][books.entitlements][unsupported] status=405, fallback to /access only');
        return null;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        debugPrint('[API][books.entitlements][response] status=${response.statusCode}');
        return null;
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return const <String>{};
      return _parseEntitlementBookIds(body);
    } catch (e, st) {
      debugPrint('[API][books.entitlements][error] $e\n$st');
      return null;
    }
  }

  @override
  void clearPaidBookIdsCache() {
    _paidIdsCache = null;
    _paidIdsCacheUserId = null;
    _paidIdsCacheAt = null;
    _paidIdsInFlight = null;
  }

  Future<Set<String>?> _loadPaidIdsFromDisk(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_paidIdsDiskKeyPrefix$userId');
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded.map((e) => e.toString()).where((id) => id.isNotEmpty).toSet();
    } catch (_) {
      return null;
    }
  }

  Future<void> _savePaidIdsToDisk(String userId, Set<String> ids) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_paidIdsDiskKeyPrefix$userId',
        jsonEncode(ids.toList(growable: false)),
      );
    } catch (_) {}
  }

  @override
  Future<Set<String>> fetchPaidBookIds({
    required String userId,
    bool forceRefresh = false,
  }) async {
    if (baseUrl.isEmpty || userId.isEmpty) return const <String>{};

    if (!forceRefresh &&
        _paidIdsCacheUserId == userId &&
        _paidIdsCache != null &&
        _paidIdsCacheAt != null &&
        DateTime.now().difference(_paidIdsCacheAt!) <= _paidIdsCacheTtl) {
      return Set<String>.from(_paidIdsCache!);
    }

    if (!forceRefresh && (_paidIdsCache == null || _paidIdsCacheUserId != userId)) {
      final disk = await _loadPaidIdsFromDisk(userId);
      if (disk != null) {
        _paidIdsCache = disk;
        _paidIdsCacheUserId = userId;
        _paidIdsCacheAt = DateTime.now();
      }
    }

    final pending = _paidIdsInFlight;
    if (pending != null && !forceRefresh) {
      return pending;
    }

    final future = _fetchPaidBookIdsNetwork(userId);
    _paidIdsInFlight = future;
    try {
      return await future;
    } catch (e, st) {
      debugPrint('[API][books.paidIds][error] $e\n$st');
      if (_paidIdsCache != null && _paidIdsCacheUserId == userId) {
        return Set<String>.from(_paidIdsCache!);
      }
      final disk = await _loadPaidIdsFromDisk(userId);
      if (disk != null) return disk;
      return const <String>{};
    } finally {
      if (identical(_paidIdsInFlight, future)) {
        _paidIdsInFlight = null;
      }
    }
  }

  Future<Set<String>> _fetchPaidBookIdsNetwork(String userId) async {
    final granted = <String>{};

    final fromEntitlements = await _fetchEntitlementBookIds(userId: userId);
    if (fromEntitlements != null) {
      granted.addAll(fromEntitlements);
      await _commitPaidIdsCache(userId, granted);
      if (granted.isNotEmpty) {
        debugPrint('[API][books.paidIds] entitlements count=${granted.length}');
      }
      return granted;
    }

    final books = await fetchBooks();
    final paidBooks = books.where((b) => b.isPaid).toList(growable: false);
    if (paidBooks.isEmpty) {
      await _commitPaidIdsCache(userId, granted);
      return granted;
    }

    // Eski backend: `/entitlements` 405 — faqat qolgan pullik kitoblar uchun qisqa `/access`.
    final pending = paidBooks.where((b) => !granted.contains(b.id)).toList(growable: false);
    const chunkSize = 2;
    for (var i = 0; i < pending.length; i += chunkSize) {
      final chunk = pending.skip(i).take(chunkSize);
      final checks = await Future.wait(
        chunk.map((book) async {
          final ok = await hasPaidBookAccess(userId: userId, bookId: book.id);
          return ok ? book.id : null;
        }),
      );
      for (final id in checks) {
        if (id != null) granted.add(id);
      }
    }

    await _commitPaidIdsCache(userId, granted);
    if (granted.isNotEmpty) {
      debugPrint('[API][books.paidIds] resolved count=${granted.length}');
    }
    return granted;
  }

  Future<void> _commitPaidIdsCache(String userId, Set<String> granted) async {
    _paidIdsCache = Set<String>.from(granted);
    _paidIdsCacheUserId = userId;
    _paidIdsCacheAt = DateTime.now();
    unawaited(_savePaidIdsToDisk(userId, granted));
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
      final response = await _client
          .get(uri)
          .timeout(bookAccessCheckTimeoutForBaseUrl(baseUrl));
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
