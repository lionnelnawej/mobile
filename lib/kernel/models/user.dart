import 'package:loyambo/kernel/models/restaurant_table.dart';

class User {
  final int? id;
  final String? name;
  final String? email;
  final String? role;
  final String? status;
  final int? etsId;
  final int? emplacementId;
  final List<Emplacement> emplacements;
  final Etablissement? etablissement;
  final bool canRemise;
  final bool canDeleteOrder;
  final List<String> permissions;

  User({
    this.id,
    this.name,
    this.email,
    this.role,
    this.status,
    this.etsId,
    this.emplacementId,
    this.emplacements = const [],
    this.etablissement,
    this.canRemise = false,
    this.canDeleteOrder = false,
    this.permissions = const [],
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      status: json['status'],
      etsId: json['ets_id'],
      emplacementId: json['emplacement_id'],
      emplacements: (json['emplacements'] as List? ?? [])
          .map((item) => Emplacement.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      etablissement: json['etablissement'] != null 
          ? Etablissement.fromJson(json['etablissement']) 
          : (json['établissement'] != null ? Etablissement.fromJson(json['établissement']) : null),
      canRemise: json['can_remise'] == true || json['can_remise'] == 1 || json['can_remise'] == '1',
      canDeleteOrder: json['can_delete_order'] == true || json['can_delete_order'] == 1 || json['can_delete_order'] == '1',
      permissions: _permissionNames(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'status': status,
      'ets_id': etsId,
      'emplacement_id': emplacementId,
      'emplacements': emplacements
          .map((place) => {'id': place.id, 'libelle': place.libelle, 'type': place.type})
          .toList(),
      'etablissement': etablissement?.toJson(),
      'can_remise': canRemise,
      'can_delete_order': canDeleteOrder,
      'permissions': permissions,
    };
  }

  static List<String> _permissionNames(Map<String, dynamic> json) {
    final raw = json['permission_names'] ?? json['permissions'];
    if (raw is! List) return const [];
    return raw.map((item) {
      if (item is Map) return (item['name'] ?? '').toString();
      return item.toString();
    }).where((name) => name.isNotEmpty && !name.startsWith('{')).toList();
  }

  bool allows(String name) {
    if (role == 'admin') return true;
    return permissions.contains(name);
  }

  bool get isAdmin => role == 'admin' || role == 'caissier';
  bool get canGrantRemise => allows('accorder-remise');
  bool get canCancelOrder => allows('supprimer-commandes');
  bool get canModifyOrder => allows('modifier-commandes');
  bool get canGrantBonus => allows('accorder-bonus');
}

class Etablissement {
  final int id;
  final String nom;
  final String? type;
  final String? adresse;
  final String? telephone;
  final double? taux;

  Etablissement({
    required this.id,
    required this.nom,
    this.type,
    this.adresse,
    this.telephone,
    this.taux
  });

  factory Etablissement.fromJson(Map<String, dynamic> json) {
    return Etablissement(
      id: json['id'],
      nom: json['nom'] ?? '',
      type: json['type'],
      adresse: json['adresse'],
      telephone: json['telephone'],
      taux: double.parse(json['taux'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nom': nom,
      'type': type,
      'adresse': adresse,
      'telephone': telephone,
      'taux': taux
    };
  }
}
