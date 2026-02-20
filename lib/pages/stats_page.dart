import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';

// ModÃ¨le pour les stats d'un joueur
class PlayerStats {
  final String name;
  final int goals;
  final int assists;
  final int total; // Buts + Passes

  PlayerStats({
    required this.name,
    required this.goals,
    required this.assists,
    required this.total,
  });
}

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final PageController _pageController = PageController(initialPage: 0);

  // --- VARIABLES D'Ã‰TAT ---
  bool _isLoading = true;
  List<PlayerStats> _allStats = []; // Stats brutes

  // Filtres
  String _filtreEquipe = 'Tout';
  String _filtreCompet = 'Tout';
  final List<String> _listeEquipes = ['17', '18A', '18B'];
  final List<String> _listeCompet = ['Phase 1', 'Phase 2', 'Phase 3', 'Coupe', 'Amical'];

  // Mode de classement : 0 = Buteurs, 1 = Passeurs, 2 = Mixte
  int _selectedTab = 0; 

  @override
  void initState() {
    super.initState();
    _chargerStats();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _chargerStats() async {
    try {
      // 1. RÃ©cupÃ©rer tous les joueurs
      final resJoueurs = await _client.from('joueurs').select();
      
      // 2. RÃ©cupÃ©rer toutes les actions avec les infos du match liÃ©
      // On utilise la syntaxe matchs!inner pour Ãªtre sÃ»r d'avoir le match
      final resActions = await _client.from('actions').select('type, joueur_id, matchs(equipe, competition)');

      Map<int, Map<String, dynamic>> statsMap = {};

      // Initialiser la map avec tous les joueurs (pour ceux qui ont 0 stats)
      for (var j in resJoueurs) {
        statsMap[j['id']] = {
          'name': j['nom'],
          'goals': 0,
          'assists': 0,
        };
      }

      // Remplir avec les actions
      for (var action in resActions) {
        final match = action['matchs'];
        if (match == null) continue;

        // FILTRAGE BRUT ICI (pour calculer uniquement ce qui correspond aux filtres)
        bool okEquipe = _filtreEquipe == 'Tout' || match['equipe'] == _filtreEquipe;
        bool okCompet = _filtreCompet == 'Tout' || match['competition'] == _filtreCompet;

        if (okEquipe && okCompet) {
          final jId = action['joueur_id'];
          final type = action['type'];

          if (statsMap.containsKey(jId)) {
            if (type == 'Goal') {
              statsMap[jId]!['goals']++;
            } else {
              statsMap[jId]!['assists']++;
            }
          }
        }
      }

      // Convertir en liste d'objets PlayerStats
      List<PlayerStats> computed = [];
      statsMap.forEach((key, value) {
        // On ne garde que ceux qui ont au moins 1 stat (sinon la liste est trop longue)
        int total = value['goals'] + value['assists'];
        if (total > 0) {
          computed.add(PlayerStats(
            name: value['name'],
            goals: value['goals'],
            assists: value['assists'],
            total: total,
          ));
        }
      });

      setState(() {
        _allStats = computed;
        _isLoading = false;
      });

    } catch (e) {
      print("Erreur stats: $e");
      setState(() => _isLoading = false);
    }
  }

  List<PlayerStats> _getSortedStatsForTab(int tabIndex) {
    List<PlayerStats> sorted = List.from(_allStats);

    if (tabIndex == 0) {
      // BUTEURS : Buts > Passes
      sorted.sort((a, b) {
        int cmp = b.goals.compareTo(a.goals);
        if (cmp != 0) return cmp;
        return b.assists.compareTo(a.assists);
      });
    } else if (tabIndex == 1) {
      // PASSEURS : Passes > Buts
      sorted.sort((a, b) {
        int cmp = b.assists.compareTo(a.assists);
        if (cmp != 0) return cmp;
        return b.goals.compareTo(a.goals);
      });
    } else {
      // MIXTE : Total > Buts
      sorted.sort((a, b) {
        int cmp = b.total.compareTo(a.total);
        if (cmp != 0) return cmp;
        return b.goals.compareTo(a.goals);
      });
    }

    return sorted;
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
        title: const Text('STATISTIQUES'),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // 1. FILTRES (MÃªme style que Resultats/Calendrier)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.black12))),
            child: Row(
              children: [
                Expanded(child: _buildPrettyFilter(value: _filtreEquipe, label: "Ã‰quipe", icon: Icons.groups, items: ['Tout', ..._listeEquipes], onChanged: (v) { setState(() { _filtreEquipe = v!; _isLoading = true; }); _chargerStats(); })),
                const SizedBox(width: 12),
                Expanded(child: _buildPrettyFilter(value: _filtreCompet, label: "CompÃ©tition", icon: Icons.emoji_events, items: ['Tout', ..._listeCompet], onChanged: (v) { setState(() { _filtreCompet = v!; _isLoading = true; }); _chargerStats(); })),
              ],
            ),
          ),

          // 2. BOUTONS DE SÃ‰LECTION (Tabs)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                _buildTabButton("Buteurs", 0),
                _buildTabButton("Passeurs", 1),
                _buildTabButton("Total", 2),
              ],
            ),
          ),

          // 3. CONTENU (PODIUM + LISTE)
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _allStats.isEmpty
                    ? const Center(child: Text("Aucune statistique disponible."))
                    : PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _selectedTab = index);
                        },
                        children: [
                          _buildClassementContent(0),
                          _buildClassementContent(1),
                          _buildClassementContent(2),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildTabButton(String title, int index) {
    bool isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))] : [],
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? AppTheme.bleuMarine : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClassementContent(int tabIndex) {
    final stats = _getSortedStatsForTab(tabIndex);

    return CustomScrollView(
      slivers: [
        if (stats.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _buildPodium(stats, tabIndex),
            ),
          ),
        if (stats.length > 3)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final realIndex = index + 3;
                final player = stats[realIndex];
                final prevPlayer = stats[realIndex - 1];

                String rankStr = "${realIndex + 1}";
                int currentScore = tabIndex == 0 ? player.goals : (tabIndex == 1 ? player.assists : player.total);
                int prevScore = tabIndex == 0 ? prevPlayer.goals : (tabIndex == 1 ? prevPlayer.assists : prevPlayer.total);
                if (currentScore == prevScore) rankStr = "-";

                return _buildStatRow(player, rankStr, tabIndex);
              },
              childCount: stats.length - 3,
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildPodium(List<PlayerStats> stats, int tabIndex) {
    // RÃ©cupÃ©ration sÃ©curisÃ©e des 3 premiers
    PlayerStats? first = stats.isNotEmpty ? stats[0] : null;
    PlayerStats? second = stats.length > 1 ? stats[1] : null;
    PlayerStats? third = stats.length > 2 ? stats[2] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end, // Aligner en bas
      children: [
        // 2ND PLACE (Gauche)
        if (second != null) _buildPodiumStep(second, 2, 120, const Color(0xFFC0C0C0), tabIndex), // Argent
        
        // 1ST PLACE (Centre, plus grand)
        if (first != null) _buildPodiumStep(first, 1, 150, const Color(0xFFFFD700), tabIndex), // Or
        
        // 3RD PLACE (Droite)
        if (third != null) _buildPodiumStep(third, 3, 100, const Color(0xFFCD7F32), tabIndex), // Bronze
      ],
    );
  }

  Widget _buildPodiumStep(PlayerStats player, int rank, double height, Color color, int tabIndex) {
    int score = tabIndex == 0 ? player.goals : (tabIndex == 1 ? player.assists : player.total);
    String mainLabel = tabIndex == 0
        ? _formatButs(score)
        : (tabIndex == 1 ? _formatPasses(score) : "$score total");
    String? secondaryLabel;
    if (tabIndex == 0) secondaryLabel = _formatPasses(player.assists);
    if (tabIndex == 1) secondaryLabel = _formatButs(player.goals);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Nom
          Text(
            player.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          // Barre du podium
          Container(
            width: rank == 1 ? 90 : 80,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [color.withOpacity(0.8), color],
              ),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), topRight: Radius.circular(8)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5, offset: const Offset(0, 3))],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$rank",
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(10)),
                  child: Text(mainLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondaryLabel,
                    style: TextStyle(color: Colors.white.withOpacity(0.95), fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(PlayerStats player, String rank, int tabIndex) {
    int mainScore = tabIndex == 0 ? player.goals : (tabIndex == 1 ? player.assists : player.total);
    // Info secondaire (ex: si on est en buteur, on montre aussi les passes en petit)
    String subInfo = "";
    if (tabIndex == 0) subInfo = _formatPasses(player.assists);
    else if (tabIndex == 1) subInfo = _formatButs(player.goals);
    else subInfo = "${_formatButs(player.goals)} / ${_formatPasses(player.assists)}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Rang
          SizedBox(
            width: 30,
            child: Text(
              rank,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          // Nom
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.bleuMarine)),
                Text(subInfo, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          // Score Principal
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.bleuClair.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              "$mainScore",
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.bleuMarine, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  String _formatButs(int value) {
    final unit = value <= 1 ? "but" : "buts";
    return "$value $unit";
  }

  String _formatPasses(int value) {
    final unit = value <= 1 ? "passe" : "passes";
    return "$value $unit";
  }

  // Widget Filtre (Le mÃªme que Resultats/Calendrier)
  Widget _buildPrettyFilter({required String value, required String label, required IconData icon, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      height: 45,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.bleuMarine),
          const SizedBox(width: 8),
          Expanded(child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: value, isExpanded: true, icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey), items: items.map((e) { Color textColor = Colors.black87; if (label == "CompÃ©tition" && e != 'Tout') { textColor = _getColorForCompet(e); } return DropdownMenuItem(value: e, child: Row(children: [ if (label == "CompÃ©tition" && e != 'Tout') ...[ Container(width: 8, height: 8, decoration: BoxDecoration(color: textColor, shape: BoxShape.circle)), const SizedBox(width: 8)], Text(e == 'Tout' ? 'Tout' : e, style: TextStyle(fontSize: 13, color: textColor, fontWeight: (label == "CompÃ©tition" && e != 'Tout') ? FontWeight.bold : FontWeight.normal), overflow: TextOverflow.ellipsis)])); }).toList(), onChanged: onChanged))),
        ],
      ),
    );
  }
}

