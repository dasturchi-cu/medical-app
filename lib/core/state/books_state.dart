import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/content_asset_models.dart';
import '../di/providers.dart';
import 'auth_controller.dart';

final booksFeedProvider = StreamProvider<List<BookItemModel>>((ref) {
  return ref.read(booksRepositoryProvider).watchBooks();
});

final bookProgressProvider = FutureProvider<List<BookProgressModel>>((ref) async {
  final userId = ref.watch(authControllerProvider.select((s) => s.userId)) ?? '';
  if (userId.isEmpty) return const [];
  return ref.read(booksRepositoryProvider).fetchProgress(userId: userId);
});

final paidBookIdsProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(authControllerProvider.select((s) => s.userId)) ?? '';
  if (userId.isEmpty) {
    return Stream.value(const <String>{});
  }
  final repo = ref.read(booksRepositoryProvider);
  final controller = StreamController<Set<String>>();
  Timer? timer;
  Timer? debounce;
  Future<void>? pushInFlight;
  var disposed = false;
  Set<String> lastEmitted = const {};

  Future<void> pushImpl({required bool force}) async {
    if (disposed) return;
    final ids = await repo.fetchPaidBookIds(userId: userId, forceRefresh: force);
    if (disposed || controller.isClosed) return;
    if (ids.length == lastEmitted.length && ids.containsAll(lastEmitted)) {
      return;
    }
    lastEmitted = Set<String>.from(ids);
    controller.add(lastEmitted);
  }

  Future<void> push({bool force = false}) async {
    if (disposed) return;
    if (pushInFlight != null) {
      await pushInFlight;
      return;
    }
    pushInFlight = pushImpl(force: force);
    try {
      await pushInFlight;
    } finally {
      pushInFlight = null;
    }
  }

  void schedulePush({bool force = false}) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(push(force: force));
    });
  }

  Timer(const Duration(seconds: 2), () => unawaited(push(force: true)));
  timer = Timer.periodic(const Duration(minutes: 2), (_) => schedulePush());

  ref.onDispose(() async {
    disposed = true;
    debounce?.cancel();
    timer?.cancel();
    await controller.close();
  });

  return controller.stream;
});

/// Kitob ruxsati yangilanganda cache tozalash.
void refreshPaidBookIds(WidgetRef ref) {
  ref.read(booksRepositoryProvider).clearPaidBookIdsCache();
  ref.invalidate(paidBookIdsProvider);
}
