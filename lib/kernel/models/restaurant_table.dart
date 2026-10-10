class RestaurantTable {
  final int id;
  final String name;
  final String? status;
  final int? etsId;
  final int? emplacementId;
  final String? location; // Libellé de l'emplacement

  RestaurantTable({
    required this.id,
    required this.name,
    this.status,
    this.etsId,
    this.emplacementId,
    this.location,
  });

  factory RestaurantTable.fromJson(Map<String, dynamic> json) {
    return RestaurantTable(
      id: json['id'],
      name: json['numero']?.toString() ?? '',
      status: json['statut'],
      etsId: json['ets_id'],
      emplacementId: json['emplacement_id'] == null
          ? null
          : int.tryParse(json['emplacement_id'].toString()),
      location: json['emplacement'] != null ? json['emplacement']['libelle'] : null,
    );
  }
}

class Emplacement {
  final int id;
  final String libelle;
  final String? type;
  final List<RestaurantTable> tables;

  Emplacement({
    required this.id,
    required this.libelle,
    this.type,
    this.tables = const [],
  });

  factory Emplacement.fromJson(Map<String, dynamic> json) {
    var list = json['tables'] as List? ?? [];
    List<RestaurantTable> tablesList = list.map((i) => RestaurantTable.fromJson(i)).toList();

    return Emplacement(
      id: json['id'],
      libelle: json['libelle'],
      type: json['type'],
      tables: tablesList,
    );
  }
}
