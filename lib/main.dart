import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation_screen.dart';
import 'services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.initialize();

  // Status Bar Stili (iOS ve Android için)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light, // iOS için
    ),
  );

  runApp(const EksperMobileApp());
}

class EksperMobileApp extends StatelessWidget {
  const EksperMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AppThemeProvider()),
      ],
      child: Consumer<AppThemeProvider>(
        builder: (_, themeProvider, __) => MaterialApp(
          title: '2EKSPER Mobil',
          debugShowCheckedModeBanner: false,
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
                  value: Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light.copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: const Color(0xFF0F172A),
                  )
                : SystemUiOverlayStyle.dark.copyWith(
                    statusBarColor: Colors.transparent,
                    systemNavigationBarColor: Colors.white,
                  ),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AppRoot(),
        ),
      ),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  Timer? _minimumSplashTimer;
  bool _minimumSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    _minimumSplashTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => _minimumSplashElapsed = true);
    });
  }

  @override
  void dispose() {
    _minimumSplashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    if (!authProvider.isInitialized || !_minimumSplashElapsed) {
      return const _LoadingScreen();
    }

    if (authProvider.isLoggedIn) {
      return const MainNavigationScreen();
    } else {
      return const LoginScreen();
    }
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0F172A) : const Color(0xFFF0F9FF);
    final accent = const Color(0xFF38BDF8);
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              right: -90,
              top: -100,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: dark ? .15 : .10),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: dark ? .2 : .1),
                      blurRadius: 60,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: -120,
              bottom: -130,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: dark ? .12 : .08),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: dark ? .2 : .1),
                      blurRadius: 60,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
              child: Column(
                children: [
                  const Spacer(flex: 4),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 360),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color:
                              Colors.black.withValues(alpha: dark ? .28 : .08),
                          blurRadius: 34,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/brand_splash_logo.png',
                      width: 310,
                      fit: BoxFit.contain,
                      semanticLabel: '2EKSPER',
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Oto Ekspertiz & Galeri',
                    style: TextStyle(
                      color: dark ? Colors.white : const Color(0xFF253247),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .2,
                    ),
                  ),
                  const Spacer(flex: 3),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: accent,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Güvenli bağlantı kuruluyor…',
                    style: TextStyle(
                      color: dark
                          ? Colors.white.withValues(alpha: .62)
                          : const Color(0xFF737C8A),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '2EKSPER MOBILE',
                    style: TextStyle(
                      color: dark
                          ? Colors.white.withValues(alpha: .28)
                          : const Color(0xFF9DA4AE),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.8,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
