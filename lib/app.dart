import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'features/diary/presentation/add_food_page.dart';
import 'features/diary/presentation/dashboard_page.dart';
import 'features/profile/presentation/onboarding_page.dart';
import 'features/profile/presentation/profile_page.dart';
import 'features/settings/presentation/settings_page.dart';

class MyDietApp extends ConsumerWidget {
  const MyDietApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 啟動流程（匯入種子食物、判斷是否需要 Onboarding）只需要觸發一次。
    ref.watch(appStartupProvider);

    return MaterialApp.router(
      title: 'MyDieT',
      localizationsDelegates: AppTheme.localizationsDelegates,
      supportedLocales: AppTheme.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final onboarding = ref.watch(onboardingStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: onboarding,
    redirect: (context, state) {
      final done = onboarding.value;
      final loc = state.matchedLocation;

      // 還在判斷中
      if (done == null) return loc == '/loading' ? null : '/loading';
      // 還沒設定過 Profile
      if (!done) return loc == '/onboarding' ? null : '/onboarding';
      // 已完成，不該再停在啟動用的頁面
      if (loc == '/onboarding' || loc == '/loading') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/loading', builder: (_, _) => const _LoadingPage()),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingPage()),
      GoRoute(path: '/diary/add', builder: (_, _) => const AddFoodPage()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/', builder: (_, _) => const DashboardPage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/profile', builder: (_, _) => const ProfilePage()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: '今日'),
          NavigationDestination(icon: Icon(Icons.person), label: '我的'),
          NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}
