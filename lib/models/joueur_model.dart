class JoueurModel {
  final String id;
  final String nom;
  final String? genre;
  final String? categorieDetail;
  final bool actif;

  JoueurModel({
    required this.id,
    required this.nom,
    this.genre,
    this.categorieDetail,
    this.actif = true,
  });

  factory JoueurModel.fromJson(Map<String, dynamic> json) {
    return JoueurModel(
      id: json['id'].toString(),
      nom: json['nom'] ?? '',
      genre: json['genre']?.toString(),
      categorieDetail: json['categorie_detail']?.toString(),
      actif: json['actif'] != false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
      'genre': genre,
      'categorie_detail': categorieDetail,
      'actif': actif,
    };
  }
}
