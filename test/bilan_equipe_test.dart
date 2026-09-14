import 'package:flutter_test/flutter_test.dart';
import 'package:statok/models/bilan_equipe.dart';

/// Les tests du calcul de bilan.
///
/// C'est du Dart pur : ni Supabase, ni Flutter, ni réseau. Ils tournent
/// en une fraction de seconde avec `flutter test`, et ils verrouillent la
/// règle qui nous avait déjà valu un bug — celle des tirs au but.

Resultat match({
  required int pour,
  required int contre,
  int? tabPour,
  int? tabContre,
  int jour = 1,
}) => Resultat(
  equipeId: 'e1',
  date: DateTime(2026, 9, jour),
  scorePour: pour,
  scoreContre: contre,
  tabPour: tabPour,
  tabContre: tabContre,
);

void main() {
  group('Issue d\'une rencontre', () {
    test('le score décide', () {
      expect(match(pour: 3, contre: 1).issue, Issue.victoire);
      expect(match(pour: 1, contre: 1).issue, Issue.nul);
      expect(match(pour: 0, contre: 2).issue, Issue.defaite);
    });

    test('un nul gagné aux tirs au but reste un nul', () {
      final m = match(pour: 1, contre: 1, tabPour: 4, tabContre: 3);
      expect(m.auxTirsAuBut, isTrue);
      expect(
        m.issue,
        Issue.nul,
        reason: 'seul le temps réglementaire compte, ici comme dans les '
            'séries en cours',
      );
    });

    test('un nul perdu aux tirs au but reste un nul', () {
      expect(
        match(pour: 2, contre: 2, tabPour: 3, tabContre: 5).issue,
        Issue.nul,
      );
    });
  });

  group('Bilan de saison', () {
    final resultats = [
      match(pour: 2, contre: 0, jour: 20), // le plus récent
      match(pour: 1, contre: 1, jour: 13, tabPour: 4, tabContre: 2),
      match(pour: 0, contre: 3, jour: 6),
      match(pour: 4, contre: 1, jour: 1),
    ];

    test('compte victoires, nuls et défaites', () {
      final b = BilanEquipe.depuis(resultats);
      expect(b.joues, 4);
      expect(b.victoires, 2);
      expect(b.nuls, 1, reason: 'le match aux tirs au but compte pour un nul');
      expect(b.defaites, 1);
    });

    test('additionne les buts et calcule la différence', () {
      final b = BilanEquipe.depuis(resultats);
      expect(b.butsPour, 7);
      expect(b.butsContre, 5);
      expect(b.difference, 2);
    });

    test('le pourcentage de victoires est arrondi', () {
      expect(BilanEquipe.depuis(resultats).pourcentageVictoires, 50);
      expect(BilanEquipe.vide.pourcentageVictoires, 0);
    });

    test('la forme se lit du plus ancien au plus récent', () {
      final b = BilanEquipe.depuis(resultats);
      expect(
        b.forme.map((i) => i.lettre).join(),
        'VDNV',
        reason: 'le repository renvoie du plus récent au plus ancien, '
            'la ligne de forme doit inverser',
      );
    });

    test('ne garde que les cinq derniers', () {
      final huit = List.generate(
        8,
        (i) => match(pour: 1, contre: 0, jour: i + 1),
      );
      expect(BilanEquipe.depuis(huit).forme.length, 5);
    });

    test('une équipe sans match a un bilan vide', () {
      final b = BilanEquipe.depuis(const []);
      expect(b.joues, 0);
      expect(b.forme, isEmpty);
      expect(b.difference, 0);
    });
  });
}
