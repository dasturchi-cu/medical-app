import '../models/slide_models.dart';

abstract class SlidesRepository {
  Future<List<HomeSlideItem>> fetchSlides({bool forceRefresh = false});
  Stream<List<HomeSlideItem>> watchSlides({
    Duration pollInterval = const Duration(seconds: 8),
  });
}
