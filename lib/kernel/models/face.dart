import 'dart:convert';

class FacePicture {
  final String matricule;
  final String? name;
  final List<double> embedding;
  final String? imagePath;

  FacePicture({
    required this.matricule,
    this.name,
    required this.embedding,
    this.imagePath,
  });

  Map<String, dynamic> toMap() => {
        'matricule': matricule,
        'name': name,
        'embedding': jsonEncode(embedding),
        'image_path': imagePath
      };

  static FacePicture fromMap(Map<String, dynamic> map) => FacePicture(
        matricule: map['matricule'] as String,
        name: map['name'] as String?,
        embedding: List<double>.from(jsonDecode(map['embedding'])),
        imagePath: map['image_path'] as String?,
      );
}
