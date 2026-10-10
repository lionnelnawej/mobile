import 'package:get/get.dart';
import 'package:loyambo/kernel/controllers/cart_controller.dart';
import 'package:loyambo/kernel/models/product.dart';
import 'package:loyambo/kernel/services/devise_book.dart';
import 'package:loyambo/kernel/models/restaurant_table.dart';
import 'package:loyambo/kernel/models/user.dart';

class OrderItem extends Product {
  final int detailId;
  final String? itemServiceStatus;
  final String? groupLabel;
  final bool isBonus;

  OrderItem({
    required int id,
    required String name,
    required double price,
    required String category,
    String? categoryType,
    String? image,
    String? stockActuel,
    bool quantified = true,
    String currency = 'FC',
    int quantity = 0,
    required this.detailId,
    this.itemServiceStatus,
    this.groupLabel,
    this.isBonus = false,
  }) : super(
          id: id,
          name: name,
          price: price,
          category: category,
          categoryType: categoryType,
          image: image,
          stockActuel: stockActuel,
          quantified: quantified,
          currency: currency,
          quantity: quantity,
        );

  bool get isServed => itemServiceStatus == "servie";
}

class Order {
  final int id;
  final String? numeroFacture;
  final DateTime createdAt;
  final String status;
  final String? statusService;
  final bool kitchenReady;
  final bool barReady;
  double totalTtc;
  final RestaurantTable? table;
  final User? user;
  List<OrderItem> items;

  Order({
    required this.id,
    this.numeroFacture,
    required this.createdAt,
    required this.status,
    this.statusService,
    this.kitchenReady = false,
    this.barReady = false,
    required this.totalTtc,
    this.table,
    this.user,
    this.items = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    var details = json['details'] as List? ?? [];
    
    // Récupération du cache pour accélération
    Map<int, Product>? productCache;
    try {
      if (Get.isRegistered<CartController>()) {
        productCache = Get.find<CartController>().productMap;
      }
    } catch (_) {}

    List<OrderItem> products = details.map((d) {
      final int detailId = d['id'];
      final String? itemStatus = d['statut_service'];
      Product p;
      
      if (d['produit'] != null) {
        p = Product.fromJson(d['produit']);
      } else {
        final int prodId = d['produit_id'];
        final double price = DeviseBook.instance.parseMoney(d['prix_unitaire']);
        
        // Recherche ultra-rapide via la Map injectée dans CartController
        Product? cachedProduct = productCache?[prodId];

        if (cachedProduct != null) {
          p = Product(
            id: cachedProduct.id,
            name: cachedProduct.name,
            category: cachedProduct.category,
            categoryType: cachedProduct.categoryType,
            price: price,
            image: cachedProduct.image,
            stockActuel: cachedProduct.stockActuel,
            quantified: cachedProduct.quantified,
            currency: cachedProduct.currency,
          );
        } else {
          p = Product(
            id: prodId,
            name: "Produit #$prodId",
            price: price,
            category: "Général",
            currency: (d['devise'] ?? 'FC').toString(),
          );
        }
      }
      
      return OrderItem(
        id: p.id,
        name: p.name,
        category: p.category,
        categoryType: p.categoryType,
        price: d['prix_unitaire'] == null ? p.price : DeviseBook.instance.parseMoney(d['prix_unitaire']),
        image: p.image,
        stockActuel: p.stockActuel ?? productCache?[p.id]?.stockActuel,
        quantified: p.quantified,
        currency: _lineCurrency(d['devise'], p.currency),
        quantity: d['quantite'] is int ? d['quantite'] : int.tryParse(d['quantite'].toString()) ?? 0,
        detailId: detailId,
        itemServiceStatus: itemStatus,
        groupLabel: (d['groupe_libelle'] ?? '').toString().trim().isEmpty
            ? null
            : d['groupe_libelle'].toString(),
        isBonus: d['bonus'] == true || d['bonus'] == 1 || d['bonus'] == '1',
      );
    }).toList();

    return Order(
      id: json['id'],
      numeroFacture: json['numero_facture'],
      createdAt: DateTime.parse(json['created_at']),
      status: json['statut'] ?? 'en_attente',
      statusService: json['statut_service'],
      kitchenReady: json['cuisine_prete'] == true || json['cuisine_prete'] == 1 || json['cuisine_prete'] == '1',
      barReady: json['bar_prete'] == true || json['bar_prete'] == 1 || json['bar_prete'] == '1',
      totalTtc: double.tryParse(json['total_ttc']?.toString() ?? json['total_ht']?.toString() ?? '0.0') ?? 0.0,
      table: json['table'] != null ? RestaurantTable.fromJson(json['table']) : null,
      user: json['user'] != null ? User.fromJson(json['user']) : null,
      items: products,
    );
  }

  double get totalAmount => totalTtc > 0 ? totalTtc : items.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  Map<String, List<OrderItem>> get groups {
    final map = <String, List<OrderItem>>{};
    final fallback = table?.name != null ? 'Table ${table!.name}' : 'Commande';
    for (final item in items) {
      final key = (item.groupLabel ?? '').trim().isEmpty ? fallback : item.groupLabel!.trim();
      map.putIfAbsent(key, () => []).add(item);
    }
    return map;
  }
}

String _lineCurrency(dynamic raw, String fallback) {
  final text = (raw ?? '').toString().trim();
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}
