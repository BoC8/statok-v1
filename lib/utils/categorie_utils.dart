/// Tout ce qui touche à la notion de « catégorie » dans STATOK.
///
/// CONTEXTE
///   L'interface affiche `'U16 - U17 - U18'`, la base stocke `'U16-17-18'`.
///   Ces conversions étaient recopiées dans 8 fichiers — avec des divergences
///   silencieuses. Elles vivent désormais ici, et nulle part ailleurs.
///
///   Toute nouvelle catégorie se déclare dans ce fichier uniquement.
library;

// =====================================================================
// Vocabulaire
//
//   « libellé »   : ce que voit l'utilisateur      -> 'U16 - U17 - U18'
//   « valeur db » : ce que stocke Postgres          -> 'U16-17-18'
//   « détail »    : joueurs.categorie_detail        -> '16', '17', 'Senior'
// =====================================================================

/// Les libellés proposés par `CategorySelectionPage`, dans l'ordre d'affichage.
const List<String> categoriesAffichees = <String>[
  'U14 - U15',
  'U16 - U17 - U18',
  'SENIORS',
];

/// Tous les détails connus, dans l'ordre de progression d'un joueur.
const List<String> tousLesDetails = <String>[
  '14',
  '15',
  '16',
  '17',
  '18',
  'Senior',
];

/// Convertit un libellé d'interface en valeur stockée en base.
///
/// Une valeur déjà normalisée (ou inconnue) est renvoyée telle quelle : c'est
/// ce qui rend la fonction sûre à appliquer deux fois.
String? categoriePourDb(String? categorie) {
  switch (categorie) {
    case 'U14 - U15':
    case 'U14-15':
      return 'U14-15';
    case 'U16 - U17 - U18':
    case 'U16-17-18':
      return 'U16-17-18';
    case 'SENIORS':
    case 'Seniors':
      return 'Seniors';
  }
  return categorie;
}

/// Vrai si la valeur lue en base correspond à la catégorie sélectionnée,
/// quelle que soit l'écriture utilisée de part et d'autre.
///
/// [selected] à `null` signifie « aucun filtre » : tout correspond.
///
/// Depuis le passage au filtrage côté serveur (23/08/2026), cette fonction ne
/// sert plus qu'aux flux temps réel des onglets admin, où le filtrage se fait
/// encore en Dart sur le stream.
bool categorieMatches(String? selected, dynamic dbValue) {
  if (selected == null) return true;
  final db = dbValue?.toString();
  return db == selected || db == categoriePourDb(selected);
}

/// Les `categorie_detail` correspondant à une catégorie.
///
/// Un ensemble **vide** signale une catégorie inconnue. Les appelants
/// l'interprètent comme « aucune restriction » (`details.isEmpty || ...`).
Set<String> detailsPourCategorie(String? categorie) {
  switch (categorie) {
    case 'U14 - U15':
    case 'U14-15':
      return {'14', '15'};
    case 'U16 - U17 - U18':
    case 'U16-17-18':
      return {'16', '17', '18'};
    case 'SENIORS':
    case 'Seniors':
      return {'Senior'};
  }
  return <String>{};
}

/// Même chose, mais pour **construire une interface** : une catégorie inconnue
/// renvoie *tous* les détails plutôt qu'aucun, pour que l'écran reste utilisable.
///
/// Cette différence de repli était implicite dans l'ancien code ; elle est
/// désormais portée par deux noms distincts.
List<String> detailsAffichesPourCategorie(String? categorie) {
  final connus = detailsPourCategorie(categorie);
  if (connus.isEmpty) return List<String>.from(tousLesDetails);
  return tousLesDetails.where(connus.contains).toList();
}

/// La catégorie (valeur db) à laquelle appartient un `categorie_detail`.
///
/// Renvoie `null` pour un détail inconnu. Les appelants qui ont besoin d'une
/// valeur non nulle ajoutent leur propre repli, par exemple `?? 'Seniors'`.
String? categoriePourDetail(String? detail) {
  switch (detail) {
    case '14':
    case '15':
      return 'U14-15';
    case '16':
    case '17':
    case '18':
      return 'U16-17-18';
    case 'Senior':
      return 'Seniors';
  }
  return null;
}

/// Le détail suivant dans la progression d'un joueur, ou `null` s'il n'y en a
/// plus (un Senior reste Senior).
String? detailSuivant(String? detail) {
  final i = tousLesDetails.indexOf(detail ?? '');
  if (i < 0 || i >= tousLesDetails.length - 1) return null;
  return tousLesDetails[i + 1];
}

/// Ramène une valeur de genre hétérogène à `'M'` ou `'F'`.
///
/// La base contient des `varchar` libres ; tout ce qui commence par « F »
/// (après passage en majuscules) est féminin, le reste est masculin.
String normaliserGenre(dynamic value) {
  final upper = value?.toString().trim().toUpperCase() ?? '';
  return upper.startsWith('F') ? 'F' : 'M';
}
