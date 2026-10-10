import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:loyambo/kernel/services/api.dart';

class RealtimeDataProvider<T> {
  final StreamController<T> _dataStreamController = StreamController<T>.broadcast();
  late Stream<T> dataStream;
  final String baseURL = Api.baseUrl;
  StreamSubscription? _pollSub;
  bool _disposed = false;

  RealtimeDataProvider({required String url}) {
    dataStream = _dataStreamController.stream;
    _init(url);
  }

  void _init(String url) {
    const fetchInterval = Duration(seconds: 30);

    _pollSub = Stream.periodic(fetchInterval).listen((_) async {
      if (_disposed) return;
      try {
        final response = await http.get(
          Uri.parse("$baseURL$url"),
          headers: {'Content-Type': 'application/json'},
        );
        if (_disposed) return;
        if (response.statusCode == 200) {
          var data = jsonDecode(response.body);
          if (!_dataStreamController.isClosed) {
            _dataStreamController.add(data as T);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('Erreur : $e');
        }
      }
    });
  }

  void dispose() {
    _disposed = true;
    _pollSub?.cancel();
    _pollSub = null;
    if (!_dataStreamController.isClosed) {
      _dataStreamController.close();
    }
  }
}
