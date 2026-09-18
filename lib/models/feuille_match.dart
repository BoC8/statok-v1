import 'rencontre.dart';

/// La feuille de match telle que le coach la saisit : des compteurs.
///
/// POURQUOI DES COMPTEURS ET NON UNE LIGNE PAR BUT
///   Le club ne note pas qui a servi qui — ça ne l'intéresse pas, et le
///   demander le dimanche soir invitait surtout à la faute de saisie. Ce
///   qui compte, ce sont les totaux : trois buts pour un tel, une passe
///   pour un autre.
///
///   La base, elle, garde une ligne par but, avec son buteur et son
///   passeur éventuel. Ce n'est pas une contrainte qu'on subit : c'est
///   ce qui permet de compter un but par match, de savoir dans quelle
///   rencontre il est tombé, et d'effacer proprement une feuille en
///   supprimant son match. Les deux formes coexistent donc, et ce
///   fichier fait le passage de l'une à l'autre.
///
/// CE QUE LA BASE IMPOSE, ET QU'IL FAUT RESPECTER ICI
///   · `buts_csc_coherent` — un csc n'a ni buteur ni passeur ; tout
///     autre but DOIT avoir un buteur. Une passe décisive ne peut donc
///     pas flotter seule : il lui faut un but sur lequel se poser.
///   · `buts_passeur_distinct` — personne ne se sert lui-même.
class LigneCompteur {
  LigneCompteur({this.joueurId, this.nombre = 1});

  String? joueurId;
  int nombre;

  bool get complete => joueurId != null && nombre > 0;
}

/// Ce que produit la composition : les lignes à écrire, et ce qu'il
/// faut dire au coach si tout n'a pas tenu.
class FeuilleComposee {
  const FeuilleComposee({required this.buts, this.avertissement});

  final List<But> buts;

  /// `null` quand tout est entré. Sinon, une phrase à afficher — jamais
  /// un blocage : le coach connaît son match mieux que nous.
  final String? avertissement;
}

/// Étale les compteurs en une ligne par but.
///
/// L'ORDRE DE PLACEMENT DES PASSES
///   Les passes se posent sur les buts dans l'ordre, en sautant ceux du
///   même joueur — on ne se sert pas soi-même. Une passe qui ne trouve
///   aucun but libre est abandonnée et signalée : c'est le seul cas où
///   la saisie du coach ne peut pas être retranscrite telle quelle.
FeuilleComposee composerButs({
  required List<LigneCompteur> buteurs,
  required List<LigneCompteur> passeurs,
  required int csc,
}) {
  // Un emplacement par but : d'abord ceux du FCPB, puis les csc
  // adverses, qui ne peuvent porter aucune passe.
  final emplacements = <_Emplacement>[];
  for (final b in buteurs) {
    if (!b.complete) continue;
    for (var i = 0; i < b.nombre; i++) {
      emplacements.add(_Emplacement(joueurId: b.joueurId));
    }
  }
  for (var i = 0; i < csc; i++) {
    emplacements.add(_Emplacement(csc: true));
  }

  var passesPerdues = 0;
  for (final p in passeurs) {
    if (!p.complete) continue;
    for (var i = 0; i < p.nombre; i++) {
      _Emplacement? libre;
      for (final e in emplacements) {
        if (!e.csc && e.passeurId == null && e.joueurId != p.joueurId) {
          libre = e;
          break;
        }
      }
      if (libre == null) {
        passesPerdues++;
      } else {
        libre.passeurId = p.joueurId;
      }
    }
  }

  return FeuilleComposee(
    buts: [
      for (final e in emplacements)
        But(
          rencontreId: '',
          joueurId: e.csc ? null : e.joueurId,
          passeurId: e.csc ? null : e.passeurId,
          csc: e.csc,
        ),
    ],
    avertissement: passesPerdues == 0
        ? null
        : '$passesPerdues passe${passesPerdues > 1 ? 's' : ''} '
              '${passesPerdues > 1 ? 'n’ont' : 'n’a'} pas pu être '
              'enregistrée${passesPerdues > 1 ? 's' : ''} : il faut un but '
              "d'un autre joueur pour chacune. Vérifie les buts avant "
              'les passes.',
  );
}

/// L'inverse : relit une feuille existante en compteurs.
///
/// Sert à rouvrir une rencontre déjà saisie. L'appariement buteur ↔
/// passeur qui existait en base est perdu au passage — et c'est sans
/// conséquence, puisque personne ne le lit.
({List<LigneCompteur> buteurs, List<LigneCompteur> passeurs, int csc})
decomposerButs(List<But> buts) {
  final parButeur = <String, int>{};
  final parPasseur = <String, int>{};
  var csc = 0;

  for (final b in buts) {
    if (b.csc) {
      csc++;
      continue;
    }
    if (b.joueurId != null) {
      parButeur[b.joueurId!] = (parButeur[b.joueurId!] ?? 0) + 1;
    }
    if (b.passeurId != null) {
      parPasseur[b.passeurId!] = (parPasseur[b.passeurId!] ?? 0) + 1;
    }
  }

  List<LigneCompteur> enLignes(Map<String, int> m) => [
    for (final e in m.entries)
      LigneCompteur(joueurId: e.key, nombre: e.value),
  ];

  return (
    buteurs: enLignes(parButeur),
    passeurs: enLignes(parPasseur),
    csc: csc,
  );
}

class _Emplacement {
  _Emplacement({this.joueurId, this.csc = false});

  final String? joueurId;
  final bool csc;
  String? passeurId;
}
