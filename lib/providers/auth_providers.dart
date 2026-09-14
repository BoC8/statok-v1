import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/equipe.dart';
import '../models/profil.dart';
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

/// Les équipes sur lesquelles le staff connecté a le droit d'écrire.
///
/// Sert à n'afficher dans les formulaires que ce qui pourra réellement
/// être enregistré. La base refusera de toute façon le reste — mais un
/// bouton qui mène à une erreur est un mauvais bouton.
final equipesModifiablesProvider = FutureProvider<List<Equipe>>((ref) async {
  final profil = await ref.watch(profilProvider.future);
  if (profil == null) return const [];

  final equipes = await ref.watch(equipesProvider.future);
  return equipes.where(profil.peutEcrireEquipe).toList();
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
  ref.invalidate(adversairesProvider);
}
