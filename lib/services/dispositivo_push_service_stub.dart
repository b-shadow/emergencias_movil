class DispositivoPushService {
  static final DispositivoPushService _instancia =
      DispositivoPushService._internal();

  factory DispositivoPushService() {
    return _instancia;
  }

  DispositivoPushService._internal();

  Future<bool> registrarTokenFCM({int reintentos = 3}) async {
    return false;
  }

  Future<void> initForAuthenticatedUser() async {
    return;
  }

  void configurarListenersFCM() {}
}
