class JoueurModel {
  final int id;
  final String nom;
  // Tu pourras ajouter 'prenom', 'poste', 'equipe' ici si tu ajoutes ces colonnes en base plus tard.
  // Pour l'instant on se base sur ton schéma actuel : id, nom.

  JoueurModel({
    required this.id,
    required this.nom,
  });

  factory JoueurModel.fromJson(Map<String, dynamic> json) {
    return JoueurModel(
      id: json['id'],
      nom: json['nom'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nom': nom,
    };
  }
}