import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';

class PurchaseState {
  final Set<String> purchasedCourseIds;

  const PurchaseState({required this.purchasedCourseIds});

  bool isPurchased(String courseId) => purchasedCourseIds.contains(courseId);

  bool isBasePurchased(String courseId, String sectionId) =>
      purchasedCourseIds.contains(basePurchaseKey(courseId, sectionId));
}

String basePurchaseKey(String courseId, String sectionId) =>
    '${courseId}_base_$sectionId';

final purchaseControllerProvider =
    NotifierProvider<PurchaseController, PurchaseState>(PurchaseController.new);

class PurchaseController extends Notifier<PurchaseState> {
  @override
  PurchaseState build() => const PurchaseState(purchasedCourseIds: {});

  Future<void> syncFromBackend(String userId) async {
    if (userId.isEmpty) return;
    final items = await ref.read(purchasesRepositoryProvider).fetchUserEntitlements(userId: userId);
    final keys = <String>{};
    for (final item in items) {
      if (item.sectionId != null && item.sectionId!.isNotEmpty && item.courseId != null && item.courseId!.isNotEmpty) {
        keys.add(basePurchaseKey(item.courseId!, item.sectionId!));
      } else if (item.courseId != null && item.courseId!.isNotEmpty) {
        keys.add(item.courseId!);
      }
    }
    state = PurchaseState(purchasedCourseIds: keys);
  }

  void clear() {
    state = const PurchaseState(purchasedCourseIds: {});
  }

  void purchaseCourse(String courseId) {
    state = PurchaseState(purchasedCourseIds: {...state.purchasedCourseIds, courseId});
  }

  void purchaseBase(String courseId, String sectionId) {
    purchaseCourse(basePurchaseKey(courseId, sectionId));
  }
}

