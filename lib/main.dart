// dcpos_app/lib/main.dart

import 'package:dcpos_app/data_sources/local_platform_data_source.dart';
import 'package:dcpos_app/repositories/platform_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dcpos_app/isar_service.dart';
import 'package:dcpos_app/services/api_service.dart';
import 'package:dcpos_app/providers/app_state_provider.dart';
import 'package:dcpos_app/pages/auth_checker.dart';

// -------------------------------------------------------------------
// TEMA
// -------------------------------------------------------------------

final ThemeData dcposTheme = ThemeData(
  colorScheme: ColorScheme(
    brightness: Brightness.light,
    primary: const Color(0xFF005BBB),
    onPrimary: Colors.white,
    secondary: const Color(0xFF00A2E8),
    onSecondary: Colors.white,
    error: Colors.redAccent,
    onError: Colors.white,
    background: const Color(0xFFF5F8FB),
    onBackground: const Color(0xFF1E2A3A),
    surface: Colors.white,
    onSurface: const Color(0xFF1E2A3A),
  ),
  scaffoldBackgroundColor: const Color(0xFFF5F8FB),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF005BBB),
    foregroundColor: Colors.white,
    elevation: 0,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF005BBB),
      foregroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: Color(0xFF1E2A3A)),
    bodyMedium: TextStyle(color: Color(0xFF1E2A3A)),
  ),
);

// -------------------------------------------------------------------
// PUNTO DE ENTRADA (Dependencies)
// -------------------------------------------------------------------

final IsarService isarService = IsarService();
late final ApiService apiService;
// NUEVAS DEPENDENCIAS GLOBALES

late final LocalPlatformDataSource localDataSource;
late final PlatformRepository platformRepository;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await isarService.db;

  // 1. Inicializar ApiService (maneja Dio y el Interceptor de Token)
  apiService = ApiService(isarService);

  // 2. Inicializar Data Sources
  localDataSource = LocalPlatformDataSource(isarService);

  // 3. Inicializar el Repositorio inyectando los Data Sources.
  //    Pasamos 'apiService' para que el Repositorio lo use en lugar de un ApiClient crudo.
  platformRepository = PlatformRepository(apiService, localDataSource);

  runApp(const DCAPOSApp());
}

class DCAPOSApp extends StatelessWidget {
  const DCAPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inyectamos el AppStateProvider, que ahora usará platformRepository.
    return ChangeNotifierProvider(
      create: (context) => AppStateProvider(
        platformRepository: platformRepository,
      ), // ⬅️ Inyección del Repositorio
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'DCAPOS UI',
        theme: dcposTheme,
        home: const AuthChecker(),
      ),
    );
  }
}
