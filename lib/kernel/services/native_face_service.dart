import 'dart:async';
import 'package:flutter/services.dart';

class NativeFaceService {
  static const _channel = MethodChannel('salama/terminal_native');
  static const _eventChannel = EventChannel('salama/terminal_events');

  Stream<Map<String, dynamic>>? _eventStream;

  Stream<Map<String, dynamic>> get events {
    _eventStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event as Map));
    return _eventStream!;
  }

  Future<bool> startScan() async {
    try {
      return await _channel.invokeMethod('startScan') ?? false;
    } on PlatformException catch (e) {
      print("Failed to start scan: '${e.message}'.");
      return false;
    }
  }

  Future<bool> stopScan() async {
    try {
      return await _channel.invokeMethod('stopScan') ?? false;
    } on PlatformException catch (e) {
      print("Failed to stop scan: '${e.message}'.");
      return false;
    }
  }

  Future<String?> captureEnrollmentPhoto() async {
    try {
      return await _channel.invokeMethod<String>('captureEnrollmentPhoto');
    } on PlatformException catch (e) {
      print("Failed to capture photo: '${e.message}'.");
      return null;
    }
  }

  Future<bool> enrollFace(String matricule, List<String> images) async {
    try {
      return await _channel.invokeMethod('enrollFace', {
        'matricule': matricule,
        'images': images
      }) ?? false;
    } on PlatformException catch (e) {
      print("Failed to enroll face: '${e.message}'.");
      return false;
    }
  }
  
  Future<bool> enableMdmKiosk() async {
    try {
      return await _channel.invokeMethod('enableMdmKiosk') ?? false;
    } on PlatformException catch (e) {
      print("Failed to enable kiosk: '${e.message}'.");
      return false;
    }
  }

  Future<bool> disableMdmKiosk() async {
    try {
      return await _channel.invokeMethod('disableMdmKiosk') ?? false;
    } on PlatformException catch (e) {
      print("Failed to disable kiosk: '${e.message}'.");
      return false;
    }
  }

  Future<bool> isMdmKioskEnabled() async {
    try {
      return await _channel.invokeMethod('isMdmKioskEnabled') ?? false;
    } on PlatformException catch (e) {
      print("Failed to check kiosk status: '${e.message}'.");
      return false;
    }
  }

   Future<Map<String, double>?> getTerminalLocation() async {
    try {
      final location = await _channel.invokeMethod<Map<dynamic, dynamic>>('getTerminalLocation');
      return location?.cast<String, double>();
    } on PlatformException catch (e) {
      print("Failed to get location: '${e.message}'.");
      return null;
    }
  }
}
