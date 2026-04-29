import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  void purchaseCourse(String courseId) {
    state = PurchaseState(purchasedCourseIds: {...state.purchasedCourseIds, courseId});
  }

  void purchaseBase(String courseId, String sectionId) {
    purchaseCourse(basePurchaseKey(courseId, sectionId));
  }
}

