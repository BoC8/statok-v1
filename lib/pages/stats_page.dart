import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_filter_button.dart';
import '../providers/match_provider.dart';

// Modèle pour les stats d'un joueur
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

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  final PageController _pageController = PageController(initialPage: 0);

  // --- VARIABLES D'ÉTAT ---
  List<PlayerStats> _allStats = []; // Stats brutes

  // Filtres
  Set<String> _filtresEquipes = {};
  Set<String> _filtresCompet = {};
  Set<String> _filtresLieux = {};
  List<String> _listeEquipes = [];
  List<String> _listeCompet = [];

  // Mode de classement : 0 = Buteurs, 1 = Passeurs, 2 = Mixte
  int _selectedTab = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Recalcule le classement à partir des données en cache et des filtres.
  ///
  /// AMÉLIORATION AU PASSAGE
  ///   Avant, changer un filtre relançait `_chargerStats()`, donc **une requête
  ///   réseau complète**. Les filtres n'étant appliqués qu'en Dart, c'était du
  ///   trafic pour rien. Désormais les données restent en cache et seul ce
  ///   calcul est refait : le filtrage est instantané et hors ligne.
  ///
  /// Appelée depuis `build`, donc sans `setState`.
  void _preparer(
    List<Map<String, dynamic>> resJoueurs,
    List<Map<String, dynamic>> resActions,
  ) {
    Map<String, Map<String, dynamic>> statsMap = {};

    // Initialiser la map avec tous les joueurs (pour ceux qui ont 0 stats)
    for (var j in resJoueurs) {
      statsMap[j['id'].toString()] = {
        'name': j['nom'],
        'goals': 0,
        'assists': 0,
      };
    }

    // Remplir avec les actions
    final equipes = <String>{};
    final competitions = <String>{};
    for (var action in resActions) {
      final match = action['matchs'];
      if (match == null) continue;

      final equipe = match['equipe']?.toString() ?? '';
      final competition = match['competition']?.toString() ?? '';
      if (equipe.isNotEmpty) equipes.add(equipe);
      if (competition.isNotEmpty) competitions.add(competition);

      // FILTRAGE BRUT ICI (pour calculer uniquement ce qui correspond aux filtres)
      bool okEquipe =
          _filtresEquipes.isEmpty ||
          _filtresEquipes.contains(match['equipe']);
      bool okCompet =
          _filtresCompet.isEmpty ||
          _filtresCompet.contains(match['competition']);
      bool okLieu =
          _filtresLieux.isEmpty ||
          _filtresLieux.contains(_lieuCode(match['lieu']));

      if (okEquipe && okCompet && okLieu) {
        final jId = action['joueur_id'].toString();
        final type = action['type'];

        if (statsMap.containsKey(jId)) {
          if (type == 'Goal') {
            statsMap[jId]!['goals']++;
          } else if (type == 'Assist') {
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
        computed.add(
          PlayerStats(
            name: value['name'],
            goals: value['goals'],
            assists: value['assists'],
            total: total,
          ),
        );
      }
    });

      _listeEquipes = equipes.toList()..sort();
      _listeCompet = competitions.toList()..sort();
      _filtresEquipes = _filtresEquipes.intersection(equipes);
      _filtresCompet = _filtresCompet.intersection(competitions);
      _filtresLieux = _filtresLieux.intersection({'DOM', 'EXT'});
      _allStats = computed;
      _syncPageControllerWithSelectedTab();
  }

  void _syncPageControllerWithSelectedTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients || _allStats.isEmpty) return;
      _pageController.jumpToPage(_selectedTab);
    });
  }

  List<PlayerStats> _getSortedStatsForTab(int tabIndex) {
    List<PlayerStats> sorted = _allStats.where((player) {
      if (tabIndex == 0) return player.goals > 0;
      if (tabIndex == 1) return player.assists > 0;
      return true;
    }).toList();

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

  String _lieuCode(dynamic lieu) {
    final value = lieu?.toString().trim().toUpperCase() ?? '';
    if (value.startsWith('DOM')) return 'DOM';
    if (value.startsWith('EXT')) return 'EXT';
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final joueursAsync = ref.watch(joueursProvider);
    final actionsAsync = ref.watch(actionsProvider);

    final chargement = joueursAsync.isLoading || actionsAsync.isLoading;
    final erreur = joueursAsync.error ?? actionsAsync.error;

    if (joueursAsync.hasValue && actionsAsync.hasValue) {
      _preparer(joueursAsync.value!, actionsAsync.value!);
    }

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
          // 1. FILTRES
          CompactFilterButton(
            equipes: _listeEquipes,
            competitions: _listeCompet,
            selectedEquipes: _filtresEquipes,
            selectedCompetitions: _filtresCompet,
            selectedLieux: _filtresLieux,
            competitionColor: _getColorForCompet,
            onApply: (equipes, competitions, lieux) {
              // Plus de requête : le recalcul se fait sur les données en cache.
              setState(() {
                _filtresEquipes = equipes;
                _filtresCompet = competitions;
                _filtresLieux = lieux;
              });
            },
          ),

          // 2. BOUTONS DE SÉLECTION (Tabs)
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
            child: chargement
                ? const Center(child: CircularProgressIndicator())
                : erreur != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger les statistiques.\n$erreur',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
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
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
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
            delegate: SliverChildBuilderDelegate((context, index) {
              final realIndex = index + 3;
              final player = stats[realIndex];
              final prevPlayer = stats[realIndex - 1];

              String rankStr = "${realIndex + 1}";
              int currentScore = tabIndex == 0
                  ? player.goals
                  : (tabIndex == 1 ? player.assists : player.total);
              int prevScore = tabIndex == 0
                  ? prevPlayer.goals
                  : (tabIndex == 1 ? prevPlayer.assists : prevPlayer.total);
              if (currentScore == prevScore) rankStr = "-";

              return _buildStatRow(player, rankStr, tabIndex);
            }, childCount: stats.length - 3),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildPodium(List<PlayerStats> stats, int tabIndex) {
    // Récupération sécurisée des 3 premiers
    PlayerStats? first = stats.isNotEmpty ? stats[0] : null;
    PlayerStats? second = stats.length > 1 ? stats[1] : null;
    PlayerStats? third = stats.length > 2 ? stats[2] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end, // Aligner en bas
      children: [
        // 2ND PLACE (Gauche)
        if (second != null)
          _buildPodiumStep(
            second,
            2,
            120,
            const Color(0xFFC0C0C0),
            tabIndex,
          ), // Argent
        // 1ST PLACE (Centre, plus grand)
        if (first != null)
          _buildPodiumStep(
            first,
            1,
            150,
            const Color(0xFFFFD700),
            tabIndex,
          ), // Or
        // 3RD PLACE (Droite)
        if (third != null)
          _buildPodiumStep(
            third,
            3,
            100,
            const Color(0xFFCD7F32),
            tabIndex,
          ), // Bronze
      ],
    );
  }

  Widget _buildPodiumStep(
    PlayerStats player,
    int rank,
    double height,
    Color color,
    int tabIndex,
  ) {
    int score = tabIndex == 0
        ? player.goals
        : (tabIndex == 1 ? player.assists : player.total);
    String mainLabel = tabIndex == 0
        ? _formatButs(score)
        : (tabIndex == 1 ? _formatPasses(score) : "$score total");
    String? secondaryLabel;
    if (tabIndex == 0) secondaryLabel = _formatPasses(player.assists);
    if (tabIndex == 1) secondaryLabel = _formatButs(player.goals);
    if (tabIndex == 2) {
      secondaryLabel =
          "${_formatButs(player.goals)}\n${_formatPasses(player.assists)}";
    }

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
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "$rank",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    mainLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (secondaryLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    secondaryLabel,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.95),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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

  Widget _buildStatRow(PlayerStats player, String rank, int tabIndex) {
    int mainScore = tabIndex == 0
        ? player.goals
        : (tabIndex == 1 ? player.assists : player.total);
    // Info secondaire (ex: si on est en buteur, on montre aussi les passes en petit)
    String subInfo = "";
    if (tabIndex == 0)
      subInfo = _formatPasses(player.assists);
    else if (tabIndex == 1)
      subInfo = _formatButs(player.goals);
    else
      subInfo =
          "${_formatButs(player.goals)} / ${_formatPasses(player.assists)}";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rang
          SizedBox(
            width: 30,
            child: Text(
              rank,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          // Nom
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.bleuMarine,
                  ),
                ),
                Text(
                  subInfo,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          // Score Principal
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppTheme.bleuClair.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              "$mainScore",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.bleuMarine,
                fontSize: 16,
              ),
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
}
