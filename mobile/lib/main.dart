import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:kitakitar_mobile/firebase_options.dart';
import 'package:kitakitar_mobile/providers/auth_provider.dart';
import 'package:kitakitar_mobile/providers/user_provider.dart';
import 'package:kitakitar_mobile/providers/scan_filters_provider.dart';
import 'package:kitakitar_mobile/screens/auth/login_screen.dart';
import 'package:kitakitar_mobile/screens/auth/register_screen.dart';
import 'package:kitakitar_mobile/screens/auth/forgot_password_screen.dart';
import 'package:kitakitar_mobile/screens/main/main_screen.dart';
import 'package:kitakitar_mobile/screens/scan/scan_result_screen.dart';
import 'package:kitakitar_mobile/screens/scan/scan_history_screen.dart';
import 'package:kitakitar_mobile/models/ai_scan_model.dart';
import 'package:kitakitar_mobile/screens/qr/qr_scanner_screen.dart';

late final AuthProvider _authProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env (including GEMINI_API_KEY)
  await dotenv.load(fileName: '.env');
  
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      print('Firebase already initialized');
    } else {
      print('ERROR: Firebase not configured!');
      print('See README.md for setup instructions');
      print('Error: $e');
    }
  }

  _authProvider = AuthProvider();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authProvider),
        ChangeNotifierProvider(create: (_) => ScanFiltersProvider()),
        ChangeNotifierProxyProvider<AuthProvider, UserProvider>(
          create: (_) => UserProvider(),
          update: (_, authProvider, previous) {
            final up = previous ?? UserProvider();
            if (authProvider.user != null &&
                up.user?.id != authProvider.user!.uid) {
              up.init(authProvider);
            } else if (authProvider.user == null) {
              up.init(authProvider);
            }
            return up;
          },
        ),
      ],
      child: MaterialApp.router(
        title: 'KitaKitar',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
          primaryColor: const Color(0xFF4CAF50),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF4CAF50),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        routerConfig: _router,
      ),
    );
  }
}

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  refreshListenable: _authProvider,
  redirect: (context, state) {
    final isLoggedIn = _authProvider.isAuthenticated;
    final isAuthRoute = state.matchedLocation == '/login' ||
        state.matchedLocation == '/register' ||
        state.matchedLocation == '/forgot-password';

    if (!isLoggedIn && !isAuthRoute) {
      return '/login';
    }
    // Do NOT redirect from /register or /forgot-password
    if (isLoggedIn && state.matchedLocation == '/login') {
      return '/';
    }
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final initialTab = extra?['initialTab'] as int?;
        return MainScreen(initialTab: initialTab);
      },
    ),
    GoRoute(
      path: '/scan-result',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>?;
        final raw = args?['detectedMaterials'];
        final List<DetectedMaterial> materials = raw is List
            ? raw
                .map((e) =>
                    e is DetectedMaterial ? e : DetectedMaterial.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList()
            : [];
        return ScanResultScreen(
          detectedMaterials: materials,
          preparationTip: args?['preparationTip'] as String?,
          imagePath: args?['imagePath'] as String?,
          imageUrl: args?['imageUrl'] as String?,
        );
      },
    ),
    GoRoute(
      path: '/scan-history',
      builder: (context, state) => const ScanHistoryScreen(),
    ),
    GoRoute(
      path: '/qr-scanner',
      builder: (context, state) => const QrScannerScreen(),
    ),
  ],
);

