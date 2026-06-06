import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'auth_service.dart';

class DispositivoPushService {
  static String get baseUrl => AuthService.baseUrl;
  final AuthService _authService = AuthService();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  
  // Flag para evitar configurar listeners duplicados
  bool _listenersConfigured = false;
  
  // LocalNotifications para mostrar push en foreground
  late FlutterLocalNotificationsPlugin _localNotificationsPlugin;
  
  static final DispositivoPushService _instancia = DispositivoPushService._internal();
  
  factory DispositivoPushService() {
    return _instancia;
  }
  
  DispositivoPushService._internal() {
    _inicializarLocalNotifications();
  }

  /// Inicializa flutter_local_notifications
  void _inicializarLocalNotifications() {
    _localNotificationsPlugin = FlutterLocalNotificationsPlugin();
    
    // Configuración Android
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración iOS
    final DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );
    
    final InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    _localNotificationsPlugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationTap,
    );
    
    debugPrint('[LocalNotif] ✅ Flutter Local Notifications inicializado');
  }

  /// Maneja el tap de una notificación local (foreground)
  void _handleNotificationTap(NotificationResponse response) {
    debugPrint('[LocalNotif] 👆 Usuario tappeó notificación');
    final payload = response.payload;
    if (payload != null) {
      debugPrint('[LocalNotif] Payload: $payload');
      // Aquí puedes navegar a pantalla correspondiente según payload
    }
  }

  /// Registra el token FCM del dispositivo en el backend
  /// Se debe llamar después del login y al iniciar app con sesión activa
  /// Reintentar si el usuario deniega permisos
  Future<bool> registrarTokenFCM({int reintentos = 3}) async {
    debugPrint('[FCM_REGISTER] Iniciando registro de token FCM...');

    try {
      // 1. Solicitar permiso de notificaciones (Android 13+)
      debugPrint('[FCM_REGISTER] Solicitando permisos de notificaciones...');
      NotificationSettings settings = await _firebaseMessaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      
      debugPrint('[FCM_REGISTER] Permiso respondió: ${settings.authorizationStatus}');
      
      // Si usuario deniega, desistir sin reintentar (mejor UX)
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM_REGISTER] ERROR: Permisos denegados por el usuario');
        debugPrint('[FCM_REGISTER] El usuario deberá habilitar desde Configuración');
        return false;
      }
      
      if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('[FCM_REGISTER] ADVERTENCIA: Permisos solo provisional');
      } else if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('[FCM_REGISTER] OK: Permisos autorizados');
      }

      // 2. Obtener token FCM
      debugPrint('[FCM_REGISTER] Obteniendo token FCM...');
      final token = await _firebaseMessaging.getToken();
      if (token == null) {
        debugPrint('[FCM_REGISTER] ERROR: No se pudo obtener token FCM');
        return false;
      }
      debugPrint('[FCM_REGISTER] Token obtenido: ${token.substring(0, 30)}...');

      // 3. Obtener información del dispositivo
      String plataforma = Platform.isAndroid ? 'ANDROID' : 'IOS';
      String nombreDispositivo = await _obtenerNombreDispositivo();
      String deviceId = await _obtenerDeviceIdPersistente();

      debugPrint('[FCM_REGISTER] Dispositivo: plataforma=$plataforma, device_id=${deviceId.substring(0, 20)}...');
      debugPrint('[FCM_REGISTER] Nombre: $nombreDispositivo');

      // 4. Validar autenticación
      final headers = await _authService.getAuthHeaders();
      if (!headers.containsKey('Authorization')) {
        debugPrint('[FCM_REGISTER] ERROR: No hay token de autenticación');
        return false;
      }
      debugPrint('[FCM_REGISTER] Headers de autenticación: OK');

      // 5. Enviar token al backend
      headers['Content-Type'] = 'application/json';

      final requestBody = {
        'plataforma': plataforma,
        'token_fcm': token,
        'device_id': deviceId,
        'nombre_dispositivo': nombreDispositivo,
      };

      debugPrint('[FCM_REGISTER] Enviando request a /push/register-token...');
      debugPrint('[FCM_REGISTER] URL: $baseUrl/push/register-token');
      
      final response = await http.post(
        Uri.parse('$baseUrl/push/register-token'),
        headers: headers,
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('[FCM_REGISTER] ERROR: Timeout (15s) esperando respuesta del backend');
          throw Exception('Backend timeout (15s)');
        }
      );

      debugPrint('[FCM_REGISTER] Respuesta del backend: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('[FCM_REGISTER] EXITO: Token registrado en backend');
        debugPrint('[FCM_REGISTER] Body: ${response.body.substring(0, 100)}...');
        return true;
      } else if (response.statusCode == 401) {
        debugPrint('[FCM_REGISTER] ERROR: No autorizado (401) - sesión expirada');
        return false;
      } else if (response.statusCode == 400) {
        debugPrint('[FCM_REGISTER] ERROR: Request inválido (400)');
        debugPrint('[FCM_REGISTER] Body: ${response.body}');
        return false;
      } else {
        debugPrint('[FCM_REGISTER] ERROR: Status ${response.statusCode}');
        debugPrint('[FCM_REGISTER] Body: ${response.body}');
        return false;
      }
    } catch (e) {
      if (e is TimeoutException) {
        debugPrint('[FCM_REGISTER] ERROR Timeout: $e');
      } else {
        debugPrint('[FCM_REGISTER] ERROR Excepción: $e');
        debugPrint('[FCM_REGISTER] Stack trace: ${StackTrace.current}');
      }
      return false;
    }
  }

  /// Inicializa push para usuario autenticado
  /// Configura listeners (solo una vez) y registra token FCM
  /// Centraliza el flujo de inicialización para login y restore de sesión
  Future<void> initForAuthenticatedUser() async {
    debugPrint('[FCM] 🚀 Inicializando push para usuario autenticado...');
    
    // Configurar listeners solo si no se han configurado antes
    if (!_listenersConfigured) {
      debugPrint('[FCM] 🔧 Configurando listeners de FCM (primera vez)...');
      configurarListenersFCM();
      _listenersConfigured = true;
    } else {
      debugPrint('[FCM] ℹ️  Listeners ya estaban configurados, omitiendo...');
    }
    
    // Registrar token
    debugPrint('[FCM] 📝 Registrando token FCM...');
    await registrarTokenFCM();
    
    debugPrint('[FCM] ✅ Push inicializado correctamente');
  }

  /// Escucha cambios de token FCM y re-registra automáticamente
  void escucharCambiosToken() {
    debugPrint('[FCM] 👂 Escuchando cambios de token FCM...');
    
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] 🔄 Token FCM renovado: ${newToken.substring(0, 20)}...');
      // Automáticamente re-registrar el nuevo token
      registrarTokenFCM();
    }).onError((err) {
      debugPrint('[FCM] ❌ Error escuchando token refresh: $err');
    });
  }

  /// Obtiene el nombre del dispositivo
  Future<String> _obtenerNombreDispositivo() async {
    try {
      if (Platform.isAndroid) {
        final info = await _deviceInfo.androidInfo;
        return '${info.manufacturer} ${info.model}';
      } else if (Platform.isIOS) {
        final info = await _deviceInfo.iosInfo;
        return info.model;
      }
      return 'Dispositivo desconocido';
    } catch (e) {
      debugPrint('[FCM] ⚠️  Error obteniendo nombre dispositivo: $e');
      return 'Dispositivo';
    }
  }

  /// Obtiene o genera un ID de dispositivo persistente
  /// Genera un UUID una sola vez y lo guarda en SharedPreferences
  /// Esto garantiza que el mismo dispositivo siempre tenga el mismo ID
  /// (importantísimo para el upsert de tokens en backend)
  Future<String> _obtenerDeviceIdPersistente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Intentar obtener ID existente
      final existingId = prefs.getString('pushDeviceId');
      if (existingId != null && existingId.isNotEmpty) {
        debugPrint('[FCM] Usando device ID persistente: ${existingId.substring(0, 20)}...');
        return existingId;
      }
      
      // Generar nuevo UUID y guardarlo
      final newId = const Uuid().v4();
      await prefs.setString('pushDeviceId', newId);
      debugPrint('[FCM] Generado y guardado nuevo device ID: ${newId.substring(0, 20)}...');
      return newId;
    } catch (e) {
      debugPrint('[FCM] ⚠️  Error obteniendo device ID persistente: $e');
      // Fallback: retornar un ID temporal basado en timestamp
      return DateTime.now().millisecondsSinceEpoch.toString();
    }
  }

  /// Muestra una notificación local (para foreground)
  Future<void> _mostrarNotificacionLocal(RemoteMessage message) async {
    try {
      final notification = message.notification;
      final data = message.data;
      
      if (notification != null) {
        const AndroidNotificationDetails androidDetails =
            AndroidNotificationDetails(
          'emergencias_canal', // Channel ID
          'Emergencias', // Channel name
          channelDescription: 'Notificaciones de emergencias vehiculares',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
        );
        
        const DarwinNotificationDetails iosDetails =
            DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );
        
        final NotificationDetails details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );
        
        await _localNotificationsPlugin.show(
          notification.hashCode,
          notification.title ?? 'Notificación',
          notification.body ?? '',
          details,
          payload: jsonEncode(data),
        );
        
        debugPrint('[LocalNotif] ✅ Notificación local mostrada: ${notification.title}');
      }
    } catch (e) {
      debugPrint('[LocalNotif] ❌ Error mostrando notificación local: $e');
    }
  }

  /// Configura listeners para mensajes FCM (foreground, background, app abierta)
  void configurarListenersFCM() {
    debugPrint('[FCM] 🔧 Configurando listeners de FCM...');

    // ===== FOREGROUND =====
    // Mensaje cuando la app está en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] 📬 Mensaje en foreground: ${message.notification?.title}');
      debugPrint('[FCM] Body: ${message.notification?.body}');
      debugPrint('[FCM] Data: ${message.data}');
      
      // Mostrar notificación local para que sea visible al usuario
      _mostrarNotificacionLocal(message);
    });

    // ===== APP ABIERTA POR NOTIFICACIÓN =====
    // Cuando el usuario tappa la notificación (desde foreground o background)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] 👆 Usuario abrió notificación desde tap: ${message.notification?.title}');
      debugPrint('[FCM] Data: ${message.data}');
      // Aquí navegar a pantalla según tipo de evento
      _manejarNavegacionNotificacion(message.data);
    });

    // ===== CUANDO APP ESTÁ TERMINADA =====
    // Obtener el mensaje que abrió la app (si fue desde una notificación)
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[FCM] 📲 App abierta DESDE notificación (app terminada): ${message.notification?.title}');
        _manejarNavegacionNotificacion(message.data);
      }
    });

    // ===== CAMBIOS DE TOKEN =====
    // Escuchar cuando FCM renueva el token
    escucharCambiosToken();

    debugPrint('[FCM] ✅ Todos los listeners configurados');
  }

  /// Maneja navegación según el tipo de notificación
  void _manejarNavegacionNotificacion(Map<String, dynamic> data) {
    debugPrint('[FCM] 🔍 Procesando datos de notificación: $data');
    
    final tipoEvento = data['categoria_evento'] ?? data['type'];
    final referenceId = data['referencia_id'] ?? data['reference_id'];
    
    debugPrint('[FCM] Tipo evento: $tipoEvento, ID: $referenceId');
    
    // Aquí puedes navegar según el tipo
    // Ejemplo: si es POSTULACION, ir a la pantalla de postulaciones
    switch (tipoEvento) {
      case 'POSTULACION':
        debugPrint('[FCM] → Navegando a postulaciones');
        break;
      case 'CAMBIO_ESTADO_SOLICITUD':
        debugPrint('[FCM] → Navegando a solicitud detail');
        break;
      case 'NOTIFICACION_GENERAL':
      default:
        debugPrint('[FCM] → Mostrando notificación general');
    }
  }
}


