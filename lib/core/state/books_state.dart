import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/content_asset_models.dart';
import '../di/providers.dart';
import 'auth_controller.dart';

final booksFeedProvider = StreamProvider<List<BookItemModel>>((ref) {
  return ref.read(booksRepositoryProvider).watchBooks();
});

final bookProgressProvider = FutureProvider<List<BookProgressModel>>((ref) async {
  final auth = ref.watch(authControllerProvider);
  final userId = auth.userId ?? '';
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
  var disposed = false;

  Future<void> push() async {
    if (disposed) return;
    final ids = await repo.fetchPaidBookIds(userId: userId);
    if (!disposed) controller.add(ids);
  }

  unawaited(push());
  timer = Timer.periodic(const Duration(seconds: 8), (_) => unawaited(push()));

  ref.onDispose(() async {
    disposed = true;
    timer?.cancel();
    await controller.close();
  });

  return controller.stream;
});
