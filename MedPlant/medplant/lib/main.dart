import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'firebase_options.dart';
import 'core/app_router.dart';
import 'providers/navigation_provider.dart';
import 'providers/user_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw edge-to-edge (like WhatsApp): the app paints behind a transparent
  // status bar and system navigation bar, and every screen uses SafeArea /
  // MediaQuery padding so nothing ends up hidden underneath them.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // white icons on green AppBar
    statusBarBrightness: Brightness.dark, // iOS
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  ));

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UserProvider()),
        // Keep the tab list in sync with the logged-in role, outside of
        // any widget build.
        ChangeNotifierProxyProvider<UserProvider, NavigationProvider>(
          create: (_) => NavigationProvider(),
          update: (_, user, nav) =>
              (nav ?? NavigationProvider())..configureRoutes(user.role),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

ThemeData _buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.pageBg,
  );

  return base.copyWith(
    // Same text theme as the original app.
    textTheme: GoogleFonts.latoTextTheme().copyWith(
      titleLarge: GoogleFonts.montserrat(
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
      titleMedium: GoogleFonts.montserrat(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: AppColors.white,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      iconTheme: const IconThemeData(color: Colors.white),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      surfaceTintColor: Colors.transparent,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final isRestoring =
        context.select<UserProvider, bool>((u) => u.isRestoring);

    if (isRestoring) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
        home: const _SplashScreen(),
      );
    }

    return MaterialApp.router(
      title: 'MedPlant',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,
      theme: _buildTheme(),
      builder: (context, child) {
        // Keep text readable but stop very large system font sizes from
        // breaking layouts.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler.clamp(maxScaleFactor: 1.3),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Colors.white,
              child: Icon(Icons.eco, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              'MedPlant',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Thaba-Nchu',
              style: GoogleFonts.lato(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 28),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
