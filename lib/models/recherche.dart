/// Comparer des noms comme on les tape, pas comme on les écrit.
///
/// LE PROBLÈME, CONCRÈTEMENT
///   Le club compte des Guémené, des Héric, un Vay-Marsac, et des
///   licenciés qui s'appellent Clément ou Loïc. Le dimanche soir, sur un
///   téléphone, personne ne va chercher l'accent aigu dans le clavier
///   pour retrouver « Guémené 2 » : on tape « guem » et on attend que la
///   ligne apparaisse.
///
///   Dart ne sait pas replier les accents tout seul — il n'y a pas de
///   normalisation Unicode dans sa bibliothèque standard. La table
///   ci-dessous est donc écrite à la main. Elle couvre le français et ce
///   qu'on croise dans les noms de clubs de l'Ouest ; c'est suffisant,
///   et ça se complète en une ligne le jour où il manque quelque chose.
///
/// CE QUE ÇA CHANGE AILLEURS QUE DANS LA RECHERCHE
///   La même fonction sert à décider si un adversaire existe déjà. Sans
///   elle, taper « Guemene 2 » alors que « Guémené 2 » est en base
///   proposait d'en créer un deuxième — exactement les doublons qu'on a
///   passé une soirée à fusionner.
library;

/// Chaque lettre nue, suivie de ses formes accentuées.
///
/// Les formes sont en minuscules : le repliage passe par
/// `toLowerCase()` avant de consulter la table, et « É » y arrive donc
/// en « é ». Deux entrées rendent deux lettres — les ligatures se
/// déplient, « Sœur » se cherche aussi bien en tapant « soeur ».
const _familles = <(String, String)>[
  ('a', 'àáâäãåā'),
  ('ae', 'æ'),
  ('c', 'çćč'),
  ('e', 'èéêëēėę'),
  ('i', 'ìíîïīį'),
  ('n', 'ñń'),
  ('o', 'òóôöõøō'),
  ('oe', 'œ'),
  ('s', 'śš'),
  ('ss', 'ß'),
  ('u', 'ùúûüū'),
  ('y', 'ýÿ'),
  ('z', 'źżž'),
];

/// La table retournée : une unité de code accentuée → sa forme nue.
final _pliage = <int, String>{
  for (final (nue, accentuees) in _familles)
    for (final unite in accentuees.codeUnits) unite: nue,
};

/// Le texte ramené à sa forme la plus simple : minuscules, sans accent.
///
/// Les signes diacritiques posés séparément (la forme décomposée, où
/// « é » s'écrit « e » suivi d'un accent) sont retirés au passage. Un
/// copier-coller venu d'un traitement de texte ou d'un iPhone arrive
/// parfois sous cette forme, et rien ne le laisse voir à l'écran.
String sansAccents(String texte) {
  final tampon = StringBuffer();
  for (final unite in texte.toLowerCase().codeUnits) {
    // Bloc « Combining Diacritical Marks » : on l'ignore.
    if (unite >= 0x0300 && unite <= 0x036F) continue;
    final nue = _pliage[unite];
    if (nue != null) {
      tampon.write(nue);
    } else {
      tampon.writeCharCode(unite);
    }
  }
  return tampon.toString();
}

/// Vrai si `terme` se retrouve dans `texte`, accents et casse mis de
/// côté des deux côtés. Un terme vide correspond à tout.
bool correspond(String texte, String terme) {
  final cherche = sansAccents(terme.trim());
  if (cherche.isEmpty) return true;
  return sansAccents(texte).contains(cherche);
}

/// Vrai si les deux textes désignent le même nom à l'accent et à la
/// casse près : « Guemene 2 » et « Guémené 2 » sont le même club.
bool memeNom(String a, String b) =>
    sansAccents(a.trim()) == sansAccents(b.trim());
