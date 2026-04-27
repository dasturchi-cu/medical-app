import 'package:flutter/material.dart';

import '../../../../core/localization/language_provider.dart';
import '../../../../widgets/ranking_item.dart';

class RankingPage extends StatefulWidget {
  const RankingPage({super.key});

  @override
  State<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends State<RankingPage> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
 late final List<List<_RankingUser>> _datasets;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _datasets = List.generate(2, _buildUsersForTab);
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
            users: _datasets[i],
          ),
        ),
      ),
    );
  }

  List<_RankingUser> _buildUsersForTab(int seed) {
    return List.generate(20, (i) {
      final mins = (60 * (30 - i)) - (seed * 7);
      return _RankingUser(
        rank: i + 1,
        name: i == 12 ? 'Azizbek User' : 'Foydalanuvchi ${i + 1}',
        studyMinutes: mins,
        me: i == 12,
      );
    });
  }
}

class _RankingList extends StatefulWidget {
  const _RankingList({
    required this.titleUz,
    required this.users,
  });

  final String titleUz;
  final List<_RankingUser> users;

  @override
  State<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<_RankingList>
    with AutomaticKeepAliveClientMixin<_RankingList> {
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final users = widget.users;
    final top10 = users.take(10).toList();
    final me = users.firstWhere((u) => u.me);
    final inTop10 = top10.any((u) => u.me);

    return RefreshIndicator(
      onRefresh: () async {
        // UI-only mode: lightweight feedback refresh
        await Future<void>.delayed(const Duration(milliseconds: 350));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: top10.length + (!inTop10 ? 3 : 0),
        itemBuilder: (context, index) {
          final topStart = 0;
          final topEnd = topStart + top10.length;
          if (index >= topStart && index < topEnd) {
            final u = top10[index - topStart];
            final h = u.studyMinutes ~/ 60;
            final m = u.studyMinutes % 60;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
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
                      color: Colors.black54,
                    ),
              );
            }
            if (local == 1) return const SizedBox(height: 8);
            return RankingItem(
              rank: me.rank,
              name: me.name,
              timeLabel: context.tr(
                'time_hm',
                params: {'h': '${me.studyMinutes ~/ 60}', 'm': '${me.studyMinutes % 60}'},
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

