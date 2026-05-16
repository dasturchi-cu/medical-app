import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/feature_flags.dart';

final selectedCategoryIdProvider = StateProvider<String>(
  (ref) => 'cat_nevralogiya',
);

final homeSearchQueryProvider = StateProvider<String>((ref) => '');

/// While false and [HomeAggregateConfig.enabled], slides/banners streams are not subscribed
/// so duplicate slow requests are avoided until `GET /api/v1/home` (or fallback warm) finishes.
final homeFeedReadyProvider = StateProvider<bool>(
  (ref) => !HomeAggregateConfig.enabled,
);
