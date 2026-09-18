import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/competition.dart';
import '../models/equipe.dart';
import '../models/joueur.dart';
import '../models/profil.dart';
import '../models/rencontre.dart';
import '../models/saison.dart';
import '../repositories/admin_repository.dart';
import 'club_providers.dart';
import 'donnees_saison.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(),
);

/// L'état d'authentification, tel que Supabase le diffuse.
///
/// On l'écoute plutôt que de le lire une fois : une session peut expirer,
/// être rafraîchie, ou être fermée depuis un autre écran. Le profil se
/// recalcule alors tout seul.
final sessionProvider = StreamProvider<Session?>((ref) {
  final auth = Supabase.instance.client.auth;
  return auth.onAuthStateChange.map((e) => e.session);
});

/// Le profil du membre du staff connecté, ou `null`.
///
/// `null` signifie aussi bien « personne n'est connecté » que « ce compte
/// n'est pas rattaché au staff ». Dans les deux cas l'espace coachs reste
/// fermé, ce qui est le comportement voulu.
final profilProvider = FutureProvider<Profil?>((ref) async {
  // Se réabonne à la session : une déconnexion vide le profil aussitôt.
  ref.watch(sessionProvider);
  return ref.watch(adminRepositoryProvider).profil();
});

/// La saison sur laquelle l'espace coachs travaille.
///
/// LE PASSÉ NE SE CORRIGE QU'EN HAUT
///   Un coach n'agit que sur la saison en cours. On ne lui propose même
///   pas de sélecteur : les archives se consultent dans les écrans
///   publics, elles ne se modifient pas. Un administrateur, lui, peut
///   revenir sur une saison terminée — il travaille alors sur celle
///   qu'il a choisie dans l'en-tête.
///
///   Cette distinction n'est pas qu'un confort d'interface : elle évite
///   qu'un coach qui vient de regarder les archives enregistre le match
///   de dimanche dans la mauvaise année. La base, elle, ne fait pas la
///   différence — c'est ici que la règle vit.
final saisonAtelierProvider = FutureProvider<Saison>((ref) async {
  final profil = await ref.watch(profilProvider.future);
  if (profil != null && profil.estAdmin) {
    return ref.watch(saisonCouranteProvider.future);
  }
  return ref.watch(saisonActiveProvider.future);
});

/// Les rencontres de la saison de travail du staff.
///
/// Volontairement séparé de `donneesSaisonProvider`, qui suit le
/// sélecteur des écrans publics : le coach doit voir ses matchs de la
/// saison en cours même s'il vient de consulter 2025-2026.
final rencontresAtelierProvider = FutureProvider<List<Rencontre>>((
  ref,
) async {
  final saison = await ref.watch(saisonAtelierProvider.future);
  return ref.watch(adminRepositoryProvider).rencontresDeLaSaison(saison.id);
});

/// La feuille de match d'une rencontre, relue à l'ouverture du
/// formulaire. Voir `AdminRepository.detailRencontre`.
final detailRencontreProvider =
    FutureProvider.family<(List<But>, List<TirAuBut>), String>(
      (ref, id) => ref.watch(adminRepositoryProvider).detailRencontre(id),
    );

/// Les équipes sur lesquelles le staff connecté peut écrire, pour une
/// saison donnée.
///
/// DEUX FILTRES, PAS UN
///   L'habilitation dit sur quelles catégories le coach a la main. La
///   saison dit quelles équipes existaient à ce moment-là — le club
///   alignait un U14 l'an dernier et ne le fait plus. Saisir un vieux
///   match doit proposer les équipes de l'époque, pas celles
///   d'aujourd'hui.
final equipesModifiablesProvider =
    FutureProvider.family<List<Equipe>, String>((ref, saisonId) async {
      final profil = await ref.watch(profilProvider.future);
      if (profil == null) return const [];

      final toutes = await ref.watch(equipesProvider.future);
      final deLaSaison = await ref
          .watch(clubRepositoryProvider)
          .equipesDeLaSaison(saisonId);

      return toutes
          .where((e) => deLaSaison.contains(e.id) && profil.peutEcrireEquipe(e))
          .toList();
    });

/// Les compétitions d'une équipe, pour une saison donnée.
///
/// La saison fait partie de la clé, et ce n'est pas un détail : les
/// engagements d'une équipe changent d'une année sur l'autre, et le
/// formulaire ne travaille pas forcément sur la saison consultée.
///
/// Un enregistrement en clé de `family` fonctionne parce qu'il a une
/// égalité de valeur — deux couples identiques partagent le cache.
final engagementsProvider =
    FutureProvider.family<
      List<OptionCompetition>,
      ({String equipeId, String saisonId})
    >(
      (ref, cle) => ref.watch(adminRepositoryProvider).engagements(
        equipeId: cle.equipeId,
        saisonId: cle.saisonId,
      ),
    );

/// Les paramètres de l'application : des textes que le super
/// administrateur peut réécrire sans qu'on reprenne le code.
final parametresProvider = FutureProvider<Map<String, String>>(
  (ref) => ref.watch(adminRepositoryProvider).parametres(),
);

/// Le texte du pavé « Bon à savoir », avec sa valeur de repli.
///
/// Le repli compte : si la table n'a pas encore été créée, ou si la clé
/// a été effacée, l'écran ne doit pas afficher un cadre vide.
final bonASavoirProvider = Provider<String>((ref) {
  final p = ref.watch(parametresProvider).value;
  final texte = p?['bon_a_savoir'];
  if (texte != null && texte.trim().isNotEmpty) return texte;
  return 'Les classements se calculent tout seuls à partir des buts '
      'saisis. Pensez à renseigner les passeurs : sans eux, le classement '
      'des passes décisives reste vide.\n\n'
      'Une rencontre se saisit une seule fois : on la programme, puis on '
      'revient y ajouter le score après le match.';
});

/// Toutes les équipes, y compris celles qui ne sont plus alignées.
final toutesLesEquipesProvider = FutureProvider<List<Equipe>>(
  (ref) => ref.watch(adminRepositoryProvider).toutesLesEquipes(),
);

/// Les compétitions connues du district.
final competitionsProvider = FutureProvider<List<Competition>>(
  (ref) => ref.watch(adminRepositoryProvider).competitions(),
);

/// Les inscriptions d'une équipe pour une saison, avec leur phase.
final engagementsDetaillesProvider =
    FutureProvider.family<
      List<Engagement>,
      ({String equipeId, String saisonId})
    >(
      (ref, cle) => ref.watch(adminRepositoryProvider).engagementsDetailles(
        equipeId: cle.equipeId,
        saisonId: cle.saisonId,
      ),
    );

/// Tous les licenciés, actifs ou non.
///
/// Distinct de `joueursProvider`, qui ne sert que les écrans publics et
/// n'expose que l'effectif en activité. Ici on veut aussi les partis :
/// c'est comme ça qu'on peut en réactiver un qui revient.
final tousLesJoueursProvider = FutureProvider<List<Joueur>>(
  (ref) => ref.watch(adminRepositoryProvider).tousLesJoueurs(),
);

/// Les adversaires déjà rencontrés, pour la saisie assistée.
final adversairesProvider = FutureProvider<List<Adversaire>>(
  (ref) => ref.watch(adminRepositoryProvider).adversaires(),
);

/// Recharge tout ce qu'un enregistrement a pu changer.
///
/// Après une écriture, les écrans publics doivent refléter la nouvelle
/// donne. Plutôt que de laisser chaque page y penser — c'est ainsi qu'on
/// se retrouve avec un écran qui affiche encore l'ancien score —, on
/// invalide la saison entière depuis un seul endroit.
void rafraichirApresEcriture(WidgetRef ref) {
  ref.invalidate(donneesSaisonProvider);
  ref.invalidate(rencontresAtelierProvider);
  ref.invalidate(detailRencontreProvider);
  ref.invalidate(adversairesProvider);
  ref.invalidate(joueursProvider);
  ref.invalidate(tousLesJoueursProvider);
}

/// Recharge la structure du club après une modification de catégorie,
/// d'équipe ou d'engagement.
///
/// Plus large que `rafraichirApresEcriture` : changer une catégorie
/// déplace des licenciés, des droits et des classements. Mieux vaut tout
/// relire que de chercher à deviner ce qui bouge.
void rafraichirApresStructure(WidgetRef ref) {
  ref.invalidate(categoriesProvider);
  ref.invalidate(equipesProvider);
  ref.invalidate(toutesLesEquipesProvider);
  ref.invalidate(competitionsProvider);
  ref.invalidate(engagementsDetaillesProvider);
  ref.invalidate(engagementsProvider);
  ref.invalidate(equipesModifiablesProvider);
  ref.invalidate(donneesSaisonProvider);
  ref.invalidate(rencontresAtelierProvider);
}
