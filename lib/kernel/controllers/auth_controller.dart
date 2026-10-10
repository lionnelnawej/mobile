import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:loyambo/global/store.dart';
import 'package:loyambo/kernel/models/user.dart';
import 'package:loyambo/kernel/services/devise_book.dart';
import 'package:loyambo/kernel/services/database_helper.dart';
import 'package:loyambo/kernel/services/http_manager.dart';
import 'package:loyambo/screens/auth/login.dart';

class AuthController extends GetxController with WidgetsBindingObserver {
  static AuthController get instance => Get.find();
  final DatabaseHelper _dbHelper = DatabaseHelper();

  var savedAccounts = <String>[].obs;
  var isObscure = true.obs;
  var currentUser = Rxn<User>();
  var isLoggedIn = false.obs;
  var isLoading = false.obs;

  final idController = TextEditingController();
  final passwordController = TextEditingController();
  final idFocusNode = FocusNode();
  Timer? _dayWatch;
  bool _kicking = false;
  bool _refreshingSession = false;
  DateTime? _lastResumeRefresh;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    loadSavedAccounts();
    _restoreSession();
    _dayWatch = Timer.periodic(const Duration(seconds: 60), (_) => leaveIfDayClosed());
  }

  Future<void> leaveIfDayClosed() async {
    if (_kicking || !isLoggedIn.value) return;
    final role = currentUser.value?.role;
    if (role == null || role == 'admin' || role == 'caissier') return;
    final status = await HttpManager.instance.dayStatus();
    if (status == null || status['ouverte'] == true) return;
    _kicking = true;
    logout();
    EasyLoading.showInfo("La journée est fermée. Seuls le caissier et l'administrateur restent connectés.");
    Get.offAll(() => const LoginScreen());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Ne jamais rebloquer l'UI avec EasyLoading au retour.
      if (EasyLoading.isShow) EasyLoading.dismiss();
      final now = DateTime.now();
      if (_lastResumeRefresh != null &&
          now.difference(_lastResumeRefresh!).inSeconds < 4) {
        return;
      }
      _lastResumeRefresh = now;
      if (isLoggedIn.value && currentUser.value?.id != null) {
        // Refresh silencieux : sans overlay, sans déconnexion locale.
        refreshSessionSilent();
      }
    }
  }

  void _restoreSession() {
    final userData = localStorage.read('user_data');
    if (userData != null) {
      currentUser.value = User.fromJson(userData);
      isLoggedIn.value = true;
      // Session locale d'abord, refresh réseau en arrière-plan sans bloquer.
      refreshSessionSilent();
    }
  }

  /// Rafraîchit le token/session sans overlay. Si le réseau échoue, on garde
  /// la session locale pour que l'app reste utilisable au retour.
  Future<void> refreshSessionSilent() async {
    final id = currentUser.value?.id;
    if (id == null || _refreshingSession) return;
    _refreshingSession = true;
    try {
      await loginById(id, silent: true);
    } catch (_) {
      // garder la session locale
    } finally {
      _refreshingSession = false;
      if (EasyLoading.isShow) EasyLoading.dismiss();
    }
  }

  Future<bool> login() async {
    final email = idController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) return false;

    isLoading.value = true;
    try {
      final response = await HttpManager.instance.login(email, password);
      if (response != null) {
        currentUser.value = User.fromJson(response['user']);
        DeviseBook.instance.load(
          response['devises'],
          legacyUsdRate: currentUser.value?.etablissement?.taux,
        );
        isLoggedIn.value = true;
        
        // Stockage des données utilisateur
        localStorage.write('user_data', currentUser.value?.toJson());
        
        await saveAccount(email);
        return true;
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> loginById(int userId, {bool silent = false}) async {
    if (!silent) isLoading.value = true;
    try {
      final response = await HttpManager.instance.loginMobile(userId, silent: silent);
      if (response != null) {
        currentUser.value = User.fromJson(response['user']);
        DeviseBook.instance.load(
          response['devises'],
          legacyUsdRate: currentUser.value?.etablissement?.taux,
        );
        isLoggedIn.value = true;

        // Stockage des données utilisateur
        localStorage.write('user_data', currentUser.value?.toJson());

        await saveAccount(userId.toString());
        return true;
      }
      // En silent, ne pas invalider la session locale si le réseau échoue.
      return silent && isLoggedIn.value;
    } finally {
      if (!silent) isLoading.value = false;
    }
  }

  void logout() {
    currentUser.value = null;
    isLoggedIn.value = false;
    // Suppression des données stockées
    localStorage.remove('user_data');
  }

  Future<void> loadSavedAccounts() async {
    final accounts = await _dbHelper.getAccounts();
    savedAccounts.assignAll(accounts);
  }

  Future<void> saveAccount(String id) async {
    if (id.trim().isEmpty) return;
    await _dbHelper.insertAccount(id.trim());
    await loadSavedAccounts();
  }

  Future<void> removeAccount(String id) async {
    await _dbHelper.deleteAccount(id);
    await loadSavedAccounts();
  }

  List<String> get filteredAccounts {
    final query = idController.text.trim().toLowerCase();
    if (query.isEmpty) return savedAccounts;
    return savedAccounts.where((a) => a.toLowerCase().contains(query)).toList();
  }

  void toggleObscure() => isObscure.value = !isObscure.value;

  @override
  void onClose() {
    _dayWatch?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    idController.dispose();
    passwordController.dispose();
    idFocusNode.dispose();
    super.onClose();
  }
}
