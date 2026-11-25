import 'package:go_router/go_router.dart';

import '../design/components/cinematic_transition.dart';
import '../screens/capsule_screen.dart';
import '../screens/create_screen.dart';
import '../screens/galaxy_screen.dart';
import '../screens/planet_screen.dart';
import '../screens/reading_screen.dart';
import '../screens/reveal_screen.dart';
import '../screens/universe_screen.dart';

/// Flat routes: exactly one spatial level is on the navigator at a time, so
/// overlays of hidden levels can never receive touches. Android back moves up
/// one level (see ScreenFrame). Also reachable as deep links
/// `memoria://prototype/<path>` (used by the CI screenshot run).
GoRouter buildRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (c, s) => cinematicPage(
        key: s.pageKey,
        child: UniverseScreen(
          fromYear: int.tryParse(s.uri.queryParameters['from'] ?? ''),
        ),
      ),
    ),
    GoRoute(
      path: '/galaxy/:year',
      pageBuilder: (c, s) => cinematicPage(
        key: s.pageKey,
        child: GalaxyScreen(
          year: int.tryParse(s.pathParameters['year']!) ?? 2025,
          initialFocus: s.uri.queryParameters['focus'],
        ),
      ),
    ),
    GoRoute(
      path: '/planet/:id',
      pageBuilder: (c, s) => cinematicPage(
        key: s.pageKey,
        child: PlanetScreen(memoryId: s.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/capsule/:id',
      pageBuilder: (c, s) => cinematicPage(
        key: s.pageKey,
        child: CapsuleScreen(
          memoryId: s.pathParameters['id']!,
          prototypeUnlock: s.uri.queryParameters['prototypeClock'] == 'unlock',
        ),
      ),
    ),
    GoRoute(
      path: '/reveal/:id',
      pageBuilder: (c, s) => cinematicPage(
        key: s.pageKey,
        child: RevealScreen(memoryId: s.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/read/:id',
      pageBuilder: (c, s) => cinematicPage(
        key: s.pageKey,
        child: ReadingScreen(memoryId: s.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/create',
      pageBuilder: (c, s) => cinematicPage(
        key: s.pageKey,
        child: CreateScreen(
          year: int.tryParse(s.uri.queryParameters['year'] ?? ''),
        ),
      ),
    ),
  ],
);
