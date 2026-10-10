import 'package:loyambo/kernel/services/devise_book.dart';

class Product {
  final int id;
  final String name;
  final double price;
  final String category;
  final String? categoryType;
  final String? image;
  String? stockActuel;
  final bool quantified;
  final String currency;
  final int? placeId;
  final String? placeName;
  int quantity;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    this.categoryType,
    this.image,
    this.stockActuel,
    this.quantified = true,
    this.currency = 'FC',
    this.placeId,
    this.placeName,
    this.quantity = 0,
  });

  Product placedAt(int placeId, String placeName) {
    return Product(
      id: id,
      name: name,
      price: price,
      category: category,
      categoryType: categoryType,
      image: image,
      stockActuel: stockActuel,
      quantified: quantified,
      currency: currency,
      placeId: placeId,
      placeName: placeName,
      quantity: quantity,
    );
  }

  /// Stock entier connu. Null si le serveur n'a pas envoyé de quantité.
  int? get availableStock {
    final raw = stockActuel;
    if (raw == null || raw.trim().isEmpty) return null;
    final value = double.tryParse(raw.replaceAll(',', '.'));
    if (value == null) return null;
    if (value <= 0) return 0;
    return value.floor();
  }

  /// Vrai seulement pour les produits dont le stock est suivi et connu.
  bool get tracksStock => quantified && availableStock != null;

  bool get isOutOfStock => tracksStock && availableStock == 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['libelle'] ?? 'Produit inconnu',
      price: DeviseBook.instance.parseMoney(json['prix_unitaire']),
      category: json['categorie'] != null ? json['categorie']['libelle'] : 'Général',
      categoryType: json['categorie'] != null ? json['categorie']['type_service'] : null,
      image: json['image'],
      stockActuel: json.containsKey('stock_actuel') ? json['stock_actuel']?.toString() : null,
      quantified: _asBool(json['quantified']),
      currency: _currencyOf(json),
    );
  }

  static String _currencyOf(Map<String, dynamic> json) {
    for (final key in ['prix_devise', 'devise']) {
      final text = (json[key] ?? '').toString().trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return 'FC';
  }

  static bool _asBool(dynamic value, {bool fallback = true}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }

  Map<String, dynamic> toJson() {
    return {
      'produit_id': id,
      'quantite': quantity,
      'prix_unitaire': price,
    };
  }
}

class Category {
  final int id;
  final String libelle;
  final String? type;
  final List<Product> produits;

  Category({required this.id, required this.libelle, this.type, this.produits = const []});

  factory Category.fromJson(Map<String, dynamic> json) {
    var list = json['produits'] as List? ?? [];
    return Category(
      id: json['id'],
      libelle: json['libelle'],
      type: json['type_service'],
      produits: list.map((i) => Product.fromJson(i)).toList(),
    );
  }
}
