import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bilan_equipe.dart';
import '../models/categorie.dart';
import '../models/equipe.dart';
import '../models/saison.dart';

/// L'accès à la structure du club : saisons, catégories, équipes, et les
/// résultats bruts qui alimentent les bilans.
///
/// PRINCIPE
///   Le repository parle à Supabase et rend des objets typés. Il ne
///   connaît ni Riverpod ni Flutter : on peut l'appeler depuis un test
///   sans monter la moindre interface.
///
///   Tout filtrage se fait **côté serveur**. On ne rapatrie jamais une
///   table entière pour la trier dans l'application.
class ClubRepository {
  ClubRepository({SupabaseClient? client})
    : _db = client ?? Supabase.instance.client;

  final SupabaseClient _db;

  /// Les saisons, de la plus récente à la plus ancienne.
  Future<List<Saison>> saisons() async {
    final lignes = await _db
        .from('saisons')
        .select('id, annee_debut, libelle, en_cours, montee_faite')
        .order('annee_debut', ascending: false);

    return lignes.map((l) => Saison.depuisJson(l)).toList();
  }

  /// Les trois catégories, dans l'ordre d'affichage.
  Future<List<Categorie>> categories() async {
    final lignes = await _db
        .from('categories')
        .select('id, libelle, ordre, generations')
        .order('ordre');

    return lignes.map((l) => Categorie.depuisJson(l)).toList();
  }

  /// Les équipes actives, déjà triées comme elles doivent s'afficher.
  Future<List<Equipe>> equipes() async {
    final lignes = await _db
        .from('equipes')
        .select('id, categorie_id, genre, nom, ordre, generation_max, actif')
        .eq('actif', true)
        .order('ordre');

    return lignes.map((l) => Equipe.depuisJson(l)).toList();
  }

  /// Les rencontres jouées d'une saison, groupées par équipe et triées du
  /// plus récent au plus ancien.
  ///
  /// On ne demande que les six colonnes nécessaires au bilan : inutile de
  /// faire voyager l'adversaire, la compétition ou le lieu pour compter
  /// des victoires.
  Future<Map<String, List<Resultat>>> resultatsParEquipe(
    String saisonId,
  ) async {
    final lignes = await _db
        .from('rencontres')
        .select(
          'equipe_id, date_heure, score_pour, score_contre, '
          'tab_pour, tab_contre',
        )
        .eq('saison_id', saisonId)
        .eq('statut', 'jouee')
        .order('date_heure', ascending: false);

    final parEquipe = <String, List<Resultat>>{};
    for (final ligne in lignes) {
      final r = Resultat.depuisJson(ligne);
      parEquipe.putIfAbsent(r.equipeId, () => []).add(r);
    }
    return parEquipe;
  }
}
