import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/auth_controller.dart';
import 'package:loyambo/kernel/controllers/manager_controller.dart';
import 'package:loyambo/kernel/controllers/order_controller.dart';
import 'package:loyambo/kernel/models/order.dart';
import 'package:loyambo/kernel/models/product.dart';
import 'package:loyambo/kernel/models/restaurant_table.dart';
import 'package:loyambo/kernel/models/user.dart';
import 'package:loyambo/kernel/services/api.dart';
import 'package:loyambo/kernel/services/devise_book.dart';
import 'package:loyambo/kernel/services/database_helper.dart';
import 'package:loyambo/kernel/services/http_manager.dart';

class CartController extends GetxController with WidgetsBindingObserver {
  static CartController get instance => Get.find();

  var cart = <Product>[].obs;
  var allProducts = <Product>[].obs;
  var placeCatalogs = <PlaceCatalog>[].obs;
  var categories = <Category>[].obs;
  var tables = <RestaurantTable>[].obs;
  var selectedTable = Rxn<RestaurantTable>();
  var popularProducts = <Product>[].obs;

  var isLoading = false.obs;
  var isActionLoading = false.obs;

  // Callback pour afficher le panier depuis n'importe où
  VoidCallback? onShowCartRequested;

  // Cache pour un accès rapide aux produits par ID
  final RxMap<int, Product> productMap = <int, Product>{}.obs;

  Timer? _stockTimer;
  bool _syncingStock = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    if (Get.find<AuthController>().isLoggedIn.value) {
      refreshData();
    }
    _stockTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      syncStock();
    });
  }

  @override
  void onClose() {
    _stockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Sync stock sans bloquer l'UI (pas d'EasyLoading).
      Future.microtask(() => syncStock());
    }
  }

  Future<void> refreshData() async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user?.etsId == null) return;

    isLoading.value = true;
    try {
      final results = await Future.wait([
        _loadCatalog(user!),
        HttpManager.instance.getCategories(user.etsId!),
        HttpManager.instance.getTables(user.etsId!, user.id!),
      ]);

      final catalogs = results[0] as List<PlaceCatalog>;
      placeCatalogs.assignAll(catalogs);
      allProducts.assignAll(catalogs.expand((place) => place.products));
      productMap.assignAll({for (var p in allProducts) p.id: p});

      categories.assignAll(results[1] as List<Category>);
      tables.assignAll(results[2] as List<RestaurantTable>);

      await loadPopularProducts();
    } catch (e) {
      EasyLoading.showError("Erreur de synchronisation");
    } finally {
      isLoading.value = false;
    }
  }

  /// Met à jour les quantités sans recharger l'écran.
  Future<void> syncStock() async {
    if (_syncingStock || isLoading.value) return;
    final user = Get.find<AuthController>().currentUser.value;
    if (user?.etsId == null || placeCatalogs.isEmpty) return;

    _syncingStock = true;
    try {
      final fresh = await _loadCatalog(user!);
      _copyStock(fresh);
    } catch (_) {
    } finally {
      _syncingStock = false;
    }
  }

  void noteSale(Order order) {
    final placeId = order.table?.emplacementId;
    var changed = false;
    for (final item in order.items) {
      final product = productInPlace(item.id, placeId);
      if (product == null || !product.tracksStock) continue;
      final next = (product.availableStock ?? 0) - item.quantity;
      product.stockActuel = next <= 0 ? '0' : '$next';
      changed = true;
    }
    if (!changed) return;
    _pushStockToCart();
    _notifyStock();
  }

  void _copyStock(List<PlaceCatalog> fresh) {
    var changed = false;
    for (final incomingPlace in fresh) {
      PlaceCatalog? current;
      for (final place in placeCatalogs) {
        if (place.id == incomingPlace.id) {
          current = place;
          break;
        }
      }
      if (current == null) continue;
      for (final incoming in incomingPlace.products) {
        Product? existing;
        for (final product in current.products) {
          if (product.id == incoming.id) {
            existing = product;
            break;
          }
        }
        if (existing == null) continue;
        if (existing.stockActuel != incoming.stockActuel) {
          existing.stockActuel = incoming.stockActuel;
          changed = true;
        }
      }
    }
    if (!changed) return;
    _pushStockToCart();
    _notifyStock();
  }

  void _pushStockToCart() {
    for (final line in cart) {
      final source = productInPlace(line.id, line.placeId);
      if (source != null) line.stockActuel = source.stockActuel;
    }
  }

  void _notifyStock() {
    allProducts.refresh();
    placeCatalogs.refresh();
    popularProducts.refresh();
    cart.refresh();
  }

  Future<void> loadPopularProducts() async {
    try {
      final dbHelper = DatabaseHelper();
      final popularIds = await dbHelper.getPopularProductIds(limit: 6);

      if (popularIds.isEmpty) {
        popularProducts.clear();
        return;
      }

      final List<Product> filtered = [];
      for (var id in popularIds) {
        final product = productMap[id];
        if (product != null) {
          filtered.add(product);
        }
      }
      popularProducts.assignAll(filtered);
    } catch (e) {
      print("Error loading popular products: $e");
    }
  }

  Product? productInPlace(int productId, int? placeId) {
    if (placeId != null) {
      for (final place in placeCatalogs) {
        if (place.id != placeId) continue;
        for (final product in place.products) {
          if (product.id == productId) return product;
        }
      }
    }
    return productMap[productId];
  }

  Future<List<PlaceCatalog>> _loadCatalog(User user) async {
    final places = user.emplacements.isNotEmpty
        ? user.emplacements
        : (user.emplacementId != null
            ? [Emplacement(id: user.emplacementId!, libelle: '')]
            : <Emplacement>[]);
    final grouped = user.role == 'serveur' || user.role == 'caissier';
    if (!grouped || places.isEmpty) {
      final products = await HttpManager.instance.getProducts(user.etsId!);
      return [PlaceCatalog(id: 0, name: '', products: products)];
    }
    final catalogs = await Future.wait(places.map((place) async {
      final products = await HttpManager.instance.getProducts(user.etsId!, empId: place.id);
      return PlaceCatalog(
        id: place.id,
        name: place.libelle,
        products: products.map((product) => product.placedAt(place.id, place.libelle)).toList(),
      );
    }));
    return catalogs;
  }

  Future<void> selectTable(RestaurantTable table) async {
    // Le catalogue est déjà chargé par emplacement. On ne le remplace pas
    // par le prix d'une seule table, pour garder le stock de chaque lieu.
    if (selectedTable.value == null && placeCatalogs.every((place) => place.id == 0)) {
      final user = Get.find<AuthController>().currentUser.value;
      if (user?.etsId != null) {
        EasyLoading.show(status: 'Mise à jour des prix...');
        try {
          final updatedProducts = await HttpManager.instance.getProducts(
            user!.etsId!,
            empId: table.emplacementId,
          );
          
          if (updatedProducts.isNotEmpty) {
            allProducts.assignAll(updatedProducts);
            productMap.assignAll({for (var p in allProducts) p.id: p});
            // Recharger les produits populaires avec les nouveaux prix
            await loadPopularProducts();
          }
        } catch (e) {
          debugPrint("Erreur rechargement prix par emplacement: $e");
        } finally {
          EasyLoading.dismiss();
        }
      }
    }
    selectedTable.value = table;
  }

  void addToCart(Product product) {
    final user = Get.find<AuthController>().currentUser.value;
    if (user != null && user.role != 'admin' && !user.allows('passer-commandes')) {
      EasyLoading.showError("Vous n'avez pas le droit de passer une commande.");
      return;
    }
    final latestProduct = product.placeId != null
        ? product
        : (productMap[product.id] ?? product);

    final incomingPlace = latestProduct.placeId;
    if (cart.isNotEmpty && incomingPlace != null && incomingPlace > 0) {
      final currentPlace = cart.first.placeId;
      if (currentPlace != null && currentPlace > 0 && currentPlace != incomingPlace) {
        EasyLoading.showInfo(
          "Validez d'abord la commande en cours avant de prendre des articles dans un autre emplacement.",
          duration: const Duration(seconds: 4),
        );
        return;
      }
    }

    int index = cart.indexWhere(
      (p) => p.id == latestProduct.id && p.placeId == latestProduct.placeId,
    );
    int currentQty = (index != -1) ? cart[index].quantity : 0;

    if (latestProduct.tracksStock) {
      final stock = latestProduct.availableStock ?? 0;
      if ((currentQty + 1) > stock) {
        EasyLoading.showError(
          _shortageLine(latestProduct.name, stock),
          duration: const Duration(seconds: 4),
        );
        return;
      }
    }

    if (index != -1) {
      cart[index].quantity++;
      cart.refresh();
    } else {
      final newProduct = Product(
        id: latestProduct.id,
        name: latestProduct.name,
        category: latestProduct.category,
        categoryType: latestProduct.categoryType,
        price: latestProduct.price,
        image: latestProduct.image,
        stockActuel: latestProduct.stockActuel,
        quantified: latestProduct.quantified,
        currency: latestProduct.currency,
        placeId: latestProduct.placeId,
        placeName: latestProduct.placeName,
        quantity: 1,
      );
      cart.add(newProduct);
    }
  }

  void removeFromCart(Product product) {
    int index = cart.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      if (cart[index].quantity > 1) {
        cart[index].quantity--;
        cart.refresh();
      } else {
        cart.removeAt(index);
      }
    }
  }

  void clearCart() {
    cart.clear();
    selectedTable.value = null;
    if (Get.isRegistered<ManagerController>()) {
      Get.find<ManagerController>().selectedServer.value = null;
    }
  }

  void cancelOrder() {
    clearCart();
  }

  void showCart() {
    if (onShowCartRequested != null) {
      onShowCartRequested!();
    } else {
      debugPrint("CartController: onShowCartRequested est null.");
    }
  }

  /// Relit le stock via GET /products avant d'envoyer.
  /// Retourne le message à afficher, ou null si la quantité passe.
  Future<String?> shortageMessage(List<Product> items, {int? placeId}) async {
    final user = Get.find<AuthController>().currentUser.value;
    if (user?.etsId == null || items.isEmpty) return null;

    final fresh = await HttpManager.instance.getProducts(
      user!.etsId!,
      empId: (placeId != null && placeId > 0) ? placeId : null,
    );
    if (fresh.isEmpty) {
      return "Impossible de vérifier le stock. Réessayez.";
    }

    final byId = {for (final product in fresh) product.id: product};
    final wanted = <int, int>{};
    final names = <int, String>{};
    for (final item in items) {
      wanted[item.id] = (wanted[item.id] ?? 0) + item.quantity;
      names[item.id] = item.name;
    }

    final lines = <String>[];
    for (final entry in wanted.entries) {
      final live = byId[entry.key];
      if (live == null || !live.tracksStock) continue;
      final stock = live.availableStock ?? 0;
      if (entry.value > stock) {
        lines.add(_shortageLine(names[entry.key] ?? 'Produit', stock));
      }
    }

    for (final live in fresh) {
      final existing = productInPlace(live.id, placeId);
      if (existing != null) existing.stockActuel = live.stockActuel;
    }
    _pushStockToCart();
    _notifyStock();

    return lines.isEmpty ? null : lines.join('\n');
  }

  String _shortageLine(String name, int stock) {
    return "Stock insuffisant pour $name : il n'en reste que $stock.";
  }

  Future<bool> validateOrder() async {
    if (isActionLoading.value) return false;

    dynamic user;
    if (Get.isRegistered<ManagerController>()) {
      user = Get.find<ManagerController>().selectedServer.value;
    }
    user ??= Get.find<AuthController>().currentUser.value;

    if (user?.id == null || selectedTable.value == null || cart.isEmpty) {
      EasyLoading.showInfo("Veuillez finaliser la sélection");
      return false;
    }

    isActionLoading.value = true;
    EasyLoading.show(status: "Vérification du stock...");
    try {
      final shortage = await shortageMessage(
        cart.toList(),
        placeId: selectedTable.value?.emplacementId,
      );
      if (shortage != null) {
        EasyLoading.showError(shortage, duration: const Duration(seconds: 5));
        return false;
      }

      final itemsToTrack = List<Product>.from(cart);
      EasyLoading.show(status: "Enregistrement...");

      final response = await Api.request(
        method: 'post',
        url: 'orders',
        body: {
          'ets_id': user.etsId,
          'table_id': selectedTable.value!.id,
          'user_id': user.id,
          'details': cart
              .map(
                (p) => {
                  'produit_id': p.id,
                  'quantite': p.quantity,
                  'prix_unitaire': DeviseBook.instance.roundMoney(p.price),
                  'devise': p.currency,
                },
              )
              .toList(),
        },
      );

      if (response != null && response['status'] == 'success') {
        Order? newOrder;
        if (response['result'] != null) {
          newOrder = Order.fromJson(response['result']);
        }

        clearCart();
        EasyLoading.showSuccess("Commande créée avec succès");

        final dbHelper = DatabaseHelper();
        for (var item in itemsToTrack) {
          dbHelper.incrementProductPopularity(item.id, item.quantity);
        }

        loadPopularProducts();
        Get.find<OrderController>().fetchOrders(silent: true);
        return true;
      }
      final errors = response is Map ? response['errors'] : null;
      EasyLoading.showError(
        errors == null ? "Commande refusée" : errors.toString(),
        duration: const Duration(seconds: 5),
      );
      return false;
    } catch (e) {
      EasyLoading.showError("Erreur lors de la création");
      return false;
    } finally {
      isActionLoading.value = false;
    }
  }

  int get cartCount => cart.fold(0, (sum, item) => sum + item.quantity);
  double get totalAmount =>
      cart.fold(0, (sum, item) => sum + (item.price * item.quantity));

  bool tableMatchesProduct(RestaurantTable? table, Product product) {
    if (table == null) return false;
    if (product.placeId == null || product.placeId == 0) return true;
    return table.emplacementId == product.placeId;
  }

  Map<String, List<RestaurantTable>> tablesForProduct(Product? product) {
    final placeId = product?.placeId;
    final source = (placeId == null || placeId == 0)
        ? tables
        : tables.where((table) => table.emplacementId == placeId);
    final grouped = <String, List<RestaurantTable>>{};
    for (final table in source) {
      final loc = table.location ?? product?.placeName ?? "Général";
      grouped.putIfAbsent(loc, () => []).add(table);
    }
    return grouped;
  }

  Map<String, List<RestaurantTable>> get groupedTables => tablesForProduct(null);
}

class PlaceCatalog {
  final int id;
  final String name;
  final List<Product> products;

  PlaceCatalog({
    required this.id,
    required this.name,
    required this.products,
  });
}
