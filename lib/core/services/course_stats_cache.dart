import '../state/course_stats_state.dart';
import 'memory_ttl_cache.dart';
import 'my_rating_local_store.dart';

/// Kurs/banner statistikasi — barcha sahifalar bir xil keshdan o'qiydi.
class CourseStatsCache {
  CourseStatsCache._();

  static final MemoryTtlCache<CourseCardStats> _stats = MemoryTtlCache<CourseCardStats>(
    ttl: const Duration(minutes: 3),
  );
  static final MemoryTtlCache<int> _myRatings = MemoryTtlCache<int>(
    ttl: const Duration(minutes: 3),
  );
  static final MemoryTtlCache<Map<String, CourseCardStats>> _homeBatch = MemoryTtlCache<Map<String, CourseCardStats>>(
    ttl: const Duration(minutes: 3),
  );

  static String _statsKey({
    required String key,
    required String userId,
    required bool useFeedbackApi,
  }) =>
      '${useFeedbackApi ? 'fb' : 'course'}|$key|${userId.trim()}';

  static String homeBatchKey(String catalogIdentity, String userId) =>
      'home|$catalogIdentity|${userId.trim()}';

  static CourseCardStats? peekStats({
    required String key,
    required String userId,
    bool useFeedbackApi = false,
  }) =>
      _stats.peek(_statsKey(key: key, userId: userId, useFeedbackApi: useFeedbackApi));

  static void putStats({
    required String key,
    required String userId,
    required CourseCardStats stats,
    bool useFeedbackApi = false,
  }) {
    _stats.put(_statsKey(key: key, userId: userId, useFeedbackApi: useFeedbackApi), stats);
  }

  static int? peekMyRating({
    required String key,
    required String userId,
    bool useFeedbackApi = false,
  }) =>
      _myRatings.peek(_statsKey(key: key, userId: userId, useFeedbackApi: useFeedbackApi));

  static void putMyRating({
    required String key,
    required String userId,
    required int myRating,
    bool useFeedbackApi = false,
  }) {
    _myRatings.put(_statsKey(key: key, userId: userId, useFeedbackApi: useFeedbackApi), myRating);
    if (myRating >= 1 && myRating <= 5) {
      MyRatingLocalStore.write(
        courseKey: key,
        userId: userId,
        stars: myRating,
        useFeedbackApi: useFeedbackApi,
      );
    }
  }

  static Future<int?> readPersistedMyRating({
    required String key,
    required String userId,
    bool useFeedbackApi = false,
  }) =>
      MyRatingLocalStore.read(
        courseKey: key,
        userId: userId,
        useFeedbackApi: useFeedbackApi,
      );

  static Future<CourseCardStats> statsOrFetch({
    required String key,
    required String userId,
    required bool useFeedbackApi,
    required Future<CourseCardStats> Function() fetch,
    bool forceRefresh = false,
  }) {
    return _stats.getOrFetch(
      _statsKey(key: key, userId: userId, useFeedbackApi: useFeedbackApi),
      fetch,
      forceRefresh: forceRefresh,
    );
  }

  static Map<String, CourseCardStats>? peekHomeBatch(String catalogIdentity, String userId) =>
      _homeBatch.peek(homeBatchKey(catalogIdentity, userId));

  static void putHomeBatch(String catalogIdentity, String userId, Map<String, CourseCardStats> map) {
    _homeBatch.put(homeBatchKey(catalogIdentity, userId), map);
  }

  static Future<Map<String, CourseCardStats>> homeBatchOrFetch({
    required String catalogIdentity,
    required String userId,
    required Future<Map<String, CourseCardStats>> Function() fetch,
    bool forceRefresh = false,
  }) {
    return _homeBatch.getOrFetch(
      homeBatchKey(catalogIdentity, userId),
      fetch,
      forceRefresh: forceRefresh,
    );
  }

  static void invalidateKey(String key) {
    _stats.invalidatePrefix('course|$key|');
    _stats.invalidatePrefix('fb|$key|');
    _myRatings.invalidatePrefix('course|$key|');
    _myRatings.invalidatePrefix('fb|$key|');
    _homeBatch.clear();
  }
}
