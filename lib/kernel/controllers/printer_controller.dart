import 'dart:async';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/models/order.dart';
import 'package:loyambo/kernel/services/devise_book.dart';
import 'package:intl/intl.dart';
import 'package:loyambo/global/store.dart';
import 'package:loyambo/global/controllers.dart';
import 'dart:developer' as dev;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class PrinterController extends GetxController {
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  var devices = <BluetoothDevice>[].obs;
  var selectedDevice = Rxn<BluetoothDevice>();
  var isConnected = false.obs;
  var isScanning = false.obs;
  StreamSubscription? _stateSub;
  bool _disconnecting = false;
  bool _connecting = false;

  @override
  void onInit() {
    super.onInit();
    // Pas d'observer lifecycle : couper/reconnecter le BT au retour plantait l'app.
    Future.microtask(() async {
      try {
        await _requestPermissions().timeout(const Duration(seconds: 3));
        await initBluetooth();
      } catch (e) {
        dev.log("Printer boot ignored: $e");
      }
    });
  }

  Future<void> _safeDisconnect() async {
    if (_disconnecting) return;
    _disconnecting = true;
    try {
      final connected = await bluetooth.isConnected.timeout(const Duration(milliseconds: 300));
      if (connected == true) {
        await bluetooth.disconnect().timeout(const Duration(milliseconds: 400));
      }
    } catch (_) {
      // ignore native teardown races
    } finally {
      isConnected.value = false;
      _disconnecting = false;
    }
  }

  @override
  void onClose() {
    _stateSub?.cancel();
    unawaited(_safeDisconnect());
    super.onClose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
      
      dev.log("Permissions status: $statuses");
    }
  }

  Future<void> initBluetooth() async {
    await _stateSub?.cancel();
    _stateSub = bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case 1: // CONNECTED
          isConnected.value = true;
          dev.log("Printer: Connected");
          break;
        case 0: // DISCONNECTED
        case -1: // ERROR
          isConnected.value = false;
          dev.log("Printer: Disconnected or Error ($state)");
          break;
        default:
          break;
      }
    });

    String? lastAddress = localStorage.read('last_printer_address');
    if (lastAddress != null) {
      try {
        await getDevices().timeout(const Duration(seconds: 4));
        final devFound = devices.firstWhere((d) => d.address == lastAddress);
        selectedDevice.value = devFound;
        // Pas de reconnexion auto au démarrage : elle fige l'app au retour.
        // La connexion se fait à l'impression via _ensureConnected.
      } catch (_) {}
    }
  }

  Future<void> getDevices() async {
    isScanning.value = true;
    try {
      bool? isOn = await bluetooth.isOn;
      if (isOn == true) {
        List<BluetoothDevice> bluetoothDevices = await bluetooth.getBondedDevices();
        devices.assignAll(bluetoothDevices);
      } else {
        dev.log("Bluetooth is OFF");
      }
    } catch (e) {
      dev.log("Error getting devices: $e");
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> connect({bool silent = false}) async {
    if (selectedDevice.value == null || _connecting) return;
    _connecting = true;
    try {
      bool? alreadyConnected = await bluetooth.isConnected.timeout(const Duration(seconds: 1));
      if (alreadyConnected == true) {
        isConnected.value = true;
        return;
      }

      if (!silent) EasyLoading.show(status: 'Connexion à ${selectedDevice.value!.name}...');

      await bluetooth.connect(selectedDevice.value!).timeout(const Duration(seconds: 6));

      localStorage.write('last_printer_address', selectedDevice.value!.address);
      isConnected.value = true;
      if (!silent) EasyLoading.showSuccess("Connecté");
    } catch (e) {
      dev.log("Connect Error: $e");
      isConnected.value = false;
      if (!silent) EasyLoading.showError("Connexion impossible");
      if (EasyLoading.isShow && silent) EasyLoading.dismiss();
    } finally {
      _connecting = false;
      if (!silent && EasyLoading.isShow) {
        // laisser showSuccess/showError gérer, sinon fermer
      }
    }
  }

  Future<void> disconnect() async {
    await _safeDisconnect();
  }

  Future<bool> _ensureConnected() async {
    try {
      if (await bluetooth.isConnected.timeout(const Duration(seconds: 1)) == true) {
        return true;
      }
    } catch (_) {}
    if (selectedDevice.value == null) return false;
    try {
      await connect(silent: true);
      return await bluetooth.isConnected.timeout(const Duration(seconds: 1)) == true;
    } catch (e) {
      dev.log("Reconnect print Error: $e");
      isConnected.value = false;
      return false;
    }
  }

  Future<void> printNewOrderTickets(Order order) async {
    if (!await _ensureConnected()) return;
    await _executePrint(order);
  }

  Future<void> printOrderTicket(
    Order order, {
    String mode = 'native',
    double remise = 0,
    String remiseType = 'pourcent',
    String remiseDevise = 'FC',
    bool receipt = false,
    bool quiet = false,
  }) async {
    if (await _ensureConnected()) {
      await _executePrint(
        order,
        mode: mode,
        remise: remise,
        remiseType: remiseType,
        remiseDevise: remiseDevise,
        receipt: receipt,
      );
    } else if (!quiet) {
      EasyLoading.showError("Imprimante non connectée");
    }
  }

  Future<void> printCuisineTicket(Order order) async {
    if (await _ensureConnected()) {
      final cuisineItems = order.items.where((item) => item.categoryType?.toLowerCase() == 'cuisine').toList();
      
      if (cuisineItems.isEmpty) {
        EasyLoading.showInfo("Aucun produit de type cuisine");
        return;
      }

      await _executeCuisinePrint(order, cuisineItems);
    } else {
      EasyLoading.showError("Imprimante non connectée");
    }
  }

  /// Nettoie le texte des caractères Unicode spéciaux (espaces insécables)
  /// et des accents pour éviter les caractères chinois sur les imprimantes thermiques.
  String _cleanText(String text) {
    return text
        .replaceAll('\u00A0', ' ') // Espace insécable
        .replaceAll('\u202F', ' ') // Espace insécable étroit
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('û', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('ç', 'c')
        .replaceAll('É', 'E')
        .replaceAll('À', 'A');
  }

  String _money(double amount) {
    final rounded = DeviseBook.instance.roundMoney(amount);
    return NumberFormat('#,##0.00', 'en_US').format(rounded).replaceAll(',', ' ');
  }

  String _sym(String code) {
    final normalized = DeviseBook.instance.normalize(code);
    if (normalized == 'USD') return 'USD';
    if (normalized == 'EUR') return 'EUR';
    if (normalized == 'FCFA') return 'FCFA';
    return 'FC';
  }

  double _roundMoney(double value) => (value * 100).round() / 100;

  Map<String, double> _netTotals(Order order, double remise, String remiseType, String remiseDevise) {
    final book = DeviseBook.instance;
    final raw = book.nativeTotals(
      order.items.map((item) => (devise: item.currency, amount: item.price * item.quantity)),
    );
    if (remise <= 0) return raw;
    if (remiseType == 'montant') {
      final next = Map<String, double>.from(raw);
      final code = book.normalize(remiseDevise);
      final left = _roundMoney((next[code] ?? 0) - remise);
      if (left <= 0.0001) {
        next.remove(code);
      } else {
        next[code] = left;
      }
      return next;
    }
    final factor = (1 - (remise / 100)).clamp(0.0, 1.0);
    return raw.map((code, value) => MapEntry(code, _roundMoney(value * factor)));
  }

  Future<void> _executePrint(
    Order order, {
    String mode = 'native',
    double remise = 0,
    String remiseType = 'pourcent',
    String remiseDevise = 'FC',
    bool receipt = false,
  }) async {
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
    final ets = authController.currentUser.value?.etablissement;
    final book = DeviseBook.instance;
    final target = book.normalize(mode);
    final singleCurrency = mode != 'native' && target.isNotEmpty;

    try {
      bluetooth.printNewLine();
      bluetooth.printCustom(_cleanText(ets?.nom.toUpperCase() ?? "LOYAMBO"), 3, 1);
      if (ets?.telephone != null) {
        bluetooth.printCustom("Tel: ${ets!.telephone}", 0, 1);
      }
      bluetooth.printNewLine();

      bluetooth.printCustom("TICKET DE CAISSE", 1, 1);
      bluetooth.printLeftRight("FAC:", order.numeroFacture ?? "#${order.id}", 1);
      bluetooth.printLeftRight("TABLE:", _cleanText(order.table?.name.toUpperCase() ?? 'N/A'), 1);
      bluetooth.printLeftRight("DATE:", formatter.format(order.createdAt), 1);
      bluetooth.printLeftRight("SERVEUR:", _cleanText(order.user?.name?.toUpperCase() ?? 'N/A'), 1);
      bluetooth.printCustom("--------------------------------", 1, 1);

      final groups = order.groups;
      final split = groups.length > 1;
      groups.forEach((label, items) {
        if (split) {
          bluetooth.printCustom(_cleanText(label.toUpperCase()), 1, 1);
        }
        for (var item in items) {
          final code = book.normalize(item.currency);
          final line = item.quantity * item.price;
          final name = item.isBonus ? "${item.name} BONUS" : item.name;
          bluetooth.printCustom(_cleanText(name), 1, 0);
          bluetooth.printLeftRight(
            "  ${item.quantity} x ${_money(item.price)} ${_sym(code)}",
            "${_money(line)} ${_sym(code)}",
            1,
          );
          bluetooth.printCustom("- - - - - - - - - - - - - - - -", 0, 1);
        }
        if (split) {
          final sub = <String, double>{};
          for (final item in items) {
            final code = book.normalize(item.currency);
            sub[code] = (sub[code] ?? 0) + item.quantity * item.price;
          }
          sub.forEach((code, value) {
            bluetooth.printCustom("SOUS-TOTAL: ${_money(value)} ${_sym(code)}", 1, 2);
          });
          bluetooth.printCustom("--------------------------------", 1, 1);
        }
      });

      bluetooth.printCustom("--------------------------------", 1, 1);
      if (receipt && remise > 0) {
        final remiseText = remiseType == 'montant'
            ? "${_money(remise)} ${_sym(remiseDevise)}"
            : "${_money(remise)} %";
        bluetooth.printCustom("REMISE: $remiseText", 1, 2);
      }
      if (receipt) {
        final payment = singleCurrency ? "TOUT EN ${_sym(target)}" : "NATIF";
        bluetooth.printCustom("PAIEMENT: $payment", 1, 2);
      }

      final net = _netTotals(order, receipt ? remise : 0, remiseType, remiseDevise);
      if (!singleCurrency) {
        if (net.isEmpty) {
          bluetooth.printCustom("TOTAL: 0", 2, 2);
        }
        net.forEach((code, value) {
          bluetooth.printCustom("TOTAL: ${_money(value)} ${_sym(code)}", 2, 2);
        });
      } else {
        var total = 0.0;
        net.forEach((code, value) {
          total += book.convert(value, code, target);
        });
        bluetooth.printCustom("TOTAL: ${_money(_roundMoney(total))} ${_sym(target)}", 2, 2);
      }

      bluetooth.printCustom("--------------------------------", 1, 1);
      final primary = book.normalize(book.primary);
      for (final rate in book.currencies) {
        if (!rate.enabled || rate.code == primary || rate.rate <= 0) continue;
        bluetooth.printCustom(
          "TAUX: 1 ${_sym(rate.code)} = ${_money(rate.rate)} ${_sym(primary)}",
          0,
          1,
        );
      }
      bluetooth.printNewLine();

      if (ets?.adresse != null) {
        bluetooth.printCustom(_cleanText(ets!.adresse!), 1, 1);
      }
      bluetooth.printCustom("Merci de votre visite !", 1, 1);
      bluetooth.printNewLine();
      
      String qrData = order.numeroFacture ?? "#${order.id}";
      bluetooth.printQRcode(qrData, 200, 200, 1);

      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } catch (e) {
      dev.log("Print error: $e");
    }
  }

  Future<void> _executeCuisinePrint(Order order, List<OrderItem> cuisineItems) async {
    final DateFormat formatter = DateFormat('dd/MM/yyyy HH:mm');
    final ets = authController.currentUser.value?.etablissement;

    try {
      bluetooth.printNewLine();
      bluetooth.printCustom(_cleanText(ets?.nom.toUpperCase() ?? "LOYAMBO"), 3, 1);
      bluetooth.printCustom("BON DE CUISINE", 3, 1);
      bluetooth.printNewLine();

      bluetooth.printLeftRight("FAC:", order.numeroFacture ?? "#${order.id}", 1);
      bluetooth.printLeftRight("TABLE:", _cleanText(order.table?.name.toUpperCase() ?? 'N/A'), 1);
      bluetooth.printLeftRight("DATE:", formatter.format(DateTime.now()), 1);
      bluetooth.printLeftRight("SERVEUR:", _cleanText(order.user?.name?.toUpperCase() ?? 'N/A'), 1);
      bluetooth.printCustom("--------------------------------", 1, 1);
      
      for (var item in cuisineItems) {
        bluetooth.printCustom("${item.quantity} x ${_cleanText(item.name)}", 2, 0);
        bluetooth.printCustom("- - - - - - - - - - - - - - - -", 0, 1);
      }
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut();
    } catch (e) {
      dev.log("Cuisine Print error: $e");
    }
  }
}
