import '../utils/course_title.dart';

class Category {
  final String id;
  final String titleUz;
  final String iconKey;

  const Category({
    required this.id,
    required this.titleUz,
    required this.iconKey,
  });
}

class Course {
  final String id;
  final String categoryId;
  final String titleUz;
  final String titleRu;
  final String titleEn;
  final String authorUz;
  final String imageUrl;
  final String priceUz;
  final double progress; // 0..1
  final double rating; // 0..5
  final int commentsCount;
  final int lessonCount;
  final bool isPaid;
  final String descriptionUz;
  final String descriptionRu;
  final String descriptionEn;
  final List<Section> sections;

  const Course({
    required this.id,
    required this.categoryId,
    required this.titleUz,
    this.titleRu = '',
    this.titleEn = '',
    required this.authorUz,
    required this.imageUrl,
    required this.priceUz,
    required this.progress,
    required this.rating,
    this.commentsCount = 0,
    this.lessonCount = 0,
    required this.isPaid,
    required this.descriptionUz,
    this.descriptionRu = '',
    this.descriptionEn = '',
    required this.sections,
  });

  String localizedTitle(String langCode) {
    return pickLocalizedText(
      uz: titleUz,
      ru: titleRu,
      en: titleEn,
      langCode: langCode,
    );
  }

  String localizedDescription(String langCode) {
    return pickLocalizedText(
      uz: descriptionUz,
      ru: descriptionRu,
      en: descriptionEn,
      langCode: langCode,
    );
  }
}

class Section {
  final String id;
  final String titleUz;
  final String durationUz;
  final List<Lesson> lessons;

  const Section({
    required this.id,
    required this.titleUz,
    required this.durationUz,
    required this.lessons,
  });
}

class Lesson {
  final String id;
  final String titleUz;
  final String durationUz;
  final bool isLocked;
  final bool isCompleted;
  final String transcriptUz;
  final List<String> slides;
  final String videoUrl;

  const Lesson({
    required this.id,
    required this.titleUz,
    required this.durationUz,
    required this.isLocked,
    required this.isCompleted,
    required this.transcriptUz,
    required this.slides,
    required this.videoUrl,
  });
}

