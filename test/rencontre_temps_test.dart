import 'package:flutter_test/flutter_test.dart';
import 'package:statok/models/bilan_equipe.dart';
import 'package:statok/models/rencontre.dart';

/// Une rencontre minimale : seuls la date, le statut et le score
/// comptent pour ce qu'on vérifie ici.
Rencontre rencontre({
  required DateTime date,
  String statut = 'programmee',
  String? forfait,
  int? scorePour,
  int? scoreContre,
}) => Rencontre(
  id: 'r',
  saisonId: 's',
  equipeId: 'e',
  adversaire: 'Guémené 2',
  competition: 'D1',
  typeCompetition: 'championnat',
  phase: 0,
  date: date,
  domicile: true,
  statut: statut,
  forfait: forfait,
  scorePour: scorePour,
  scoreContre: scoreContre,
);

void main() {
  // Un dimanche, coup d'envoi à 15 h.
  final coupDEnvoi = DateTime(2026, 10, 4, 15);

  group('les trois moments d’une rencontre programmée', () {
    final r = rencontre(date: coupDEnvoi);

    test('avant le coup d’envoi, elle est à venir', () {
      final avant = coupDEnvoi.subtract(const Duration(minutes: 1));
      expect(r.aVenir(avant), isTrue);
      expect(r.enCours(avant), isFalse);
      expect(r.aSaisir(avant), isFalse);
    });

    test('à l’heure pile, elle est déjà en cours', () {
      expect(r.aVenir(coupDEnvoi), isFalse);
      expect(r.enCours(coupDEnvoi), isTrue);
      expect(r.aSaisir(coupDEnvoi), isFalse);
    });

    test('une heure cinquante-neuf plus tard, elle l’est encore', () {
      final pendant = coupDEnvoi.add(
        const Duration(hours: 1, minutes: 59),
      );
      expect(r.enCours(pendant), isTrue);
      expect(r.aSaisir(pendant), isFalse);
    });

    test('à deux heures pile, elle attend sa saisie', () {
      final fin = coupDEnvoi.add(const Duration(hours: 2));
      expect(r.aVenir(fin), isFalse);
      expect(r.enCours(fin), isFalse);
      expect(r.aSaisir(fin), isTrue);
    });

    test('le lendemain, elle l’attend toujours', () {
      final demain = coupDEnvoi.add(const Duration(days: 1));
      expect(r.aSaisir(demain), isTrue);
      expect(r.enCours(demain), isFalse);
    });

    test('les trois états s’excluent, à tout instant', () {
      for (var minutes = -60; minutes <= 240; minutes += 5) {
        final t = coupDEnvoi.add(Duration(minutes: minutes));
        final vrais = [
          r.aVenir(t),
          r.enCours(t),
          r.aSaisir(t),
        ].where((b) => b).length;
        expect(
          vrais,
          1,
          reason: 'à $minutes min du coup d’envoi, $vrais états vrais',
        );
      }
    });
  });

  group('une rencontre jouée n’est dans aucun des trois', () {
    final r = rencontre(
      date: coupDEnvoi,
      statut: 'jouee',
      scorePour: 3,
      scoreContre: 2,
    );

    test('ni à venir, ni en cours, ni à saisir', () {
      for (final t in [
        coupDEnvoi.subtract(const Duration(days: 1)),
        coupDEnvoi,
        coupDEnvoi.add(const Duration(days: 1)),
      ]) {
        expect(r.aVenir(t), isFalse);
        expect(r.enCours(t), isFalse);
        expect(r.aSaisir(t), isFalse);
      }
    });
  });

  group('forfaits', () {
    test('un forfait de l’adversaire est une victoire 3–0', () {
      final r = rencontre(
        date: coupDEnvoi,
        statut: 'jouee',
        forfait: 'eux',
        scorePour: 3,
        scoreContre: 0,
      );
      expect(r.estForfait, isTrue);
      expect(r.forfaitDEux, isTrue);
      expect(r.forfaitDeNous, isFalse);
      expect(r.issue, Issue.victoire);
      expect(r.resultat, isNotNull);
    });

    test('notre forfait est une défaite 0–3', () {
      final r = rencontre(
        date: coupDEnvoi,
        statut: 'jouee',
        forfait: 'nous',
        scorePour: 0,
        scoreContre: 3,
      );
      expect(r.forfaitDeNous, isTrue);
      expect(r.issue, Issue.defaite);
    });

    test('il compte dans le bilan comme n’importe quel match', () {
      final bilan = BilanEquipe.depuis([
        rencontre(
          date: coupDEnvoi,
          statut: 'jouee',
          forfait: 'eux',
          scorePour: 3,
          scoreContre: 0,
        ).resultat!,
        rencontre(
          date: coupDEnvoi,
          statut: 'jouee',
          scorePour: 1,
          scoreContre: 2,
        ).resultat!,
      ]);
      expect(bilan.joues, 2);
      expect(bilan.victoires, 1);
      expect(bilan.defaites, 1);
      expect(bilan.butsPour, 4);
      expect(bilan.butsContre, 2);
    });

    test('un match disputé n’est pas un forfait', () {
      final r = rencontre(
        date: coupDEnvoi,
        statut: 'jouee',
        scorePour: 3,
        scoreContre: 0,
      );
      expect(r.estForfait, isFalse);
    });
  });
}
