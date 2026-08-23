import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/joueur_model.dart';
import '../../services/equipe_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/categorie_utils.dart';
import 'match_detail_dialog.dart';
import 'tab_session_page.dart';

class MatchsTab extends StatefulWidget {
  final String selectedSeason;
  final String categorie;

  const MatchsTab({
    super.key,
    required this.selectedSeason,
    required this.categorie,
  });

  @override
  State<MatchsTab> createState() => _MatchsTabState();
}

class _MatchsTabState extends State<MatchsTab> {
  final SupabaseClient _client = Supabase.instance.client;
  late final EquipeService _equipeService;
  final _formKey = GlobalKey<FormState>();

  DateTime _dateSelectionnee = DateTime.now();
  String _equipe = '';
  final TextEditingController _adversaireCtrl = TextEditingController();
  String _lieu = 'DOM';
  String _competition = '';

  final List<String> _listeLieux = ['DOM', 'EXT'];
  List<String> _listeEquipes = [];
  List<String> _listeCompet = [];
  List<String> _adversaires = [];
  Map<String, String> _adversairesParId = {};
  Map<String, String> _genresEquipes = {};

  List<JoueurModel> _tousLesJoueurs = [];
  final List<Map<String, dynamic>> _actionsTemp = [];

  String _rechercheTexte = '';
  Set<String> _filtresEquipes = {};
  Set<String> _filtresCompet = {};
  int _refreshTick = 0;

  final TextEditingController _butsFcpbCtrl = TextEditingController();
  final TextEditingController _butsAdvCtrl = TextEditingController();
  final TextEditingController _tabFcpbCtrl = TextEditingController();
  final TextEditingController _tabAdvCtrl = TextEditingController();
  List<Map<String, dynamic>> _tabTireurs = [];

  @override
  void initState() {
    super.initState();
    _equipeService = EquipeService(_client);
    _initialiserListes();
  }

  @override
  void didUpdateWidget(covariant MatchsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSeason != widget.selectedSeason ||
        oldWidget.categorie != widget.categorie) {
      _initialiserListes();
    }
  }

  @override
  void dispose() {
    _adversaireCtrl.dispose();
    _butsFcpbCtrl.dispose();
    _butsAdvCtrl.dispose();
    _tabFcpbCtrl.dispose();
    _tabAdvCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialiserListes() async {
    final results = await Future.wait([
      _chargerEquipesContexte(),
      _chargerAdversaires(),
      _chargerJoueurs(),
      _chargerGenresEquipes(),
    ]);
    final equipes = results[0] as List<String>;
    final adversaires = results[1] as Map<String, String>;
    final joueurs = results[2] as List<JoueurModel>;
    final genresEquipes = results[3] as Map<String, String>;
    final competitions = _competitionsPourCategorie();

    if (!mounted) return;
    setState(() {
      _listeEquipes = equipes;
      _listeCompet = competitions;
      _adversairesParId = adversaires;
      _genresEquipes = genresEquipes;
      _adversaires = adversaires.values.toList()..sort();
      _tousLesJoueurs = joueurs;
      _equipe = equipes.contains(_equipe) ? _equipe : equipes.first;
      _competition = competitions.contains(_competition)
          ? _competition
          : competitions.first;
      _filtresEquipes = _filtresEquipes.intersection(equipes.toSet());
      _filtresCompet = _filtresCompet.intersection(competitions.toSet());
    });
  }

  Future<List<JoueurModel>> _chargerJoueurs() async {
    try {
      final data = await _client
          .from('joueurs')
          .select()
          .neq('actif', false)
          .order('nom');
      return (data as List).map((e) => JoueurModel.fromJson(e)).toList();
    } catch (_) {
      final data = await _client.from('joueurs').select().order('nom');
      return (data as List).map((e) => JoueurModel.fromJson(e)).toList();
    }
  }

  Future<List<String>> _chargerEquipesContexte() async {
    final equipes = await _equipeService.chargerEquipes(
      categorie: widget.categorie,
      saison: widget.selectedSeason,
    );
    if (equipes.isEmpty) return _equipesParDefaut();
    return equipes;
  }

  Future<Map<String, String>> _chargerAdversaires() async {
    try {
      final data = await _client
          .from('adversaires')
          .select('id, nom')
          .order('nom');
      return {
        for (final row in data)
          if (row['id'] != null && row['nom'] != null)
            row['id'].toString(): row['nom'].toString(),
      };
    } catch (_) {
      return {};
    }
  }

  Future<Map<String, String>> _chargerGenresEquipes() async {
    try {
      final data = await _client
          .from('equipes')
          .select('nom, genre, categorie, actif')
          .neq('actif', false);
      return {
        for (final row in data)
          if (row['nom'] != null &&
              categorieMatches(widget.categorie, row['categorie']) &&
              row['genre'] != null)
            row['nom'].toString(): normaliserGenre(row['genre']),
      };
    } catch (_) {
      return {};
    }
  }

  List<String> _competitionsPourCategorie() {
    if (widget.categorie.toUpperCase().contains('SENIORS')) {
      return ['Championnat', 'Coupe', 'Amical'];
    }
    return ['Phase 1', 'Phase 2', 'Phase 3', 'Coupe', 'Amical'];
  }

  List<String> _equipesParDefaut() {
    switch (widget.categorie) {
      case 'U14 - U15':
        return ['14', '15'];
      case 'SENIORS':
        return ['Seniors A', 'Seniors B'];
      default:
        return ['17', '18A', '18B'];
    }
  }

  String _genreEquipeDepuisDb(String equipe) {
    final dbGenre = _genresEquipes[equipe];
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

  List<JoueurModel> _joueursEligiblesPourEquipe(String equipe) {
    final details = detailsPourCategorie(widget.categorie);
    final genre = _genreEquipeDepuisDb(equipe);
    return _tousLesJoueurs.where((joueur) {
      final joueurGenre = (joueur.genre ?? 'M').toUpperCase();
      final joueurDetail = joueur.categorieDetail;
      final categorieOk = details.isEmpty || details.contains(joueurDetail);
      return categorieOk && joueurGenre == genre;
    }).toList();
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

  Future<void> _chercherProgrammation() async {
    final jour = DateTime(
      _dateSelectionnee.year,
      _dateSelectionnee.month,
      _dateSelectionnee.day,
    );
    final debut = jour.toIso8601String();
    final fin = jour.add(const Duration(days: 1)).toIso8601String();
    try {
      final data = await _client
          .from('programmations')
          .select()
          .eq('equipe', _equipe)
          .eq('saison', widget.selectedSeason)
          .gte('date', debut)
          .lt('date', fin)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _adversaireCtrl.text = _nomAdversaire(data);
          _lieu = data['lieu'];
          if (_listeCompet.contains(data['competition'])) {
            _competition = data['competition'];
          }
        });
      }
    } catch (_) {}
  }

  void _ajouterLigneAction(String type) {
    setState(() {
      _actionsTemp.add({
        'joueur_id': null,
        'joueur_nom': '',
        'type': type,
        'quantite': 1,
      });
    });
  }

  bool get _isCoupe => _competition.toLowerCase().contains('coupe');

  Future<void> _ouvrirSeanceTab() async {
    if (_tabTireurs.isEmpty) {
      _tabTireurs = List.generate(3, (index) => {'nom': '', 'reussi': true});
    }

    final result = await showDialog<TabSessionResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return TabSessionPage(
          fcpbScore: _tabFcpbCtrl.text,
          advScore: _tabAdvCtrl.text,
          tireurs: _tabTireurs,
          joueurs: _joueursEligiblesPourEquipe(_equipe),
        );
      },
    );

    if (result == null) return;
    setState(() {
      _tabFcpbCtrl.text = result.fcpbScore;
      _tabAdvCtrl.text = result.advScore;
      _tabTireurs = result.tireurs;
    });
  }

  Future<void> _enregistrerMatch() async {
    if (!_formKey.currentState!.validate()) return;
    if (_butsFcpbCtrl.text.isEmpty || _butsAdvCtrl.text.isEmpty) return;
    if (_isCoupe &&
        (_tabFcpbCtrl.text.trim().isEmpty != _tabAdvCtrl.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Renseignez les deux scores de la séance de TAB'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final tabTireursSelectionnes = _tabTireurs
        .where((tireur) => tireur['joueur_id'] != null)
        .toList();
    if (_isCoupe &&
        _tabFcpbCtrl.text.trim().isNotEmpty &&
        _tabTireurs.any(
          (tireur) =>
              tireur['joueur_id'] == null &&
              (tireur['nom']?.toString().trim().isNotEmpty ?? false),
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez les tireurs TAB dans la liste'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (_actionsTemp.any(
      (a) => a['joueur_id'] == null || (a['quantite'] as int? ?? 0) <= 0,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez les joueurs pour les actions'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final joueursEligiblesIds = _joueursEligiblesPourEquipe(
      _equipe,
    ).map((joueur) => joueur.id).toSet();
    if (_actionsTemp.any(
          (a) => !joueursEligiblesIds.contains(a['joueur_id']),
        ) ||
        tabTireursSelectionnes.any(
          (tireur) => !joueursEligiblesIds.contains(tireur['joueur_id']),
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

    try {
      final adversaire = _adversaireCtrl.text.trim();
      final adversaireId = await _ensureAdversaire(adversaire);
      final base = {
        'date': _dateSelectionnee.toIso8601String(),
        'equipe': _equipe,
        'adversaire_id': adversaireId,
        'lieu': _lieu,
        'competition': _competition,
        'buts_gjpb': int.parse(_butsFcpbCtrl.text),
        'buts_adv': int.parse(_butsAdvCtrl.text),
        if (_isCoupe && _tabFcpbCtrl.text.trim().isNotEmpty)
          'tab_fcpb': int.parse(_tabFcpbCtrl.text),
        if (_isCoupe && _tabAdvCtrl.text.trim().isNotEmpty)
          'tab_adv': int.parse(_tabAdvCtrl.text),
        'categorie': categoriePourDb(widget.categorie),
        'saison': widget.selectedSeason,
      };

      final response = await _client
          .from('matchs')
          .insert(base)
          .select()
          .single();

      final newMatchId = response['id'];
      if (_actionsTemp.isNotEmpty) {
        final actionsADb = _actionsTemp.expand((action) {
          final quantite = action['quantite'] as int? ?? 1;
          return List.generate(quantite, (_) {
            return {
              'match_id': newMatchId,
              'joueur_id': action['joueur_id'],
              'type': action['type'],
            };
          });
        }).toList();
        actionsADb.addAll(
          tabTireursSelectionnes.map(
            (tireur) => {
              'match_id': newMatchId,
              'joueur_id': tireur['joueur_id'],
              'type': tireur['reussi'] == true ? 'TAB_Reussi' : 'TAB_Rate',
            },
          ),
        );
        await _client.from('actions').insert(actionsADb);
      } else if (tabTireursSelectionnes.isNotEmpty) {
        final actionsTab = tabTireursSelectionnes
            .map(
              (tireur) => {
                'match_id': newMatchId,
                'joueur_id': tireur['joueur_id'],
                'type': tireur['reussi'] == true ? 'TAB_Reussi' : 'TAB_Rate',
              },
            )
            .toList();
        await _client.from('actions').insert(actionsTab);
      }

      final jour = DateTime(
        _dateSelectionnee.year,
        _dateSelectionnee.month,
        _dateSelectionnee.day,
      );
      if (adversaireId != null) {
        await _client
            .from('programmations')
            .delete()
            .eq('equipe', _equipe)
            .eq('adversaire_id', adversaireId)
            .gte('date', jour.toIso8601String())
            .lt('date', jour.add(const Duration(days: 1)).toIso8601String());
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Match enregistré')));
        setState(() {
          _actionsTemp.clear();
          _tabTireurs.clear();
          _adversaireCtrl.clear();
          _butsFcpbCtrl.clear();
          _butsAdvCtrl.clear();
          _tabFcpbCtrl.clear();
          _tabAdvCtrl.clear();
          _refreshTick++;
        });
        _initialiserListes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _ouvrirDetailsMatch(Map<String, dynamic> match) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return MatchDetailDialog(
          match: match,
          tousLesJoueurs: _tousLesJoueurs,
          listeCompet: _listeCompet,
          adversaires: _adversaires,
          adversairesParId: _adversairesParId,
          genresEquipes: _genresEquipes,
        );
      },
    );

    // Le flux temps réel de Supabase ne transmet pas les UPDATE lorsque la RLS
    // est active (bug Supabase ouvert depuis avril 2025). On ne s'y fie donc
    // plus : incrémenter _refreshTick recrée le StreamBuilder, qui refait une
    // lecture initiale — celle-ci, elle, est toujours à jour.
    if (mounted) setState(() => _refreshTick++);
  }

  void _ouvrirFiltres() {
    var equipes = Set<String>.from(_filtresEquipes);
    var compet = Set<String>.from(_filtresCompet);
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filtres'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FCPB',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._listeEquipes.map(
                  (e) => CheckboxListTile(
                    dense: true,
                    value: equipes.contains(e),
                    title: Text(e),
                    onChanged: (v) => setDialogState(
                      () => v == true ? equipes.add(e) : equipes.remove(e),
                    ),
                  ),
                ),
                const Divider(),
                const Text(
                  'Compétitions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ..._listeCompet.map(
                  (c) => CheckboxListTile(
                    dense: true,
                    value: compet.contains(c),
                    title: Text(c),
                    onChanged: (v) => setDialogState(
                      () => v == true ? compet.add(c) : compet.remove(c),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _filtresEquipes.clear();
                  _filtresCompet.clear();
                });
                Navigator.pop(context);
              },
              child: const Text('Réinitialiser'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _filtresEquipes = equipes;
                  _filtresCompet = compet;
                });
                Navigator.pop(context);
              },
              child: const Text('Appliquer'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getResultColor(int fcpb, int adv) {
    if (fcpb > adv) return Colors.green;
    if (fcpb == adv) return Colors.grey;
    return Colors.red;
  }

  bool _isMatchDomicile(dynamic lieu) {
    final value = lieu?.toString().trim().toUpperCase() ?? '';
    return value == 'DOM' || value == 'DOMICILE';
  }

  @override
  Widget build(BuildContext context) {
    if (_listeEquipes.isEmpty || _listeCompet.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                title: const Text(
                  'AJOUTER UN MATCH',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.bleuMarine,
                  ),
                ),
                leading: const Icon(Icons.add_circle, color: AppTheme.dore),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      locale: const Locale('fr', 'FR'),
                                      firstDate: DateTime(2023),
                                      lastDate: DateTime(2030),
                                      initialDate: _dateSelectionnee,
                                    );
                                    if (d != null) {
                                      setState(() => _dateSelectionnee = d);
                                      _chercherProgrammation();
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                      labelText: 'Date',
                                      border: OutlineInputBorder(),
                                    ),
                                    child: Text(
                                      DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(_dateSelectionnee),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _equipe,
                                  items: _listeEquipes
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    setState(() {
                                      _equipe = v!;
                                      _actionsTemp.clear();
                                      _tabTireurs.clear();
                                    });
                                    _chercherProgrammation();
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'FCPB',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildAdversaireAutocomplete()),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _lieu,
                                  items: _listeLieux
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) => setState(() => _lieu = v!),
                                  decoration: const InputDecoration(
                                    labelText: 'Lieu',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _competition,
                            items: _listeCompet
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _competition = v!),
                            decoration: const InputDecoration(
                              labelText: 'Compétition',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _butsFcpbCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Buts FCPB',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
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
                              Expanded(
                                child: TextFormField(
                                  controller: _butsAdvCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Buts adversaire',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _ajouterLigneAction('Goal'),
                                child: const Text('Ajouter buteur(euse)'),
                              ),
                              OutlinedButton(
                                onPressed: () => _ajouterLigneAction('Assist'),
                                child: const Text('Ajouter passeur(euse)'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ..._actionsTemp.asMap().entries.map((entry) {
                            final index = entry.key;
                            final action = entry.value;
                            final joueursEligibles =
                                _joueursEligiblesPourEquipe(_equipe);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Autocomplete<JoueurModel>(
                                      optionsBuilder: (value) =>
                                          value.text.isEmpty
                                          ? const Iterable<JoueurModel>.empty()
                                          : joueursEligibles.where(
                                              (opt) => opt.nom
                                                  .toLowerCase()
                                                  .contains(
                                                    value.text.toLowerCase(),
                                                  ),
                                            ),
                                      displayStringForOption: (opt) => opt.nom,
                                      onSelected: (sel) => setState(() {
                                        action['joueur_id'] = sel.id;
                                        action['joueur_nom'] = sel.nom;
                                      }),
                                      fieldViewBuilder:
                                          (ctx, ctrl, focus, submit) {
                                            if (action['joueur_nom'] != '' &&
                                                ctrl.text.isEmpty) {
                                              ctrl.text = action['joueur_nom'];
                                            }
                                            return TextField(
                                              controller: ctrl,
                                              focusNode: focus,
                                              decoration: const InputDecoration(
                                                labelText: 'Joueur(euse)',
                                                border: OutlineInputBorder(),
                                                isDense: true,
                                              ),
                                            );
                                          },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 62,
                                    child: TextFormField(
                                      initialValue: (action['quantite'] ?? 1)
                                          .toString(),
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        labelText: 'Nb',
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      onChanged: (v) => setState(
                                        () => action['quantite'] =
                                            int.tryParse(v) ?? 0,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: action['type'],
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Goal',
                                          child: Text('But'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Assist',
                                          child: Text('Passe'),
                                        ),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => action['type'] = v),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => setState(
                                      () => _actionsTemp.removeAt(index),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          if (_isCoupe) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _ouvrirSeanceTab,
                                icon: const Icon(Icons.sports_soccer),
                                label: Text(
                                  _tabFcpbCtrl.text.isEmpty ||
                                          _tabAdvCtrl.text.isEmpty
                                      ? 'Ajouter une séance de tir au but'
                                      : 'TAB : FCPB ${_tabFcpbCtrl.text} - ${_tabAdvCtrl.text} Adv',
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _enregistrerMatch,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.bleuMarine,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('ENREGISTRER'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Derniers matchs joués',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _ouvrirFiltres,
                icon: const Icon(Icons.filter_list),
                label: const Text('Filtres'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              labelText: 'Rechercher un adversaire...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
              ),
              fillColor: Colors.white,
              filled: true,
            ),
            onChanged: (val) => setState(() => _rechercheTexte = val),
          ),
          const SizedBox(height: 8),
          StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey(_refreshTick),
            stream: _client
                .from('matchs')
                .stream(primaryKey: ['id'])
                .order('date', ascending: false),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              var matchs = snapshot.data!
                  .where((m) => categorieMatches(widget.categorie, m['categorie']))
                  .where((m) => m['saison'] == widget.selectedSeason)
                  .toList();

              if (_rechercheTexte.isNotEmpty) {
                matchs = matchs
                    .where(
                      (m) => _nomAdversaire(
                        m,
                      ).toLowerCase().contains(_rechercheTexte.toLowerCase()),
                    )
                    .toList();
              }
              if (_filtresEquipes.isNotEmpty) {
                matchs = matchs
                    .where((m) => _filtresEquipes.contains(m['equipe']))
                    .toList();
              }
              if (_filtresCompet.isNotEmpty) {
                matchs = matchs
                    .where((m) => _filtresCompet.contains(m['competition']))
                    .toList();
              }

              if (matchs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Aucun match trouvé.'),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matchs.length,
                separatorBuilder: (_, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) => _buildMatchTile(matchs[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdversaireAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return _adversaires.where((nom) => nom.toLowerCase().contains(query));
      },
      onSelected: (value) => _adversaireCtrl.text = value,
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        if (textController.text != _adversaireCtrl.text) {
          textController.text = _adversaireCtrl.text;
        }
        textController.addListener(
          () => _adversaireCtrl.text = textController.text,
        );
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Adversaire',
            border: OutlineInputBorder(),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
        );
      },
    );
  }

  Widget _buildMatchTile(Map<String, dynamic> match) {
    final equipe = match['equipe']?.toString() ?? '';
    final notreEquipe = _nomEquipeFcpb(equipe);
    final adversaire = _nomAdversaire(match);
    final domicile = _isMatchDomicile(match['lieu']);
    final fcpb = match['buts_gjpb'] ?? 0;
    final adv = match['buts_adv'] ?? 0;
    final isWin = fcpb > adv;
    final isDraw = fcpb == adv;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: CircleAvatar(
          radius: 17,
          backgroundColor: _getResultColor(fcpb, adv),
          child: Text(
            isWin ? 'V' : (isDraw ? 'N' : 'D'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: RichText(
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: const TextStyle(color: Colors.black, fontSize: 14),
            children: domicile
                ? [
                    TextSpan(
                      text: notreEquipe,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: ' $fcpb - $adv $adversaire'),
                  ]
                : [
                    TextSpan(text: '$adversaire $adv - $fcpb '),
                    TextSpan(
                      text: notreEquipe,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
          ),
        ),
        subtitle: Text(
          '${DateFormat('dd/MM').format(DateTime.parse(match['date']))} - ${match['lieu']} (${match['competition']})',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.edit_note, color: Colors.grey),
        onTap: () => _ouvrirDetailsMatch(match),
      ),
    );
  }

  String _nomAdversaire(Map<String, dynamic> row) {
    final direct = row['adversaire']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final adversaireId = row['adversaire_id']?.toString();
    if (adversaireId != null && _adversairesParId[adversaireId] != null) {
      return _adversairesParId[adversaireId]!;
    }
    final adversaire = row['adversaires'];
    if (adversaire is Map && adversaire['nom'] != null) {
      return adversaire['nom'].toString();
    }
    return 'Adversaire';
  }

  String _nomEquipeFcpb(String equipe) {
    final clean = equipe.trim();
    if (clean.isEmpty) return 'FCPB';
    if (clean.toUpperCase().startsWith('FCPB')) return clean;
    return 'FCPB $clean';
  }
}
