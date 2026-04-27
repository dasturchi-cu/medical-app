import 'package:flutter/material.dart';

IconData iconForCategoryKey(String key) {
  switch (key) {
    case 'brain':
      return Icons.psychology;
    case 'wave':
      return Icons.show_chart;
    case 'medical':
      return Icons.medical_services_outlined;
    case 'bolt':
      return Icons.bolt;
    case 'book':
      return Icons.menu_book;
    case 'all':
    default:
      return Icons.grid_view_rounded;
  }
}

