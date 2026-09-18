import 'package:flutter_test/flutter_test.dart';
import 'package:statok/models/feuille_match.dart';
import 'package:statok/models/rencontre.dart';

/// Ce que la base exige de chaque ligne, vérifié à la main : ces tests
/// doivent échouer ici plutôt qu'au moment de l'enregistrement, où le
/// coach n'y peut plus rien.
void verifierContraintes(List<But> buts) {
  for (final b in buts) {
    if (b.csc) {
      expect(b.joueurId, isNull, reason: 'un csc n’a pas de buteur');
      expect(b.passeurId, isNull, reason: 'un csc n’a pas de passeur');
    } else {
      expect(
        b.joueurId,
        isNotNull,
        reason: 'buts_csc_coherent : tout but non-csc a un buteur',
      );
      expect(
        b.passeurId,
        isNot(equals(b.joueurId)),
        reason: 'buts_passeur_distinct : on ne se sert pas soi-même',
      );
    }
  }
}

void main() {
  group('composerButs', () {
    test('un triplé fait trois lignes pour le même buteur', () {
      final f = composerButs(
        buteurs: [LigneCompteur(joueurId: 'theo', nombre: 3)],
        passeurs: [],
        csc: 0,
      );
      expect(f.buts.length, 3);
      expect(f.buts.every((b) => b.joueurId == 'theo'), isTrue);
      expect(f.avertissement, isNull);
      verifierContraintes(f.buts);
    });

    test('les passes se posent sur les buts des autres', () {
      final f = composerButs(
        buteurs: [
          LigneCompteur(joueurId: 'theo', nombre: 2),
          LigneCompteur(joueurId: 'hugo', nombre: 1),
        ],
        passeurs: [LigneCompteur(joueurId: 'leo', nombre: 2)],
        csc: 0,
      );
      expect(f.buts.length, 3);
      expect(f.buts.where((b) => b.passeurId == 'leo').length, 2);
      expect(f.avertissement, isNull);
      verifierContraintes(f.buts);
    });

    test('un buteur qui a aussi donné une passe ne se sert pas lui-même', () {
      final f = composerButs(
        buteurs: [
          LigneCompteur(joueurId: 'theo', nombre: 1),
          LigneCompteur(joueurId: 'hugo', nombre: 1),
        ],
        passeurs: [LigneCompteur(joueurId: 'theo', nombre: 1)],
        csc: 0,
      );
      final avecPasse = f.buts.firstWhere((b) => b.passeurId != null);
      expect(avecPasse.joueurId, 'hugo');
      expect(f.avertissement, isNull);
      verifierContraintes(f.buts);
    });

    test('le seul buteur ne peut pas se donner la passe : elle est perdue', () {
      final f = composerButs(
        buteurs: [LigneCompteur(joueurId: 'theo', nombre: 2)],
        passeurs: [LigneCompteur(joueurId: 'theo', nombre: 1)],
        csc: 0,
      );
      expect(f.buts.length, 2);
      expect(f.buts.every((b) => b.passeurId == null), isTrue);
      expect(f.avertissement, isNotNull);
      verifierContraintes(f.buts);
    });

    test('plus de passes que de buts : le surplus est signalé', () {
      final f = composerButs(
        buteurs: [LigneCompteur(joueurId: 'theo', nombre: 1)],
        passeurs: [LigneCompteur(joueurId: 'leo', nombre: 3)],
        csc: 0,
      );
      expect(f.buts.length, 1);
      expect(f.buts.first.passeurId, 'leo');
      expect(f.avertissement, contains('2 passes'));
      verifierContraintes(f.buts);
    });

    test('un csc ne porte ni buteur ni passeur', () {
      final f = composerButs(
        buteurs: [LigneCompteur(joueurId: 'theo', nombre: 1)],
        passeurs: [LigneCompteur(joueurId: 'leo', nombre: 1)],
        csc: 2,
      );
      expect(f.buts.length, 3);
      expect(f.buts.where((b) => b.csc).length, 2);
      // La passe n'a pu se poser que sur le but de Théo.
      expect(f.buts.where((b) => b.passeurId == 'leo').length, 1);
      verifierContraintes(f.buts);
    });

    test('une ligne sans joueur ou à zéro est ignorée', () {
      final f = composerButs(
        buteurs: [
          LigneCompteur(joueurId: null, nombre: 3),
          LigneCompteur(joueurId: 'theo', nombre: 0),
          LigneCompteur(joueurId: 'hugo', nombre: 1),
        ],
        passeurs: [LigneCompteur(joueurId: null, nombre: 2)],
        csc: 0,
      );
      expect(f.buts.length, 1);
      expect(f.buts.first.joueurId, 'hugo');
      verifierContraintes(f.buts);
    });

    test('une feuille vide ne produit aucune ligne', () {
      final f = composerButs(buteurs: [], passeurs: [], csc: 0);
      expect(f.buts, isEmpty);
      expect(f.avertissement, isNull);
    });
  });

  group('decomposerButs', () {
    test('regroupe les lignes par joueur', () {
      const r = '';
      final buts = [
        const But(rencontreId: r, joueurId: 'theo', csc: false),
        const But(
          rencontreId: r,
          joueurId: 'theo',
          passeurId: 'leo',
          csc: false,
        ),
        const But(
          rencontreId: r,
          joueurId: 'hugo',
          passeurId: 'leo',
          csc: false,
        ),
        const But(rencontreId: r, csc: true),
      ];

      final d = decomposerButs(buts);
      expect(d.csc, 1);
      expect(
        d.buteurs.firstWhere((l) => l.joueurId == 'theo').nombre,
        2,
      );
      expect(
        d.buteurs.firstWhere((l) => l.joueurId == 'hugo').nombre,
        1,
      );
      expect(d.passeurs.single.joueurId, 'leo');
      expect(d.passeurs.single.nombre, 2);
    });

    test('composer puis décomposer conserve les totaux', () {
      final depart = composerButs(
        buteurs: [
          LigneCompteur(joueurId: 'theo', nombre: 3),
          LigneCompteur(joueurId: 'hugo', nombre: 1),
        ],
        passeurs: [
          LigneCompteur(joueurId: 'leo', nombre: 2),
          LigneCompteur(joueurId: 'theo', nombre: 1),
        ],
        csc: 1,
      );
      final relu = decomposerButs(depart.buts);

      expect(relu.csc, 1);
      expect(relu.buteurs.firstWhere((l) => l.joueurId == 'theo').nombre, 3);
      expect(relu.buteurs.firstWhere((l) => l.joueurId == 'hugo').nombre, 1);
      expect(relu.passeurs.firstWhere((l) => l.joueurId == 'leo').nombre, 2);
      expect(relu.passeurs.firstWhere((l) => l.joueurId == 'theo').nombre, 1);
    });
  });
}
