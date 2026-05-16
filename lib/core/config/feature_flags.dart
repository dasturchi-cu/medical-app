/// Compile-time flags for A/B or benchmarking (dart-define).
///
/// Benchmark `/api/v1/home` vs parallel `/slides` + `/banners` + `/mobile/courses`:
/// ```
/// flutter run --dart-define=USE_HOME_AGGREGATE_ENDPOINT=true
/// ```
class HomeAggregateConfig {
  HomeAggregateConfig._();

  static const bool enabled = bool.fromEnvironment(
    'USE_HOME_AGGREGATE_ENDPOINT',
    defaultValue: false,
  );
}
