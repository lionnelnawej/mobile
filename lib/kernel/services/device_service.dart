import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_storage/get_storage.dart';
import 'package:uuid/uuid.dart';

class DeviceService {
  static final GetStorage _storage = GetStorage();

  /// Récupère un identifiant UNIQUE et PERSISTANT pour ce téléphone.
  /// L'UUID est généré une seule fois et stocké localement.
  static Future<String> getDeviceId() async {
    // 1. On vérifie si un ID a déjà été généré et stocké
    String? storedId = _storage.read('device_unique_id');
    
    // Si l'ID existe et qu'il n'est pas un ID système générique (comme le Build ID Android)
    if (storedId != null && storedId.contains('-')) {
      return storedId;
    }

    // 2. Si non, on génère un UUID v4 (ex: 550e8400-e29b-41d4-a716-446655440000)
    // C'est statistiquement unique pour chaque téléphone.
    String newId = const Uuid().v4();

    // 3. On le sauvegarde de manière persistante (GetStorage)
    await _storage.write('device_unique_id', newId);
    
    return newId;
  }

  /// Récupère le nom réel du modèle de l'appareil (ex: "SAMSUNG SM-G980")
  static Future<String> getDeviceName() async {
    try {
      if (Platform.isAndroid) {
        return "";
      } else if (Platform.isIOS) {
        return "";
      }
    } catch (_) {}
    return "Terminal Inconnu";
  }

  /// Récupère le token Firebase Cloud Messaging
  static Future<String?> getFcmToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }

  /// Retourne le nom de la plateforme
  static String getPlatform() {
    if (Platform.isAndroid) return "android";
    if (Platform.isIOS) return "ios";
    return "unknown";
  }
}
