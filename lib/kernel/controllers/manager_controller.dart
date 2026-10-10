import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/models/order.dart';
import 'package:loyambo/kernel/models/user.dart';
import 'package:loyambo/kernel/services/api.dart';
import 'package:loyambo/kernel/services/http_manager.dart';

class ManagerController extends GetxController {
  static ManagerController get instance => Get.find();

  var dashboardCounts = {}.obs;
  var allFactures = <Order>[].obs;
  var allSells = <dynamic>[].obs;
  var servers = <User>[].obs;
  var selectedServer = Rxn<User?>(null);
  var isLoading = false.obs;
  void onInit() {
    super.onInit();
    _initData();
  }

  void _initData() {
    final user = Get.find<AuthController>().currentUser.value;
    if (user != null && user.isAdmin) {
      refreshManagerData();
    }
  }

  Future<void> refreshManagerData() async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user?.etsId == null) return;

    isLoading.value = true;
    try {
      final results = await Future.wait([
        HttpManager.instance.getDashboardCounts(user!.id!),
        HttpManager.instance.getAllFactures(user.etsId!, user.id!),
        HttpManager.instance.getAllSells(user.etsId!, user.id!),
      ]);

      dashboardCounts.assignAll(results[0] as Map<String, dynamic>);
      allFactures.assignAll(results[1] as List<Order>);
      allSells.assignAll(results[2] as List<dynamic>);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchServers() async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user?.etsId == null) return;

    try {
      final response = await Api.request(
        method: 'get',
        url: 'serveur/serveurs.all?user_id=${user!.id}',
      );

      if (response != null && response['status'] == 'success') {
        final List<dynamic> usersData = response['users'] ?? [];
        servers.assignAll(
          usersData
              .map((u) => User.fromJson(u as Map<String, dynamic>))
              .toList(),
        );
      }
    } catch (e) {
      print('Erreur lors de la récupération des serveurs: $e');
    }
  }
}
