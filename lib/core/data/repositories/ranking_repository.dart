import '../models/ranking_models.dart';

abstract class RankingRepository {
  Future<List<RankingItemModel>> fetchRanking({int limit = 50});
}
