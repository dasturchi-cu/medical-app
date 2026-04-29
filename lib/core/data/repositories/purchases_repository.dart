import '../models/purchase_models.dart';

abstract class PurchasesRepository {
  Future<List<UserEntitlementItem>> fetchUserEntitlements({required String userId});
  Future<void> createPurchase({
    required String userId,
    String? courseId,
    String? sectionId,
    double amountUzs = 0,
  });
}
