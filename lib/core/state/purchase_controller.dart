import 'package:flutter_riverpod/flutter_riverpod.dart';

class PurchaseState {
  final Set<String> purchasedCourseIds;

  const PurchaseState({required this.purchasedCourseIds});

  bool isPurchased(String courseId) => purchasedCourseIds.contains(courseId);
}

final purchaseControllerProvider =
    NotifierProvider<PurchaseController, PurchaseState>(PurchaseController.new);

class PurchaseController extends Notifier<PurchaseState> {
  @override
  PurchaseState build() => const PurchaseState(purchasedCourseIds: {});

  void purchaseCourse(String courseId) {
    state = PurchaseState(purchasedCourseIds: {...state.purchasedCourseIds, courseId});
  }
}

