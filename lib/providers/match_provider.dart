import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_providers.dart';

/// Les données des écrans publics, mises en cache et rechargées automatiquement
/// quand la catégorie ou la saison change.
///
/// COMMENT ÇA MARCHE
///   Chaque provider fait `await ref.watch(contexteProvider.future)`. Deux
///   conséquences, toutes deux souhaitables :
///
///   1. Il attend que le contexte soit lu avant d'interroger la base — donc
///      plus de requête lancée avec une saison encore nulle.
///   2. Il se **réabonne** au contexte. Si celui-ci change (l'utilisateur choisit
///      une autre saison), Riverpod relance la requête tout seul et les écrans
///      qui l'affichent se reconstruisent. Aucune page n'a à s'en occuper.
///
/// FORMAT
///   Des `Map<String, dynamic>` bruts, comme les repositories. Chaque page les
///   convertit ensuite dans son propre modèle d'affichage (`MatchResult`,
///   `MatchEvent`, `PlayerStats`) — ces modèles sont propres à chaque écran.

/// Les matchs joués de la catégorie et de la saison courantes,
/// du plus récent au plus ancien.
final matchsJouesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final contexte = await ref.watch(contexteProvider.future);
  return ref
      .watch(matchRepositoryProvider)
      .matchsJoues(categorie: contexte.categorie, saison: contexte.saison);
});

/// Les matchs programmés de la catégorie et de la saison courantes.
final programmationsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final contexte = await ref.watch(contexteProvider.future);
  return ref
      .watch(matchRepositoryProvider)
      .programmations(categorie: contexte.categorie, saison: contexte.saison);
});

/// Tous les joueurs, pour initialiser les classements.
final joueursProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(statsRepositoryProvider).tousLesJoueurs();
});

/// Les actions (buts, passes, TAB) de la catégorie et de la saison courantes,
/// avec les informations du match auquel elles appartiennent.
final actionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final contexte = await ref.watch(contexteProvider.future);
  return ref
      .watch(statsRepositoryProvider)
      .actionsAvecMatch(categorie: contexte.categorie, saison: contexte.saison);
});

/// Les matchs joués d'une équipe donnée.
///
/// `family` : une instance de provider (et donc un cache) par nom d'équipe.
final matchsEquipeProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      equipe,
    ) async {
      final contexte = await ref.watch(contexteProvider.future);
      return ref
          .watch(matchRepositoryProvider)
          .matchsDeLEquipe(
            equipe,
            categorie: contexte.categorie,
            saison: contexte.saison,
          );
    });

/// Les prochaines rencontres d'une équipe donnée.
final prochainesEquipeProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      equipe,
    ) async {
      final contexte = await ref.watch(contexteProvider.future);
      return ref
          .watch(matchRepositoryProvider)
          .prochainesProgrammations(
            equipe,
            categorie: contexte.categorie,
            saison: contexte.saison,
          );
    });
