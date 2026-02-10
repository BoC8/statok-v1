import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

// Modèle spécifique pour les Résultats
class MatchResult {
  final int id;
  final DateTime date;
  final String equipe;
  final String adversaire;
  final String competition;
  final String lieu;
  final int butsGjpb;
  final int butsAdv;
  final List<String> buteurs;
  final List<String> passeurs;

  MatchResult({
    required this.id,
    required this.date,
    required this.equipe,
    required this.adversaire,
    required this.competition,
    required this.lieu,
    required this.butsGjpb,
    required this.butsAdv,
    required this.buteurs,
    required this.passeurs,
  });
}

class ResultatsPage extends StatefulWidget {
  const ResultatsPage({super.key});

  @override
  State<ResultatsPage> createState() => _ResultatsPageState();
}

class _ResultatsPageState extends State<ResultatsPage> {
  final SupabaseClient _client = Supabase.instance.client;

  // Données
  List<MatchResult> _allMatches = [];
  List<MatchResult> _filteredMatches = [];
  bool _isLoading = true;

  // Filtres
  String _filtreEquipe = 'Tout';
  String _filtreCompet = 'Tout';
  final List<String> _listeEquipes = ['17', '18A', '18B'];
  final List<String> _listeCompet = ['Phase 1', 'Phase 2', 'Phase 3', 'Coupe', 'Amical'];
  
  // État d'expansion des cartes
  Set<int> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _chargerResultats();
  }

  Future<void> _chargerResultats() async {
    try {
      // On récupère les matchs joués avec leurs actions
      final response = await _client
          .from('matchs')
          .select('*, actions(type, joueurs(nom))')
          .order('date', ascending: false); // Les plus récents en premier

      List<MatchResult> loaded = [];

      for (var m in response) {
        List<String> goals = [];
        List<String> assists = [];

        if (m['actions'] != null) {
          for (var action in m['actions']) {
            final nom = action['joueurs']?['nom'] ?? 'Inconnu';
            if (action['type'] == 'Goal') {
              goals.add(nom);
            } else {
              assists.add(nom);
            }
          }
        }

        loaded.add(MatchResult(
          id: m['id'],
          date: DateTime.parse(m['date']),
          equipe: m['equipe'],
          adversaire: m['adversaire'],
          competition: m['competition'] ?? 'Championnat',
          lieu: m['lieu'],
          butsGjpb: m['buts_gjpb'] ?? 0,
          butsAdv: m['buts_adv'] ?? 0,
          buteurs: goals,
          passeurs: assists,
        ));
      }

      setState(() {
        _allMatches = loaded;
        _isLoading = false;
        _appliquerFiltres();
      });

    } catch (e) {
      print("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  void _appliquerFiltres() {
    setState(() {
      _filteredMatches = _allMatches.where((m) {
        bool okEquipe = _filtreEquipe == 'Tout' || m.equipe == _filtreEquipe;
        bool okCompet = _filtreCompet == 'Tout' || m.competition == _filtreCompet;
        return okEquipe && okCompet;
      }).toList();
    });
  }

  // Grouper les matchs par mois
  Map<String, List<MatchResult>> _grouperParMois() {
    Map<String, List<MatchResult>> grouped = {};
    
    for (var match in _filteredMatches) {
      String monthKey = DateFormat('MMMM yyyy', 'fr_FR').format(match.date);
      if (!grouped.containsKey(monthKey)) {
        grouped[monthKey] = [];
      }
      grouped[monthKey]!.add(match);
    }
    
    return grouped;
  }

  // Compter les occurrences d'un joueur
  Map<String, int> _compterOccurrences(List<String> liste) {
    Map<String, int> count = {};
    for (var nom in liste) {
      count[nom] = (count[nom] ?? 0) + 1;
    }
    return count;
  }

  Color _getColorForCompet(String compet) {
    if (compet.contains('Coupe')) return AppTheme.dore;
    if (compet.contains('Amical')) return Colors.grey;
    return AppTheme.bleuMarine;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RÉSULTATS'),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: const Color.fromARGB(255, 178, 209, 239),
      body: Column(
        children: [
          // --- ZONE FILTRES ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPrettyFilter(
                    value: _filtreEquipe,
                    label: "Équipe",
                    icon: Icons.groups,
                    items: ['Tout', ..._listeEquipes],
                    onChanged: (v) { _filtreEquipe = v!; _appliquerFiltres(); },
                  )
                ),
                const SizedBox(width: 12),
                Expanded(
                   child: _buildPrettyFilter(
                    value: _filtreCompet,
                    label: "Compétition",
                    icon: Icons.emoji_events,
                    items: ['Tout', ..._listeCompet],
                    onChanged: (v) { _filtreCompet = v!; _appliquerFiltres(); },
                  )
                ),
              ],
            ),
          ),

          // --- LISTE DES RÉSULTATS GROUPÉS PAR MOIS ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredMatches.isEmpty
                ? const Center(child: Text("Aucun résultat trouvé.", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: _grouperParMois().length,
                    itemBuilder: (context, index) {
                      final months = _grouperParMois().keys.toList();
                      final monthKey = months[index];
                      final matchesInMonth = _grouperParMois()[monthKey]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // En-tête du mois
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 79, 133, 213),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.calendar_month, size: 18, color: const Color.fromARGB(255, 255, 255, 255)),
                                const SizedBox(width: 8),
                                Text(
                                  monthKey.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromARGB(255, 255, 255, 255),
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bleuMarine,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${matchesInMonth.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Matchs du mois
                          ...matchesInMonth.map((match) => _buildResultCard(match)),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrettyFilter({required String value, required String label, required IconData icon, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.bleuMarine),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
                items: items.map((e) {
                  Color textColor = Colors.black87;
                  if (label == "Compétition" && e != 'Tout') {
                    textColor = _getColorForCompet(e);
                  }
                  return DropdownMenuItem(
                    value: e, 
                    child: Row(
                      children: [
                         if (label == "Compétition" && e != 'Tout') ...[
                           Container(width: 8, height: 8, decoration: BoxDecoration(color: textColor, shape: BoxShape.circle)),
                           const SizedBox(width: 8),
                         ],
                         Text(
                           e == 'Tout' ? 'Toutes $label' : e, 
                           style: TextStyle(fontSize: 13, color: textColor, fontWeight: (label == "Compétition" && e != 'Tout') ? FontWeight.bold : FontWeight.normal), 
                           overflow: TextOverflow.ellipsis
                         ),
                      ],
                    )
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(MatchResult match) {
    Color barColor = _getColorForCompet(match.competition);
    bool isWin = match.butsGjpb > match.butsAdv;
    bool isDraw = match.butsGjpb == match.butsAdv;
    bool isExpanded = _expandedCards.contains(match.id);

    // Compter les occurrences pour détecter les triplés
    Map<String, int> buteursCount = _compterOccurrences(match.buteurs);
    Map<String, int> passeursCount = _compterOccurrences(match.passeurs);
    
    bool hasStats = match.buteurs.isNotEmpty || match.passeurs.isNotEmpty;
    bool isAway = match.lieu.toUpperCase().startsWith('EXT');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Barre latérale couleur
              Container(width: 6, color: barColor),
              Expanded(
                child: Column(
                  children: [
                    // Partie principale (toujours visible)
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header : Date - Compet - Lieu
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.calendar_today, size: 12, color: Colors.grey[600]),
                                  const SizedBox(width: 4),
                                  Text(DateFormat('dd/MM/yyyy').format(match.date), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
                                  const SizedBox(width: 8),
                                  Text("-", style: TextStyle(color: Colors.grey[400])),
                                  const SizedBox(width: 8),
                                  Text("${match.competition} (${match.lieu})", style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                              // Badge Résultat (V, N, D)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), 
                                decoration: BoxDecoration(
                                  color: isWin ? Colors.green.withOpacity(0.1) : (isDraw ? Colors.grey.withOpacity(0.2) : Colors.red.withOpacity(0.1)), 
                                  borderRadius: BorderRadius.circular(4)
                                ), 
                                child: Text(
                                  isWin ? "VICTOIRE" : (isDraw ? "NUL" : "DÉFAITE"), 
                                  style: TextStyle(fontSize: 9, color: isWin ? Colors.green : (isDraw ? Colors.grey[700] : Colors.red), fontWeight: FontWeight.bold)
                                )
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          
                          // Score et Equipes
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isAway ? match.adversaire : "GJPB ${match.equipe}",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isAway ? FontWeight.w500 : FontWeight.bold,
                                    color: isAway ? Colors.black : AppTheme.bleuMarine,
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                width: 55, height: 45,
                                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                                child: Center(
                                  child: Text(
                                    isAway
                                        ? "${match.butsAdv}-${match.butsGjpb}"
                                        : "${match.butsGjpb}-${match.butsAdv}",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isAway ? "GJPB ${match.equipe}" : match.adversaire,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isAway ? FontWeight.bold : FontWeight.w500,
                                    color: isAway ? AppTheme.bleuMarine : Colors.black,
                                  ),
                                  textAlign: TextAlign.right,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Bouton pour afficher les détails
                    if (hasStats)
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedCards.remove(match.id);
                            } else {
                              _expandedCards.add(match.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(top: BorderSide(color: Colors.grey.shade200)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 18,
                                color: AppTheme.bleuMarine,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isExpanded ? "Masquer les joueurs décisifs" : "Voir les joueurs décisifs",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.bleuMarine,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Détails (Buteurs / Passeurs) - Affichage conditionnel
                    if (isExpanded && hasStats)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Buteurs
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: const [Icon(Icons.sports_soccer, size: 14, color: Colors.black54), SizedBox(width: 4), Text("Buteurs", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))]),
                                  const SizedBox(height: 6),
                                  if (match.buteurs.isEmpty)
                                     const Text("-", style: TextStyle(fontSize: 12, color: Colors.grey))
                                  else
                                    ...buteursCount.entries.map((entry) {
                                      final nom = entry.key;
                                      final count = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                nom,
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            if (count >= 3)
                                              Container(
                                                margin: const EdgeInsets.only(left: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.dore,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'x$count',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            else if (count > 1)
                                              Text(
                                                ' (x$count)',
                                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                      );
                                    })
                                ],
                              ),
                            ),
                            Container(width: 1, height: 30, color: Colors.grey.shade200),
                            const SizedBox(width: 12),
                            // Passeurs
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: const [Icon(Icons.start, size: 14, color: Colors.black54), SizedBox(width: 4), Text("Passeurs", style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold))]),
                                  const SizedBox(height: 6),
                                   if (match.passeurs.isEmpty)
                                     const Text("-", style: TextStyle(fontSize: 12, color: Colors.grey))
                                  else
                                    ...passeursCount.entries.map((entry) {
                                      final nom = entry.key;
                                      final count = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 2),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                nom,
                                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                              ),
                                            ),
                                            if (count >= 3)
                                              Container(
                                                margin: const EdgeInsets.only(left: 4),
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.dore,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'x$count',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              )
                                            else if (count > 1)
                                              Text(
                                                ' (x$count)',
                                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                                              ),
                                          ],
                                        ),
                                      );
                                    })
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
