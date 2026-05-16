import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/banner_models.dart';
import '../data/models/content_asset_models.dart';
import '../data/models/slide_models.dart';

/// Bosh sahifa slayd/banner/kitoblar — tarmoqsiz darhol ko‘rinishi uchun disk keshi.
class HomeFeedsDiskCache {
  HomeFeedsDiskCache._();

  static const _slidesKey = 'home_slides_json_v1';
  static const _bannersKey = 'home_banners_json_v1';
  static const _booksKey = 'home_books_json_v1';

  static List<HomeSlideItem> _slides = const [];
  static List<CourseBannerItem> _banners = const [];
  static List<BookItemModel> _books = const [];

  static List<HomeSlideItem> get slides => _slides;
  static List<CourseBannerItem> get banners => _banners;
  static List<BookItemModel> get books => _books;

  static Future<void> preloadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final slidesRaw = prefs.getString(_slidesKey);
      if (slidesRaw != null && slidesRaw.isNotEmpty) {
        final body = jsonDecode(slidesRaw);
        if (body is Map<String, dynamic>) {
          final items = body['items'];
          if (items is List && items.isNotEmpty) {
            _slides = items
                .whereType<Map<String, dynamic>>()
                .map(HomeSlideItem.fromJson)
                .toList(growable: false);
          }
        }
      }
      final bannersRaw = prefs.getString(_bannersKey);
      if (bannersRaw != null && bannersRaw.isNotEmpty) {
        final body = jsonDecode(bannersRaw);
        if (body is Map<String, dynamic>) {
          final items = body['items'];
          if (items is List && items.isNotEmpty) {
            _banners = items
                .whereType<Map<String, dynamic>>()
                .map(CourseBannerItem.fromJson)
                .toList(growable: false);
          }
        }
      }
      final booksRaw = prefs.getString(_booksKey);
      if (booksRaw != null && booksRaw.isNotEmpty) {
        final body = jsonDecode(booksRaw);
        if (body is Map<String, dynamic>) {
          final items = body['items'];
          if (items is List && items.isNotEmpty) {
            _books = items
                .whereType<Map<String, dynamic>>()
                .map(BookItemModel.fromJson)
                .toList(growable: false);
          }
        }
      }
      debugPrint(
        '[HomeFeedsDiskCache] slides=${_slides.length} banners=${_banners.length} books=${_books.length}',
      );
    } catch (e, st) {
      debugPrint('[HomeFeedsDiskCache.preload][error] $e\n$st');
    }
  }

  static Future<void> saveSlides(List<HomeSlideItem> items) async {
    _slides = List<HomeSlideItem>.from(items);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _slidesKey,
        jsonEncode({
          'items': items
              .map(
                (e) => {
                  'id': e.id,
                  'title': e.title,
                  'subtitle': e.subtitle,
                  'button_text': e.buttonText,
                  'image_url': e.imageUrl,
                  'course_id': e.courseId,
                  'order_no': e.orderNo,
                },
              )
              .toList(growable: false),
        }),
      );
    } catch (e, st) {
      debugPrint('[HomeFeedsDiskCache.saveSlides][error] $e\n$st');
    }
  }

  static Future<void> saveBanners(List<CourseBannerItem> items) async {
    _banners = List<CourseBannerItem>.from(items);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _bannersKey,
        jsonEncode({
          'items': items
              .map(
                (e) => {
                  'id': e.id,
                  'title': e.title,
                  'message': e.message,
                  'image_url': e.imageUrl,
                  'price_label': e.priceLabel,
                  'course_id': e.courseId,
                  'telegram': e.telegram,
                  'sort_order': e.sortOrder,
                  'is_active': e.isActive,
                },
              )
              .toList(growable: false),
        }),
      );
    } catch (e, st) {
      debugPrint('[HomeFeedsDiskCache.saveBanners][error] $e\n$st');
    }
  }

  static Future<void> saveBooksRaw(List<Map<String, dynamic>> rawItems) async {
    _books = rawItems.map(BookItemModel.fromJson).toList(growable: false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _booksKey,
        jsonEncode({'items': rawItems}),
      );
    } catch (e, st) {
      debugPrint('[HomeFeedsDiskCache.saveBooks][error] $e\n$st');
    }
  }
}
