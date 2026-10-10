class Client {
  int? id;
  String? name;
  String? code;
  String? adresse;
  String? latlng;
  String? phone;
  String? emails;
  int? agencyId;
  int? secteurId;
  String? status;
  String? fcmToken;
  String? clientEmail;
  String? createdAt;
  String? updatedAt;

  Client(
      {this.id,
      this.name,
      this.code,
      this.adresse,
      this.latlng,
      this.phone,
      this.emails,
      this.agencyId,
      this.secteurId,
      this.status,
      this.fcmToken,
      this.clientEmail,
      this.createdAt,
      this.updatedAt});

  Client.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    code = json['code'];
    adresse = json['adresse'];
    latlng = json['latlng'];
    phone = json['phone'];
    emails = json['emails'];
    agencyId = json['agency_id'];
    secteurId = json['secteur_id'];
    status = json['status'];
    fcmToken = json['fcm_token'];
    clientEmail = json['client_email'];
    createdAt = json['created_at'];
    updatedAt = json['updated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['code'] = code;
    data['adresse'] = adresse;
    data['latlng'] = latlng;
    data['phone'] = phone;
    data['emails'] = emails;
    data['agency_id'] = agencyId;
    data['secteur_id'] = secteurId;
    data['status'] = status;
    data['fcm_token'] = fcmToken;
    data['client_email'] = clientEmail;
    data['created_at'] = createdAt;
    data['updated_at'] = updatedAt;
    return data;
  }
}
