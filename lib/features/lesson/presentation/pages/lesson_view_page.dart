import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/app_state_providers.dart';
import '../../../../core/state/progress_controller.dart';
import '../../../../widgets/video_player_box.dart';

class LessonViewPage extends ConsumerStatefulWidget {
  const LessonViewPage({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LessonViewPage> createState() => _LessonViewPageState();
}

class _LessonViewPageState extends ConsumerState<LessonViewPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _slidesController = PageController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slidesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(courseRepositoryProvider);
    final lesson = repo.getLessonById(widget.lessonId);
    final courseId = repo.getCourseIdForLesson(widget.lessonId);

    if (lesson == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Dars'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Dars topilmadi')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dars tafsiloti'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E6BB8),
              unselectedLabelColor: Colors.black54,
              indicatorColor: const Color(0xFF1E6BB8),
              labelStyle: const TextStyle(fontWeight: FontWeight.w800),
              tabs: const [
                Tab(text: 'Video'),
                Tab(text: 'Slaydshou'),
              ],
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        children: [
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              if (_tabController.index == 0) {
                return VideoPlayerBox(url: lesson.videoUrl);
              }
              return _SlideViewer(
                slides: lesson.slides,
                controller: _slidesController,
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            'Dars matni',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                lesson.transcriptUz,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.35,
                      color: Colors.black87,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E6BB8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () {
                if (courseId != null) {
                  ref.read(selectedCourseIdProvider.notifier).state = courseId;
                  ref
                      .read(progressControllerProvider.notifier)
                      .completeLesson(courseId: courseId, lessonId: widget.lessonId);
                }
                context.push('${AppRoutes.quiz}?id=quiz_1');
              },
              child: const Text(
                'Darsni yakunlash va testga o‘tish',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SlideViewer extends StatefulWidget {
  const _SlideViewer({
    required this.slides,
    required this.controller,
  });

  final List<String> slides;
  final PageController controller;

  @override
  State<_SlideViewer> createState() => _SlideViewerState();
}

class _SlideViewerState extends State<_SlideViewer> {
  int _page = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _SlideViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
      _page = (widget.controller.page ?? 0).round();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final next = (widget.controller.page ?? 0).round();
    if (next == _page) return;
    setState(() => _page = next);
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    final controller = widget.controller;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 200,
            child: PageView.builder(
              controller: controller,
              itemCount: slides.length,
              itemBuilder: (context, index) {
                return Container(
                  color: const Color(0xFF1E6BB8),
                  child: Center(
                    child: Text(
                      'Slayd\nko‘rinishi',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 10),
        SmoothPageIndicator(
          controller: controller,
          count: slides.length,
          effect: WormEffect(
            dotWidth: 8,
            dotHeight: 8,
            activeDotColor: const Color(0xFF1E6BB8),
            dotColor: Colors.black.withValues(alpha: 0.14),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              onPressed: () => controller.previousPage(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
              ),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '${_page + 1} / ${slides.length}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            IconButton(
              onPressed: () => controller.nextPage(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
              ),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

