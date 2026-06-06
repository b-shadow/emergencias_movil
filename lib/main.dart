import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'screens/login_screen.dart';
import 'screens/register_cliente_screen.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'firebase_options.dart';
import 'theme/theme_controller.dart';
import 'services/dispositivo_push_service_stub.dart'
    if (dart.library.io) 'services/dispositivo_push_service.dart';
import 'services/push_setup_stub.dart'
    if (dart.library.io) 'services/push_setup_mobile.dart';
import 'services/tracking_service.dart';
import 'services/solicitud_service.dart';
import 'services/notificacion_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 2. Registrar background message handler (solo plataformas moviles)
  await configurePushBackgroundHandler();

  const stripePk = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');
  // flutter_stripe en web puede invocar dart:io internamente en ciertos flujos.
  // Evitamos inicialización global en web para no romper el arranque.
  if (!kIsWeb && stripePk.isNotEmpty) {
    Stripe.publishableKey = stripePk;
    await Stripe.instance.applySettings();
  }
  
  debugPrint('[MAIN] Aplicación inicializada');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const appFontFamily = 'Arial';
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'App de Emergencias',
          routes: {
            '/login': (_) => const LoginScreen(),
            '/dashboard': (_) => const DashboardScreen(),
            '/register-cliente': (_) => const RegisterClienteScreen(),
          },
          themeMode: mode,
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
            fontFamily: appFontFamily,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.redAccent,
              brightness: Brightness.dark,
            ),
            fontFamily: appFontFamily,
            useMaterial3: true,
          ),
          home: const _SessionValidator(),
        );
      },
    );
  }
}

/// Widget que valida sesión al iniciar y registra token si existe
class _SessionValidator extends StatefulWidget {
  const _SessionValidator();

  @override
  State<_SessionValidator> createState() => _SessionValidatorState();
}

class _SessionValidatorState extends State<_SessionValidator> {
  late Future<void> _validationFuture;

  @override
  void initState() {
    super.initState();
    _validationFuture = _validateAndInitPush();
  }

  Future<void> _validateAndInitPush() async {
    try {
      final authService = AuthService();
      
      debugPrint('[SESSION] Validando sesión persistida...');
      
      // Revisar si hay token guardado
      final token = await authService.getStoredToken();
      
      if (token == null || token.isEmpty) {
        debugPrint('[SESSION] No hay sesión persistida');
        return;
      }
      
      debugPrint('[SESSION] Token encontrado, validando...');
      
      // Validar que el token sea válido
      final isValid = await authService.validateToken();
      if (!isValid) {
        debugPrint('[SESSION] Token inválido, limpiando sesión');
        await authService.clearSession();
        return;
      }
      
      debugPrint('[SESSION] Sesión válida, inicializando push...');
      final pushService = DispositivoPushService();
      // Usar método centralizado que evita listeners duplicados
      await pushService.initForAuthenticatedUser();
      await TrackingService().syncPendingOperations();
      await SolicitudService().syncPendingOperations();
      await NotificacionService().syncPendingOperations();
      
      debugPrint('[SESSION] Push inicializado correctamente');
    } catch (e) {
      debugPrint('[SESSION] Error validando sesión: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _validationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Mientras valida la sesión, mostrar splash screen
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text('Inicializando...'),
                ],
              ),
            ),
          );
        }

        // Después de validar, mostrar el screen correspondiente
        final authService = AuthService();
        return FutureBuilder<String?>(
          future: authService.getStoredToken(),
          builder: (context, tokenSnapshot) {
            if (tokenSnapshot.hasData && tokenSnapshot.data != null) {
              // Hay sesión válida, ir a dashboard
              debugPrint('[SESSION] Navigating to dashboard');
              return const DashboardScreen();
            } else {
              // No hay sesión, ir a login
              debugPrint('[SESSION] Navigating to login');
              return const LoginScreen();
            }
          },
        );
      },
    );
  }
}






