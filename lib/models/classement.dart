import 'joueur.dart';
import 'rencontre.dart';

/// Ce que classe un classement.
enum TypeClassement {
  buteurs,
  passeurs,
  decisifs;

  String get libelle => switch (this) {
    TypeClassement.buteurs => 'Buteurs',
    TypeClassement.passeurs => 'Passeurs',
    TypeClassement.decisifs => 'Buts + passes',
  };
}

/// Une ligne de classement : un joueur et ses compteurs.
class LigneClassement {
  const LigneClassement({
    required this.joueur,
    required this.buts,
    required this.passes,
    required this.valeur,
    required this.rang,
    required this.exAequo,
  });

  final Joueur joueur;
  final int buts;
  final int passes;

  /// Le nombre affiché à droite : buts, passes ou cumul selon le type.
  final int valeur;

  /// Le rang effectif, médailles comprises.
  final int rang;

  /// Vrai quand ce joueur est à égalité avec celui du dessus. Sa ligne
  /// affiche alors un tiret, mais il hérite du rang — et donc de la
  /// médaille — du premier.
  final bool exAequo;

  bool get surLePodium => rang <= 3;
}

/// Construit un classement à partir des buts d'un périmètre.
///
/// UNE RÈGLE PAR CLASSEMENT
///   Un classement de buteurs ne se départage qu'aux buts, un classement
///   de passeurs qu'aux passes. Seul le cumul garde les buts comme
///   second critère, puisque c'est le seul qui les affiche. À égalité
///   complète, on trie par nom pour que l'ordre soit stable d'un
///   affichage à l'autre.
///
/// Les buts contre son camp adverses (`csc`) n'entrent dans aucun
/// classement : ils n'ont ni buteur ni passeur à créditer.
List<LigneClassement> construireClassement({
  required List<But> buts,
  required Map<String, Joueur> joueurs,
  required TypeClassement type,
}) {
  final compteurs = <String, ({int buts, int passes})>{};

  void ajouter(String id, {int but = 0, int passe = 0}) {
    final actuel = compteurs[id] ?? (buts: 0, passes: 0);
    compteurs[id] = (buts: actuel.buts + but, passes: actuel.passes + passe);
  }

  for (final b in buts) {
    if (b.csc) continue;
    if (b.joueurId != null) ajouter(b.joueurId!, but: 1);
    if (b.passeurId != null) ajouter(b.passeurId!, passe: 1);
  }

  int valeurDe(({int buts, int passes}) c) => switch (type) {
    TypeClassement.buteurs => c.buts,
    TypeClassement.passeurs => c.passes,
    TypeClassement.decisifs => c.buts + c.passes,
  };

  final brut =
      compteurs.entries
          .where((e) => joueurs.containsKey(e.key) && valeurDe(e.value) > 0)
          .map(
            (e) => (
              joueur: joueurs[e.key]!,
              buts: e.value.buts,
              passes: e.value.passes,
              valeur: valeurDe(e.value),
            ),
          )
          .toList()
        ..sort((a, b) {
          final parValeur = b.valeur.compareTo(a.valeur);
          if (parValeur != 0) return parValeur;
          if (type == TypeClassement.decisifs) {
            final parButs = b.buts.compareTo(a.buts);
            if (parButs != 0) return parButs;
          }
          return a.joueur.nom.toLowerCase().compareTo(
            b.joueur.nom.toLowerCase(),
          );
        });

  // Deux joueurs à égalité sur ce qui est affiché partagent le rang ;
  // le suivant reprend à sa place réelle. Deux premiers à égalité
  // donnent donc or, or, bronze.
  final lignes = <LigneClassement>[];
  for (var i = 0; i < brut.length; i++) {
    final e = brut[i];
    final precedent = i > 0 ? brut[i - 1] : null;

    final memeValeur =
        precedent != null &&
        precedent.valeur == e.valeur &&
        (type != TypeClassement.decisifs ||
            (precedent.buts == e.buts && precedent.passes == e.passes));

    lignes.add(
      LigneClassement(
        joueur: e.joueur,
        buts: e.buts,
        passes: e.passes,
        valeur: e.valeur,
        rang: memeValeur ? lignes[i - 1].rang : i + 1,
        exAequo: memeValeur,
      ),
    );
  }
  return lignes;
}
