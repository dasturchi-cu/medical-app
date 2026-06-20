import '../models/ranking_models.dart';

/// Video reyting: `daily` — bugun; `overall` — barcha vaqt. Pomodoro alohida.
enum RankingScope { overall, daily }

abstract class RankingRepository {
  Future<List<LeaderboardRowModel>> fetchVideoLeaderboard({
    required RankingScope scope,
    String? currentUserId,
    int limit = 10,
    bool forceRefresh = false,
  });

  Future<List<LeaderboardRowModel>> fetchPomodoroLeaderboard({
    String? currentUserId,
    int limit = 10,
    bool forceRefresh = false,
  });

  void invalidateVideoRankingCache({RankingScope? scope});

  void invalidatePomodoroRankingCache();
}
