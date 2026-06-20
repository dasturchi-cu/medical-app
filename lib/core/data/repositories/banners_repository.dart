import '../models/banner_models.dart';

abstract class BannersRepository {
  Future<List<CourseBannerItem>> fetchBanners({bool forceRefresh = false});
  Stream<List<CourseBannerItem>> watchBanners({
    Duration pollInterval = const Duration(seconds: 120),
  });
}
