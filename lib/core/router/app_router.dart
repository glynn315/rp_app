import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/tasks/screens/tasks_screen.dart';
import '../../features/tasks/screens/add_task_screen.dart';
import '../../features/requests/screens/requests_screen.dart';
import '../../features/requests/screens/leave_request_screen.dart';
import '../../features/requests/screens/ot_request_screen.dart';
import '../../features/requests/screens/time_log_screen.dart';
import '../../features/performance/screens/performance_screen.dart';
import '../../features/profile/screens/profile_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final isAuthenticated = authState.isAuthenticated;

      if (loc == '/splash') return null;
      if (!isAuthenticated && loc != '/login') return '/login';
      if (isAuthenticated && loc == '/login') return '/home';
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeScreen(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const DashboardScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/tasks',
              builder: (context, state) => const TasksScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/requests',
              builder: (context, state) => const RequestsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/performance',
              builder: (context, state) => const PerformanceScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),
      // Full-screen routes (no bottom nav)
      GoRoute(
        path: '/tasks/add',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) {
          final taskId = state.extra as String?;
          return AddTaskScreen(editTaskId: taskId);
        },
      ),
      GoRoute(
        path: '/requests/leave',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LeaveRequestScreen(),
      ),
      GoRoute(
        path: '/requests/ot',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const OtRequestScreen(),
      ),
      GoRoute(
        path: '/requests/timelog',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const TimeLogScreen(),
      ),
    ],
  );
});
