import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/localization/language_provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/catalog_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.bootstrap();
  await CatalogService.bootstrap();
  runApp(const ProviderScope(child: NeuroscienceApp()));
}

class NeuroscienceApp extends ConsumerWidget {
  const NeuroscienceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locAsync = ref.watch(localizationProvider);

    return locAsync.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: Text(e.toString()))),
      ),
      data: (st) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: translate(st, 'app_name'),
          theme: AppTheme.light(),
          routerConfig: router,
          locale: Locale(st.langCode),
          supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return TrScope(state: st, child: child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}
