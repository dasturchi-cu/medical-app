import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../widgets/option_button.dart';
import '../providers/quiz_controller.dart';

class QuizPage extends ConsumerWidget {
  const QuizPage({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(quizControllerProvider(quizId));
    final controller = ref.read(quizControllerProvider(quizId).notifier);

    if (state == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Test'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(child: Text('Test topilmadi')),
      );
    }

    final q = state.current;
    final selected = state.selectedForCurrent();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test sahifasi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Savol ${state.index + 1} / ${state.total}',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Colors.black54,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  q.questionUz,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.builder(
                itemCount: 4,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 2.6,
                ),
                itemBuilder: (context, i) {
                  final label = String.fromCharCode('A'.codeUnitAt(0) + i);
                  return OptionButton(
                    label: label,
                    selected: selected == i,
                    onTap: () => controller.pick(i),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6BB8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  final isLast = state.index == state.total - 1;
                  if (!isLast) {
                    controller.next();
                    return;
                  }
                  final score = state.computeScore();
                  context.push('${AppRoutes.result}?score=$score&total=100');
                },
                child: const Text(
                  'Javobni yuborish',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

