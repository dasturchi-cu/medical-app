import 'package:flutter/material.dart';

import 'app_palette.dart';

export 'app_palette.dart';

/// @deprecated Use [BuildContext.appColors] — faqat primary brand uchun qoldi.
class AppColors {
  AppColors._();
  static const Color primary = Color(0xFF2563EB);
}

class AppSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
}

class AppRadius {
  static const double card = 16;
  static const double button = 12;
  static const double input = 12;
}

class AppShadows {
  static List<BoxShadow> soft(BuildContext context) => [
        BoxShadow(
          color: context.appColors.shadow,
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}

class AppTextStyles {
  static TextStyle title(BuildContext context) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: context.appColors.textPrimary,
      );

  static TextStyle subtitle(BuildContext context) => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: context.appColors.textPrimary,
      );

  static TextStyle caption(BuildContext context) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: context.appColors.textSecondary,
      );
}
