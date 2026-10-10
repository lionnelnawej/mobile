import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import '/kernel/models/product.dart';
import '/kernel/models/restaurant_table.dart';
import '/kernel/models/order.dart';
import '/kernel/services/api.dart';
import '/kernel/services/devise_book.dart';

class HttpManager extends GetxService {
  static HttpManager get instance => Get.find();

  // --- AUTHENTIFICATION ---

  Future<Map<String, dynamic>?> login(String email, String password) async {
    EasyLoading.show(status: 'Connexion...');
    try {
      final response = await Api.request(
        method: 'post',
        url: 'login',
        body: {
          'email': email,
          'password': password,
        },
      );

      if (response != null && response['status'] == 'success') {
        EasyLoading.dismiss();
        return response;
      } else {
        EasyLoading.showError(_extractErrorMessage(response));
      }
    } catch (e) {
      dev.log("Login Error: $e");
      EasyLoading.showError("Erreur de connexion au serveur");
    }
    return null;
  }

  Future<Map<String, dynamic>?> loginMobile(int userId, {bool silent = false}) async {
    if (!silent) EasyLoading.show(status: 'Connexion...');
    try {
      final response = await Api.request(
        method: 'post',
        url: 'mobile/login',
        body: {'user_id': userId},
      );

      if (response != null && response['status'] == 'success') {
        if (!silent) EasyLoading.dismiss();
        return response;
      } else if (!silent) {
        EasyLoading.showError(_extractErrorMessage(response));
      }
    } catch (e) {
      dev.log("LoginMobile Error: $e");
      if (!silent) EasyLoading.showError("Erreur de connexion");
    }
    return null;
  }

  // --- CONFIGURATION & DONNÉES ---

  Future<List<Category>> getCategories(int etsId) async {
    try {
      final response = await Api.request(
        method: 'get',
        url: 'categories?ets_id=$etsId',
      );

      if (response != null && response['categories'] != null) {
        return (response['categories'] as List)
            .map((json) => Category.fromJson(json))
            .toList();
      }
    } catch (e) {
      dev.log("GetCategories Error: $e");
    }
    return [];
  }

  Future<List<Product>> getProducts(int etsId, {int? empId}) async {
    try {
      String url = 'products?ets_id=$etsId';
      if (empId != null) {
        url += '&emp_id=$empId';
      }
      
      final response = await Api.request(
        method: 'get',
        url: url,
      );

      final list = response?['produits'] ?? response?['products'];
      if (list != null) {
        return (list as List)
            .map((json) => Product.fromJson(json))
            .toList();
      }
    } catch (e) {
      dev.log("GetProducts Error: $e");
    }
    return [];
  }

  Future<List<Emplacement>> getAreas(int etsId) async {
    try {
      final response = await Api.request(
        method: 'get',
        url: 'areas?ets_id=$etsId',
      );

      final list = response?['emplacements'] ?? response?['areas'];
      if (list != null) {
        return (list as List)
            .map((json) => Emplacement.fromJson(json))
            .toList();
      }
    } catch (e) {
      dev.log("GetAreas Error: $e");
    }
    return [];
  }

  Future<List<RestaurantTable>> getTables(int etsId, int userId) async {
    try {
      final response = await Api.request(
        method: 'get',
        url: 'tables?ets_id=$etsId&user_id=$userId',
      );

      if (response != null && response['tables'] != null) {
        return (response['tables'] as List)
            .map((json) => RestaurantTable.fromJson(json))
            .toList();
      }
    } catch (e) {
      dev.log("GetTables Error: $e");
    }
    return [];
  }

  // --- GESTION DES COMMANDES (ORDERS) ---

  Future<List<Order>?> getOrdersActive() async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return [];

    try {
      String query = user.role == 'admin' ? "ets_id=${user.etsId}" : "user_id=${user.id}";
      
      final response = await Api.request(
        method: 'get',
        url: 'orders/active?$query',
      );

      final list = response?['commandes'] ?? response?['orders'];
      if (response != null && response['status'] == 'success' && list != null) {
        return (list as List)
            .map((json) => Order.fromJson(json))
            .toList();
      }
    } catch (e) {
      dev.log("getOrdersActive Error: $e");
    }
    return null;
  }

  Future<List<Order>?> getDoneOrders() async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return [];
    try {
      final response = await Api.request(
        method: 'get',
        url: 'orders/done?user_id=${user.id}',
      );
      final list = response?['commandes'];
      if (response != null && response['status'] == 'success' && list is List) {
        return list.map((json) => Order.fromJson(Map<String, dynamic>.from(json as Map))).toList();
      }
    } catch (e) {
      dev.log("getDoneOrders Error: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>?> getStationTickets(String service) async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return [];
    try {
      final response = await Api.request(
        method: 'get',
        url: 'kitchen?service=$service&user_id=${user.id}',
      );
      final list = response?['tickets'];
      if (response != null && list is List) {
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (e) {
      dev.log("getStationTickets Error: $e");
    }
    return null;
  }

  Future<bool> markStationReady(int ticketId, String service) async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return false;
    try {
      final response = await Api.request(
        method: 'post',
        url: 'kitchen/$ticketId/ready',
        body: {'user_id': user.id, 'service': service},
      );
      return response != null && response['status'] == 'success';
    } catch (e) {
      dev.log("markStationReady Error: $e");
    }
    return false;
  }

  Future<Order?> getOrderDetails(int orderId, int etsId) async {
    try {
      final response = await Api.request(
        method: 'get',
        url: 'orders/$orderId?ets_id=$etsId',
      );

      if (response != null && response['status'] == 'success' && response['commande'] != null) {
        return Order.fromJson(response['commande']);
      }
    } catch (e) {
      dev.log("getOrderDetails Error: $e");
    }
    return null;
  }

  Future<Order?> saveOrder({
    int? factureId,
    required int tableId,
    required int userId,
    required int etsId,
    required List<Product> items,
    double remise = 0,
  }) async {
    EasyLoading.show(status: 'Enregistrement...');
    try {
      final response = await Api.request(
        method: 'post',
        url: 'orders',
        body: {
          'ets_id': etsId,
          'facture_id': factureId,
          'table_id': tableId,
          'user_id': userId,
          'remise': remise,
          'details': items.map((p) => {
            'produit_id': p.id,
            'quantite': p.quantity,
            'prix_unitaire': DeviseBook.instance.roundMoney(p.price),
            'devise': p.currency,
            'bonus': p is OrderItem && p.isBonus ? 1 : 0,
            'groupe_libelle': p is OrderItem ? p.groupLabel : null,
          }).toList(),
        },
      );

      if (response != null && response['status'] == 'success' && response['result'] != null) {
        EasyLoading.dismiss();
        return Order.fromJson(response['result']);
      } else {
        EasyLoading.showError(_extractErrorMessage(response));
      }
    } catch (e) {
      dev.log("SaveOrder Error: $e");
    }
    return null;
  }

  Future<bool> deleteOrder(int orderId) async {
    try {
      final response = await Api.request(
        method: 'post',
        url: 'orders/$orderId/delete',
        body: {
          'user_id': Get.find<AuthController>().currentUser.value?.id,
        },
      );
      if (response != null && response['status'] == 'success') {
        EasyLoading.showSuccess('Commande supprimée');
        return true;
      }
      EasyLoading.showError(_extractErrorMessage(response));
    } catch (e) {
      dev.log("deleteOrder Error: $e");
      EasyLoading.showError("Erreur lors de la suppression");
    }
    return false;
  }

  Future<String?> updateOrderTable(int orderId, int sourceTableId, int targetTableId) async {
    try {
      final response = await Api.request(
        method: 'patch', 
        url: 'orders/$orderId/table',
        body: {
          'op': 'transfert',
          'source_id': sourceTableId,
          'cible_id': targetTableId,
          'facture_id': orderId,
          'user_id': Get.find<AuthController>().currentUser.value?.id,
        },
      );
      if (response != null && response['status'] == 'success') return null;
      return _extractErrorMessage(response);
    } catch (e) {
      return "Le transfert n'a pas abouti.";
    }
  }

  Future<String?> grantBonus(int orderId, int productId) async {
    try {
      final response = await Api.request(
        method: 'post',
        url: 'orders/$orderId/bonus',
        body: {
          'facture_id': orderId,
          'produit_id': productId,
          'quantite': 1,
          'user_id': Get.find<AuthController>().currentUser.value?.id,
        },
      );
      if (response != null && response['status'] == 'success') return null;
      return _extractErrorMessage(response);
    } catch (e) {
      return "Le bonus n'a pas pu être ajouté.";
    }
  }

  Future<String?> mergeOrdersMultiple(List<int> factureIds, int tableId) async {
    try {
      final response = await Api.request(
        method: 'post',
        url: 'orders/merge',
        body: {
          'facture_ids': factureIds,
          'table_id': tableId,
          'user_id': Get.find<AuthController>().currentUser.value?.id,
        },
      );
      if (response != null && response['status'] == 'success') return null;
      return _extractErrorMessage(response);
    } catch (e) {
      return "La fusion n'a pas abouti.";
    }
  }

  Future<String?> payOrder(
    int orderId,
    int etsId, {
    String method = "cash",
    String devise = "native",
    double remise = 0,
    String remiseType = "pourcent",
    String remiseDevise = "FC",
  }) async {
    try {
      final userId = Get.find<AuthController>().currentUser.value?.id;
      final response = await Api.request(
        method: 'post',
        url: 'orders/$orderId/pay',
        body: {
          'ets_id': etsId,
          'user_id': userId,
          'devise': devise,
          'mode': method,
          'methode': method,
          'remise': remise,
          'remise_type': remiseType,
          'remise_devise': remiseDevise,
        },
      );
      if (response != null && response['status'] == 'success') return null;
      final errors = response?['errors'] ?? response?['error'];
      if (errors is List && errors.isNotEmpty) return errors.join('\n');
      if (errors is String && errors.isNotEmpty) return errors;
      if (response is Map && response['message'] != null) {
        return response['message'].toString();
      }
      return "Erreur lors de l'encaissement";
    } catch (e) {
      return "Erreur lors de l'encaissement";
    }
  }

  Future<bool> servirCommande(int orderId) async {
    try {
      final response = await Api.request(
        method: 'post',
        url: 'serveur/cmd.servir',
        body: {
          "id":orderId
        }
      );
      return (response != null && response['status'] == 'success');
    } catch (e) {
      return false;
    }
  }

  // --- ENDPOINTS CAISSIER / MANAGER ---

  Future<List<Order>> getAllFactures(int etsId, int userId) async {
    try {
      final response = await Api.request(
        method: 'get',
        url: 'caissier/factures.all?ets_id=$etsId&user_id=$userId',
      );
      if (response != null && response['status'] == 'success') {
        final list = response['factures'] ?? response['commandes'] ?? [];
        return (list as List).map((json) => Order.fromJson(json)).toList();
      }
    } catch (e) {}
    return [];
  }

  Future<Map<String, dynamic>> getDashboardCounts(int userId) async {
    try {
      final response = await Api.request(
        method: 'get',
        url: 'caissier/counts.all?user_id=$userId',
      );
      return (response != null && response['counts'] != null) ? response['counts'] : {};
    } catch (e) {}
    return {};
  }

  Future<List<dynamic>> getAllSells(int etsId, int userId) async {
    try {
      final response = await Api.request(
        method: 'get',
        url: 'caissier/sells.all?ets_id=$etsId&user_id=$userId',
      );
      return (response != null) ? (response['ventes'] ?? response['sells'] ?? []) : [];
    } catch (e) {}
    return [];
  }

  Future<Map<String, dynamic>?> dayStatus() async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user?.id == null) return null;
    try {
      final response = await Api.request(
        method: 'get',
        url: 'admin/day.status?user_id=${user!.id}',
      );
      if (response != null && response['status'] == 'success') return response;
    } catch (e) {
      dev.log("dayStatus Error: $e");
    }
    return null;
  }

  Future<Map<String, dynamic>?> startDay(double rate, List<int> serveurIds) async {
    final user = Get.find<AuthController>().currentUser.value;
    try {
      return await Api.request(
        method: 'post',
        url: 'admin/day.start',
        body: {
          'user_id': user?.id,
          'currencie_value': rate,
          'serveur_ids': serveurIds,
        },
      );
    } catch (e) {
      dev.log("startDay Error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> saveCashReport({
    required int serveurId,
    required Map<String, double> especes,
    required int ticketsServeur,
    required int ticketsEmis,
    required double valeurTheorique,
  }) async {
    final user = Get.find<AuthController>().currentUser.value;
    try {
      return await Api.request(
        method: 'post',
        url: 'admin/day.close.report',
        body: {
          'user_id': user?.id,
          'serveur_id': serveurId,
          'especes': especes,
          'tickets_serveur': ticketsServeur,
          'tickets_emis': ticketsEmis,
          'valeur_theorique': valeurTheorique,
        },
      );
    } catch (e) {
      dev.log("saveCashReport Error: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> closeDay() async {
    final user = Get.find<AuthController>().currentUser.value;
    try {
      return await Api.request(
        method: 'post',
        url: 'admin/day.close',
        body: {'user_id': user?.id},
      );
    } catch (e) {
      dev.log("closeDay Error: $e");
      return null;
    }
  }

  Future<bool> printOrderRemote(int orderId, int etsId) async {
    try {
      final response = await Api.request(
        method: 'post',
        url: 'orders/$orderId/print',
        body: {'ets_id': etsId},
      );
      return (response != null && response['success'] == true);
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> staffReport() async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user?.id == null) return null;
    try {
      final response = await Api.request(
        method: 'get',
        url: 'staff/day-report?user_id=${user!.id}',
      );
      if (response != null && response['status'] == 'success') return Map<String, dynamic>.from(response);
    } catch (e) {
      dev.log("staffReport Error: $e");
    }
    return null;
  }

  Future<String?> submitStaffReport(int ticketsPhysique) async {
    final user = Get.find<AuthController>().currentUser.value;
    try {
      final response = await Api.request(
        method: 'post',
        url: 'staff/day-report',
        body: {
          'user_id': user?.id,
          'tickets_physique': ticketsPhysique,
        },
      );
      if (response != null && response['status'] == 'success') return null;
      return _extractErrorMessage(response);
    } catch (e) {
      return "Le rapport n'a pas pu être envoyé.";
    }
  }

  Future<Map<String, dynamic>?> dayRoster() async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user?.id == null) return null;
    try {
      final response = await Api.request(
        method: 'get',
        url: 'day/roster?user_id=${user!.id}',
      );
      if (response != null && response['status'] == 'success') return Map<String, dynamic>.from(response);
    } catch (e) {
      dev.log("dayRoster Error: $e");
    }
    return null;
  }

  Future<String?> toggleRoster(int serveurId, bool present) async {
    final user = Get.find<AuthController>().currentUser.value;
    try {
      final response = await Api.request(
        method: 'post',
        url: 'day/roster',
        body: {
          'user_id': user?.id,
          'serveur_id': serveurId,
          'present': present,
        },
      );
      if (response != null && response['status'] == 'success') return null;
      return _extractErrorMessage(response);
    } catch (e) {
      return "La présence n'a pas pu être modifiée.";
    }
  }

  // --- UTILITAIRES ---

  String _extractErrorMessage(dynamic response) {
    if (response == null) return "Une erreur est survenue.";
    if (response is Map) {
      if (response.containsKey("errors")) {
        var err = response["errors"];
        if (err is List && err.isNotEmpty) return err[0].toString();
        if (err is Map && err.isNotEmpty) {
          var firstVal = err.values.first;
          return firstVal is List ? firstVal[0].toString() : firstVal.toString();
        }
        return err.toString();
      }
      if (response.containsKey("message")) return response["message"].toString();
    }
    return "Une erreur inconnue est survenue.";
  }
}
