import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'screens/login_screen.dart';
import 'services/dispositivo_push_service.dart';
import 'services/auth_service.dart';
import 'screens/dashboard_screen.dart';
import 'firebase_options.dart';

/// Handler para mensajes FCM en background (app minimizada o terminada)
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  print('[FCM-BG] Mensaje en background: ${message.notification?.title}');
  print('[FCM-BG] Body: ${message.notification?.body}');
  print('[FCM-BG] Data: ${message.data}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inicializar Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 2. Registrar background message handler
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);
  
  print('[MAIN] Aplicación inicializada');
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App de Emergencias',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.redAccent),
        useMaterial3: true,
      ),
      home: const _SessionValidator(),
    );
  }
}

/// Widget que valida sesión al iniciar y registra token si existe
class _SessionValidator extends StatefulWidget {
  const _SessionValidator({Key? key}) : super(key: key);

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
      
      print('[SESSION] Validando sesión persistida...');
      
      // Revisar si hay token guardado
      final token = await authService.getStoredToken();
      
      if (token == null || token.isEmpty) {
        print('[SESSION] No hay sesión persistida');
        return;
      }
      
      print('[SESSION] Token encontrado, validando...');
      
      // Validar que el token sea válido
      final isValid = await authService.validateToken();
      if (!isValid) {
        print('[SESSION] Token inválido, limpiando sesión');
        await authService.clearSession();
        return;
      }
      
      print('[SESSION] Sesión válida, inicializando push...');
      final pushService = DispositivoPushService();
      // Usar método centralizado que evita listeners duplicados
      await pushService.initForAuthenticatedUser();
      
      print('[SESSION] Push inicializado correctamente');
    } catch (e) {
      print('[SESSION] Error validando sesión: $e');
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
              print('[SESSION] Navigating to dashboard');
              return const DashboardScreen();
            } else {
              // No hay sesión, ir a login
              print('[SESSION] Navigating to login');
              return const LoginScreen();
            }
          },
        );
      },
    );
  }
}