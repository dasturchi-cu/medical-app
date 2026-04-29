import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../widgets/ranking_item.dart';

class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _loading = true;
  List<_RankingUser> _users = const [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    Future.microtask(_load);
  }

  Future<void> _load() async {
    final currentUserId = ref.read(authControllerProvider).userId ?? "";
    final items = await ref.read(rankingRepositoryProvider).fetchRanking(limit: 50);
    if (!mounted) return;
    setState(() {
      _users = items
          .map(
            (item) => _RankingUser(
              rank: item.rank,
              name: item.fullName,
              studyMinutes: item.quizMinutes.round(),
              me: item.userId == currentUserId,
            ),
          )
          .toList(growable: false);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabTitles = [context.tr('tab_daily'), context.tr('tab_overall')];
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('ranking')),
        actions: [
          IconButton(
            tooltip: context.tr('ranking_info_title'),
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: Text(ctx.tr('ranking_info_title')),
                    content: Text(ctx.tr('ranking_info_body')),
                    actions: [
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text(ctx.tr('btn_understood')),
                      ),
                    ],
                  );
                },
              );
            },
            icon: const Icon(Icons.info_outline),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: tabTitles.map((e) => Tab(text: e)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: List.generate(
          tabTitles.length,
          (i) => _RankingList(
            titleUz: tabTitles[i],
            users: _users,
            loading: _loading,
            onRefresh: _load,
          ),
        ),
      ),
    );
  }
}

class _RankingList extends StatefulWidget {
  const _RankingList({
    required this.titleUz,
    required this.users,
    required this.loading,
    required this.onRefresh,
  });

  final String titleUz;
  final List<_RankingUser> users;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<_RankingList>
    with AutomaticKeepAliveClientMixin<_RankingList> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final users = widget.users;
    if (users.isEmpty) {
      return const Center(child: Text('Reyting maʼlumoti yo‘q'));
    }
    final top10 = users.take(10).toList();
    final me = users.firstWhere((u) => u.me, orElse: () => users.first);
    final inTop10 = top10.any((u) => u.me);

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.s16),
        itemCount: top10.length + (!inTop10 ? 3 : 0),
        itemBuilder: (context, index) {
          final topStart = 0;
          final topEnd = topStart + top10.length;
          if (index >= topStart && index < topEnd) {
            final u = top10[index - topStart];
            final h = u.studyMinutes ~/ 60;
            final m = u.studyMinutes % 60;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s8),
              child: RankingItem(
                rank: u.rank,
                name: u.name,
                timeLabel: context.tr(
                  'time_hm',
                  params: {'h': '$h', 'm': '$m'},
                ),
                isCurrentUser: u.me,
              ),
            );
          }

          if (!inTop10) {
            final local = index - topEnd;
            if (local == 0) {
              return Text(
                context.tr('your_place'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              );
            }
            if (local == 1) return const SizedBox(height: AppSpacing.s8);
            return RankingItem(
              rank: me.rank,
              name: me.name,
              timeLabel: context.tr(
                'time_hm',
                params: {
                  'h': '${me.studyMinutes ~/ 60}',
                  'm': '${me.studyMinutes % 60}',
                },
              ),
              isCurrentUser: true,
              prefixLabel: context.tr('nav_profile'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _RankingUser {
  final int rank;
  final String name;
  final int studyMinutes;
  final bool me;

  const _RankingUser({
    required this.rank,
    required this.name,
    required this.studyMinutes,
    required this.me,
  });
}
