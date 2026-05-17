import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase/supabase.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/state/auth_controller.dart';
import '../../../../core/localization/language_provider.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/utils/format_study_duration.dart';
import '../../../../widgets/ranking_item.dart';
import '../../../../core/data/models/ranking_models.dart';
import '../../../../core/data/repositories/ranking_repository.dart';
import '../../../../core/services/supabase_realtime_client.dart';

class _TabLeaderboard {
  const _TabLeaderboard({
    required this.top,
    this.currentUser,
  });

  final List<LeaderboardRowModel> top;
  final LeaderboardRowModel? currentUser;

  static _TabLeaderboard fromRows(List<LeaderboardRowModel> rows) {
    final top = <LeaderboardRowModel>[];
    LeaderboardRowModel? me;
    for (final row in rows) {
      if (row.isCurrentUserRow) {
        me = row;
      } else if (row.isTopRow) {
        top.add(row);
      }
    }
    return _TabLeaderboard(top: top, currentUser: me);
  }

  bool get hasAnyActivity => top.isNotEmpty || currentUser != null;
}

class RankingPage extends ConsumerStatefulWidget {
  const RankingPage({super.key});

  @override
  ConsumerState<RankingPage> createState() => _RankingPageState();
}

class _RankingPageState extends ConsumerState<RankingPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabs;
  ProviderSubscription<dynamic>? _authSub;
  ProviderSubscription<AsyncValue<LocalizationState>>? _locSub;
  bool _isLoggedIn = false;
  List<String> _dailyOverallTitles = const ['Kunlik', 'Umumiy'];
  bool _loading = true;
  bool _pomodoroLoading = true;
  _TabLeaderboard _daily = const _TabLeaderboard(top: []);
  _TabLeaderboard _overall = const _TabLeaderboard(top: []);
  _TabLeaderboard _pomodoro = const _TabLeaderboard(top: []);
  String? _pomodoroError;
  String? _dailyRankingError;
  String? _overallRankingError;
  String? _lastDailyLocalDate;

  RealtimeChannel? _realtimeChannel;
  Timer? _realtimeDebounce;
  bool _realtimeDisposed = false;
  bool _loadInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);
    _isLoggedIn = ref.read(authControllerProvider).isLoggedIn;
    final loc0 = ref.read(localizationProvider).valueOrNull;
    if (loc0 != null) {
      _dailyOverallTitles = _titlesFromLocalization(loc0);
    }
    _authSub = ref.listenManual(authControllerProvider, (prev, next) {
      if (!mounted) return;
      final loggedIn = next?.isLoggedIn == true;
      if (_isLoggedIn == loggedIn) return;
      setState(() => _isLoggedIn = loggedIn);
    });
    _locSub = ref.listenManual<AsyncValue<LocalizationState>>(
      localizationProvider,
      (prev, next) {
        final st = next.valueOrNull;
        if (!mounted || st == null) return;
        final titles = _titlesFromLocalization(st);
        if (_dailyOverallTitles[0] == titles[0] &&
            _dailyOverallTitles[1] == titles[1]) {
          return;
        }
        setState(() => _dailyOverallTitles = titles);
      },
    );
    Future.microtask(() async {
      await _load();
      _subscribeRealtime();
    });
  }

  List<String> _titlesFromLocalization(LocalizationState st) {
    String trKey(String key, String uzFallback) {
      final t = translate(st, key);
      return t == key ? uzFallback : t;
    }

    return [trKey('tab_daily', 'Kunlik'), trKey('tab_overall', 'Umumiy')];
  }

  void _onTabChanged() {
    if (!_tabs.indexIsChanging) return;
    if (_tabs.index == 0) {
      unawaited(_loadDaily(force: true));
    } else if (_tabs.index == 2) {
      unawaited(_loadPomodoroOnly());
    }
  }

  Future<void> _loadPomodoroOnly() async {
    if (!mounted) return;
    setState(() {
      _pomodoroLoading = true;
      _pomodoroError = null;
    });
    final currentUserId = ref.read(authControllerProvider).userId;
    final repo = ref.read(rankingRepositoryProvider);
    try {
      final items = await repo.fetchPomodoroLeaderboard(
        currentUserId: currentUserId,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _pomodoro = _TabLeaderboard.fromRows(items);
        _pomodoroError = items.isEmpty
            ? 'Hali Pomodoro reyting faolligi yo‘q.'
            : null;
      });
    } catch (e, st) {
      debugPrint('[RANKING] fetch pomodoro tab failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _pomodoro = const _TabLeaderboard(top: []);
        _pomodoroError = 'Pomodoro reytingini yuklashda xatolik. Qayta urinib ko‘ring.';
      });
    } finally {
      if (mounted) setState(() => _pomodoroLoading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadDaily(force: true));
    }
  }

  void _scheduleRealtimeRefetch() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(seconds: 4), () {
      if (!mounted || _realtimeDisposed) return;
      unawaited(_load());
    });
  }

  void _subscribeRealtime() {
    final client = getRealtimeSupabaseClient();
    if (client == null) return;
    _realtimeChannel = client
        .channel('ranking-leaderboard')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'video_progress',
          callback: (_) => _scheduleRealtimeRefetch(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'rank_daily_lesson_watch',
          callback: (_) => _scheduleRealtimeRefetch(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pomodoro_sessions',
          callback: (_) => _scheduleRealtimeRefetch(),
        )
        .subscribe();
  }

  String _todayLocalDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadDaily({bool force = false}) async {
    final today = _todayLocalDateKey();
    if (_lastDailyLocalDate != null && _lastDailyLocalDate != today) {
      if (mounted) {
        setState(() => _daily = const _TabLeaderboard(top: []));
      }
    }
    if (!force && _lastDailyLocalDate == today && _daily.hasAnyActivity) {
      return;
    }
    final currentUserId = ref.read(authControllerProvider).userId;
    final repo = ref.read(rankingRepositoryProvider);
    try {
      final items = await repo.fetchVideoLeaderboard(
        scope: RankingScope.daily,
        currentUserId: currentUserId,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _daily = _TabLeaderboard.fromRows(items);
        _dailyRankingError = null;
        _lastDailyLocalDate = today;
      });
    } catch (e, st) {
      debugPrint('[RANKING] fetch daily failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _daily = const _TabLeaderboard(top: []);
        _dailyRankingError =
            'Kunlik reytingni yuklashda xatolik. Internetni tekshiring.';
      });
    }
  }

  Future<void> _load() async {
    if (!mounted || _loadInFlight) return;
    _loadInFlight = true;
    setState(() {
      _loading = true;
      _pomodoroLoading = true;
      _pomodoroError = null;
      _dailyRankingError = null;
      _overallRankingError = null;
    });

    final currentUserId = ref.read(authControllerProvider).userId;
    final repo = ref.read(rankingRepositoryProvider);

    try {
      await _loadDaily(force: true);
      if (!mounted) return;

      try {
        final items = await repo.fetchVideoLeaderboard(
          scope: RankingScope.overall,
          currentUserId: currentUserId,
          limit: 10,
        );
        if (!mounted) return;
        setState(() {
          _overall = _TabLeaderboard.fromRows(items);
          _overallRankingError = null;
        });
      } catch (e, st) {
        debugPrint('[RANKING] fetch overall failed: $e\n$st');
        if (!mounted) return;
        setState(() {
          _overall = const _TabLeaderboard(top: []);
          _overallRankingError =
              'Umumiy reytingni yuklashda xatolik. Internetni tekshiring.';
        });
      }

      try {
        final items = await repo.fetchPomodoroLeaderboard(
          currentUserId: currentUserId,
          limit: 10,
        );
        if (!mounted) return;
        setState(() {
          _pomodoro = _TabLeaderboard.fromRows(items);
          _pomodoroError = items.isEmpty
              ? 'Hali Pomodoro reyting faolligi yo‘q.'
              : null;
        });
      } catch (e, st) {
        debugPrint('[RANKING] fetch pomodoro failed: $e\n$st');
        if (!mounted) return;
        var msg = e.toString();
        if (msg.startsWith('Exception: ')) {
          msg = msg.substring('Exception: '.length).trim();
        }
        setState(() {
          _pomodoro = const _TabLeaderboard(top: []);
          _pomodoroError = msg.isEmpty
              ? 'Pomodoro reytingini yuklashda xatolik. Internetni tekshiring.'
              : msg;
        });
      }
    } finally {
      _loadInFlight = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _pomodoroLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _realtimeDisposed = true;
    _realtimeDebounce?.cancel();
    _authSub?.close();
    _locSub?.close();
    final ch = _realtimeChannel;
    if (ch != null) {
      unawaited(getRealtimeSupabaseClient()?.removeChannel(ch));
    }
    WidgetsBinding.instance.removeObserver(this);
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const pomodoroTabLabel = 'POMODORO';
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
          tabs: [
            Tab(text: _dailyOverallTitles[0]),
            Tab(text: _dailyOverallTitles[1]),
            Tab(
              child: Text(
                pomodoroTabLabel,
                style: (Theme.of(context).textTheme.titleSmall ?? const TextStyle()).copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _RankingList(
            data: _daily,
            loading: _loading,
            rankingError: _dailyRankingError,
            emptyRankingMessage: context.tr('ranking_empty_daily'),
            noActivityMessage: 'Sizda hali reyting faolligi yo‘q',
            isPomodoro: false,
            isLoggedIn: _isLoggedIn,
            onRefresh: _load,
          ),
          _RankingList(
            data: _overall,
            loading: _loading,
            rankingError: _overallRankingError,
            emptyRankingMessage: context.tr('ranking_empty_overall'),
            noActivityMessage: 'Sizda hali reyting faolligi yo‘q',
            isPomodoro: false,
            isLoggedIn: _isLoggedIn,
            onRefresh: _load,
          ),
          _RankingList(
            data: _pomodoro,
            loading: _pomodoroLoading,
            pomodoroError: _pomodoroError,
            emptyRankingMessage: context.tr('pomodoro_leaderboard_empty'),
            noActivityMessage: 'Sizda hali Pomodoro faolligi yo‘q',
            isPomodoro: true,
            isLoggedIn: _isLoggedIn,
            onRefresh: _load,
          ),
        ],
      ),
    );
  }
}

class _RankingList extends StatefulWidget {
  const _RankingList({
    required this.data,
    required this.loading,
    required this.isPomodoro,
    required this.isLoggedIn,
    required this.onRefresh,
    required this.emptyRankingMessage,
    required this.noActivityMessage,
    this.rankingError,
    this.pomodoroError,
  });

  final _TabLeaderboard data;
  final bool loading;
  final bool isPomodoro;
  final bool isLoggedIn;
  final Future<void> Function() onRefresh;
  final String emptyRankingMessage;
  final String noActivityMessage;
  final String? rankingError;
  final String? pomodoroError;

  @override
  State<_RankingList> createState() => _RankingListState();
}

class _RankingListState extends State<_RankingList>
    with AutomaticKeepAliveClientMixin<_RankingList> {
  String _countSubtitle(LeaderboardRowModel row) {
    if (widget.isPomodoro) {
      final n = row.completedCount;
      if (n <= 0) return '';
      return '$n sessiya';
    }
    final n = row.completedCount;
    if (n <= 0) return '';
    return '$n dars';
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.s16),
            FilledButton.icon(
              onPressed: () => unawaited(widget.onRefresh()),
              icon: const Icon(Icons.refresh),
              label: const Text('Qayta urinish'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowTile(LeaderboardRowModel row, {String? prefixLabel}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.s8),
      child: RankingItem(
        rank: row.rank,
        name: row.fullName,
        timeLabel: formatStudyDurationUz(row.totalSeconds),
        subtitle: _countSubtitle(row),
        isCurrentUser: row.isCurrentUser,
        prefixLabel: prefixLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final err = widget.isPomodoro
        ? widget.pomodoroError
        : widget.rankingError;

    if ((err ?? '').isNotEmpty && !widget.data.hasAnyActivity) {
      return _errorView(err!);
    }

    if (!widget.data.hasAnyActivity) {
      if (widget.isLoggedIn) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.s24),
            child: Text(
              widget.noActivityMessage,
              textAlign: TextAlign.center,
            ),
          ),
        );
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s24),
          child: Text(
            widget.emptyRankingMessage,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final top = widget.data.top;
    final meOutside = widget.data.currentUser;
    final showYourPlace = widget.isLoggedIn && meOutside != null;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.s16),
        itemCount: top.length +
            (widget.isPomodoro && top.isNotEmpty ? 1 : 0) +
            (showYourPlace ? 3 : 0) +
            (!widget.isLoggedIn ? 1 : 0),
        itemBuilder: (context, index) {
          var cursor = 0;

          if (widget.isPomodoro && top.isNotEmpty && index == cursor) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s12),
              child: Text(
                context.tr('pomodoro_leaderboard_hint'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.appColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            );
          }
          if (widget.isPomodoro && top.isNotEmpty) {
            cursor += 1;
          }

          final topEnd = cursor + top.length;
          if (index >= cursor && index < topEnd) {
            return _rowTile(top[index - cursor]);
          }
          cursor = topEnd;

          if (!widget.isLoggedIn && index == cursor) {
            return Card(
              margin: const EdgeInsets.only(top: AppSpacing.s12),
              child: ListTile(
                leading: const Icon(Icons.login_outlined),
                title: Text(context.tr('ranking_login_prompt')),
                onTap: () => context.push(AppRoutes.login),
              ),
            );
          }
          if (!widget.isLoggedIn) {
            return const SizedBox.shrink();
          }

          if (showYourPlace) {
            final local = index - cursor;
            if (local == 0) {
              return Text(
                context.tr('your_place'),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: context.appColors.textSecondary,
                    ),
              );
            }
            if (local == 1) return const SizedBox(height: AppSpacing.s8);
            if (local == 2) {
              return _rowTile(meOutside, prefixLabel: context.tr('nav_profile'));
            }
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
