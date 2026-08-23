import 'package:supabase_flutter/supabase_flutter.dart';

class EquipeService {
  EquipeService(this._client);

  final SupabaseClient _client;

  String? categoriePourDb(String? categorie) {
    switch (categorie) {
      case 'U14 - U15':
        return 'U14-15';
      case 'U16 - U17 - U18':
        return 'U16-17-18';
      case 'SENIORS':
      case 'Seniors':
        return 'Seniors';
    }
    return categorie;
  }

  bool categorieMatches(String? selected, dynamic dbValue) {
    if (selected == null) return true;
    final db = dbValue?.toString();
    return db == selected || db == categoriePourDb(selected);
  }

  Future<List<String>> chargerEquipes({
    required String? categorie,
    String? saison,
    bool fallbackHistorique = true,
    bool persistHistorique = false,
  }) async {
    final equipes = <String>{};

    try {
      final data = await _client
          .from('equipes')
          .select('nom, categorie, actif')
          .neq('actif', false)
          .order('nom');
      for (final row in data) {
        if (!categorieMatches(categorie, row['categorie'])) continue;
        final nom = row['nom']?.toString() ?? '';
        if (nom.isNotEmpty) equipes.add(nom);
      }
    } catch (_) {}

    if (equipes.isEmpty && fallbackHistorique) {
      await _chargerEquipesDepuisHistorique(equipes, categorie, saison);
      if (equipes.isNotEmpty && persistHistorique) {
        await _enregistrerEquipesDepuisHistorique(equipes, categorie);
      }
    }

    return equipes.toList()..sort();
  }

  Future<void> _enregistrerEquipesDepuisHistorique(
    Set<String> equipes,
    String? categorie,
  ) async {
    final dbCategorie = categoriePourDb(categorie);
    final noms = equipes.toList();
    if (noms.isEmpty) return;

    try {
      var query = _client.from('equipes').select('nom, actif');
      if (dbCategorie != null) {
        query = query.eq('categorie', dbCategorie);
      }
      final existing = await query.inFilter('nom', noms);

      final existingNoms = <String>{};
      final inactiveNoms = <String>[];
      for (final row in existing) {
        final nom = row['nom']?.toString() ?? '';
        if (nom.isEmpty) continue;
        existingNoms.add(nom);
        if (row['actif'] == false) {
          inactiveNoms.add(nom);
        }
      }

      if (inactiveNoms.isNotEmpty) {
        var updateQuery = _client.from('equipes').update({'actif': true});
        if (dbCategorie != null) {
          updateQuery = updateQuery.eq('categorie', dbCategorie);
        }
        await updateQuery.inFilter('nom', inactiveNoms);
      }

      final missing = equipes.difference(existingNoms);
      if (missing.isNotEmpty) {
        await _client
            .from('equipes')
            .insert(
              missing
                  .map(
                    (nom) => {
                      'nom': nom.trim(),
                      'categorie': dbCategorie,
                      'actif': true,
                    },
                  )
                  .toList(),
            );
      }
    } catch (_) {}
  }

  Future<void> _chargerEquipesDepuisHistorique(
    Set<String> equipes,
    String? categorie,
    String? saison,
  ) async {
    try {
      final matchs = await _client
          .from('matchs')
          .select('equipe, categorie, saison');
      final programmations = await _client
          .from('programmations')
          .select('equipe, categorie, saison');

      for (final row in [...matchs, ...programmations]) {
        if (!categorieMatches(categorie, row['categorie'])) continue;
        if (saison != null && row['saison'] != saison) continue;
        final equipe = row['equipe']?.toString() ?? '';
        if (equipe.isNotEmpty) equipes.add(equipe);
      }
    } catch (_) {}
  }

  Future<void> ajouterEquipe({
    required String nom,
    required String categorie,
  }) async {
    await _client.from('equipes').insert({
      'nom': nom.trim(),
      'categorie': categoriePourDb(categorie),
      'actif': true,
    });
  }

  Future<void> desactiverEquipe({
    required String nom,
    required String categorie,
  }) async {
    await _client
        .from('equipes')
        .update({'actif': false})
        .eq('nom', nom)
        .eq('categorie', categoriePourDb(categorie) ?? categorie);
  }
}
