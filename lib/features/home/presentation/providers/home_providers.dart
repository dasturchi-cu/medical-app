import 'package:flutter_riverpod/flutter_riverpod.dart';

final selectedCategoryIdProvider = StateProvider<String>((ref) => 'cat_online');

final homeSearchQueryProvider = StateProvider<String>((ref) => '');

