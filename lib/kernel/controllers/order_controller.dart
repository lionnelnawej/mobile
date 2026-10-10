import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/controllers/cart_controller.dart';
import 'package:loyambo/kernel/controllers/manager_controller.dart';
import 'package:loyambo/kernel/models/order.dart';
import 'package:loyambo/kernel/models/product.dart';
import 'package:loyambo/kernel/services/chime.dart';
import 'package:loyambo/kernel/services/http_manager.dart';

class OrderController extends GetxController with WidgetsBindingObserver {
  static OrderController get instance => Get.find();

  var orders = <Order>[].obs;
  var doneOrders = <Order>[].obs;
  var showDone = false.obs;
  var isLoading = false.obs;
  var isActionLoading = false.obs;
  Timer? _timer;
  bool _readyPrimed = false;
  bool _fetching = false;
  Set<int> _readyIds = {};

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    fetchOrders();
    // Plus fréquent pour voir immédiatement une fusion faite depuis le web.
    _timer = Timer.periodic(const Duration(seconds: 12), (timer) {
      fetchOrders(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchOrders(silent: true);
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.onClose();
  }

  Future<void> fetchOrders({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!silent) isLoading.value = true;
    try {
      final activeOrders = await HttpManager.instance.getOrdersActive();
      if (activeOrders == null) return;
      // Ne jamais afficher les factures absorbées par une fusion.
      final visible = activeOrders
          .where((order) => order.status != 'fusionnée' && order.status != 'annulée')
          .toList();
      final readyNow = visible.where((order) => order.kitchenReady || order.barReady).map((order) => order.id).toSet();
      final role = Get.find<AuthController>().currentUser.value?.role;
      if (_readyPrimed && (role == 'serveur' || role == 'caissier') && readyNow.difference(_readyIds).isNotEmpty) {
        Chime.play();
      }
      _readyIds = readyNow;
      _readyPrimed = true;
      orders.assignAll(visible);
    } finally {
      _fetching = false;
      if (!silent) isLoading.value = false;
    }
  }

  Future<void> fetchDone() async {
    final list = await HttpManager.instance.getDoneOrders();
    if (list != null) doneOrders.assignAll(list);
  }

  Future<void> updateOrderProducts(int orderId, List<Product> items) async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user == null) return;

    isActionLoading.value = true;
    EasyLoading.show(status: 'Mise à jour...');

    try {
      final order = orders.firstWhereOrNull((o) => o.id == orderId);
      final result = await HttpManager.instance.saveOrder(
        factureId: orderId,
        tableId: order?.table?.id ?? 0,
        userId: user.id!,
        etsId: user.etsId!,
        items: items,
      );

      if (result != null) {
        await fetchOrders(silent: true);
        EasyLoading.showSuccess("Mise à jour effectuée");
      }
    } catch (e) {
      EasyLoading.showError("Erreur lors de la mise à jour");
    } finally {
      isActionLoading.value = false;
      if (EasyLoading.isShow) EasyLoading.dismiss();
    }
  }

  Future<void> grantBonus(int orderId, Product product) async {
    final actor = Get.find<AuthController>().currentUser.value;
    if (actor == null || !actor.canGrantBonus) {
      EasyLoading.showError("Vous n'avez pas le droit d'accorder un bonus.");
      return;
    }
    isActionLoading.value = true;
    EasyLoading.show(status: "Bonus...");
    try {
      final error = await HttpManager.instance.grantBonus(orderId, product.id);
      if (error == null) {
        await fetchOrders(silent: true);
        if (Get.isRegistered<CartController>()) {
          unawaited(Get.find<CartController>().syncStock());
        }
        EasyLoading.showSuccess("Bonus ajouté");
      } else {
        EasyLoading.showError(error);
      }
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> addProductToOrder(int orderId, Product product) async {
    final actor = Get.find<AuthController>().currentUser.value;
    if (actor != null && !actor.canModifyOrder) {
      EasyLoading.showError("Vous n'avez pas le droit de modifier une commande.");
      return;
    }
    final order = orders.firstWhereOrNull((o) => o.id == orderId);
    if (order == null) return;

    var currentItems = order.items
        .map(
          (item) => Product(
            id: item.id,
            name: item.name,
            category: item.category,
            categoryType: item.categoryType,
            price: item.price,
            image: item.image,
            stockActuel: item.stockActuel,
            quantified: item.quantified,
            currency: item.currency,
            quantity: item.quantity,
          ),
        )
        .toList();

    int itemIndex = currentItems.indexWhere((p) => p.id == product.id);
    final nextQty = itemIndex != -1 ? currentItems[itemIndex].quantity + 1 : 1;

    if (Get.isRegistered<CartController>()) {
      final shortage = await Get.find<CartController>().shortageMessage(
        [
          Product(
            id: product.id,
            name: product.name,
            price: product.price,
            category: product.category,
            quantity: nextQty,
          ),
        ],
        placeId: order.table?.emplacementId,
      );
      if (shortage != null) {
        EasyLoading.showError(shortage, duration: const Duration(seconds: 5));
        return;
      }
    }

    final catalog = Get.isRegistered<CartController>()
        ? Get.find<CartController>().productInPlace(product.id, order.table?.emplacementId)
        : null;
    final stockSource = catalog ?? product;

    if (itemIndex != -1) {
      currentItems[itemIndex].quantity++;
    } else {
      currentItems.add(
        Product(
          id: product.id,
          name: product.name,
          category: product.category,
          categoryType: product.categoryType,
          price: product.price,
          image: product.image,
          stockActuel: stockSource.stockActuel,
          quantified: stockSource.quantified,
          currency: product.currency,
          quantity: 1,
        ),
      );
    }

    await updateOrderProducts(orderId, currentItems);
  }

  Future<void> decreaseProductQuantity(int orderId, int productId) async {
    final actor = Get.find<AuthController>().currentUser.value;
    if (actor != null && !actor.canModifyOrder) {
      EasyLoading.showError("Vous n'avez pas le droit de modifier une commande.");
      return;
    }
    final order = orders.firstWhereOrNull((o) => o.id == orderId);
    if (order == null) return;

    var currentItems = order.items
        .map(
          (item) => Product(
            id: item.id,
            name: item.name,
            category: item.category,
            categoryType: item.categoryType,
            price: item.price,
            image: item.image,
            stockActuel: item.stockActuel,
            quantified: item.quantified,
            currency: item.currency,
            quantity: item.quantity,
          ),
        )
        .toList();

    int itemIndex = currentItems.indexWhere((p) => p.id == productId);

    if (itemIndex != -1) {
      if (currentItems[itemIndex].quantity > 1) {
        currentItems[itemIndex].quantity--;
      } else {
        currentItems.removeAt(itemIndex);
      }
      await updateOrderProducts(orderId, currentItems);
    }
  }

  Future<void> changeTable(
    int orderId,
    int sourceTableId,
    int targetTableId,
  ) async {
    isActionLoading.value = true;
    EasyLoading.show(status: "Chargement...");
    try {
      final error = await HttpManager.instance.updateOrderTable(
        orderId,
        sourceTableId,
        targetTableId,
      );
      if (error == null) {
        await fetchOrders(silent: true);
        EasyLoading.showSuccess("Commande déplacée");
      } else {
        EasyLoading.showError(error);
      }
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> mergeOrders(List<int> factureIds, int tableId) async {
    if (factureIds.length < 2) return;

    isActionLoading.value = true;
    EasyLoading.show(status: "Chargement...");
    try {
      final error = await HttpManager.instance.mergeOrdersMultiple(
        factureIds,
        tableId,
      );
      if (error == null) {
        await fetchOrders(silent: true);
        EasyLoading.showSuccess("Fusion réussie");
      } else {
        EasyLoading.showError(error);
      }
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<bool> deleteOrder(int orderId) async {
    isActionLoading.value = true;
    EasyLoading.show(status: "Suppression...");
    try {
      final success = await HttpManager.instance.deleteOrder(orderId);
      if (success) {
        orders.removeWhere((order) => order.id == orderId);
        await fetchOrders(silent: true);
      }
      return success;
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> servingItem(int orderId) async {
    isActionLoading.value = true;
    EasyLoading.show(status: "Chargement...");
    try {
      bool success = await HttpManager.instance.servirCommande(orderId);
      if (success) {
        EasyLoading.showSuccess("Commande servie.");
        await fetchOrders(silent: true);
      }
    } finally {
      isActionLoading.value = false;
      EasyLoading.dismiss();
    }
  }

  Future<bool> encaissement(
    int orderId,
    int etsId,
    String method, {
    String devise = 'native',
    double remise = 0,
    String remiseType = 'pourcent',
    String remiseDevise = 'FC',
  }) async {
    isActionLoading.value = true;
    EasyLoading.show(status: "Encaissement...");
    try {
      final error = await HttpManager.instance.payOrder(
        orderId,
        etsId,
        method: method,
        devise: devise,
        remise: remise,
        remiseType: remiseType,
        remiseDevise: remiseDevise,
      );
      if (error == null) {
        final sold = orders.cast<Order?>().firstWhere(
          (order) => order!.id == orderId,
          orElse: () => null,
        );
        if (sold != null && Get.isRegistered<CartController>()) {
          Get.find<CartController>().noteSale(sold);
        }
        await fetchOrders(silent: true);
        if (Get.isRegistered<CartController>()) {
          unawaited(Get.find<CartController>().syncStock());
        }
        if (Get.isRegistered<ManagerController>()) {
          await Get.find<ManagerController>().refreshManagerData();
        }
        EasyLoading.showSuccess("Encaissement réussi");
        return true;
      }
      EasyLoading.showError(error);
      return false;
    } catch (e) {
      EasyLoading.showError("Erreur lors de l'encaissement");
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  Future<void> remotePrint(int orderId, int etsId) async {
    isActionLoading.value = true;
    try {
      await HttpManager.instance.printOrderRemote(orderId, etsId);
    } finally {
      isActionLoading.value = false;
    }
  }
}
