import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/equipe_service.dart';
import '../../theme/app_theme.dart';

class EquipesAdminTab extends StatefulWidget {
  final String categorie;
  final VoidCallback? onEquipesChanged;

  const EquipesAdminTab({
    super.key,
    required this.categorie,
    this.onEquipesChanged,
  });

  @override
  State<EquipesAdminTab> createState() => _EquipesAdminTabState();
}

class _EquipesAdminTabState extends State<EquipesAdminTab> {
  final _controller = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;
  late final EquipeService _equipeService;
  List<String> _equipes = [];
  List<String> _equipesDesactivees = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _equipeService = EquipeService(_client);
    _chargerEquipes();
  }

  @override
  void didUpdateWidget(covariant EquipesAdminTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categorie != widget.categorie) {
      _chargerEquipes();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _chargerEquipes() async {
    setState(() => _isLoading = true);
    await _equipeService.chargerEquipes(
      categorie: widget.categorie,
      fallbackHistorique: true,
      persistHistorique: true,
    );
    final dbCategorie = _equipeService.categoriePourDb(widget.categorie);
    final data = await _client
        .from('equipes')
        .select('nom, categorie, actif')
        .eq('categorie', dbCategorie ?? widget.categorie)
        .order('nom');
    final equipes = <String>[];
    final desactivees = <String>[];
    for (final row in data) {
      final nom = row['nom']?.toString() ?? '';
      if (nom.isEmpty) continue;
      if (row['actif'] == false) {
        desactivees.add(nom);
      } else {
        equipes.add(nom);
      }
    }
    if (!mounted) return;
    setState(() {
      _equipes = equipes;
      _equipesDesactivees = desactivees;
      _isLoading = false;
    });
  }

  Future<void> _ajouterEquipe() async {
    final nom = _controller.text.trim();
    if (nom.isEmpty) return;

    try {
      final existing = await _client
          .from('equipes')
          .select('actif')
          .eq(
            'categorie',
            _equipeService.categoriePourDb(widget.categorie) ??
                widget.categorie,
          )
          .ilike('nom', nom)
          .maybeSingle();

      if (existing != null) {
        final message = existing['actif'] == false
            ? 'Cette équipe existe déjà dans les équipes désactivées. Vous pouvez la réactiver en dessous.'
            : 'Cette équipe existe déjà dans les équipes actives.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      await _equipeService.ajouterEquipe(nom: nom, categorie: widget.categorie);
      _controller.clear();
      await _chargerEquipes();
      widget.onEquipesChanged?.call();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Équipe ajoutée')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reactiverEquipe(String equipe) async {
    try {
      await _client
          .from('equipes')
          .update({'actif': true})
          .eq('nom', equipe)
          .eq(
            'categorie',
            _equipeService.categoriePourDb(widget.categorie) ??
                widget.categorie,
          );
      await _chargerEquipes();
      widget.onEquipesChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _desactiverEquipe(String equipe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retirer cette équipe ?'),
        content: Text('Désactiver $equipe pour ${widget.categorie} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _equipeService.desactiverEquipe(
        nom: equipe,
        categorie: widget.categorie,
      );
      await _chargerEquipes();
      widget.onEquipesChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _categoriePourDetail(String detail) {
    switch (detail) {
      case '14':
      case '15':
        return 'U14-15';
      case '16':
      case '17':
      case '18':
        return 'U16-17-18';
      case 'Senior':
      default:
        return 'Seniors';
    }
  }

  String? _detailSuivant(String? detail) {
    switch (detail) {
      case '14':
        return '15';
      case '15':
        return '16';
      case '16':
        return '17';
      case '17':
        return '18';
      case '18':
        return 'Senior';
      default:
        return null;
    }
  }

  Future<void> _monterJoueursCategorie() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Faire monter les joueurs ?'),
        content: const Text(
          'Cette action passe les joueurs actifs à la catégorie supérieure '
          '(14 -> 15, 15 -> 16, 16 -> 17, 17 -> 18, 18 -> Senior). '
          'Les Seniors ne sont pas modifiés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.bleuMarine,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final joueurs = await _client
          .from('joueurs')
          .select('id, categorie_detail')
          .neq('actif', false);

      var updated = 0;
      for (final joueur in joueurs) {
        final next = _detailSuivant(joueur['categorie_detail']?.toString());
        if (next == null) continue;
        await _client
            .from('joueurs')
            .update({
              'categorie_detail': next,
              'categorie': _categoriePourDetail(next),
            })
            .eq('id', joueur['id']);
        updated++;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$updated joueur(s) mis à jour')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Paramètres',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.bleuMarine,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: const Icon(Icons.trending_up, color: AppTheme.dore),
              title: const Text('Montée annuelle des joueurs'),
              subtitle: const Text('14 -> 15 -> 16 -> 17 -> 18 -> Senior'),
              trailing: ElevatedButton(
                onPressed: _monterJoueursCategorie,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.bleuMarine,
                  foregroundColor: Colors.white,
                ),
                child: const Text('+1'),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Équipes par catégorie',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        labelText: 'Nom de l’équipe',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _ajouterEquipe(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _ajouterEquipe,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.bleuMarine,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      if (_equipes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Aucune équipe active.'),
                        )
                      else
                        ..._equipes.map(
                          (equipe) => ListTile(
                            dense: true,
                            title: Text(
                              equipe,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              color: Colors.red,
                              onPressed: () => _desactiverEquipe(equipe),
                            ),
                          ),
                        ),
                      if (_equipesDesactivees.isNotEmpty) ...[
                        const Divider(height: 24),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Text(
                            'Équipes désactivées',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ..._equipesDesactivees.map(
                          (equipe) => ListTile(
                            dense: true,
                            title: Text(
                              equipe,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            trailing: TextButton(
                              onPressed: () => _reactiverEquipe(equipe),
                              child: const Text('Réactiver'),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
