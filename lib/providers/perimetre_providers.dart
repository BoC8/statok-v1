import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bilan_equipe.dart';
import '../models/equipe.dart';
import '../models/joueur.dart';
import '../models/perimetre.dart';
import '../models/rencontre.dart';
import 'club_providers.dart';
import 'donnees_saison.dart';

/// Tout ce qu'un écran de périmètre affiche.
class DonneesPerimetre {
  const DonneesPerimetre({
    required this.titre,
    required this.sousTitre,
    required this.equipes,
    required this.rencontres,
    required this.buts,
    required this.tirsAuBut,
    required this.joueurs,
    required this.bilan,
  });

  /// « U18 A » ou « U16 – U18 · Féminines ».
  final String titre;

  /// Le niveau pour une équipe, le décompte pour une catégorie.
  final String sousTitre;

  /// Les équipes du périmètre. Une seule si c'est une équipe.
  final List<Equipe> equipes;

  /// Les rencontres du périmètre, de la plus récente à la plus ancienne.
  final List<Rencontre> rencontres;

  final List<But> buts;
  final List<TirAuBut> tirsAuBut;
  final Map<String, Joueur> joueurs;
  final BilanEquipe bilan;

  List<Rencontre> get jouees => rencontres.where((r) => r.jouee).toList();

  /// Les rencontres à venir, de la plus proche à la plus lointaine.
  List<Rencontre> get aVenir =>
      rencontres.where((r) => r.programmee).toList().reversed.toList();

  Rencontre? get prochaine => aVenir.isEmpty ? null : aVenir.first;
  Rencontre? get derniere => jouees.isEmpty ? null : jouees.first;

  List<But> butsDe(String rencontreId) =>
      buts.where((b) => b.rencontreId == rencontreId).toList();

  List<TirAuBut> tirsDe(String rencontreId) =>
      tirsAuBut.where((t) => t.rencontreId == rencontreId).toList();

  /// Le bilan d'une équipe en particulier, au sein d'une catégorie.
  BilanEquipe bilanDe(String equipeId) => BilanEquipe.depuis(
    jouees
        .where((r) => r.equipeId == equipeId)
        .map((r) => r.resultat!)
        .toList(),
  );
}

/// L'écran d'un périmètre, **découpé dans la saison déjà chargée**.
///
/// Aucune requête ici : tout vient de `donneesSaisonProvider`. Ouvrir
/// les U18 A puis les Seniors B ne touche pas le réseau — c'est la même
/// saison, vue sous deux angles.
///
/// `family` : un cache par périmètre, invalidé en même temps que la
/// saison.
final donneesPerimetreProvider =
    FutureProvider.family<DonneesPerimetre, Perimetre>((ref, perimetre) async {
      final saison = await ref.watch(saisonCouranteProvider.future);
      final d = await ref.watch(donneesSaisonProvider.future);

      final equipes = d.equipesDuPerimetre(perimetre);
      if (equipes.isEmpty) {
        throw StateError('Ce périmètre ne contient aucune équipe active.');
      }

      final ids = equipes.map((e) => e.id).toSet();
      final rencontres = d.rencontres
          .where((r) => ids.contains(r.equipeId))
          .toList();
      final desRencontres = rencontres.map((r) => r.id).toSet();

      // Le titre et le sous-titre
      final String titre;
      final String sousTitre;
      if (perimetre.estEquipe) {
        titre = equipes.first.nom;
        // Le niveau n'est pas stocké sur l'équipe : il change de phase en
        // phase chez les jeunes. On le lit sur ses championnats joués.
        final niveaux = rencontres
            .where((r) => r.typeCompetition == 'championnat')
            .map((r) => r.competition)
            .toSet();
        sousTitre = niveaux.isEmpty ? 'Aucun championnat' : niveaux.join(' · ');
      } else {
        final categorie = d.categorie(perimetre.categorieId!);
        final genre = perimetre.genre == 'F' ? 'Féminines' : 'Masculins';
        titre = '${categorie?.libelle ?? 'Catégorie'} · $genre';
        sousTitre =
            '${equipes.length} équipe${equipes.length > 1 ? 's' : ''} · '
            'saison ${saison.libelle}';
      }

      return DonneesPerimetre(
        titre: titre,
        sousTitre: sousTitre,
        equipes: equipes,
        rencontres: rencontres,
        buts: d.buts
            .where((b) => desRencontres.contains(b.rencontreId))
            .toList(),
        tirsAuBut: d.tirsAuBut
            .where((t) => desRencontres.contains(t.rencontreId))
            .toList(),
        joueurs: d.joueurs,
        bilan: d.bilanDe(ids),
      );
    });
