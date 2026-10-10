import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:loyambo/kernel/controllers/auth_controller.dart';

class Api {
  static String baseUrl = 'http://10.0.2.2:8000/api';

  static Future<dynamic> request({
    required String method,
    required String url,
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Map<String, File>? files,
  }) async {
    final fullUrl = Uri.parse('$baseUrl/$url');
    if (kDebugMode) {
      print('API Request ($method): $fullUrl');
    }
    const apiKey = "16jA/0l6TBmFoPk64MnrmLzVp2MRL2Do0yD5N6K4e54=";

    headers = {
      'Content-Type': 'application/json',
      'X-API-KEY': apiKey,
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Linux; Android 11; SM-G960F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.101 Mobile Safari/537.36',
      'Cookie': 'humans_21909=1',
      ...?headers,
    };
    if (Get.isRegistered<AuthController>()) {
      final userId = Get.find<AuthController>().currentUser.value?.id;
      if (userId != null) {
        headers.putIfAbsent('X-User-Id', () => '$userId');
      }
    }

    http.Response response;
    try {
      if (files != null && files.isNotEmpty) {
        var request = http.MultipartRequest(method.toUpperCase(), fullUrl);
        request.headers.addAll(headers);

        if (body != null) {
          for (var entry in body.entries) {
            if (entry.value is Map) {
              (entry.value as Map).forEach((subKey, subValue) {
                if (subValue != null) {
                  request.fields['${entry.key}[$subKey]'] = subValue.toString();
                }
              });
            } else {
              if (entry.value != null) {
                request.fields[entry.key] = entry.value.toString();
              }
            }
          }
        }
        for (var entry in files.entries) {
          var fileBytes = await entry.value.readAsBytes();
          var multipartFile = http.MultipartFile.fromBytes(
            entry.key,
            fileBytes,
            filename: entry.value.path.split("/").last,
          );
          request.files.add(multipartFile);
        }
        var streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      } else {
        final String m = method.toLowerCase();
        const timeout = Duration(seconds: 15);
        if (m == 'get') {
          response = await http.get(fullUrl, headers: headers).timeout(timeout);
        } else if (m == 'post') {
          response = await http.post(fullUrl, headers: headers, body: jsonEncode(body ?? {})).timeout(timeout);
        } else if (m == 'patch') {
          response = await http.patch(fullUrl, headers: headers, body: jsonEncode(body ?? {})).timeout(timeout);
        } else if (m == 'put') {
          response = await http.put(fullUrl, headers: headers, body: jsonEncode(body ?? {})).timeout(timeout);
        } else {
          throw Exception("Méthode HTTP non prise en charge : $method");
        }
      }

      if (kDebugMode) {
        print("API Response ($url): ${response.body}");
      }

      if (response.body.isEmpty) return null;
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        return null;
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      if (decoded is Map) return decoded;
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Exception API ($url): $e');
      }
      return null;
    }
  }
}
