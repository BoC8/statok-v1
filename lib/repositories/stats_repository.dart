import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/categorie_utils.dart';

/// Accès aux données nécessaires au classement des buteurs et passeurs.
///
/// Voir `MatchRepository` pour les conventions (libellé d'interface en entrée,
/// `null` = pas de filtre, `Map` bruts en sortie).
class StatsRepository {
  StatsRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Tous les joueurs, actifs comme inactifs.
  ///
  /// Le classement part de la liste complète pour que celui qui a marqué puis
  /// quitté le club reste comptabilisé sur la saison où il a joué.
  Future<List<Map<String, dynamic>>> tousLesJoueurs() async {
    return await _client.from('joueurs').select();
  }

  /// Les actions (buts, passes, tirs au but) d'une catégorie et d'une saison,
  /// accompagnées des informations du match auquel elles appartiennent.
  ///
  /// POINT TECHNIQUE
  ///   `actions` ne porte ni catégorie ni saison : ces colonnes sont sur
  ///   `matchs`. Le `!inner` rend la jointure obligatoire, ce qui autorise
  ///   PostgREST à filtrer sur `matchs.categorie` et `matchs.saison` — donc à
  ///   ne transmettre que les actions réellement concernées.
  ///
  ///   Effet de bord voulu : une action orpheline (dont le match a disparu) est
  ///   exclue côté serveur, là où l'ancien code la recevait pour l'ignorer.
  Future<List<Map<String, dynamic>>> actionsAvecMatch({
    String? categorie,
    String? saison,
  }) async {
    var q = _client
        .from('actions')
        .select(
          'type, joueur_id, '
          'matchs!inner(equipe, competition, lieu, categorie, saison)',
        );

    final dbCategorie = categoriePourDb(categorie);
    if (dbCategorie != null) q = q.eq('matchs.categorie', dbCategorie);
    if (saison != null) q = q.eq('matchs.saison', saison);

    return await q;
  }
}
