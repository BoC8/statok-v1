import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bilan_equipe.dart';
import '../models/categorie.dart';
import '../models/equipe.dart';
import '../models/joueur.dart';
import '../models/perimetre.dart';
import '../models/rencontre.dart';
import '../repositories/rencontre_repository.dart';
import 'club_providers.dart';

final rencontreRepositoryProvider = Provider<RencontreRepository>(
  (ref) => RencontreRepository(),
);

/// Les licenciés, indexés par identifiant.
///
/// Ils ne dépendent pas de la saison : une soixantaine de lignes,
/// chargées une fois pour toute l'application.
final joueursProvider = FutureProvider<Map<String, Joueur>>((ref) async {
  final liste = await ref.watch(rencontreRepositoryProvider).joueurs();
  return {for (final j in liste) j.id: j};
});

// =====================================================================
//  Le filtre commun aux écrans du club
// =====================================================================

/// Ce que l'utilisateur a choisi de voir.
///
/// Un filtre vide signifie « tout ». C'est volontaire : il n'y a jamais
/// d'état où l'écran n'affiche rien parce qu'on a oublié de cocher.
class FiltreClub {
  const FiltreClub({
    this.categorieId,
    this.genre,
    this.equipeId,
    this.types = const {},
    this.competitions = const {},
  });

  /// `null` pour tout le club.
  final String? categorieId;
  final String? genre;

  /// Affine à une seule équipe du groupe choisi.
  final String? equipeId;

  /// `championnat`, `coupe`, `amical`.
  final Set<String> types;

  /// Noms de compétitions.
  final Set<String> competitions;

  bool get surToutLeClub => categorieId == null && equipeId == null;
  int get nombreFiltresCompetition => types.length + competitions.length;

  FiltreClub avecGroupe(String? categorieId, String? genre) => FiltreClub(
    categorieId: categorieId,
    genre: genre,
    types: types,
    competitions: competitions,
  );

  FiltreClub avecEquipe(String? equipeId) => FiltreClub(
    categorieId: categorieId,
    genre: genre,
    equipeId: equipeId,
    types: types,
    competitions: competitions,
  );

  FiltreClub avecCompetitions({
    Set<String>? types,
    Set<String>? competitions,
  }) => FiltreClub(
    categorieId: categorieId,
    genre: genre,
    equipeId: equipeId,
    types: types ?? this.types,
    competitions: competitions ?? this.competitions,
  );
}

// =====================================================================
//  Toutes les données d'une saison
// =====================================================================

/// L'intégralité d'une saison, chargée en une fois.
///
/// POURQUOI TOUT D'UN COUP
///   Une saison complète du club, c'est quelques centaines de lignes.
///   Les rapatrier une fois et filtrer en mémoire rend le changement de
///   puce instantané, et évite une requête par écran, par onglet et par
///   clic de filtre.
///
///   Le filtrage **par saison**, lui, reste fait par la base : on ne
///   charge jamais l'historique entier du club. C'est la frontière —
///   la base découpe ce qui est gros, l'application arrange ce qui est
///   déjà petit.
class DonneesSaison {
  const DonneesSaison({
    required this.categories,
    required this.equipes,
    required this.joueurs,
    required this.rencontres,
    required this.buts,
    required this.tirsAuBut,
  });

  final List<Categorie> categories;
  final List<Equipe> equipes;
  final Map<String, Joueur> joueurs;

  /// Toutes les rencontres de la saison, de la plus récente à la plus
  /// ancienne.
  final List<Rencontre> rencontres;

  final List<But> buts;
  final List<TirAuBut> tirsAuBut;

  Equipe? equipe(String id) {
    for (final e in equipes) {
      if (e.id == id) return e;
    }
    return null;
  }

  String nomEquipe(String id) => equipe(id)?.nom ?? 'FCPB';

  Categorie? categorie(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Les équipes d'un groupe, dans leur ordre d'affichage.
  List<Equipe> equipesDuGroupe(String categorieId, String genre) =>
      equipes
          .where((e) => e.categorieId == categorieId && e.genre == genre)
          .toList()
        ..sort((a, b) => a.ordre.compareTo(b.ordre));

  /// Les équipes d'un périmètre.
  List<Equipe> equipesDuPerimetre(Perimetre p) {
    if (p.estEquipe) {
      final e = equipe(p.equipeId!);
      return e == null ? const [] : [e];
    }
    return equipesDuGroupe(p.categorieId!, p.genre!);
  }

  /// Applique un filtre aux rencontres.
  List<Rencontre> filtrer(FiltreClub f) {
    final ids = _equipesRetenues(f);
    return rencontres.where((r) {
      if (!ids.contains(r.equipeId)) return false;
      if (f.types.isNotEmpty && !f.types.contains(r.typeCompetition)) {
        return false;
      }
      if (f.competitions.isNotEmpty &&
          !f.competitions.contains(r.competition)) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Les buts correspondant à un filtre, en passant par les rencontres
  /// retenues : c'est la rencontre qui dit à quelle équipe un but
  /// appartient, jamais la fiche du joueur.
  List<But> butsFiltres(FiltreClub f) {
    final retenues = filtrer(f).map((r) => r.id).toSet();
    return buts.where((b) => retenues.contains(b.rencontreId)).toList();
  }

  Set<String> _equipesRetenues(FiltreClub f) {
    if (f.equipeId != null) return {f.equipeId!};
    if (f.categorieId == null) return equipes.map((e) => e.id).toSet();
    return equipesDuGroupe(f.categorieId!, f.genre ?? 'M')
        .map((e) => e.id)
        .toSet();
  }

  /// Les types de compétition réellement présents dans une sélection.
  ///
  /// On ne propose jamais un filtre qui ne ramènerait rien : c'est ce
  /// qui évite les listes vides et les « pourquoi il n'y a rien ? ».
  List<String> typesDisponibles(FiltreClub f) {
    final sansCompetition = f.avecCompetitions(
      types: const {},
      competitions: const {},
    );
    final presents = filtrer(sansCompetition)
        .map((r) => r.typeCompetition)
        .toSet();
    return ['championnat', 'coupe', 'amical']
        .where(presents.contains)
        .toList();
  }

  List<String> competitionsDisponibles(FiltreClub f) {
    final sansNom = f.avecCompetitions(competitions: const {});
    return (filtrer(sansNom).map((r) => r.competition).toSet().toList()
      ..sort());
  }

  List<Rencontre> get jouees => rencontres.where((r) => r.jouee).toList();

  List<But> butsDe(String rencontreId) =>
      buts.where((b) => b.rencontreId == rencontreId).toList();

  List<TirAuBut> tirsDe(String rencontreId) =>
      tirsAuBut.where((t) => t.rencontreId == rencontreId).toList();

  BilanEquipe bilanDe(Iterable<String> equipeIds) {
    final ids = equipeIds.toSet();
    return BilanEquipe.depuis(
      rencontres
          .where((r) => r.jouee && ids.contains(r.equipeId))
          .map((r) => r.resultat!)
          .toList(),
    );
  }
}

/// Charge la saison affichée, en entier.
///
/// Changer de saison invalide ce provider, et **tout** ce qui en dépend
/// se recharge en cascade : accueil, calendrier, classements, écrans
/// d'équipe. Aucune page n'a à s'en occuper.
final donneesSaisonProvider = FutureProvider<DonneesSaison>((ref) async {
  final saison = await ref.watch(saisonCouranteProvider.future);
  final repo = ref.watch(rencontreRepositoryProvider);

  final (categories, equipes, joueurs, rencontres, buts, tirs) = await (
    ref.watch(categoriesProvider.future),
    ref.watch(equipesProvider.future),
    ref.watch(joueursProvider.future),
    repo.rencontres(saisonId: saison.id),
    repo.buts(saisonId: saison.id),
    repo.tirsAuBut(saisonId: saison.id),
  ).wait;

  return DonneesSaison(
    categories: categories,
    equipes: equipes,
    joueurs: joueurs,
    rencontres: rencontres,
    buts: buts,
    tirsAuBut: tirs,
  );
});
