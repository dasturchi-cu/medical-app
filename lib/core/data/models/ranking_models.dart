class LeaderboardRowModel {
  const LeaderboardRowModel({
    required this.rank,
    required this.userId,
    required this.fullName,
    required this.totalSeconds,
    required this.completedCount,
    required this.isCurrentUser,
    required this.rowType,
  });

  final int rank;
  final String userId;
  final String fullName;
  final int totalSeconds;
  final int completedCount;
  final bool isCurrentUser;
  /// `top` | `current_user`
  final String rowType;

  bool get isTopRow => rowType == 'top';
  bool get isCurrentUserRow => rowType == 'current_user';

  factory LeaderboardRowModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardRowModel(
      rank: int.tryParse((json['rank'] ?? '0').toString()) ?? 0,
      userId: (json['user_id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'Foydalanuvchi').toString(),
      totalSeconds: int.tryParse((json['total_seconds'] ?? '0').toString()) ?? 0,
      completedCount: int.tryParse(
            (json['completed_lessons'] ?? json['completed_sessions'] ?? '0').toString(),
          ) ??
          0,
      isCurrentUser: json['is_current_user'] == true,
      rowType: (json['row_type'] ?? 'top').toString(),
    );
  }
}

/// Legacy — eski `/ranking/legacy` javobi.
class RankingItemModel {
  const RankingItemModel({
    required this.userId,
    required this.fullName,
    required this.totalScore,
    required this.quizMinutes,
    required this.rank,
    this.watchedSeconds,
  });

  final String userId;
  final String fullName;
  final double totalScore;
  final double quizMinutes;
  final int rank;
  final int? watchedSeconds;

  int get studySeconds {
    final fromApi = watchedSeconds;
    if (fromApi != null && fromApi > 0) return fromApi;
    final fromMinutes = (quizMinutes * 60).round();
    if (fromMinutes > 0) return fromMinutes;
    return totalScore.round();
  }

  factory RankingItemModel.fromJson(Map<String, dynamic> json) {
    final watchedRaw = json['watched_seconds'];
    final watchedParsed =
        watchedRaw == null ? null : int.tryParse(watchedRaw.toString());
    return RankingItemModel(
      userId: (json['user_id'] ?? '').toString(),
      fullName: (json['full_name'] ?? 'Foydalanuvchi').toString(),
      totalScore: double.tryParse((json['total_score'] ?? '0').toString()) ?? 0,
      quizMinutes: double.tryParse((json['quiz_minutes'] ?? '0').toString()) ?? 0,
      rank: int.tryParse((json['rank'] ?? '0').toString()) ?? 0,
      watchedSeconds: watchedParsed,
    );
  }
}
