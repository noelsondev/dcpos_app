// dcpos_app/lib/main.dart

import 'package:dcpos_app/data_sources/local_platform_data_source.dart';
import 'package:dcpos_app/repositories/platform_repository.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dcpos_app/isar_service.dart';
import 'package:dcpos_app/services/api_service.dart';
import 'package:dcpos_app/providers/app_state_provider.dart';
import 'package:dcpos_app/pages/auth_checker.dart';
import 'package:dcpos_app/data_sources/local_user_data_source.dart';

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

late final LocalPlatformDataSource
    localPlatformDataSource; // ⬅️ RENOMBRADO para claridad
late final LocalUserDataSource localUserDataSource; // ⬅️ NUEVO
late final PlatformRepository platformRepository;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await isarService.db;

  // 1. Inicializar Data Sources
  localPlatformDataSource = LocalPlatformDataSource(isarService);
  localUserDataSource = LocalUserDataSource(isarService); // ⬅️ INICIALIZAR

  // 2. Inicializar ApiService (inyectamos el nuevo DataSource para Login Offline)
  apiService = ApiService(
    isarService,
    localUserDataSource: localUserDataSource, // ⬅️ INYECCIÓN
  );

  // 3. Inicializar el Repositorio inyectando los Data Sources.
  platformRepository = PlatformRepository(
    apiService,
    localPlatformDataSource, // ⬅️ Usar el nombre renombrado
    localUserDataSource, // ⬅️ INYECCIÓN
  );

  // =======================================================
  // 🚨 PASO CRÍTICO: LIMPIEZA TOTAL PARA ELIMINAR DUPLICADOS
  // =======================================================
  print('Iniciando limpieza total de la base de datos local...');
  try {
    await apiService.clearAllLocalData();
    print('✅ Base de datos Isar limpiada con éxito.');
  } catch (e) {
    print('⚠️ Error al limpiar Isar: $e');
  }

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
