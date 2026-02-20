import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/joueur_model.dart';
import '../../theme/app_theme.dart';

class MatchsTab extends StatefulWidget {
  const MatchsTab({super.key});

  @override
  State<MatchsTab> createState() => _MatchsTabState();
}

class _MatchsTabState extends State<MatchsTab> {
  final SupabaseClient _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // --- VARIABLES DU FORMULAIRE D'AJOUT ---
  DateTime _dateSelectionnee = DateTime.now();
  String _equipe = '18A';
  final TextEditingController _adversaireCtrl = TextEditingController();
  String _lieu = 'DOM';
  
  // Valeur par défaut mise à jour
  String _competition = 'Phase 1';

  final List<String> _listeEquipes = ['17', '18A', '18B'];
  final List<String> _listeLieux = ['DOM', 'EXT'];
  
  // LISTE COMPLETE
  final List<String> _listeCompet = ['Phase 1', 'Phase 2', 'Phase 3', 'Coupe', 'Amical'];

  // Gestion Joueurs / Actions
  List<JoueurModel> _tousLesJoueurs = [];
  final List<Map<String, dynamic>> _actionsTemp = [];

  // --- VARIABLES DE FILTRE (RECHERCHE LOCAL) ---
  String _rechercheTexte = '';
  String _filtreEquipe = 'Tout';
  String _filtreCompetition = 'Tout';

  final TextEditingController _butsGjpbCtrl = TextEditingController();
  final TextEditingController _butsAdvCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chargerJoueurs();
  }

  Future<void> _chargerJoueurs() async {
    final data = await _client.from('joueurs').select().order('nom');
    if (mounted) {
      setState(() {
        _tousLesJoueurs = (data as List).map((e) => JoueurModel.fromJson(e)).toList();
      });
    }
  }

  // Vérification Programmation
  Future<void> _chercherProgrammation() async {
    final dateStr = DateFormat('yyyy-MM-dd').format(_dateSelectionnee);
    try {
      final data = await _client
          .from('programmations')
          .select()
          .eq('equipe', _equipe)
          .eq('date', dateStr)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _adversaireCtrl.text = data['adversaire'];
          _lieu = data['lieu'];
          if (_listeCompet.contains(data['competition'])) {
             _competition = data['competition'];
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Match programmé trouvé !'),
            backgroundColor: Colors.green,
          ));
        }
      }
    } catch (e) {
      print("Erreur recherche prog: $e");
    }
  }

  void _ajouterLigneAction(String type) {
    setState(() {
      _actionsTemp.add({'joueur_id': null, 'joueur_nom': '', 'type': type, 'quantite': 1});
    });
  }

  Future<void> _enregistrerMatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_butsGjpbCtrl.text.isEmpty || _butsAdvCtrl.text.isEmpty) return;

    if (_actionsTemp.any((a) => a['joueur_id'] == null || (a['quantite'] as int? ?? 0) <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sélectionnez les joueurs pour les actions'), backgroundColor: Colors.orange));
      return;
    }

    try {
      final matchData = {
        'date': _dateSelectionnee.toIso8601String(),
        'equipe': _equipe,
        'adversaire': _adversaireCtrl.text,
        'lieu': _lieu,
        'competition': _competition,
        'buts_gjpb': int.parse(_butsGjpbCtrl.text),
        'buts_adv': int.parse(_butsAdvCtrl.text),
      };

      final response = await _client.from('matchs').insert(matchData).select().single();
      final newMatchId = response['id'];

      if (_actionsTemp.isNotEmpty) {
        final List<Map<String, dynamic>> actionsADb = _actionsTemp.expand((action) {
          final quantite = action['quantite'] as int? ?? 1;
          return List.generate(quantite, (_) {
            return {
              'match_id': newMatchId,
              'joueur_id': action['joueur_id'],
              'type': action['type'],
            };
          });
        }).toList();
        await _client.from('actions').insert(actionsADb);
      }

      // Supprimer la programmation associée (même jour, équipe, adversaire)
      final jour = DateTime(_dateSelectionnee.year, _dateSelectionnee.month, _dateSelectionnee.day);
      final debut = jour.toIso8601String();
      final fin = jour.add(const Duration(days: 1)).toIso8601String();
      await _client
          .from('programmations')
          .delete()
          .eq('equipe', _equipe)
          .eq('adversaire', _adversaireCtrl.text)
          .gte('date', debut)
          .lt('date', fin);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match enregistré !')));
        setState(() {
          _actionsTemp.clear();
          _adversaireCtrl.clear();
          _butsGjpbCtrl.clear();
          _butsAdvCtrl.clear();
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _ouvrirDetailsMatch(Map<String, dynamic> match) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return MatchDetailDialog(
          match: match,
          tousLesJoueurs: _tousLesJoueurs,
        );
      },
    );
  }

  Color _getResultColor(int gjpb, int adv) {
    if (gjpb > adv) return Colors.green;
    if (gjpb == adv) return Colors.grey;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // --- FORMULAIRE D'AJOUT ---
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                title: const Text("AJOUTER UN MATCH", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.bleuMarine)),
                leading: const Icon(Icons.add_circle, color: AppTheme.dore),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final d = await showDatePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime(2030), initialDate: _dateSelectionnee);
                                    if (d != null) {
                                      setState(() => _dateSelectionnee = d);
                                      _chercherProgrammation();
                                    }
                                  },
                                  child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yyyy').format(_dateSelectionnee))),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField(
                                  value: _equipe,
                                  items: _listeEquipes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                                  onChanged: (v) { setState(() => _equipe = v!); _chercherProgrammation(); },
                                  decoration: const InputDecoration(labelText: 'Équipe', border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: TextFormField(controller: _adversaireCtrl, decoration: const InputDecoration(labelText: 'Adversaire', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Requis' : null)),
                              const SizedBox(width: 10),
                              Expanded(child: DropdownButtonFormField(value: _lieu, items: _listeLieux.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _lieu = v!), decoration: const InputDecoration(labelText: 'Lieu', border: OutlineInputBorder()))),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField(
                            value: _competition,
                            items: _listeCompet.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                            onChanged: (v) => setState(() => _competition = v!),
                            decoration: const InputDecoration(labelText: 'Compétition', border: OutlineInputBorder())
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _butsGjpbCtrl,
                                  keyboardType: TextInputType.number,
                                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                  decoration: const InputDecoration(labelText: 'Buts GJPB', border: OutlineInputBorder()),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text("-", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _butsAdvCtrl,
                                  keyboardType: TextInputType.number,
                                  onTapOutside: (_) => FocusScope.of(context).unfocus(),
                                  decoration: const InputDecoration(labelText: 'Buts ADV', border: OutlineInputBorder()),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Actions", style: TextStyle(fontWeight: FontWeight.bold)),
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _ajouterLigneAction('Goal'),
                                    icon: const Icon(Icons.sports_soccer),
                                    label: const Text('Ajouter buteur'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _ajouterLigneAction('Assist'),
                                    icon: const Icon(Icons.assistant),
                                    label: const Text('Ajouter passeur'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._actionsTemp.asMap().entries.map((entry) {
                            int index = entry.key;
                            Map<String, dynamic> action = entry.value;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(children: [
                                Expanded(flex: 3, child: Autocomplete<JoueurModel>(
                                  optionsBuilder: (textEditingValue) => textEditingValue.text == '' ? const Iterable<JoueurModel>.empty() : _tousLesJoueurs.where((opt) => opt.nom.toLowerCase().contains(textEditingValue.text.toLowerCase())),
                                  displayStringForOption: (opt) => opt.nom,
                                  onSelected: (sel) => setState(() { action['joueur_id'] = sel.id; action['joueur_nom'] = sel.nom; }),
                                  fieldViewBuilder: (ctx, ctrl, focus, submit) {
                                    if (action['joueur_nom'] != '' && ctrl.text.isEmpty) ctrl.text = action['joueur_nom'];
                                    return TextField(controller: ctrl, focusNode: focus, decoration: const InputDecoration(labelText: 'Joueur', border: OutlineInputBorder(), isDense: true));
                                  },
                                )),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 70,
                                  child: TextFormField(
                                    initialValue: (action['quantite'] ?? 1).toString(),
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    decoration: const InputDecoration(
                                      labelText: 'Nb',
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (v) => setState(() => action['quantite'] = int.tryParse(v) ?? 0),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(flex: 2, child: DropdownButtonFormField<String>(value: action['type'], decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true), items: const [DropdownMenuItem(value: 'Goal', child: Text('But')), DropdownMenuItem(value: 'Assist', child: Text('Passe'))], onChanged: (v) => setState(() => action['type'] = v))),
                                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => _actionsTemp.removeAt(index)))
                              ]),
                            );
                          }),
                          const SizedBox(height: 10),
                          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _enregistrerMatch, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bleuMarine, foregroundColor: Colors.white), child: const Text("ENREGISTRER"))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),
          
          // --- FILTRES ---
          const Align(alignment: Alignment.centerLeft, child: Text("Derniers matchs joués", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(height: 10),
          
          Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Rechercher un adversaire...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (val) => setState(() => _rechercheTexte = val),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filtreEquipe,
                          isExpanded: true,
                          items: ['Tout', ..._listeEquipes].map((e) => DropdownMenuItem(value: e, child: Text(e == 'Tout' ? 'Toutes Équipes' : 'Équipe $e', style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) => setState(() => _filtreEquipe = v!),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filtreCompetition,
                          isExpanded: true,
                          items: ['Tout', ..._listeCompet].map((e) => DropdownMenuItem(value: e, child: Text(e == 'Tout' ? 'Toutes Compét.' : e, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (v) => setState(() => _filtreCompetition = v!),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // --- LISTE EN REALTIME ---
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _client.from('matchs').stream(primaryKey: ['id']).order('date', ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              
              var matchs = snapshot.data!;

              // Filtres côté client (Dart)
              if (_rechercheTexte.isNotEmpty) {
                matchs = matchs.where((m) => m['adversaire'].toString().toLowerCase().contains(_rechercheTexte.toLowerCase())).toList();
              }
              if (_filtreEquipe != 'Tout') {
                matchs = matchs.where((m) => m['equipe'] == _filtreEquipe).toList();
              }
              if (_filtreCompetition != 'Tout') {
                matchs = matchs.where((m) => m['competition'] == _filtreCompetition).toList();
              }

              if (matchs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Aucun match trouvé.")));

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matchs.length,
                separatorBuilder: (_,__) => const Divider(),
                itemBuilder: (context, index) {
                  final match = matchs[index];
                  final isWin = (match['buts_gjpb'] ?? 0) > (match['buts_adv'] ?? 0);
                  final isDraw = (match['buts_gjpb'] ?? 0) == (match['buts_adv'] ?? 0);
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: _getResultColor(match['buts_gjpb'], match['buts_adv']),
                      child: Text(
                         isWin ? "V" : (isDraw ? "N" : "D"),
                         style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text("${match['equipe']} vs ${match['adversaire']}"),
                    subtitle: Text("${DateFormat('dd/MM').format(DateTime.parse(match['date']))} - ${match['competition']}"),
                    trailing: const Icon(Icons.edit_note, color: Colors.grey),
                    onTap: () => _ouvrirDetailsMatch(match),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MODALE MATCH DETAIL
// ============================================================================
class MatchDetailDialog extends StatefulWidget {
  final Map<String, dynamic> match;
  final List<JoueurModel> tousLesJoueurs;

  const MatchDetailDialog({super.key, required this.match, required this.tousLesJoueurs});

  @override
  State<MatchDetailDialog> createState() => _MatchDetailDialogState();
}

class _MatchDetailDialogState extends State<MatchDetailDialog> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _isEditing = false;
  bool _isLoadingActions = true;

  late int _butsGjpb;
  late int _butsAdv;
  late String _adversaire;
  late String _lieu;
  late String _competition;
  List<Map<String, dynamic>> _actions = [];

  // Listes locales pour la modale
  late List<String> _localLieux;
  late List<String> _localCompet;

  @override
  void initState() {
    super.initState();
    _butsGjpb = widget.match['buts_gjpb'];
    _butsAdv = widget.match['buts_adv'];
    _adversaire = widget.match['adversaire'];
    _lieu = widget.match['lieu'] ?? 'DOM';
    _competition = widget.match['competition'] ?? 'Phase 1';

    _localLieux = ['DOM', 'EXT']; 
    // MISE A JOUR DE LA LISTE LOCALE
    _localCompet = ['Phase 1', 'Phase 2', 'Phase 3', 'Coupe', 'Amical'];

    if (!_localLieux.contains(_lieu)) {
      _localLieux.add(_lieu);
    }
    if (!_localCompet.contains(_competition)) {
      _localCompet.add(_competition);
    }

    _chargerActions();
  }

  Future<void> _chargerActions() async {
    try {
      final data = await _client.from('actions').select('*, joueurs(nom)').eq('match_id', widget.match['id']);
      if (mounted) {
        setState(() {
          _actions = List<Map<String, dynamic>>.from(data);
          _isLoadingActions = false;
        });
      }
    } catch (e) {
      print("Erreur chargement actions: $e");
    }
  }

  Future<void> _sauvegarder() async {
    try {
      await _client.from('matchs').update({
        'buts_gjpb': _butsGjpb,
        'buts_adv': _butsAdv,
        'adversaire': _adversaire,
        'lieu': _lieu,
        'competition': _competition,
      }).eq('id', widget.match['id']);

      await _client.from('actions').delete().eq('match_id', widget.match['id']);
      if (_actions.isNotEmpty) {
        final List<Map<String, dynamic>> toInsert = _actions.map((a) => {
          'match_id': widget.match['id'],
          'joueur_id': a['joueur_id'],
          'type': a['type']
        }).toList();
        await _client.from('actions').insert(toInsert);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Modifications enregistrées'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
  
  Future<void> _supprimerMatch() async {
    await _client.from('matchs').delete().eq('id', widget.match['id']);
    if(mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _isEditing 
          ? TextFormField(initialValue: _adversaire, decoration: const InputDecoration(labelText: 'Adversaire'), onChanged: (v) => _adversaire = v)
          : Center(child: Text("${widget.match['equipe']} vs $_adversaire")),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildScoreField(true), const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text("-", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), _buildScoreField(false)]),
              const SizedBox(height: 10),
              
              if (_isEditing) ...[
                 const SizedBox(height: 10),
                 DropdownButtonFormField<String>(
                    value: _lieu,
                    decoration: const InputDecoration(labelText: 'Lieu', border: OutlineInputBorder(), isDense: true),
                    items: _localLieux.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(),
                    onChanged: (v) => setState(() => _lieu = v!),
                 ),
                 const SizedBox(height: 10),
                 DropdownButtonFormField<String>(
                    value: _competition,
                    decoration: const InputDecoration(labelText: 'Compétition', border: OutlineInputBorder(), isDense: true),
                    items: _localCompet.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _competition = v!),
                 ),
                 const SizedBox(height: 10),
              ] else ...[
                Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.match['date'])), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                Text("$_lieu - $_competition", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],

              const Divider(height: 30),
              
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("Détails du match", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.bleuMarine)), 
                if (_isEditing) 
                  IconButton(
                    onPressed: () {
                      if (widget.tousLesJoueurs.isNotEmpty) {
                         setState(() {
                          _actions.add({
                            'joueur_id': widget.tousLesJoueurs.first.id, 
                            'type': 'Goal', 
                            'joueurs': {'nom': widget.tousLesJoueurs.first.nom}
                          });
                        });
                      }
                    }, 
                    icon: const Icon(Icons.add_circle, color: Colors.green)
                  )
              ]),
              const SizedBox(height: 10),
              _isLoadingActions 
                ? const Center(child: CircularProgressIndicator()) 
                : _actions.isEmpty 
                  ? const Text("Aucun buteur", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)) 
                  : Column(children: _actions.asMap().entries.map((entry) {
                      int index = entry.key;
                      var action = entry.value;
                      if (_isEditing) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0), 
                          child: Row(children: [
                            Expanded(child: DropdownButton<int>(
                              value: action['joueur_id'], 
                              isExpanded: true, 
                              items: widget.tousLesJoueurs.map((j) => DropdownMenuItem(value: j.id, child: Text(j.nom))).toList(), 
                              onChanged: (val) { setState(() { action['joueur_id'] = val; action['joueurs'] = {'nom': widget.tousLesJoueurs.firstWhere((j) => j.id == val).nom}; }); }
                            )), 
                            const SizedBox(width: 8), 
                            DropdownButton<String>(
                              value: action['type'], 
                              items: const [DropdownMenuItem(value: 'Goal', child: Text('But')), DropdownMenuItem(value: 'Assist', child: Text('Passe'))], 
                              onChanged: (val) => setState(() => action['type'] = val)
                            ), 
                            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _actions.removeAt(index)))
                          ])
                        );
                      } else {
                        bool isGoal = action['type'] == 'Goal';
                        return Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(children: [Icon(isGoal ? Icons.sports_soccer : Icons.autorenew, size: 16, color: isGoal ? Colors.black : Colors.grey), const SizedBox(width: 8), Text("${isGoal ? 'But' : 'Passe'} : ", style: TextStyle(fontWeight: FontWeight.bold, color: isGoal ? Colors.black : Colors.grey[700])), Text(action['joueurs']?['nom'] ?? 'Inconnu')]));
                      }
                    }).toList()),
            ],
          ),
        ),
      ),
      actions: [
        if (_isEditing) ...[
          TextButton(onPressed: () => setState(() => _isEditing = false), child: const Text("Annuler")), 
          ElevatedButton.icon(icon: const Icon(Icons.check), label: const Text("Valider"), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), onPressed: _sauvegarder)
        ]
        else ...[
          TextButton(onPressed: _supprimerMatch, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Supprimer")), 
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
          ElevatedButton.icon(icon: const Icon(Icons.edit), label: const Text("Modifier"), onPressed: () => setState(() => _isEditing = true))
        ]
      ],
    );
  }

  Widget _buildScoreField(bool isGjpb) {
    int val = isGjpb ? _butsGjpb : _butsAdv;
    if (_isEditing) {
      return SizedBox(width: 50, child: TextFormField(initialValue: val.toString(), keyboardType: TextInputType.number, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20), onChanged: (v) { int? newVal = int.tryParse(v); if (newVal != null) { if (isGjpb) _butsGjpb = newVal; else _butsAdv = newVal; } }));
    } else {
      return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Text(val.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)));
    }
  }
}
