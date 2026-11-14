import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // Inizializzo il plugin all'avvio dell'app
  Future<void> init() async {
    if (_isInitialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(settings: initSettings);

    // Richiedo permesso di inviare notifiche
    final androidImplementation = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();

    _isInitialized = true;
  }

  // Mostro notifica immediata
  Future<void> showPriceAlert({
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) {
      await init();
    }

    const androidDetails = AndroidNotificationDetails(
      'price_pulse_alerts',
      'Avvisi Prezzi PricePulse',
      channelDescription: 'Notifiche su ribassi dei prodotti abituali e conferme',
      importance: Importance.high,
      priority: Priority.high,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    // Uso millisecondi attuali come ID univoco per non sovrascrivere le notifiche precedenti
    final int notificationId =
    DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _plugin.show(
      id: notificationId,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}
