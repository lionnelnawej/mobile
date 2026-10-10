import 'package:get_storage/get_storage.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/controllers/cart_controller.dart';
import 'package:loyambo/kernel/controllers/order_controller.dart';
import 'package:loyambo/kernel/services/app_translations.dart';
import 'package:loyambo/kernel/services/chime.dart';
import 'package:loyambo/kernel/services/http_manager.dart';
import 'package:loyambo/screens/auth/login.dart';

import '/constants/styles.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> with WidgetsBindingObserver {
  late final Future<Widget> _startupFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Injection immédiate des services globaux
    Get.put(HttpManager());
    Get.put(AuthController());

    _startupFuture = _initApp();
    _configLoading();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    Chime.stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Toujours lever tout overlay de chargement au retour.
      try {
        if (EasyLoading.isShow) EasyLoading.dismiss();
      } catch (_) {}
      // Relancer la synchro des commandes (fusion web → mobile).
      try {
        if (Get.isRegistered<OrderController>()) {
          Get.find<OrderController>().fetchOrders(silent: true);
        }
      } catch (_) {}
      try {
        if (Get.isRegistered<CartController>()) {
          Get.find<CartController>().syncStock();
        }
      } catch (_) {}
    }
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Ne jamais bloquer le cycle de vie avec l'audio.
      Future.microtask(() => Chime.stop());
    }
  }

  void _configLoading() {
    EasyLoading.instance
      ..displayDuration = const Duration(milliseconds: 2000)
      ..indicatorType = EasyLoadingIndicatorType.fadingCircle
      ..loadingStyle = EasyLoadingStyle.light
      ..indicatorSize = 45.0
      ..radius = 10.0
      ..maskType = EasyLoadingMaskType.black
      ..userInteractions = true
      ..dismissOnTap = false;
  }

  Future<Widget> _initApp() async {
    // Tenter de restaurer la session si nécessaire ici
    return const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    final savedLocale = GetStorage().read('locale')?.toString() ?? 'fr';
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Loyambo Plateforme',
      translations: AppTranslations(),
      locale: Locale(savedLocale),
      fallbackLocale: const Locale('fr'),
      theme: ThemeData(fontFamily: "Ubuntu"),
      themeMode: ThemeMode.light,
      builder: EasyLoading.init(),
      home: FutureBuilder<Widget>(
        future: _startupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF3F6FC),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: primaryMaterialColor),
                  ],
                ),
              ),
            );
          } else if (snapshot.hasError) {
            return Scaffold(
              body: Center(
                child: Text(
                  'Erreur : ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          } else {
            return snapshot.data!;
          }
        },
      ),
    );
  }
}
