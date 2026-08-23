import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_filter_button.dart';
import '../providers/app_providers.dart';
import '../providers/match_provider.dart';

class EquipeDashboardPage extends ConsumerStatefulWidget {
  final String equipeName;

  const EquipeDashboardPage({super.key, required this.equipeName});

  @override
  ConsumerState<EquipeDashboardPage> createState() =>
      _EquipeDashboardPageState();
}

class _EquipeDashboardPageState extends ConsumerState<EquipeDashboardPage> {
  List<Map<String, dynamic>> _allMatches = [];
  List<Map<String, dynamic>> _allProgrammations = [];
  String? _selectedSeason;

  Set<String> _filtresCompet = {};
  Set<String> _filtresLieux = {};
  List<String> _listeCompet = [];

  @override
  /// Dérive l'état d'affichage des données fournies par les providers.
  /// Appelée depuis `build`, donc sans `setState`.
  void _preparer(
    List<Map<String, dynamic>> resMatches,
    List<Map<String, dynamic>> resProg,
    String? saison,
  ) {
    _allMatches = List<Map<String, dynamic>>.from(resMatches);
    _allProgrammations = List<Map<String, dynamic>>.from(resProg);
    _listeCompet = _valeursUniques([
      ..._allMatches.map((m) => m['competition']?.toString() ?? ''),
      ..._allProgrammations.map((p) => p['competition']?.toString() ?? ''),
    ]);
    _filtresCompet = _filtresCompet.intersection(_listeCompet.toSet());
    _filtresLieux = _filtresLieux.intersection({'DOM', 'EXT'});
    _selectedSeason = saison;
  }

  String _formatHeure(String? heure) {
    if (heure == null) return '?';
    if (heure.length >= 5) {
      return heure.substring(0, 5);
    }
    return heure;
  }

  String _nomAdversaire(Map<String, dynamic> row) {
    final adversaire = row['adversaires'];
    if (adversaire is Map && adversaire['nom'] != null) {
      return adversaire['nom'].toString();
    }
    final nomDirect = row['adversaire'];
    if (nomDirect != null && nomDirect.toString().trim().isNotEmpty) {
      return nomDirect.toString();
    }
    return 'Adversaire';
  }

  int? _intValue(dynamic value) {
    return int.tryParse(value?.toString() ?? '');
  }

  Color _getColorForCompet(String compet) {
    if (compet.contains('Coupe')) return AppTheme.dore;
    if (compet.contains('Amical')) return Colors.grey;
    return AppTheme.bleuMarine;
  }

  List<String> _valeursUniques(Iterable<String> values) {
    final list =
        values.where((value) => value.trim().isNotEmpty).toSet().toList()
          ..sort();
    return list;
  }

  String _lieuCode(dynamic lieu) {
    final value = lieu?.toString().trim().toUpperCase() ?? '';
    if (value.startsWith('DOM')) return 'DOM';
    if (value.startsWith('EXT')) return 'EXT';
    return value;
  }

  bool _matchPassesFilters(Map<String, dynamic> match) {
    final competition = match['competition']?.toString() ?? '';
    final okCompet =
        _filtresCompet.isEmpty || _filtresCompet.contains(competition);
    final okLieu =
        _filtresLieux.isEmpty ||
        _filtresLieux.contains(_lieuCode(match['lieu']));
    return okCompet && okLieu;
  }

  List<Map<String, dynamic>> _filteredMatches() {
    return _allMatches.where(_matchPassesFilters).toList();
  }

  List<Map<String, dynamic>> _filteredProgrammations() {
    return _allProgrammations.where(_matchPassesFilters).toList();
  }

  Widget _buildCompactResultBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 7,
          color: color == Colors.grey ? Colors.grey[700] : color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCompactTeamText(
    String text, {
    required bool isFcpb,
    TextAlign align = TextAlign.left,
  }) {
    return Text(
      text,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: isFcpb ? FontWeight.bold : FontWeight.w500,
        color: isFcpb ? AppTheme.bleuMarine : Colors.black87,
      ),
    );
  }

  Map<String, int> _getGlobalStats(List<Map<String, dynamic>> matches) {
    int v = 0, n = 0, d = 0, cs = 0;
    for (var m in matches) {
      int gjpb = m['buts_gjpb'];
      int adv = m['buts_adv'];
      if (gjpb > adv)
        v++;
      else if (gjpb == adv)
        n++;
      else
        d++;

      if (adv == 0) cs++;
    }
    return {'v': v, 'n': n, 'd': d, 'cs': cs, 'total': matches.length};
  }

  String _getCurrentStreak(List<Map<String, dynamic>> matches) {
    if (matches.isEmpty) return "Aucun match joué";

    int totalMatchesPlayed = matches.length;

    // --- 0. FONCTIONS UTILITAIRES ---
    //
    // RÈGLE : le résultat d'un match se lit sur le SCORE SEUL. Un match gagné
    // aux tirs au but reste un nul au bilan — le TAB ne décide que de la
    // qualification. C'est déjà ce que font les compteurs V/N/D
    // (`_getGlobalStats`), les cartes de résultat, la page Résultats et le
    // Calendrier : partout ailleurs le TAB n'est qu'un badge d'affichage.
    //
    // CORRIGÉ LE 23/08/2026
    //   Cette fonction était la SEULE de l'app à compter un TAB gagné comme
    //   une victoire. Elle contredisait donc les compteurs affichés juste
    //   au-dessus d'elle : deux nuls en coupe pour ouvrir la saison donnaient
    //   « 0 défaite, 100 % de victoires » et la phrase « La saison démarre
    //   fort », pendant que le bilan affichait « 2 nuls ».
    //
    //   Au passage, un nul avec un score de TAB à égalité (2-2 par exemple)
    //   n'était ni une victoire, ni une défaite, ni un nul : le match
    //   disparaissait de toutes les séries.
    bool isWin(Map<String, dynamic> m) {
      final fcpb = m['buts_gjpb'];
      final adv = m['buts_adv'];
      if (fcpb == null || adv == null) return false;
      return fcpb > adv;
    }

    bool isDefeat(Map<String, dynamic> m) {
      final fcpb = m['buts_gjpb'];
      final adv = m['buts_adv'];
      if (fcpb == null || adv == null) return false;
      return fcpb < adv;
    }

    bool isDraw(Map<String, dynamic> m) {
      final fcpb = m['buts_gjpb'];
      final adv = m['buts_adv'];
      if (fcpb == null || adv == null) return false;
      return fcpb == adv;
    }

    // --- 1. CALCULS PRÉLIMINAIRES ---

    // Série de victoires (active)
    int winStreak = 0;
    for (var m in matches) {
      if (isWin(m))
        winStreak++;
      else
        break;
    }

    // Série sans défaite (active)
    int noDefeatStreak = 0;
    for (var m in matches) {
      if (!isDefeat(m))
        noDefeatStreak++;
      else
        break;
    }

    // Série de défaites (active)
    int defeatStreak = 0;
    for (var m in matches) {
      if (isDefeat(m))
        defeatStreak++;
      else
        break;
    }

    // Série sans victoire (active)
    int noWinStreak = 0;
    for (var m in matches) {
      if (!isWin(m))
        noWinStreak++;
      else
        break;
    }

    // Série de matchs nuls (active)
    int drawStreak = 0;
    for (var m in matches) {
      if (isDraw(m))
        drawStreak++;
      else
        break;
    }

    // Victoires sur les 10 derniers matchs
    int winsInLast10 = 0;
    int range10 = matches.length < 10 ? matches.length : 10;
    for (int i = 0; i < range10; i++) {
      if (isWin(matches[i])) winsInLast10++;
    }

    // Victoires sur les 5 derniers matchs
    int winsInLast5 = 0;
    int range5 = matches.length < 5 ? matches.length : 5;
    for (int i = 0; i < range5; i++) {
      if (isWin(matches[i])) winsInLast5++;
    }

    // Calcul du Rebond
    bool isRebound = false;
    if (matches.length >= 4) {
      bool lastIsWin = isWin(matches[0]); // Le dernier match joué
      bool previousThreeAreDefeats =
          isDefeat(matches[1]) && isDefeat(matches[2]) && isDefeat(matches[3]);

      if (lastIsWin && previousThreeAreDefeats) {
        isRebound = true;
      }
    }

    // --- 2. LOGIQUE EN CASCADE (PRIORITÉS) ---

    // 1) 🌱 Début de saison (De 1 à 3 matchs joués au total)
    if (totalMatchesPlayed > 0 && totalMatchesPlayed < 4) {
      int earlyWins = matches.where((m) => isWin(m)).length;
      int earlyDraws = matches.where((m) => isDraw(m)).length;
      int earlyDefeats = matches.where((m) => isDefeat(m)).length;

      // Au moins une victoire, aucune défaite, et 50 % de victoires minimum.
      // La condition « earlyWins >= 1 » est explicite : sans elle, un début de
      // saison sans le moindre but marqué pourrait passer pour un bon départ.
      if (earlyDefeats == 0 &&
          earlyWins >= 1 &&
          (earlyWins / totalMatchesPlayed) >= 0.5) {
        return "🚀 La saison démarre fort !";
      }
      // Que des nuls depuis le coup d'envoi de la saison
      else if (totalMatchesPlayed >= 2 && earlyDraws == totalMatchesPlayed) {
        return "🧱 $earlyDraws nuls pour commencer : solides, mais il faudra gagner";
      }
      // Exactement 1 Victoire et 2 Nuls (sur 3 matchs)
      else if (earlyWins == 1 && earlyDraws == 2) {
        return "🛠️ La machine se met en route...";
      }
      // Reste des cas
      else {
        return "🌱 Début de saison en cours...";
      }
    }
    // 2) 🚨 Alerte Rouge (La vraie crise, >= 5 défaites consécutives)
    else if (defeatStreak >= 5) {
      return "🚨 Période très compliquée ($defeatStreak défaites de suite)...";
    }
    // 3) 🔥🛡️ Série de victoires depuis longtemps (>= 7)
    else if (winStreak >= 7) {
      return "🔥🛡️ $winStreak victoires consécutives !!! On est injouable.";
    }
    // 4) ✨ Le Rebond (Nouvelle victoire après une série de >= 3 défaites)
    else if (isRebound) {
      return "✨ Le rebond ! Victoire qui fait beaucoup de bien.";
    }
    // 5) 🔥 Série de victoires (>= 3)
    else if (winStreak >= 3) {
      return "🔥 $winStreak victoires consécutives !";
    }
    // 6) 🛡️ Invincibilité (>= 5 matchs sans défaite)
    else if (noDefeatStreak >= 5) {
      return "🛡️ Solide : $noDefeatStreak matchs sans défaite";
    }
    // 7) 🧱 Spécialistes du nul (>= 3 nuls de suite)
    else if (drawStreak >= 3) {
      return "🧱 Difficiles à battre, mais accrochés ($drawStreak nuls consécutifs)";
    }
    // 8) 📈 Très bonne dynamique globale (>= 6 victoires sur les 10 derniers)
    else if (winsInLast10 >= 6) {
      return "📈 $winsInLast10 victoires sur les 10 derniers matchs";
    }
    // 9) 💪 Bonne forme récente (>= 3 victoires sur les 5 derniers)
    else if (winsInLast5 >= 3) {
      return "💪 $winsInLast5 victoires sur les 5 derniers matchs";
    }
    // 10) 🚀 Début de série (Exactement 2 victoires)
    else if (winStreak == 2) {
      return "🚀 La série se lance : 2 victoires de suite";
    }
    // 11) 📉 Mauvaise série classique (>= 3 défaites consécutives)
    else if (defeatStreak >= 3) {
      return "📉 $defeatStreak défaites consécutives";
    }
    // 12) ☁️ Pas de victoire récente (>= 4 matchs sans victoire)
    else if (noWinStreak >= 4) {
      return "☁️ $noWinStreak matchs sans victoire";
    }
    // 13) ⚖️ Cas neutre (irrégulier)
    else {
      return "⚖️ Résultats récents irréguliers";
    }
  }

  Map<String, double> _getFilteredStats(List<Map<String, dynamic>> matches) {
    double v = 0, n = 0, d = 0;
    double butsM = 0, butsE = 0;
    double points = 0;
    int count = 0;

    for (var m in matches) {
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
      'v': v,
      'n': n,
      'd': d,
      'bm': butsM,
      'be': butsE,
      'total': count.toDouble(),
      'pts_match': count > 0 ? (points / count) : 0.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    // `family` : chaque équipe a son propre cache.
    final matchsAsync = ref.watch(matchsEquipeProvider(widget.equipeName));
    final progAsync = ref.watch(prochainesEquipeProvider(widget.equipeName));
    final contexteAsync = ref.watch(contexteProvider);

    if (matchsAsync.isLoading || progAsync.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final erreur = matchsAsync.error ?? progAsync.error;
    if (erreur != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.equipeName),
          backgroundColor: AppTheme.bleuMarine,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Impossible de charger cette équipe.\n$erreur',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    }

    _preparer(
      matchsAsync.value ?? const [],
      progAsync.value ?? const [],
      contexteAsync.value?.saison,
    );

    final matches = _filteredMatches();
    final programmations = _filteredProgrammations();
    final nextMatch = programmations.isNotEmpty ? programmations.first : null;
    final globalStats = _getGlobalStats(matches);
    final winPercent = globalStats['total']! > 0
        ? (globalStats['v']! / globalStats['total']! * 100).toStringAsFixed(0)
        : "0";
    final cleanSheetLabel = globalStats['cs']! > 1
        ? "Clean Sheets"
        : "Clean Sheet";

    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.equipeName}"),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          CompactFilterButton(
            equipes: const [],
            competitions: _listeCompet,
            selectedEquipes: const {},
            selectedCompetitions: _filtresCompet,
            selectedLieux: _filtresLieux,
            showEquipes: false,
            competitionColor: _getColorForCompet,
            onApply: (_, competitions, lieux) {
              setState(() {
                _filtresCompet = competitions;
                _filtresLieux = lieux;
              });
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. STATS GLOBALES
                  Text(
                    _selectedSeason == null
                        ? "SAISON EN COURS"
                        : "SAISON $_selectedSeason",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    children: [
                      _buildStatTile(
                        "Matchs",
                        "${globalStats['total']}",
                        Icons.sports_soccer,
                        Colors.blue,
                      ),
                      _buildStatTile(
                        "Victoires",
                        "$winPercent%",
                        Icons.emoji_events,
                        Colors.orange,
                      ),
                      _buildStatTile(
                        cleanSheetLabel,
                        "${globalStats['cs']}",
                        Icons.shield,
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildResultSummary(globalStats),

                  const SizedBox(height: 24),

                  // 2. FORME RÉCENTE
                  const Text(
                    "FORME RÉCENTE",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: matches.take(5).map((m) {
                            bool win = m['buts_gjpb'] > m['buts_adv'];
                            bool draw = m['buts_gjpb'] == m['buts_adv'];
                            Color color = win
                                ? Colors.green
                                : (draw ? Colors.grey : Colors.red);
                            String text = win ? "V" : (draw ? "N" : "D");
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 35,
                              height: 35,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  text,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _getCurrentStreak(matches),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.bleuMarine,
                          ),
                        ),
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
                            const Text(
                              "DERNIER",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            matches.isNotEmpty
                                ? _buildHalfWidthMatchCard(
                                    matches.first,
                                    isPlayed: true,
                                  )
                                : _buildEmptyCard("Aucun match joué"),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "PROCHAIN",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            nextMatch != null
                                ? _buildHalfWidthMatchCard(
                                    nextMatch,
                                    isPlayed: false,
                                  )
                                : _buildEmptyCard("Aucun match prévu"),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 4. ANALYSE (GRAPHIQUES)
                  const Text(
                    "ANALYSE DÉTAILLÉE",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildChartsSection(matches),

                  const SizedBox(height: 24),
                  _buildPodiumsSection(matches),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS ---

  Widget _buildStatTile(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.bleuMarine,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildResultSummary(Map<String, int> stats) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildResultCount(stats['v']!, 'victoire', Colors.green),
          _buildResultCount(stats['n']!, 'nul', Colors.grey),
          _buildResultCount(stats['d']!, 'défaite', Colors.red),
        ],
      ),
    );
  }

  Widget _buildResultCount(int count, String label, Color color) {
    final plural = count == 1 ? '' : 's';
    return Text(
      '$count $label$plural',
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      width: double.infinity,
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildHalfWidthMatchCard(
    Map<String, dynamic> m, {
    required bool isPlayed,
  }) {
    final butsFcpb = _intValue(m['buts_gjpb']) ?? 0;
    final butsAdv = _intValue(m['buts_adv']) ?? 0;
    final tabFcpb = _intValue(m['tab_fcpb']);
    final tabAdv = _intValue(m['tab_adv']);
    final hasTab = isPlayed && tabFcpb != null && tabAdv != null;
    final win = isPlayed && butsFcpb > butsAdv;
    final draw = isPlayed && butsFcpb == butsAdv;
    final tabWin = hasTab && tabFcpb > tabAdv;
    final tabLose = hasTab && tabFcpb < tabAdv;
    final isAway =
        m['lieu']?.toString().toUpperCase().startsWith('EXT') ?? false;
    final notreEquipe = 'FCPB ${widget.equipeName}';
    final adversaire = _nomAdversaire(m);
    final date = DateFormat('dd/MM').format(DateTime.parse(m['date']));
    final competition = m['competition']?.toString() ?? '';
    final competitionColor = _getColorForCompet(competition);
    final tabScore = hasTab
        ? (isAway ? '$tabAdv-$tabFcpb' : '$tabFcpb-$tabAdv')
        : null;

    Color color = isPlayed
        ? (win ? Colors.green : (draw ? Colors.grey : Colors.red))
        : AppTheme.bleuMarine;
    if (tabWin) color = Colors.green;
    if (tabLose) color = Colors.red;

    Widget resultBadges() {
      return Wrap(
        spacing: 3,
        runSpacing: 2,
        alignment: WrapAlignment.end,
        children: [
          _buildCompactResultBadge(
            label: hasTab
                ? 'NUL'
                : (win ? 'VICTOIRE' : (draw ? 'NUL' : 'DÉFAITE')),
            color: hasTab || draw
                ? Colors.grey
                : (win ? Colors.green : Colors.red),
          ),
          if (tabWin)
            _buildCompactResultBadge(
              label: 'VICTOIRE TAB',
              color: Colors.green,
            ),
          if (tabLose)
            _buildCompactResultBadge(label: 'DÉFAITE TAB', color: Colors.red),
        ],
      );
    }

    Widget playedLine() {
      final leftTeam = isAway ? adversaire : notreEquipe;
      final rightTeam = isAway ? notreEquipe : adversaire;
      final leftIsFcpb = !isAway;
      final rightIsFcpb = isAway;
      final score = isAway ? '$butsAdv-$butsFcpb' : '$butsFcpb-$butsAdv';

      return Row(
        children: [
          Expanded(
            child: _buildCompactTeamText(
              leftTeam,
              isFcpb: leftIsFcpb,
              align: TextAlign.right,
            ),
          ),
          const SizedBox(width: 5),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Center(
                  child: Text(
                    score,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.bleuMarine,
                    ),
                  ),
                ),
              ),
              if (tabScore != null)
                Text(
                  't.a.b ($tabScore)',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(width: 5),
          Expanded(
            child: _buildCompactTeamText(rightTeam, isFcpb: rightIsFcpb),
          ),
        ],
      );
    }

    Widget upcomingLine() {
      final leftTeam = isAway ? adversaire : notreEquipe;
      final rightTeam = isAway ? notreEquipe : adversaire;
      final leftIsFcpb = !isAway;
      final rightIsFcpb = isAway;

      return SizedBox(
        height: 36,
        child: Row(
          children: [
            Expanded(
              child: _buildCompactTeamText(
                leftTeam,
                isFcpb: leftIsFcpb,
                align: TextAlign.right,
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: Text(
                'vs',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: _buildCompactTeamText(rightTeam, isFcpb: rightIsFcpb),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 74,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 5,
            width: double.infinity,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          competition,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: competitionColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: isPlayed
                              ? resultBadges()
                              : Text(
                                  _formatHeure(m['heure']),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.bleuMarine,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 36,
                    child: Center(
                      child: isPlayed ? playedLine() : upcomingLine(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection(List<Map<String, dynamic>> matches) {
    final stats = _getFilteredStats(matches);
    double total = stats['total']!;
    final double butsMarquesParMatch = total > 0 ? (stats['bm']! / total) : 0.0;
    final double butsEncaissesParMatch = total > 0
        ? (stats['be']! / total)
        : 0.0;

    if (total == 0)
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text("Aucun match avec ces filtres"),
        ),
      );

    List<PieChartSectionData> sectionsResult = [
      if (stats['v']! > 0)
        PieChartSectionData(
          value: stats['v']!,
          color: Colors.green,
          title: "V",
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      if (stats['n']! > 0)
        PieChartSectionData(
          value: stats['n']!,
          color: Colors.grey,
          title: "N",
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      if (stats['d']! > 0)
        PieChartSectionData(
          value: stats['d']!,
          color: Colors.red,
          title: "D",
          radius: 50,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
    ];

    List<PieChartSectionData> sectionsButs = [
      if (stats['bm']! > 0)
        PieChartSectionData(
          value: stats['bm']!,
          color: AppTheme.bleuMarine,
          title: "${stats['bm']!.toInt()}",
          radius: 40,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      if (stats['be']! > 0)
        PieChartSectionData(
          value: stats['be']!,
          color: Colors.redAccent,
          title: "${stats['be']!.toInt()}",
          radius: 40,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
    ];

    return Column(
      children: [
        Container(
          height: 200,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sections: sectionsResult,
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                      ),
                    ),
                    Text(
                      "${((stats['v']! / total) * 100).toInt()}%",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
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
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LegendItem(
                          color: AppTheme.bleuMarine,
                          text: "Buts marqués",
                        ),
                        _LegendItem(
                          color: Colors.redAccent,
                          text: "Buts encaissés",
                        ),
                      ],
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: PieChart(
                        PieChartData(
                          sections: sectionsButs,
                          centerSpaceRadius: 40,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.bleuMarine,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Buts marqués / match :",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      butsMarquesParMatch.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Buts encaissés / match :",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      butsEncaissesParMatch.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPodiumsSection(List<Map<String, dynamic>> matches) {
    final buteurs = _getPlayerActionRanking(matches, 'Goal');
    final passeurs = _getPlayerActionRanking(matches, 'Assist');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSimplePodium(
            title: 'TOP BUTEURS',
            players: buteurs,
            unitSingular: 'but',
            unitPlural: 'buts',
            color: AppTheme.bleuMarine,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildSimplePodium(
            title: 'TOP PASSEURS',
            players: passeurs,
            unitSingular: 'passe',
            unitPlural: 'passes',
            color: AppTheme.dore,
          ),
        ),
      ],
    );
  }

  List<MapEntry<String, int>> _getPlayerActionRanking(
    List<Map<String, dynamic>> matches,
    String actionType,
  ) {
    final counts = <String, int>{};

    for (final match in matches) {
      final actions = match['actions'];
      if (actions is! List) continue;

      for (final action in actions) {
        if (action is! Map || action['type'] != actionType) continue;

        final joueur = action['joueurs'];
        String? name;
        if (joueur is Map && joueur['nom'] != null) {
          name = joueur['nom'].toString();
        }
        if (name == null || name.trim().isEmpty) continue;

        counts[name] = (counts[name] ?? 0) + 1;
      }
    }

    final ranking = counts.entries.toList()
      ..sort((a, b) {
        final scoreCompare = b.value.compareTo(a.value);
        if (scoreCompare != 0) return scoreCompare;
        return a.key.compareTo(b.key);
      });
    return ranking.take(3).toList();
  }

  Widget _buildSimplePodium({
    required String title,
    required List<MapEntry<String, int>> players,
    required String unitSingular,
    required String unitPlural,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 10),
          if (players.isEmpty)
            const Text(
              'Aucune stat',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            )
          else
            ...players.asMap().entries.map((entry) {
              final rank = entry.key + 1;
              final player = entry.value;
              final unit = player.value > 1 ? unitPlural : unitSingular;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: color.withOpacity(rank == 1 ? 1 : 0.75),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        player.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.bleuMarine,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '${player.value} $unit',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
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
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
