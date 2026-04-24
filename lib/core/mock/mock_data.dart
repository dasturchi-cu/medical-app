import '../models/course_models.dart';
import '../models/quiz_models.dart';

class MockData {
  static const categories = <Category>[
    Category(id: 'c1', titleUz: 'Barchasi'),
    Category(id: 'c2', titleUz: 'Miya'),
    Category(id: 'c3', titleUz: 'Nevron'),
    Category(id: 'c4', titleUz: 'Xotira'),
    Category(id: 'c5', titleUz: 'Diqqat'),
  ];

  static final courses = <Course>[
    Course(
      id: 'course_1',
      categoryId: 'c3',
      titleUz: 'Nevrobiologiya asoslari',
      authorUz: 'Ramin Isyimva',
      progress: 0.9,
      rating: 4.5,
      isPaid: false,
      descriptionUz:
          'Ushbu kursda miya tuzilishi, neyronlar ishlashi va asosiy nevrofan mavzulari bilan tanishasiz.',
      sections: [
        Section(
          id: 's1',
          titleUz: 'Kirish',
          durationUz: '1 soat 30 daq',
          lessons: [
            Lesson(
              id: 'l1',
              titleUz: 'Miya nima?',
              durationUz: '12:30',
              isLocked: false,
              isCompleted: true,
              transcriptUz:
                  'Miya — asab tizimining markaziy qismi bo‘lib, u fikrlash, xotira va harakatlarni boshqaradi.',
              slides: const ['Miya', 'Neyron', 'Sinaps', 'Plastiklik'],
              videoUrl:
                  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
            ),
            Lesson(
              id: 'l2',
              titleUz: 'Neyronlar va sinapslar',
              durationUz: '10:45',
              isLocked: false,
              isCompleted: false,
              transcriptUz:
                  'Neyronlar o‘zaro sinapslar orqali axborot uzatadi. Ushbu jarayon elektr va kimyoviy signallarga tayangan.',
              slides: const ['Elektr impuls', 'Kimyoviy signal', 'Retseptor', 'Tarmoq'],
              videoUrl:
                  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
            ),
          ],
        ),
        Section(
          id: 's2',
          titleUz: 'Asosiy tushunchalar',
          durationUz: '1 soat 30 daq',
          lessons: [
            Lesson(
              id: 'l3',
              titleUz: 'Plastiklik',
              durationUz: '09:20',
              isLocked: true,
              isCompleted: false,
              transcriptUz:
                  'Plastiklik — miyaning moslashuvchanligi. Tajriba va o‘rganish miyada ulanishlarni o‘zgartiradi.',
              slides: const ['O‘rganish', 'Moslashuv', 'Takror', 'Mustahkamlash'],
              videoUrl:
                  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
            ),
          ],
        ),
      ],
    ),
    Course(
      id: 'course_2',
      categoryId: 'c5',
      titleUz: 'Kognitiv fanlar',
      authorUz: 'Ramer Rantmon',
      progress: 0.5,
      rating: 4.5,
      isPaid: true,
      descriptionUz:
          'Diqqat, xotira va qaror qabul qilish jarayonlarini amaliy misollar bilan o‘rganing.',
      sections: [
        Section(
          id: 's3',
          titleUz: 'Diqqat',
          durationUz: '1 soat 30 daq',
          lessons: [
            Lesson(
              id: 'l4',
              titleUz: 'Fokus va chalg‘ish',
              durationUz: '11:10',
              isLocked: true,
              isCompleted: false,
              transcriptUz:
                  'Diqqat resurslari cheklangan. Chalg‘ituvchi omillarni boshqarish — samaradorlik kaliti.',
              slides: const ['Fokus', 'Chalg‘ish', 'Muqobil', 'Amaliyot'],
              videoUrl:
                  'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
            ),
          ],
        ),
      ],
    ),
  ];

  /// Slider items should open related courses.
  static const bannerCourseIds = <String>[
    'course_1',
    'course_2',
    'course_1',
    'course_2',
    'course_1',
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
          'Nafas olish tezligi'
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

