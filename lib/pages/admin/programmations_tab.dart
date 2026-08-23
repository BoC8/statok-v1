import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/equipe_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/categorie_utils.dart';

class ProgrammationsTab extends StatefulWidget {
  final String selectedSeason;
  final String categorie;

  const ProgrammationsTab({
    super.key,
    required this.selectedSeason,
    required this.categorie,
  });

  @override
  State<ProgrammationsTab> createState() => _ProgrammationsTabState();
}

class _ProgrammationsTabState extends State<ProgrammationsTab> {
  final SupabaseClient _client = Supabase.instance.client;
  late final EquipeService _equipeService;
  final _formKey = GlobalKey<FormState>();

  DateTime _dateSelectionnee = DateTime.now();
  int _heureSelectionnee = 15;
  int _minuteSelectionnee = 0;
  String _equipe = '';
  final TextEditingController _adversaireCtrl = TextEditingController();
  String _lieu = 'DOM';
  String _competition = '';

  final List<String> _listeLieux = ['DOM', 'EXT'];
  final List<int> _listeHeures = List.generate(24, (index) => index);
  final List<int> _listeMinutes = [0, 15, 30, 45];
  List<String> _listeEquipes = [];
  List<String> _listeCompet = [];
  List<String> _adversaires = [];
  Map<String, String> _adversairesParId = {};

  String _rechercheTexte = '';
  Set<String> _filtresEquipes = {};
  Set<String> _filtresCompet = {};
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _equipeService = EquipeService(_client);
    _initialiserListes();
  }

  @override
  void didUpdateWidget(covariant ProgrammationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSeason != widget.selectedSeason ||
        oldWidget.categorie != widget.categorie) {
      _initialiserListes();
    }
  }

  @override
  void dispose() {
    _adversaireCtrl.dispose();
    super.dispose();
  }

  Future<void> _initialiserListes() async {
    final equipes = await _chargerEquipesContexte();
    final competitions = _competitionsPourCategorie();
    final adversaires = await _chargerAdversaires();

    if (!mounted) return;
    setState(() {
      _listeEquipes = equipes;
      _listeCompet = competitions;
      _adversairesParId = adversaires;
      _adversaires = adversaires.values.toList()..sort();
      _equipe = equipes.contains(_equipe) ? _equipe : equipes.first;
      _competition = competitions.contains(_competition)
          ? _competition
          : competitions.first;
      _filtresEquipes = _filtresEquipes.intersection(equipes.toSet());
      _filtresCompet = _filtresCompet.intersection(competitions.toSet());
    });
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

  Future<void> _ajouterProgrammation() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final adversaire = _adversaireCtrl.text.trim();
      final adversaireId = await _ensureAdversaire(adversaire);
      final heureStr =
          '${_heureSelectionnee.toString().padLeft(2, '0')}:${_minuteSelectionnee.toString().padLeft(2, '0')}';
      final base = {
        'date': _dateSelectionnee.toIso8601String(),
        'heure': heureStr,
        'equipe': _equipe,
        'adversaire_id': adversaireId,
        'lieu': _lieu,
        'competition': _competition,
        'categorie': categoriePourDb(widget.categorie),
        'saison': widget.selectedSeason,
      };

      await _client.from('programmations').insert(base);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Match programmé'),
            backgroundColor: Colors.green,
          ),
        );
        _adversaireCtrl.clear();
        setState(() => _refreshTick++);
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

  void _ouvrirDetails(Map<String, dynamic> prog) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ProgrammationDetailDialog(
          prog: prog,
          listeEquipes: _listeEquipes,
          listeCompet: _listeCompet,
          listeLieux: _listeLieux,
          listeHeures: _listeHeures,
          listeMinutes: _listeMinutes,
          adversaires: _adversaires,
          adversairesParId: _adversairesParId,
        );
      },
    );
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
                leading: const Icon(Icons.calendar_today, color: AppTheme.dore),
                title: const Text(
                  'PROGRAMMER UN MATCH',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.bleuMarine,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
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
                                child: DropdownButtonFormField<int>(
                                  initialValue: _heureSelectionnee,
                                  items: _listeHeures
                                      .map(
                                        (h) => DropdownMenuItem(
                                          value: h,
                                          child: Text(
                                            h.toString().padLeft(2, '0'),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _heureSelectionnee = v!),
                                  decoration: const InputDecoration(
                                    labelText: 'Heure',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  initialValue: _minuteSelectionnee,
                                  items: _listeMinutes
                                      .map(
                                        (m) => DropdownMenuItem(
                                          value: m,
                                          child: Text(
                                            m.toString().padLeft(2, '0'),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _minuteSelectionnee = v!),
                                  decoration: const InputDecoration(
                                    labelText: 'Min.',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
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
                                  onChanged: (v) =>
                                      setState(() => _equipe = v!),
                                  decoration: const InputDecoration(
                                    labelText: 'FCPB',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: _buildAdversaireAutocomplete(
                                  _adversaireCtrl,
                                  'Adversaire',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _competition,
                                  items: _listeCompet
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _competition = v!),
                                  decoration: const InputDecoration(
                                    labelText: 'Compétition',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _ajouterProgrammation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.bleuMarine,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('VALIDER'),
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
                  'Prochains matchs',
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
                .from('programmations')
                .stream(primaryKey: ['id'])
                .order('date', ascending: true),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              var progs = snapshot.data!
                  .where((m) => categorieMatches(widget.categorie, m['categorie']))
                  .where((m) => m['saison'] == widget.selectedSeason)
                  .toList();

              if (_rechercheTexte.isNotEmpty) {
                progs = progs
                    .where(
                      (m) => _nomAdversaire(
                        m,
                      ).toLowerCase().contains(_rechercheTexte.toLowerCase()),
                    )
                    .toList();
              }
              if (_filtresEquipes.isNotEmpty) {
                progs = progs
                    .where((m) => _filtresEquipes.contains(m['equipe']))
                    .toList();
              }
              if (_filtresCompet.isNotEmpty) {
                progs = progs
                    .where((m) => _filtresCompet.contains(m['competition']))
                    .toList();
              }

              if (progs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Aucun match prévu.'),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: progs.length,
                separatorBuilder: (_, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) =>
                    _buildProgrammationTile(progs[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdversaireAutocomplete(
    TextEditingController controller,
    String label,
  ) {
    return Autocomplete<String>(
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return _adversaires.where((nom) => nom.toLowerCase().contains(query));
      },
      onSelected: (value) => controller.text = value,
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        if (textController.text != controller.text) {
          textController.text = controller.text;
        }
        textController.addListener(() => controller.text = textController.text);
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
        );
      },
    );
  }

  Widget _buildProgrammationTile(Map<String, dynamic> prog) {
    final date = DateTime.parse(prog['date']);
    final heure = _formatHeure(prog['heure']);
    final equipe = prog['equipe']?.toString() ?? '';
    final notreEquipe = _nomEquipeFcpb(equipe);
    final adversaire = _nomAdversaire(prog);
    final domicile = prog['lieu'] == 'DOM';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
        leading: Container(
          width: 48,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.bleuClair,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            heure,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
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
                    TextSpan(text: ' - $adversaire'),
                  ]
                : [
                    TextSpan(text: '$adversaire - '),
                    TextSpan(
                      text: notreEquipe,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
          ),
        ),
        subtitle: Text(
          '${DateFormat('dd/MM').format(date)} - ${prog['lieu']} (${prog['competition']})',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.edit_note, color: Colors.grey),
        onTap: () => _ouvrirDetails(prog),
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

  String _formatHeure(dynamic value) {
    final raw = value?.toString() ?? '';
    if (raw.length >= 5) return raw.substring(0, 5);
    return raw;
  }
}

class ProgrammationDetailDialog extends StatefulWidget {
  final Map<String, dynamic> prog;
  final List<String> listeEquipes;
  final List<String> listeCompet;
  final List<String> listeLieux;
  final List<int> listeHeures;
  final List<int> listeMinutes;
  final List<String> adversaires;
  final Map<String, String> adversairesParId;

  const ProgrammationDetailDialog({
    super.key,
    required this.prog,
    required this.listeEquipes,
    required this.listeCompet,
    required this.listeLieux,
    required this.listeHeures,
    required this.listeMinutes,
    required this.adversaires,
    required this.adversairesParId,
  });

  @override
  State<ProgrammationDetailDialog> createState() =>
      _ProgrammationDetailDialogState();
}

class _ProgrammationDetailDialogState extends State<ProgrammationDetailDialog> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _isEditing = false;
  late String _equipe;
  late TextEditingController _adversaireController;
  late String _lieu;
  late String _competition;
  late DateTime _date;
  late int _heureEdit;
  late int _minuteEdit;

  @override
  void initState() {
    super.initState();
    _equipe = widget.prog['equipe'];
    _adversaireController = TextEditingController(
      text: _nomAdversaire(widget.prog),
    );
    _lieu = widget.prog['lieu'];
    _competition = widget.prog['competition'];
    _date = DateTime.parse(widget.prog['date']);
    final parts = widget.prog['heure'].toString().split(':');
    _heureEdit = int.tryParse(parts.first) ?? 15;
    _minuteEdit = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
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
    return '';
  }

  String _nomEquipeFcpb(String equipe) {
    final clean = equipe.trim();
    if (clean.isEmpty) return 'FCPB';
    if (clean.toUpperCase().startsWith('FCPB')) return clean;
    return 'FCPB $clean';
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

  @override
  void dispose() {
    _adversaireController.dispose();
    super.dispose();
  }

  Future<void> _sauvegarderModifs() async {
    final heureStr =
        '${_heureEdit.toString().padLeft(2, '0')}:${_minuteEdit.toString().padLeft(2, '0')}';
    final adversaireId = await _ensureAdversaire(_adversaireController.text);
    await _client
        .from('programmations')
        .update({
          'equipe': _equipe,
          'adversaire_id': adversaireId,
          'lieu': _lieu,
          'competition': _competition,
          'date': _date.toIso8601String(),
          'heure': heureStr,
        })
        .eq('id', widget.prog['id']);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _supprimer() async {
    await _client.from('programmations').delete().eq('id', widget.prog['id']);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Modifier Programmation' : 'Détails'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditing) ...[
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    locale: const Locale('fr', 'FR'),
                    firstDate: DateTime(2023),
                    lastDate: DateTime(2030),
                    initialDate: _date,
                  );
                  if (d != null) setState(() => _date = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(DateFormat('dd/MM/yyyy').format(_date)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _heureEdit,
                      items: widget.listeHeures
                          .map(
                            (h) =>
                                DropdownMenuItem(value: h, child: Text('$h')),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _heureEdit = v!),
                      decoration: const InputDecoration(
                        labelText: 'Heure',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _minuteEdit,
                      items: widget.listeMinutes
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m.toString().padLeft(2, '0')),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _minuteEdit = v!),
                      decoration: const InputDecoration(
                        labelText: 'Min.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _equipe,
                items: widget.listeEquipes
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() => _equipe = v!),
                decoration: const InputDecoration(
                  labelText: 'FCPB',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _adversaireController,
                decoration: const InputDecoration(
                  labelText: 'Adversaire',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _lieu,
                items: widget.listeLieux
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _lieu = v!),
                decoration: const InputDecoration(
                  labelText: 'Lieu',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _competition,
                items: widget.listeCompet
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _competition = v!),
                decoration: const InputDecoration(
                  labelText: 'Compétition',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              Center(
                child: Text(
                  _lieu == 'DOM'
                      ? '${_nomEquipeFcpb(_equipe)} - ${_adversaireController.text}'
                      : '${_adversaireController.text} - ${_nomEquipeFcpb(_equipe)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const Divider(),
              Text('Date : ${DateFormat('dd/MM/yyyy').format(_date)}'),
              Text(
                'Heure : ${_heureEdit.toString().padLeft(2, '0')}:${_minuteEdit.toString().padLeft(2, '0')}',
              ),
              Text('Lieu : $_lieu'),
              Text('Compétition : $_competition'),
            ],
          ],
        ),
      ),
      actions: [
        if (_isEditing) ...[
          TextButton(
            onPressed: () => setState(() => _isEditing = false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _sauvegarderModifs,
            child: const Text('Enregistrer'),
          ),
        ] else ...[
          TextButton(
            onPressed: _supprimer,
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
}
