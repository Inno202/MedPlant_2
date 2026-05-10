import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:medplant/constants/app_colors.dart';
import 'core/app_router.dart';
import 'providers/navigation_provider.dart';
import 'providers/user_provider.dart';

void main() {
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()), // ✅ ADD THIS
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
     final userProvider = Provider.of<UserProvider>(context);
    final navProvider = Provider.of<NavigationProvider>(context);

    // 🔥 Sync role → navigation
    navProvider.configureRoutes(userProvider.role);
    
    return MaterialApp.router(
      title: 'MedPlant',
      debugShowCheckedModeBanner: false,
      routerConfig: AppRouter.router,

      theme: ThemeData(
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
      ),
    );
  }
}