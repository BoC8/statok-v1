import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

class EquipeDashboardPage extends StatefulWidget {
  final String equipeName;

  const EquipeDashboardPage({super.key, required this.equipeName});

  @override
  State<EquipeDashboardPage> createState() => _EquipeDashboardPageState();
}

class _EquipeDashboardPageState extends State<EquipeDashboardPage> {
  final SupabaseClient _client = Supabase.instance.client;

  // ==================================================================
  // ZONE DE CONFIGURATION MANUELLE (POSITIONS SEULEMENT)
  // Mettez juste la position (ex: "1er", "5ème").
  // Les points seront calculés automatiquement via les matchs.
  // ==================================================================
  Map<String, Map<String, String>> _classementsManuel = {
    '18A': {
      'Phase 1': '5ème/5',
      'Phase 2': '5ème/6',
      'Phase 3': 'en cours',
    },
    '18B': {
      'Phase 1': '6ème/6',
      'Phase 2': '1er/6',
      'Phase 3': 'en cours',
    },
    '17': {
      'Phase 1': '2ème/5',
      'Phase 2': '5ème/6',
      'Phase 3': 'en cours',
    },
  };
  // ==================================================================

  bool _isLoading = true;
  List<Map<String, dynamic>> _allMatches = [];
  Map<String, dynamic>? _nextMatch;

  String _filtreLieu = 'Tout';
  String _filtreCompet = 'Tout';
  
  final List<String> _optsLieu = ['Tout', 'Domicile', 'Extérieur'];
  final List<String> _optsCompet = ['Tout', 'Phase 1', 'Phase 2', 'Phase 3', 'Coupe', 'Amical'];

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resMatches = await _client
          .from('matchs')
          .select()
          .eq('equipe', widget.equipeName)
          .order('date', ascending: false);

      final resProg = await _client
          .from('programmations')
          .select()
          .eq('equipe', widget.equipeName)
          .gte('date', DateTime.now().toIso8601String())
          .order('date', ascending: true)
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _allMatches = List<Map<String, dynamic>>.from(resMatches);
          _nextMatch = resProg;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  String _formatHeure(String? heure) {
    if (heure == null) return '?';
    if (heure.length >= 5) {
      return heure.substring(0, 5);
    }
    return heure;
  }

  Map<String, int> _getGlobalStats() {
    int v = 0, n = 0, d = 0, cs = 0;
    for (var m in _allMatches) {
      int gjpb = m['buts_gjpb'];
      int adv = m['buts_adv'];
      if (gjpb > adv) v++;
      else if (gjpb == adv) n++;
      else d++;
      
      if (adv == 0) cs++;
    }
    return {'v': v, 'n': n, 'd': d, 'cs': cs, 'total': _allMatches.length};
  }

String _getCurrentStreak() {
    if (_allMatches.isEmpty) return "Aucun match joué";

    // --- 1. CALCULS PRÉLIMINAIRES ---

    // Série de victoires pures (active)
    int winStreak = 0;
    for (var m in _allMatches) {
      if (m['buts_gjpb'] > m['buts_adv']) winStreak++;
      else break;
    }

    // Série sans défaite (active)
    int noDefeatStreak = 0;
    for (var m in _allMatches) {
      if (m['buts_gjpb'] >= m['buts_adv']) noDefeatStreak++;
      else break;
    }

    // Série sans victoire (active - pour le cas 5)
    int noWinStreak = 0;
    for (var m in _allMatches) {
      if (m['buts_gjpb'] <= m['buts_adv']) noWinStreak++;
      else break;
    }

    // Victoires sur les 10 derniers matchs
    int winsInLast10 = 0;
    int range10 = _allMatches.length < 10 ? _allMatches.length : 10;
    for (int i = 0; i < range10; i++) {
      if (_allMatches[i]['buts_gjpb'] > _allMatches[i]['buts_adv']) winsInLast10++;
    }

    // Victoires sur les 5 derniers matchs
    int winsInLast5 = 0;
    int range5 = _allMatches.length < 5 ? _allMatches.length : 5;
    for (int i = 0; i < range5; i++) {
      if (_allMatches[i]['buts_gjpb'] > _allMatches[i]['buts_adv']) winsInLast5++;
    }

    // --- 2. LOGIQUE EN CASCADE (PRIORITÉS) ---

    // 1) "FEU" : 3 victoires ou plus consécutives
    if (winStreak >= 3) {
      return "🔥 $winStreak Victoires consécutives !";
    }
    
    // 2) "BOUCLIER" : 5 matchs ou plus sans défaite
    else if (noDefeatStreak >= 5) {
      return "🛡️ $noDefeatStreak Matchs sans défaite";
    }
    
    // 3) "FORME 10" : 5 victoires ou plus sur les 10 derniers
    else if (winsInLast10 > 5) {
      return "📈 $winsInLast10 Victoires sur les 10 derniers matchs";
    }
    
    // 4) "FORME 5" : 3 victoires ou plus sur les 5 derniers
    else if (winsInLast5 >= 3) {
      return "💪 $winsInLast5 Victoires sur les 5 derniers matchs";
    }
    
    // 5) SINON : X Matchs sans victoire
    else {
      if (noWinStreak > 0) {
        String label = noWinStreak > 1 ? "Matchs" : "Match";
        return "☁️ $noWinStreak $label sans victoire";
      } else {
        // Cas rare : On vient de gagner (donc noWinStreak = 0), 
        // mais on n'a pas atteint les seuils du dessus (ex: 1 victoire isolée ou 2 victoires)
        return "1 Victoire (Série en cours)";
      }
    }
  }

  Map<String, double> _getFilteredStats() {
    double v = 0, n = 0, d = 0;
    double butsM = 0, butsE = 0;
    double points = 0;
    int count = 0;

    for (var m in _allMatches) {
      if (_filtreLieu == 'Domicile' && m['lieu'] != 'DOM') continue;
      if (_filtreLieu == 'Extérieur' && m['lieu'] != 'EXT') continue;
      if (_filtreCompet != 'Tout' && m['competition'] != _filtreCompet) continue;

      count++;
      int gjpb = m['buts_gjpb'];
      int adv = m['buts_adv'];
      butsM += gjpb;
      butsE += adv;

      if (gjpb > adv) {
        v++;
        points += 3;
      } else if (gjpb == adv) {
        n++;
        points += 1;
      } else {
        d++;
      }
    }

    return {
      'v': v, 'n': n, 'd': d, 
      'bm': butsM, 'be': butsE, 
      'total': count.toDouble(),
      'pts_match': count > 0 ? (points / count) : 0.0
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final globalStats = _getGlobalStats();
    final winPercent = globalStats['total']! > 0 ? (globalStats['v']! / globalStats['total']! * 100).toStringAsFixed(0) : "0";

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.equipeName}"),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. STATS GLOBALES
            const Text("SAISON EN COURS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              children: [
                _buildStatTile("Matchs", "${globalStats['total']}", Icons.sports_soccer, Colors.blue),
                _buildStatTile("Victoires", "$winPercent%", Icons.emoji_events, Colors.orange),
                _buildStatTile("Clean Sheet", "${globalStats['cs']}", Icons.shield, Colors.green),
              ],
            ),
            const SizedBox(height: 10),
            
            // CLASSEMENTS (Position Manuelle + Points Auto)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildPhasePoints("Phase 1"),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  _buildPhasePoints("Phase 2"),
                  Container(width: 1, height: 30, color: Colors.grey[300]),
                  _buildPhasePoints("Phase 3"),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. FORME RÉCENTE
            const Text("FORME RÉCENTE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _allMatches.take(5).map((m) {
                      bool win = m['buts_gjpb'] > m['buts_adv'];
                      bool draw = m['buts_gjpb'] == m['buts_adv'];
                      Color color = win ? Colors.green : (draw ? Colors.grey : Colors.red);
                      String text = win ? "V" : (draw ? "N" : "D");
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 35, height: 35,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Text(_getCurrentStreak(), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.bleuMarine)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. DERNIER ET PROCHAIN MATCH
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("DERNIER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 8),
                      _allMatches.isNotEmpty 
                        ? _buildHalfWidthMatchCard(_allMatches.first, isPlayed: true)
                        : _buildEmptyCard("Aucun match joué"),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PROCHAIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                      const SizedBox(height: 8),
                      _nextMatch != null 
                        ? _buildHalfWidthMatchCard(_nextMatch!, isPlayed: false)
                        : _buildEmptyCard("Aucun match prévu"),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // 4. ANALYSE (GRAPHIQUES)
            const Text("ANALYSE DÉTAILLÉE", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 10),
            
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: _buildPrettyFilter(value: _filtreLieu, label: "Lieu", icon: Icons.place, items: _optsLieu, onChanged: (v) => setState(() => _filtreLieu = v!))),
                  const SizedBox(width: 10),
                  Expanded(child: _buildPrettyFilter(value: _filtreCompet, label: "Compét.", icon: Icons.emoji_events, items: _optsCompet, onChanged: (v) => setState(() => _filtreCompet = v!))),
                ],
              ),
            ),
            const SizedBox(height: 10),

            _buildChartsSection(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildStatTile(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.bleuMarine)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  // MODIFICATION ICI : Calcul auto des points + Position Manuelle
  Widget _buildPhasePoints(String phase) {
    // 1. Récupération de la position manuelle
    String rank = _classementsManuel[widget.equipeName]?[phase] ?? "-";
    
    // 2. Calcul des points automatique en fonction des matchs en base
    int points = 0;
    for (var m in _allMatches) {
      if (m['competition'] == phase) {
        if (m['buts_gjpb'] > m['buts_adv']) {
          points += 3; // Victoire
        } else if (m['buts_gjpb'] == m['buts_adv']) {
          points += 1; // Nul
        }
      }
    }
    
    return Column(
      children: [
        Text(phase.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 4),
        // Affichage : "2ème (18 pts)"
        Text("$rank ($points pts)", style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.bleuMarine, fontSize: 13)),
      ],
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12))),
    );
  }

  Widget _buildHalfWidthMatchCard(Map<String, dynamic> m, {required bool isPlayed}) {
    bool win = isPlayed && (m['buts_gjpb'] > m['buts_adv']);
    bool draw = isPlayed && (m['buts_gjpb'] == m['buts_adv']);
    
    Color color = isPlayed 
        ? (win ? Colors.green : (draw ? Colors.grey : Colors.red)) 
        : AppTheme.bleuMarine;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                Text(
                  "${DateFormat('dd/MM').format(DateTime.parse(m['date']))} - ${m['competition'].toString().toUpperCase()}", 
                  style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 8),
                
                if (isPlayed)
                   Text("${m['buts_gjpb']} - ${m['buts_adv']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.bleuMarine))
                else
                   Text(_formatHeure(m['heure']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppTheme.bleuMarine)),
                
                const SizedBox(height: 8),
                const Text("CONTRE", style: TextStyle(fontSize: 8, color: Colors.grey)),
                Text(
                  m['adversaire'], 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.bleuMarine),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey), items: items.map((e) { return DropdownMenuItem(value: e, child: Text(e == 'Tout' ? 'Tout' : (label == "Lieu" ? e : e), style: const TextStyle(fontSize: 13, color: Colors.black87), overflow: TextOverflow.ellipsis)); }).toList(), onChanged: onChanged))),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    final stats = _getFilteredStats();
    double total = stats['total']!;

    if (total == 0) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Aucun match avec ces filtres")));

    List<PieChartSectionData> sectionsResult = [
      if(stats['v']! > 0) PieChartSectionData(value: stats['v']!, color: Colors.green, title: "V", radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      if(stats['n']! > 0) PieChartSectionData(value: stats['n']!, color: Colors.grey, title: "N", radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      if(stats['d']! > 0) PieChartSectionData(value: stats['d']!, color: Colors.red, title: "D", radius: 50, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ];

    List<PieChartSectionData> sectionsButs = [
      if(stats['bm']! > 0) PieChartSectionData(value: stats['bm']!, color: AppTheme.bleuMarine, title: "${stats['bm']!.toInt()}", radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      if(stats['be']! > 0) PieChartSectionData(value: stats['be']!, color: Colors.redAccent, title: "${stats['be']!.toInt()}", radius: 40, titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ];

    return Column(
      children: [
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(PieChartData(sections: sectionsResult, centerSpaceRadius: 30, sectionsSpace: 2)),
                    Text("${((stats['v']!/total)*100).toInt()}%", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _LegendItem(color: Colors.green, text: "Victoires"),
                  _LegendItem(color: Colors.grey, text: "Nuls"),
                  _LegendItem(color: Colors.red, text: "Défaites"),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 10),
        
        // POINTS PAR MATCH (Conditionnel)
        if (_filtreCompet.startsWith("Phase"))
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(color: AppTheme.dore, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Points / Match :", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                Text(stats['pts_match']!.toStringAsFixed(2), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
          ),
        
        const SizedBox(height: 10),

        Container(
          height: 180,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _LegendItem(color: AppTheme.bleuMarine, text: "Marqués"),
                  _LegendItem(color: Colors.redAccent, text: "Encaissés"),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: PieChart(PieChartData(sections: sectionsButs, centerSpaceRadius: 40, sectionsSpace: 2)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;
  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}