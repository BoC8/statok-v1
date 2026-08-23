import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/joueur_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/categorie_utils.dart';

/// Consultation et modification d'un match déjà enregistré.
///
/// Extrait de `matchs_tab.dart` le 23/08/2026.

class MatchDetailDialog extends StatefulWidget {
  final Map<String, dynamic> match;
  final List<JoueurModel> tousLesJoueurs;
  final List<String> listeCompet;

  /// Noms d'adversaires connus, pour la suggestion pendant la saisie.
  final List<String> adversaires;

  final Map<String, String> adversairesParId;
  final Map<String, String> genresEquipes;

  const MatchDetailDialog({
    super.key,
    required this.match,
    required this.tousLesJoueurs,
    required this.listeCompet,
    required this.adversaires,
    required this.adversairesParId,
    required this.genresEquipes,
  });

  @override
  State<MatchDetailDialog> createState() => _MatchDetailDialogState();
}

class _MatchDetailDialogState extends State<MatchDetailDialog> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _isEditing = false;
  bool _isLoadingActions = true;

  late int _butsFcpb;
  late int _butsAdv;
  late int? _tabFcpb;
  late int? _tabAdv;
  late String _adversaire;
  late String _lieu;
  late String _competition;
  List<Map<String, dynamic>> _actions = [];
  final List<String> _localLieux = ['DOM', 'EXT'];

  @override
  void initState() {
    super.initState();
    _butsFcpb = widget.match['buts_gjpb'];
    _butsAdv = widget.match['buts_adv'];
    _tabFcpb = int.tryParse(widget.match['tab_fcpb']?.toString() ?? '');
    _tabAdv = int.tryParse(widget.match['tab_adv']?.toString() ?? '');
    _adversaire = _nomAdversaire(widget.match);
    _lieu = widget.match['lieu'] ?? 'DOM';
    _competition = widget.match['competition'] ?? widget.listeCompet.first;
    _chargerActions();
  }

  String _nomAdversaire(Map<String, dynamic> row) {
    final direct = row['adversaire']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final adversaireId = row['adversaire_id']?.toString();
    if (adversaireId != null && widget.adversairesParId[adversaireId] != null) {
      return widget.adversairesParId[adversaireId]!;
    }
    final adversaire = row['adversaires'];
    if (adversaire is Map && adversaire['nom'] != null) {
      return adversaire['nom'].toString();
    }
    return 'Adversaire';
  }

  Future<String?> _ensureAdversaire(String nom) async {
    final clean = nom.trim();
    if (clean.isEmpty) return null;
    try {
      final existing = await _client
          .from('adversaires')
          .select('id')
          .ilike('nom', clean)
          .maybeSingle();
      if (existing != null) return existing['id']?.toString();
      final created = await _client
          .from('adversaires')
          .insert({'nom': clean})
          .select('id')
          .single();
      return created['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _chargerActions() async {
    try {
      final data = await _client
          .from('actions')
          .select('*, joueurs(nom)')
          .eq('match_id', widget.match['id']);
      if (mounted) {
        setState(() {
          _actions = List<Map<String, dynamic>>.from(data);
          _isLoadingActions = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingActions = false);
    }
  }

  Future<void> _sauvegarder() async {
    try {
      final joueursEligiblesIds = _joueursEligibles.map((j) => j.id).toSet();
      if (_actions.any(
        (action) =>
            action['joueur_id'] == null ||
            !joueursEligiblesIds.contains(action['joueur_id']),
      )) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Un joueur sélectionné n'est pas éligible pour cette équipe",
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      final adversaireId = await _ensureAdversaire(_adversaire);
      final isCoupe = _competition.toLowerCase().contains('coupe');
      await _client
          .from('matchs')
          .update({
            'buts_gjpb': _butsFcpb,
            'buts_adv': _butsAdv,
            'adversaire_id': adversaireId,
            'lieu': _lieu,
            'competition': _competition,
            'tab_fcpb': isCoupe ? _tabFcpb : null,
            'tab_adv': isCoupe ? _tabAdv : null,
          })
          .eq('id', widget.match['id']);

      await _client.from('actions').delete().eq('match_id', widget.match['id']);
      if (_actions.isNotEmpty) {
        final toInsert = _actions
            .where((a) => a['joueur_id'] != null && a['type'] != null)
            .map(
              (a) => {
                'match_id': widget.match['id'],
                'joueur_id': a['joueur_id'],
                'type': a['type'],
              },
            )
            .toList();
        await _client.from('actions').insert(toInsert);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Modifications enregistrées'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _supprimerMatch() async {
    // 1. Confirmation : l'action est irréversible et le bouton est juste
    //    à côté de "Fermer".
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce match ?'),
        content: const Text(
          'Le match et toutes ses actions (buts, passes décisives, tirs au but) '
          'seront définitivement supprimés.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirme != true) return;
    if (!mounted) return;

    // On capture messenger et navigator avant les await : après une
    // opération asynchrone, le context peut ne plus être valide.
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      // 2. Les actions AVANT le match.
      //    actions.match_id référence matchs.id ; sans suppression préalable,
      //    Postgres refuse de supprimer un match qui a des buteurs.
      await _client.from('actions').delete().eq('match_id', widget.match['id']);
      await _client.from('matchs').delete().eq('id', widget.match['id']);

      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Match supprimé'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // 3. Ne jamais échouer en silence : avant, la boîte se fermait
      //    comme si tout allait bien alors que rien n'était supprimé.
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isTabAction(Map<String, dynamic> action) {
    final type = action['type']?.toString();
    return type == 'TAB_Reussi' || type == 'TAB_Rate';
  }

  List<Map<String, dynamic>> get _actionsClassiques =>
      _actions.where((action) => !_isTabAction(action)).toList();

  List<Map<String, dynamic>> get _actionsTab =>
      _actions.where(_isTabAction).toList();

  String _genreEquipeDepuisDb(String equipe) {
    final dbGenre = widget.genresEquipes[equipe];
    if (dbGenre != null) return dbGenre;
    final upper = equipe.toUpperCase();
    if (upper.contains('F') ||
        upper.contains('FEM') ||
        upper.contains('FÉM') ||
        upper.contains('FILLE')) {
      return 'F';
    }
    return 'M';
  }

  List<JoueurModel> get _joueursEligibles {
    final equipe = widget.match['equipe']?.toString() ?? '';
    final details = detailsPourCategorie(
      widget.match['categorie']?.toString(),
    );
    final genre = _genreEquipeDepuisDb(equipe);
    return widget.tousLesJoueurs.where((joueur) {
      final joueurGenre = (joueur.genre ?? 'M').toUpperCase();
      final joueurDetail = joueur.categorieDetail;
      final categorieOk = details.isEmpty || details.contains(joueurDetail);
      return categorieOk && joueurGenre == genre;
    }).toList();
  }

  String _nomJoueurAction(Map<String, dynamic> action) {
    final joueur = action['joueurs'];
    if (joueur is Map && joueur['nom'] != null) {
      return joueur['nom'].toString();
    }
    final joueurId = action['joueur_id']?.toString();
    if (joueurId != null) {
      for (final joueur in widget.tousLesJoueurs) {
        if (joueur.id == joueurId) return joueur.nom;
      }
    }
    return 'Inconnu';
  }

  void _ajouterActionClassique() {
    if (_joueursEligibles.isEmpty) return;
    final joueur = _joueursEligibles.first;
    setState(() {
      _actions.add({
        'joueur_id': joueur.id,
        'type': 'Goal',
        'joueurs': {'nom': joueur.nom},
      });
    });
  }

  void _ajouterTireurTab() {
    if (_joueursEligibles.isEmpty) return;
    final joueur = _joueursEligibles.first;
    setState(() {
      _actions.add({
        'joueur_id': joueur.id,
        'type': 'TAB_Reussi',
        'joueurs': {'nom': joueur.nom},
      });
    });
  }

  /// Champ « Adversaire » avec suggestion parmi les adversaires déjà connus.
  ///
  /// Même comportement que le formulaire de création : on peut saisir un nom
  /// libre (il sera créé par `_ensureAdversaire`) ou en choisir un existant,
  /// ce qui évite les doublons du type « Beaulieu » / « Beaulieux ».
  Widget _buildAdversaireAutocomplete() {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _adversaire),
      optionsBuilder: (valeurSaisie) {
        final query = valeurSaisie.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return widget.adversaires.where(
          (nom) => nom.toLowerCase().contains(query),
        );
      },
      onSelected: (valeur) => _adversaire = valeur,
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Adversaire',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: (v) => _adversaire = v,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final equipe = widget.match['equipe'];
    final notreEquipe = _nomEquipeFcpb(equipe?.toString() ?? '');
    final domicile = _isMatchDomicile(_lieu);
    return AlertDialog(
      title: Text(_isEditing ? 'Modifier Match' : 'Détails'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isEditing) ...[
                _buildAdversaireAutocomplete(),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(child: _buildScoreField(true)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: _buildScoreField(false)),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _lieu,
                  decoration: const InputDecoration(
                    labelText: 'Lieu',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _localLieux
                      .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                      .toList(),
                  onChanged: (v) => setState(() => _lieu = v!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _competition,
                  decoration: const InputDecoration(
                    labelText: 'Compétition',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: widget.listeCompet
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _competition = v!),
                ),
                if (_competition.toLowerCase().contains('coupe')) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: _buildTabScoreField(true)),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '-',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(child: _buildTabScoreField(false)),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
              ] else ...[
                _buildReadOnlyHeader(notreEquipe, domicile),
                const Divider(),
                Text(
                  DateFormat(
                    'dd/MM/yyyy',
                  ).format(DateTime.parse(widget.match['date'])),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  '$_lieu - $_competition',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
              const Divider(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Détails du match',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.bleuMarine,
                    ),
                  ),
                  if (_isEditing)
                    TextButton(
                      onPressed: _joueursEligibles.isEmpty
                          ? null
                          : _ajouterActionClassique,
                      child: const Text('Ajouter buteur(euse)'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _isLoadingActions
                  ? const Center(child: CircularProgressIndicator())
                  : _actionsClassiques.isEmpty
                  ? const Text(
                      'Aucun buteur',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    )
                  : _isEditing
                  ? Column(
                      children: _actionsClassiques
                          .map((action) => _buildActionClassiqueEditRow(action))
                          .toList(),
                    )
                  : _buildActionsClassiquesReadColumns(),
              if (!_isLoadingActions) ...[
                const Divider(height: 30),
                _buildTabActionsSection(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (_isEditing) ...[
          TextButton(
            onPressed: () => setState(() => _isEditing = false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Valider'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: _sauvegarder,
          ),
        ] else ...[
          TextButton(
            onPressed: _supprimerMatch,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Modifier'),
            onPressed: () => setState(() => _isEditing = true),
          ),
        ],
      ],
    );
  }

  Widget _buildActionClassiqueEditRow(Map<String, dynamic> action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Expanded(
            child: _buildJoueurActionAutocomplete(
              action: action,
              label: action['type'] == 'Assist'
                  ? 'Passeur(euse)'
                  : 'Buteur(euse)',
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: action['type'],
            items: const [
              DropdownMenuItem(value: 'Goal', child: Text('But')),
              DropdownMenuItem(value: 'Assist', child: Text('Passe')),
            ],
            onChanged: (val) => setState(() => action['type'] = val),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => setState(() => _actions.remove(action)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsClassiquesReadColumns() {
    final buteurs = _actionsClassiques
        .where((action) => action['type'] == 'Goal')
        .toList();
    final passeurs = _actionsClassiques
        .where((action) => action['type'] == 'Assist')
        .toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildActionReadColumn('Buteurs', buteurs)),
        const SizedBox(width: 16),
        Expanded(child: _buildActionReadColumn('Passeurs', passeurs)),
      ],
    );
  }

  Widget _buildJoueurActionAutocomplete({
    required Map<String, dynamic> action,
    required String label,
  }) {
    final initialName = _nomJoueurAction(action) == 'Inconnu'
        ? ''
        : _nomJoueurAction(action);

    return Autocomplete<JoueurModel>(
      displayStringForOption: (joueur) => joueur.nom,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<JoueurModel>.empty();
        return _joueursEligibles.where(
          (joueur) => joueur.nom.toLowerCase().contains(query),
        );
      },
      onSelected: (joueur) {
        setState(() {
          action['joueur_id'] = joueur.id;
          action['joueurs'] = {'nom': joueur.nom};
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        if (controller.text.isEmpty && initialName.isNotEmpty) {
          controller.text = initialName;
        }
        controller.addListener(() {
          final selected = _joueursEligibles.where(
            (joueur) =>
                joueur.nom.toLowerCase() ==
                controller.text.trim().toLowerCase(),
          );
          if (selected.isEmpty) {
            action['joueur_id'] = null;
            action['joueurs'] = {'nom': controller.text.trim()};
          } else {
            action['joueur_id'] = selected.first.id;
            action['joueurs'] = {'nom': selected.first.nom};
          }
        });
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        );
      },
    );
  }

  Widget _buildActionReadColumn(
    String title,
    List<Map<String, dynamic>> actions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.bleuMarine,
          ),
        ),
        const SizedBox(height: 6),
        if (actions.isEmpty)
          const Text('-', style: TextStyle(color: Colors.grey))
        else
          ...actions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(_nomJoueurAction(action)),
            ),
          ),
      ],
    );
  }

  Widget _buildTabActionsSection() {
    final tabActions = _actionsTab;
    final showSection =
        _isEditing ||
        tabActions.isNotEmpty ||
        _tabFcpb != null ||
        _tabAdv != null;

    if (!showSection) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Détails de la séance de tir au but',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.bleuMarine,
                ),
              ),
            ),
            if (_isEditing)
              TextButton(
                onPressed: _joueursEligibles.isEmpty ? null : _ajouterTireurTab,
                child: const Text('Ajouter un tireur'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (tabActions.isEmpty)
          const Text(
            'Aucun tireur',
            style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
          )
        else
          Column(
            children: tabActions
                .map(
                  (action) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _isEditing
                        ? _buildTabActionEditRow(action)
                        : _buildTabActionReadRow(action),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  Widget _buildTabActionReadRow(Map<String, dynamic> action) {
    final reussi = action['type'] == 'TAB_Reussi';
    return Row(
      children: [
        Expanded(child: Text(_nomJoueurAction(action))),
        Text(
          reussi ? 'Mis' : 'Raté',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: reussi ? Colors.green : Colors.red,
          ),
        ),
      ],
    );
  }

  Widget _buildTabActionEditRow(Map<String, dynamic> action) {
    return Row(
      children: [
        Expanded(
          child: _buildJoueurActionAutocomplete(
            action: action,
            label: 'Tireur',
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'TAB_Reussi', label: Text('Mis')),
            ButtonSegment(value: 'TAB_Rate', label: Text('Raté')),
          ],
          selected: {
            action['type']?.toString() == 'TAB_Rate'
                ? 'TAB_Rate'
                : 'TAB_Reussi',
          },
          onSelectionChanged: (value) {
            setState(() => action['type'] = value.first);
          },
        ),
        IconButton(
          tooltip: 'Retirer',
          onPressed: () => setState(() => _actions.remove(action)),
          icon: const Icon(Icons.close, color: Colors.red),
        ),
      ],
    );
  }

  Widget _buildReadOnlyHeader(String notreEquipe, bool domicile) {
    final scorePrincipal = domicile
        ? '$_butsFcpb - $_butsAdv'
        : '$_butsAdv - $_butsFcpb';
    final scoreTab = domicile ? '$_tabFcpb - $_tabAdv' : '$_tabAdv - $_tabFcpb';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            domicile
                ? '$notreEquipe - $_adversaire'
                : '$_adversaire - $notreEquipe',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            scorePrincipal,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
          ),
          if (_competition.toLowerCase().contains('coupe') &&
              _tabFcpb != null &&
              _tabAdv != null) ...[
            const SizedBox(height: 4),
            Text(
              'TAB : $scoreTab',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
    );
  }

  bool _isMatchDomicile(dynamic lieu) {
    final value = lieu?.toString().trim().toUpperCase() ?? '';
    return value == 'DOM' || value == 'DOMICILE';
  }

  Widget _buildScoreField(bool isFcpb) {
    final val = isFcpb ? _butsFcpb : _butsAdv;
    if (_isEditing) {
      return TextFormField(
        initialValue: val.toString(),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        decoration: InputDecoration(
          labelText: isFcpb ? 'Score FCPB' : 'Score adversaire',
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: (v) {
          final newVal = int.tryParse(v);
          if (newVal == null) return;
          if (isFcpb) {
            _butsFcpb = newVal;
          } else {
            _butsAdv = newVal;
          }
        },
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        val.toString(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
      ),
    );
  }

  Widget _buildTabScoreField(bool isFcpb) {
    final val = isFcpb ? _tabFcpb : _tabAdv;
    return TextFormField(
      initialValue: val?.toString() ?? '',
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: isFcpb ? 'TAB FCPB' : 'TAB adversaire',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (v) {
        final newVal = v.trim().isEmpty ? null : int.tryParse(v);
        if (isFcpb) {
          _tabFcpb = newVal;
        } else {
          _tabAdv = newVal;
        }
      },
    );
  }

  String _nomEquipeFcpb(String equipe) {
    final clean = equipe.trim();
    if (clean.isEmpty) return 'FCPB';
    if (clean.toUpperCase().startsWith('FCPB')) return clean;
    return 'FCPB $clean';
  }
}
