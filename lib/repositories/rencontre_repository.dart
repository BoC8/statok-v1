import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/joueur.dart';
import '../models/rencontre.dart';

/// L'accès aux rencontres et à leur détail.
///
/// TOUT LE FILTRAGE EST FAIT PAR LA BASE. On envoie la saison et la
/// liste des équipes concernées, PostgREST ne renvoie que ce qui est
/// demandé. Aucune méthode ici ne rapatrie une table pour la filtrer
/// ensuite dans l'application.
class RencontreRepository {
  RencontreRepository({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  /// Toutes les rencontres de la saison, programmées comme jouées, de
  /// la plus récente à la plus ancienne.
  ///
  /// On charge le club entier : quelques centaines de lignes, une fois.
  /// Le découpage par équipe ou par catégorie se fait ensuite en
  /// mémoire — voir `DonneesSaison`.
  ///
  /// Les noms de l'adversaire et de la compétition sont ramenés dans la
  /// même requête : sans ça, afficher trente matchs demanderait soixante
  /// allers-retours.
  Future<List<Rencontre>> rencontres({required String saisonId}) async {
    final lignes = await _db
        .from('rencontres')
        .select(
          'id, saison_id, equipe_id, phase, date_heure, domicile, statut, '
          'score_pour, score_contre, tab_pour, tab_contre, '
          'adversaires(nom), competitions(nom, type)',
        )
        .eq('saison_id', saisonId)
        .order('date_heure', ascending: false);

    return lignes.map((l) => Rencontre.depuisJson(l)).toList();
  }

  /// Les buts de la saison.
  ///
  /// Passe par la vue `v_buts`, qui joint une fois pour toutes
  /// buts → rencontres → equipes. Sans elle il faudrait une jointure
  /// imbriquée à chaque appel, et elle ne retient que les rencontres
  /// réellement jouées.
  Future<List<But>> buts({required String saisonId}) async {
    final lignes = await _db
        .from('v_buts')
        .select('rencontre_id, joueur_id, passeur_id, csc')
        .eq('saison_id', saisonId);

    return lignes.map((l) => But.depuisJson(l)).toList();
  }

  /// Les tirs au but de la saison, dans l'ordre de passage.
  ///
  /// `rencontres!inner(...)` demande une jointure **interne** : les
  /// conditions portées sur `rencontres.` filtrent réellement le
  /// résultat au lieu de se contenter de compléter les lignes.
  Future<List<TirAuBut>> tirsAuBut({required String saisonId}) async {
    final lignes = await _db
        .from('tirs_au_but')
        .select(
          'rencontre_id, ordre, joueur_id, marque, '
          'rencontres!inner(saison_id)',
        )
        .eq('rencontres.saison_id', saisonId)
        .order('ordre');

    return lignes.map((l) => TirAuBut.depuisJson(l)).toList();
  }

  /// Tous les licenciés en activité.
  ///
  /// Une soixantaine de lignes : on les charge une fois et Riverpod les
  /// garde. Les classements s'en servent pour mettre un nom sur chaque
  /// identifiant sans redemander la base à chaque écran.
  Future<List<Joueur>> joueurs() async {
    final lignes = await _db
        .from('joueurs')
        .select('id, prenom, nom, generation, genre, actif')
        .eq('actif', true)
        .order('nom');

    return lignes.map((l) => Joueur.depuisJson(l)).toList();
  }
}
