import '../models/course_models.dart';
import '../models/quiz_models.dart';

class MockData {
  static const categories = <Category>[
    Category(id: 'cat_online', titleUz: 'Onlayn kurs', iconKey: 'online'),
    Category(id: 'cat_books', titleUz: 'Kitoblar', iconKey: 'books'),
  ];

  static const _testVideo =
      'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4';

  static List<Lesson> _makeLessons({
    required String courseId,
    required int count,
    required String titlePrefixUz,
  }) {
    return List.generate(count, (i) {
      final idx = i + 1;
      return Lesson(
        id: '${courseId}_l$idx',
        titleUz: 'Dars $idx — $titlePrefixUz',
        durationUz: idx < 10 ? '0$idx:30' : '$idx:30',
        isLocked: i != 0, // only first is free
        isCompleted: false,
        transcriptUz:
            'Bu test dars matni. $titlePrefixUz mavzusining asosiy tushunchalari shu yerda bo‘ladi.',
        slides: [
          '$titlePrefixUz — 1',
          '$titlePrefixUz — 2',
          '$titlePrefixUz — 3',
          '$titlePrefixUz — 4',
        ],
        videoUrl: _testVideo,
      );
    });
  }

  static List<Section> _singleSection(
    String courseId,
    String titleUz,
    int lessons,
  ) {
    return [
      Section(
        id: '${courseId}_s1',
        titleUz: titleUz,
        durationUz: '${lessons * 10} daq',
        lessons: _makeLessons(
          courseId: courseId,
          count: lessons,
          titlePrefixUz: titleUz,
        ),
      ),
    ];
  }

  static List<Section> _doctorBases(String courseId) {
    return [
      Section(
        id: '${courseId}_b1',
        titleUz: '1-baza',
        durationUz: '320 daq',
        lessons: _makeLessons(
          courseId: '${courseId}_b1',
          count: 32,
          titlePrefixUz: '1-baza',
        ),
      ),
      Section(
        id: '${courseId}_b2',
        titleUz: '2-baza',
        durationUz: '140 daq',
        lessons: _makeLessons(
          courseId: '${courseId}_b2',
          count: 14,
          titlePrefixUz: '2-baza',
        ),
      ),
      Section(
        id: '${courseId}_b3',
        titleUz: '3-baza',
        durationUz: '150 daq',
        lessons: _makeLessons(
          courseId: '${courseId}_b3',
          count: 15,
          titlePrefixUz: '3-baza',
        ),
      ),
    ];
  }

  static final courses = <Course>[
    Course(
      id: 'course_general_bachelor',
      categoryId: 'cat_online',
      titleUz: 'Umumiy Nevrologiya (Bakalavr uchun)',
      authorUz: 'Neuroscience',
      progress: 0.1,
      rating: 4.7,
      isPaid: true,
      descriptionUz:
          'Bakalavr uchun umumiy nevrologiya asoslari. 1-dars bepul.',
      sections: _singleSection(
        'course_general_bachelor',
        'Nevrologiya kirish',
        12,
      ),
    ),
    Course(
      id: 'course_private_bachelor',
      categoryId: 'cat_online',
      titleUz: 'Xususiy Nevrologiya (Bakalavr uchun)',
      authorUz: 'Neuroscience',
      progress: 0.0,
      rating: 4.6,
      isPaid: true,
      descriptionUz: 'Bakalavr uchun xususiy nevrologiya bo‘limlari.',
      sections: _singleSection(
        'course_private_bachelor',
        'Xususiy mavzular',
        10,
      ),
    ),
    Course(
      id: 'course_eeg',
      categoryId: 'cat_online',
      titleUz: 'EEG',
      authorUz: 'Neuroscience',
      progress: 0.0,
      rating: 4.8,
      isPaid: true,
      descriptionUz: 'EEG talqini, ritmlar, artefaktlar va amaliy holatlar.',
      sections: _singleSection('course_eeg', 'EEG asoslari', 25),
    ),
    Course(
      id: 'course_epilepsy',
      categoryId: 'cat_online',
      titleUz: 'Epileptologiya',
      authorUz: 'Neuroscience',
      progress: 0.0,
      rating: 4.5,
      isPaid: true,
      descriptionUz: 'Tutqanoq turlari, diagnostika va davolash yondashuvlari.',
      sections: _singleSection('course_epilepsy', 'Epilepsiya', 7),
    ),
    Course(
      id: 'course_enmg',
      categoryId: 'cat_online',
      titleUz: 'ENMG',
      authorUz: 'Neuroscience',
      progress: 0.0,
      rating: 4.4,
      isPaid: true,
      descriptionUz: 'ENMG tekshiruvlari va periferik nerv shikastlanishlari.',
      sections: _singleSection('course_enmg', 'ENMG amaliyot', 36),
    ),
    Course(
      id: 'course_private_neuro',
      categoryId: 'cat_online',
      titleUz: 'Xususiy nevrologiya (shifokorlar uchun)',
      authorUz: 'Neuroscience',
      progress: 0.0,
      rating: 4.3,
      isPaid: true,
      descriptionUz:
          'Shifokorlar uchun chuqurlashtirilgan xususiy nevrologiya kursi.',
      sections: _doctorBases('course_private_neuro'),
    ),
  ];

  /// Slider items should open related courses.
  static const bannerCourseIds = <String>[
    'course_general_bachelor',
    'course_eeg',
    'course_epilepsy',
    'course_enmg',
    'course_private_neuro',
  ];

  static const homeSlidesUz = <String>[
    'Miya va xotira',
    'Nevron tarmoqlari',
    'Diqqat va fokus',
    'O‘rganish strategiyalari',
    'Amaliy testlar',
  ];

  static const quiz = Quiz(
    id: 'quiz_1',
    titleUz: 'Sinov testi',
    questions: [
      QuizQuestion(
        id: 'q1',
        questionUz: 'Qaysi tuzilma neyronlar orasida signal uzatadi?',
        optionsUz: ['Sinaps', 'Mushak', 'Suyak', 'Qon tomir'],
        correctIndex: 0,
      ),
      QuizQuestion(
        id: 'q2',
        questionUz: 'Plastiklik nima?',
        optionsUz: [
          'Miyaning moslashuvchanligi',
          'Ko‘rish qobiliyati',
          'Uyqu fazasi',
          'Nafas olish tezligi',
        ],
        correctIndex: 0,
      ),
      QuizQuestion(
        id: 'q3',
        questionUz: 'Diqqat resurslari qanday?',
        optionsUz: ['Cheklangan', 'Cheksiz', 'Doimiy', 'O‘zgarmas'],
        correctIndex: 0,
      ),
    ],
  );
}
