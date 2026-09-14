import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/bilan_equipe.dart';
import '../models/categorie.dart';
import '../models/equipe.dart';
import '../models/saison.dart';
import '../repositories/club_repository.dart';
import 'donnees_saison.dart';

/// Les providers de la structure du club.
///
/// CE QUI A CHANGÉ DEPUIS L'ANCIENNE VERSION
///   Il n'y a plus de « contexte » catégorie stocké dans les préférences.
///   L'application ouvre sur tout le club, et la catégorie n'est qu'un
///   filtre d'écran. Seule la **saison** est un choix global, et elle vit
///   en mémoire : au prochain lancement, on repart de la saison en cours.
///
///   Les données restent en cache tant que la saison ne change pas. Aller
///   sur Équipes, revenir, y retourner ne déclenche plus deux
///   chargements complets comme avant.

final clubRepositoryProvider = Provider<ClubRepository>(
  (ref) => ClubRepository(),
);

// =====================================================================
// La saison
// =====================================================================

final saisonsProvider = FutureProvider<List<Saison>>(
  (ref) => ref.watch(clubRepositoryProvider).saisons(),
);

/// La saison choisie par l'utilisateur. `null` signifie « celle en
/// cours » — on ne fige pas un identifiant tant qu'il n'a rien choisi.
final saisonChoisieProvider = StateProvider<String?>((ref) => null);

/// La saison effectivement affichée.
///
/// Se recalcule tout seul quand l'utilisateur change de saison, et tout
/// ce qui en dépend se recharge en cascade.
final saisonCouranteProvider = FutureProvider<Saison>((ref) async {
  final saisons = await ref.watch(saisonsProvider.future);
  if (saisons.isEmpty) {
    throw StateError(
      'Aucune saison en base. Exécute seed_v2.sql avant de lancer '
      "l'application.",
    );
  }

  final choix = ref.watch(saisonChoisieProvider);
  if (choix != null) {
    for (final s in saisons) {
      if (s.id == choix) return s;
    }
  }
  for (final s in saisons) {
    if (s.enCours) return s;
  }
  return saisons.first;
});

/// La saison RÉELLEMENT en cours, quoi que l'utilisateur consulte.
///
/// POURQUOI DEUX NOTIONS DE SAISON
///   `saisonCouranteProvider` suit le sélecteur : c'est ce qu'on regarde.
///   Celle-ci est ce qu'on vit. L'espace coachs a besoin de la seconde —
///   un coach qui a consulté les archives de 2025-2026 puis va saisir le
///   match de dimanche ne doit pas l'enregistrer dans la mauvaise saison.
final saisonActiveProvider = FutureProvider<Saison>((ref) async {
  final saisons = await ref.watch(saisonsProvider.future);
  for (final s in saisons) {
    if (s.enCours) return s;
  }
  if (saisons.isEmpty) {
    throw StateError('Aucune saison en base.');
  }
  return saisons.first;
});

// =====================================================================
// La structure
// =====================================================================

final categoriesProvider = FutureProvider<List<Categorie>>(
  (ref) => ref.watch(clubRepositoryProvider).categories(),
);

final equipesProvider = FutureProvider<List<Equipe>>(
  (ref) => ref.watch(clubRepositoryProvider).equipes(),
);

// =====================================================================
// L'écran Équipes
// =====================================================================

/// Un groupe d'affichage : une catégorie déclinée par genre.
///
/// C'est l'unité de regroupement de toute l'application. Les six groupes
/// se calculent, ils ne sont jamais stockés.
class GroupeEquipes {
  const GroupeEquipes({
    required this.categorie,
    required this.genre,
    required this.equipes,
    required this.bilans,
  });

  final Categorie categorie;
  final String genre;
  final List<Equipe> equipes;
  final Map<String, BilanEquipe> bilans;

  String get libelleGenre => genre == 'F' ? 'Féminines' : 'Masculins';

  BilanEquipe bilanDe(Equipe e) => bilans[e.id] ?? BilanEquipe.vide;
}

/// Tout ce que l'écran Équipes affiche, en une seule valeur.
class DonneesEquipes {
  const DonneesEquipes({required this.saison, required this.groupes});

  final Saison saison;
  final List<GroupeEquipes> groupes;

  int get nombreEquipes =>
      groupes.fold(0, (total, g) => total + g.equipes.length);
}

/// Assemble les six groupes du club à partir de la saison déjà chargée.
///
/// Aucune requête ici : `donneesSaisonProvider` a tout ramené une fois,
/// on ne fait que le découper.
final donneesEquipesProvider = FutureProvider<DonneesEquipes>((ref) async {
  final saison = await ref.watch(saisonCouranteProvider.future);
  final d = await ref.watch(donneesSaisonProvider.future);

  final groupes = <GroupeEquipes>[];
  for (final categorie in d.categories) {
    // Masculins d'abord, puis féminines — l'ordre de la maquette.
    for (final genre in const ['M', 'F']) {
      final duGroupe = d.equipesDuGroupe(categorie.id, genre);
      if (duGroupe.isEmpty) continue;

      groupes.add(
        GroupeEquipes(
          categorie: categorie,
          genre: genre,
          equipes: duGroupe,
          bilans: {for (final e in duGroupe) e.id: d.bilanDe([e.id])},
        ),
      );
    }
  }

  return DonneesEquipes(saison: saison, groupes: groupes);
});
