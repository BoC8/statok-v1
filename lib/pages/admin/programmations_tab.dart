import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/joueur_model.dart';
import '../../theme/app_theme.dart';

class ProgrammationsTab extends StatefulWidget {
  const ProgrammationsTab({super.key});

  @override
  State<ProgrammationsTab> createState() => _ProgrammationsTabState();
}

class _ProgrammationsTabState extends State<ProgrammationsTab> {
  final SupabaseClient _client = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // --- VARIABLES DU FORMULAIRE D'AJOUT ---
  DateTime _dateSelectionnee = DateTime.now();
  int _heureSelectionnee = 15;
  int _minuteSelectionnee = 0;
  
  String _equipe = '18A';
  final TextEditingController _adversaireCtrl = TextEditingController();
  String _lieu = 'DOM';
  
  // Valeur par défaut
  String _competition = 'Phase 1';

  // Listes
  final List<String> _listeEquipes = ['17', '18A', '18B'];
  final List<String> _listeLieux = ['DOM', 'EXT'];
  final List<String> _listeCompet = ['Phase 1', 'Phase 2', 'Phase 3', 'Coupe', 'Amical'];
  final List<int> _listeHeures = List.generate(24, (index) => index); 
  final List<int> _listeMinutes = [0, 15, 30, 45]; 

  // --- VARIABLES DE FILTRES ---
  String _rechercheTexte = '';
  String _filtreEquipe = 'Tout';
  String _filtreCompetition = 'Tout';

  List<JoueurModel> _tousLesJoueurs = [];

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

  // Ajout d'une programmation dans Supabase
  Future<void> _ajouterProgrammation() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      final heureStr = "${_heureSelectionnee.toString().padLeft(2, '0')}:${_minuteSelectionnee.toString().padLeft(2, '0')}";
      
      await _client.from('programmations').insert({
        'date': _dateSelectionnee.toIso8601String(),
        'heure': heureStr,
        'equipe': _equipe,
        'adversaire': _adversaireCtrl.text,
        'lieu': _lieu,
        'competition': _competition,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Match programmé !'), backgroundColor: Colors.green));
        _adversaireCtrl.clear();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  void _ouvrirDetails(Map<String, dynamic> prog) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return ProgrammationDetailDialog(
          prog: prog,
          // On passe TOUTES les listes nécessaires pour l'édition (Equipes ajoutées)
          listeEquipes: _listeEquipes,
          listeCompet: _listeCompet,
          listeLieux: _listeLieux,
          listeHeures: _listeHeures,
          listeMinutes: _listeMinutes,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // --- 1. FORMULAIRE D'AJOUT ---
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                leading: const Icon(Icons.calendar_today, color: AppTheme.dore),
                title: const Text("PROGRAMMER UN MATCH", style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.bleuMarine)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const Divider(),
                          // Ligne Date / Heure / Minutes
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2, 
                                child: InkWell(
                                  onTap: () async { 
                                    final d = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime(2030), initialDate: _dateSelectionnee); 
                                    if (d != null) setState(() => _dateSelectionnee = d); 
                                  }, 
                                  child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yyyy').format(_dateSelectionnee)))
                                )
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1, 
                                child: DropdownButtonFormField<int>(
                                  value: _heureSelectionnee, 
                                  items: _listeHeures.map((h) => DropdownMenuItem(value: h, child: Text("${h}h"))).toList(), 
                                  onChanged: (v) => setState(() => _heureSelectionnee = v!), 
                                  decoration: const InputDecoration(labelText: 'Heure', border: OutlineInputBorder())
                                )
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 1, 
                                child: DropdownButtonFormField<int>(
                                  value: _minuteSelectionnee, 
                                  items: _listeMinutes.map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))).toList(), 
                                  onChanged: (v) => setState(() => _minuteSelectionnee = v!), 
                                  decoration: const InputDecoration(labelText: 'Min.', border: OutlineInputBorder())
                                )
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Ligne Equipe / Adversaire
                          Row(
                            children: [
                              Expanded(flex: 1, child: DropdownButtonFormField(value: _equipe, items: _listeEquipes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _equipe = v!), decoration: const InputDecoration(labelText: 'Notre Équipe', border: OutlineInputBorder()))),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: TextFormField(controller: _adversaireCtrl, decoration: const InputDecoration(labelText: 'Adversaire', border: OutlineInputBorder()), validator: (v) => v!.isEmpty ? 'Requis' : null)),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Ligne Lieu / Compétition
                          Row(
                            children: [
                              Expanded(child: DropdownButtonFormField(value: _lieu, items: _listeLieux.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _lieu = v!), decoration: const InputDecoration(labelText: 'Lieu', border: OutlineInputBorder()))),
                              const SizedBox(width: 10),
                              Expanded(child: DropdownButtonFormField(value: _competition, items: _listeCompet.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _competition = v!), decoration: const InputDecoration(labelText: 'Compétition', border: OutlineInputBorder()))),
                            ],
                          ),
                          const SizedBox(height: 15),
                          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _ajouterProgrammation, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bleuMarine, foregroundColor: Colors.white), child: const Text("VALIDER LA PROGRAMMATION"))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- 2. FILTRES ---
          const Align(alignment: Alignment.centerLeft, child: Text("Prochains matchs", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(height: 10),
          
          TextField(
            decoration: InputDecoration(labelText: 'Rechercher un adversaire...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0), fillColor: Colors.white, filled: true),
            onChanged: (val) => setState(() => _rechercheTexte = val),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _filtreEquipe, isExpanded: true, items: ['Tout', ..._listeEquipes].map((e) => DropdownMenuItem(value: e, child: Text(e == 'Tout' ? 'Toutes Équipes' : e))).toList(), onChanged: (v) => setState(() => _filtreEquipe = v!))))),
              const SizedBox(width: 10),
              Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade400)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _filtreCompetition, isExpanded: true, items: ['Tout', ..._listeCompet].map((e) => DropdownMenuItem(value: e, child: Text(e == 'Tout' ? 'Toutes Compét.' : e, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setState(() => _filtreCompetition = v!)))))
            ],
          ),

          const SizedBox(height: 10),

          // --- 3. LISTE TEMPS RÉEL (STREAM) ---
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _client.from('programmations').stream(primaryKey: ['id']).order('date', ascending: true),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
              
              var progs = snapshot.data!;
              
              // Filtrage local
              if (_rechercheTexte.isNotEmpty) {
                progs = progs.where((m) => m['adversaire'].toString().toLowerCase().contains(_rechercheTexte.toLowerCase())).toList();
              }
              if (_filtreEquipe != 'Tout') {
                progs = progs.where((m) => m['equipe'] == _filtreEquipe).toList();
              }
              if (_filtreCompetition != 'Tout') {
                progs = progs.where((m) => m['competition'] == _filtreCompetition).toList();
              }

              if (progs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Aucun match prévu.")));

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: progs.length,
                separatorBuilder: (_,__) => const Divider(),
                itemBuilder: (context, index) {
                  final prog = progs[index];
                  final date = DateTime.parse(prog['date']);
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.bleuClair, borderRadius: BorderRadius.circular(8)),
                      child: Text(prog['heure'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    title: Text("${prog['equipe']} vs ${prog['adversaire']}"),
                    subtitle: Text("${DateFormat('dd/MM').format(date)} - ${prog['lieu']} (${prog['competition']})"),
                    trailing: const Icon(Icons.edit_calendar, color: Colors.grey),
                    onTap: () => _ouvrirDetails(prog),
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
// MODALE : DÉTAILS / MODIF COMPLETE / SUPPRESSION
// ============================================================================
class ProgrammationDetailDialog extends StatefulWidget {
  final Map<String, dynamic> prog;
  
  // Listes pour les dropdowns d'édition
  final List<String> listeEquipes; // AJOUTÉ
  final List<String> listeCompet;
  final List<String> listeLieux;
  final List<int> listeHeures;
  final List<int> listeMinutes;

  const ProgrammationDetailDialog({
    super.key, 
    required this.prog, 
    required this.listeEquipes, // AJOUTÉ
    required this.listeCompet,
    required this.listeLieux,
    required this.listeHeures,
    required this.listeMinutes,
  });

  @override
  State<ProgrammationDetailDialog> createState() => _ProgrammationDetailDialogState();
}

class _ProgrammationDetailDialogState extends State<ProgrammationDetailDialog> {
  final SupabaseClient _client = Supabase.instance.client;
  bool _isEditing = false;
  
  // Variables d'édition
  late String _equipe; // AJOUTÉ
  late String _adversaire;
  late String _lieu;
  late String _competition;
  late DateTime _date;
  late int _heureEdit;
  late int _minuteEdit;

  @override
  void initState() {
    super.initState();
    _equipe = widget.prog['equipe']; // Init
    _adversaire = widget.prog['adversaire'];
    _lieu = widget.prog['lieu'];
    _competition = widget.prog['competition'];
    _date = DateTime.parse(widget.prog['date']);

    try {
      final parts = widget.prog['heure'].split(':');
      _heureEdit = int.parse(parts[0]);
      _minuteEdit = int.parse(parts[1]);
    } catch (e) {
      _heureEdit = 15;
      _minuteEdit = 0;
    }
  }

  Future<void> _sauvegarderModifs() async {
    try {
      final heureStr = "${_heureEdit.toString().padLeft(2, '0')}:${_minuteEdit.toString().padLeft(2, '0')}";
      
      await _client.from('programmations').update({
        'equipe': _equipe, // Save Equipe
        'adversaire': _adversaire,
        'lieu': _lieu,
        'competition': _competition,
        'date': _date.toIso8601String(),
        'heure': heureStr,
      }).eq('id', widget.prog['id']);
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print(e);
    }
  }

  Future<void> _supprimer() async {
    await _client.from('programmations').delete().eq('id', widget.prog['id']);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? "Modifier Programmation" : "Détails"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isEditing) ...[
              // --- MODE ÉDITION (Champs complets) ---
              // Date
              InkWell(
                onTap: () async { 
                  final d = await showDatePicker(context: context, firstDate: DateTime(2023), lastDate: DateTime(2030), initialDate: _date); 
                  if (d != null) setState(() => _date = d); 
                },
                child: InputDecorator(decoration: const InputDecoration(labelText: 'Date', border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yyyy').format(_date))),
              ),
              const SizedBox(height: 10),
              // Heure / Minutes
              Row(
                children: [
                   Expanded(child: DropdownButtonFormField<int>(value: _heureEdit, items: widget.listeHeures.map((h) => DropdownMenuItem(value: h, child: Text("${h}h"))).toList(), onChanged: (v) => setState(() => _heureEdit = v!), decoration: const InputDecoration(labelText: 'Heure', border: OutlineInputBorder()))),
                   const SizedBox(width: 10),
                   Expanded(child: DropdownButtonFormField<int>(value: _minuteEdit, items: widget.listeMinutes.map((m) => DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0')))).toList(), onChanged: (v) => setState(() => _minuteEdit = v!), decoration: const InputDecoration(labelText: 'Min.', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 10),
              // EQUIPE (AJOUTÉ)
              DropdownButtonFormField<String>(value: _equipe, items: widget.listeEquipes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _equipe = v!), decoration: const InputDecoration(labelText: 'Notre Équipe', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextFormField(initialValue: _adversaire, decoration: const InputDecoration(labelText: 'Adversaire', border: OutlineInputBorder()), onChanged: (v) => _adversaire = v),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: _lieu, items: widget.listeLieux.map((l) => DropdownMenuItem(value: l, child: Text(l))).toList(), onChanged: (v) => setState(() => _lieu = v!), decoration: const InputDecoration(labelText: 'Lieu', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(value: _competition, items: widget.listeCompet.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _competition = v!), decoration: const InputDecoration(labelText: 'Compétition', border: OutlineInputBorder())),
            ] else ...[
              // --- MODE LECTURE ---
              // Utilisation des variables locales pour l'affichage (mise à jour directe si switch edit/lecture)
              Center(child: Text("$_equipe vs $_adversaire", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              const Divider(),
              ListTile(leading: const Icon(Icons.calendar_today, color: AppTheme.bleuMarine), title: Text("Date : ${DateFormat('dd/MM/yyyy').format(DateTime.parse(widget.prog['date']))}")),
              ListTile(leading: const Icon(Icons.access_time, color: AppTheme.bleuMarine), title: Text("Heure : ${widget.prog['heure']}")),
              ListTile(leading: const Icon(Icons.place, color: AppTheme.bleuMarine), title: Text("Lieu : ${widget.prog['lieu']}")),
              ListTile(leading: const Icon(Icons.emoji_events, color: AppTheme.bleuMarine), title: Text("Compét : ${widget.prog['competition']}")),
            ]
          ],
        ),
      ),
      actions: [
        if (_isEditing) ...[
           // BOUTONS ÉDITION
           TextButton(onPressed: () => setState(() => _isEditing = false), child: const Text("Annuler")),
           ElevatedButton(onPressed: _sauvegarderModifs, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text("Enregistrer")),
        ] else ...[
           // BOUTONS LECTURE (Supprimer / Fermer / Modifier)
           TextButton(onPressed: _supprimer, style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text("Supprimer")),
           TextButton(onPressed: () => Navigator.pop(context), child: const Text("Fermer")),
           ElevatedButton.icon(icon: const Icon(Icons.edit), label: const Text("Modifier"), onPressed: () => setState(() => _isEditing = true))
        ]
      ],
    );
  }
}