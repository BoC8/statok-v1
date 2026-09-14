/// Les tranches d'âge, de la plus jeune à la plus vieille.
///
/// L'ordre est ce qui compte : il permet de dire qu'un joueur de
/// génération 16 peut évoluer en U18, mais qu'un 18 ne peut pas
/// redescendre en U17.
const generationsOrdonnees = <String>[
  '13',
  '14',
  '15',
  '16',
  '17',
  '18',
  'senior',
];

/// Le rang d'une génération. `-1` si elle est inconnue.
int rangGeneration(String generation) =>
    generationsOrdonnees.indexOf(generation);

/// « U17 » ou « Séniors ».
String libelleGeneration(String generation) =>
    generation == 'senior' ? 'Séniors' : 'U$generation';

/// La génération qui suit, pour la montée de catégorie de l'été.
/// Les séniors ne bougent plus.
String generationSuivante(String generation) {
  final rang = rangGeneration(generation);
  if (rang < 0 || rang >= generationsOrdonnees.length - 1) return 'senior';
  return generationsOrdonnees[rang + 1];
}
