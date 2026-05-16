import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import '../data/models/purchase_models.dart';
import '../di/providers.dart';

class PurchaseState {
  final Set<String> purchasedCourseIds;

  const PurchaseState({required this.purchasedCourseIds});

  String _normalizeKey(String value) => value.trim().toLowerCase();

  bool isPurchased(String courseId) => purchasedCourseIds.contains(_normalizeKey(courseId));

  bool isBasePurchased(String courseId, String sectionId) => purchasedCourseIds.contains(
    _normalizeKey(basePurchaseKey(courseId, sectionId)),
  );
}

String basePurchaseKey(String courseId, String sectionId) =>
    '${courseId}_base_$sectionId';

final purchaseControllerProvider =
    NotifierProvider<PurchaseController, PurchaseState>(PurchaseController.new);

class PurchaseController extends Notifier<PurchaseState> {
  StreamSubscription<List<UserEntitlementItem>>? _subscription;
  Future<void>? _syncInFlight;
  String? _syncUserId;
  DateTime? _lastSyncAt;

  @override
  PurchaseState build() {
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return const PurchaseState(purchasedCourseIds: {});
  }

  void bindRealtime(String userId) {
    if (userId.isEmpty) return;
    _subscription?.cancel();
    _subscription = ref
        .read(purchasesRepositoryProvider)
        .watchUserEntitlements(userId: userId)
        .listen((items) => _applyEntitlements(items));
  }

  Future<void> syncFromBackend(String userId, {bool force = false}) async {
    if (userId.isEmpty) return;

    if (!force &&
        _lastSyncAt != null &&
        _syncUserId == userId &&
        DateTime.now().difference(_lastSyncAt!) < const Duration(seconds: 20)) {
      return;
    }

    if (_syncInFlight != null && _syncUserId == userId) {
      return _syncInFlight;
    }

    _syncUserId = userId;
    _syncInFlight = _syncFromBackendImpl(userId, force: force);
    try {
      await _syncInFlight;
    } finally {
      _syncInFlight = null;
    }
  }

  Future<void> _syncFromBackendImpl(String userId, {required bool force}) async {
    try {
      final items = await ref
          .read(purchasesRepositoryProvider)
          .fetchUserEntitlements(userId: userId, force: force);
      _applyEntitlements(items);
      _lastSyncAt = DateTime.now();
    } catch (error, stack) {
      debugPrint('[API][purchases.sync][error] $error');
      if (kDebugMode) {
        debugPrint('$stack');
      }
    }
  }

  void clear() {
    _subscription?.cancel();
    _subscription = null;
    _syncInFlight = null;
    _syncUserId = null;
    _lastSyncAt = null;
    state = const PurchaseState(purchasedCourseIds: {});
  }

  void purchaseCourse(String courseId) {
    state = PurchaseState(
      purchasedCourseIds: {...state.purchasedCourseIds, courseId.trim().toLowerCase()},
    );
  }

  void purchaseBase(String courseId, String sectionId) {
    purchaseCourse(basePurchaseKey(courseId, sectionId));
  }

  void _applyEntitlements(List<UserEntitlementItem> items) {
    final keys = <String>{};
    for (final item in items) {
      if (!item.isActive) continue;
      if (item.sectionId != null &&
          item.sectionId!.isNotEmpty &&
          item.courseId != null &&
          item.courseId!.isNotEmpty) {
        keys.add(basePurchaseKey(item.courseId!, item.sectionId!).trim().toLowerCase());
      } else if (item.courseId != null && item.courseId!.isNotEmpty) {
        keys.add(item.courseId!.trim().toLowerCase());
      }
    }
    state = PurchaseState(purchasedCourseIds: keys);
  }
}

