import 'dart:convert';
import 'dart:developer' as dev;
import 'package:firebase_messaging/firebase_messaging.dart';
import '/kernel/services/api.dart';
import '/kernel/services/database_helper.dart';
import '/kernel/services/device_service.dart';
import '/kernel/services/ota_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<void> init() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    await _registerDevice();

    FirebaseMessaging.onMessage.listen((message) {
      _logFcmMessage(message, "FOREGROUND");
      handleNotification(message, silent: false);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _logFcmMessage(message, "OPENED_APP");
      handleNotification(message, silent: false);
    });
  }

  void _logFcmMessage(RemoteMessage message, String context) {
    dev.log("🔔 FCM RECEIVED [$context]");
    dev.log("   Data: ${message.data}");
  }

  Future<void> _registerDevice() async {
    final token = await DeviceService.getFcmToken();
    final deviceId = await DeviceService.getDeviceId();
    final deviceName = await DeviceService.getDeviceName();
    if (token == null) return;

    await Api.request(
      method: 'post',
      url: 'devices/register',
      body: {
        'imei': deviceId,
        'firebase_token': token,
        'platform': DeviceService.getPlatform(),
        'device_name': deviceName,
      },
    );
  }

  Future<void> handleNotification(
    RemoteMessage message, {
    bool silent = true,
  }) async {
    final String? type = message.data['type'];

    // 1. Gestion de la mise à jour OTA
    if (type == 'update') {
      final String? url = message.data['url'];
      if (url != null && url.isNotEmpty) {
        await OtaService().updateApp(url);
      }
      return;
    }

    // 2. Gestion des synchronisations biométriques
    final dynamic rawMatricules = message.data['matricules'];
    if (rawMatricules == null) return;

    List<String> matricules = [];
    try {
      if (rawMatricules is List) {
        matricules = List<String>.from(rawMatricules);
      } else if (rawMatricules is String) {
        matricules = List<String>.from(jsonDecode(rawMatricules));
      }
    } catch (e) {
      dev.log("❌ Erreur parsing matricules FCM: $e");
      return;
    }

    if (matricules.isEmpty) return;
  }
}
