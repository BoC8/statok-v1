import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_filter_button.dart';

// ModÃ¨le spÃ©cifique pour les RÃ©sultats
class TabTireur {
  final String nom;
  final bool reussi;

  TabTireur({required this.nom, required this.reussi});
}

class MatchResult {
  final String id;
  final DateTime date;
  final String equipe;
  final String adversaire;
  final String competition;
  final String lieu;
  final int butsGjpb;
  final int butsAdv;
  final int? tabFcpb;
  final int? tabAdv;
  final List<String> buteurs;
  final List<String> passeurs;
  final List<TabTireur> tabTireurs;

  MatchResult({
    required this.id,
    required this.date,
    required this.equipe,
    required this.adversaire,
    required this.competition,
    required this.lieu,
    required this.butsGjpb,
    required this.butsAdv,
    this.tabFcpb,
    this.tabAdv,
    required this.buteurs,
    required this.passeurs,
    required this.tabTireurs,
  });

  bool get hasTab => tabFcpb != null && tabAdv != null;
}

class ResultatsPage extends StatefulWidget {
  const ResultatsPage({super.key});

  @override
  State<ResultatsPage> createState() => _ResultatsPageState();
}

class _ResultatsPageState extends State<ResultatsPage> {
  final SupabaseClient _client = Supabase.instance.client;

  // DonnÃ©es
  List<MatchResult> _allMatches = [];
  List<MatchResult> _filteredMatches = [];
  bool _isLoading = true;

  // Filtres
  Set<String> _filtresEquipes = {};
  Set<String> _filtresCompet = {};
  Set<String> _filtresLieux = {};
  String _filtreAdversaire = '';
  List<String> _listeEquipes = [];
  List<String> _listeCompet = [];
  List<String> _listeAdversaires = [];

  // Ã‰tat d'expansion des cartes
  Set<String> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _chargerResultats();
  }

  Future<void> _chargerResultats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // CORRECTION : On prend directement la valeur exacte, sans la transformer
      final categorie = prefs.getString('selected_category');
      final saison = prefs.getString('selected_season');

      // On rÃ©cupÃ¨re les matchs jouÃ©s avec leurs actions et le nom de l'adversaire
      final response = await _client
          .from('matchs')
          .select('*, adversaires(nom), actions(type, joueurs(nom))')
          .order('date', ascending: false);

      List<MatchResult> loaded = [];

      for (var m in response) {
        // Filtrage dynamique selon la catÃ©gorie choisie Ã  l'accueil
        if (!_categorieMatches(categorie, m['categorie'])) {
          continue;
        }
        if (saison != null && m['saison'] != saison) {
          continue;
        }

        List<String> goals = [];
        List<String> assists = [];
        List<TabTireur> tabTireurs = [];

        if (m['actions'] != null) {
          for (var action in m['actions']) {
            final nom = action['joueurs']?['nom'] ?? 'Inconnu';
            if (action['type'] == 'Goal') {
              goals.add(nom);
            } else if (action['type'] == 'Assist') {
              assists.add(nom);
            } else if (action['type'] == 'TAB_Reussi') {
              tabTireurs.add(TabTireur(nom: nom, reussi: true));
            } else if (action['type'] == 'TAB_Rate') {
              tabTireurs.add(TabTireur(nom: nom, reussi: false));
            }
          }
        }

        loaded.add(
          MatchResult(
            id: m['id'].toString(),
            date: DateTime.parse(m['date']),
            equipe: m['equipe'] ?? '',
            adversaire: _nomAdversaire(m),
            competition: m['competition'] ?? 'Championnat',
            lieu: m['lieu'] ?? '',
            butsGjpb: m['buts_gjpb'] ?? 0,
            butsAdv: m['buts_adv'] ?? 0,
            tabFcpb: int.tryParse(m['tab_fcpb']?.toString() ?? ''),
            tabAdv: int.tryParse(m['tab_adv']?.toString() ?? ''),
            buteurs: goals,
            passeurs: assists,
            tabTireurs: tabTireurs,
          ),
        );
      }

      setState(() {
        _allMatches = loaded;
        _listeEquipes = _valeursUniques(loaded.map((m) => m.equipe));
        _listeCompet = _valeursUniques(loaded.map((m) => m.competition));
        _listeAdversaires = _valeursUniques(loaded.map((m) => m.adversaire));
        _filtresEquipes = _filtresEquipes.intersection(_listeEquipes.toSet());
        _filtresCompet = _filtresCompet.intersection(_listeCompet.toSet());
        _filtresLieux = _filtresLieux.intersection({'DOM', 'EXT'});
        _filteredMatches = _filtrerMatches();
        _isLoading = false;
      });
    } catch (e) {
      print("Erreur: $e");
      setState(() => _isLoading = false);
    }
  }

  void _appliquerFiltres() {
    setState(() {
      _filteredMatches = _filtrerMatches();
    });
  }

  List<MatchResult> _filtrerMatches() {
    final adversaireQuery = _filtreAdversaire.trim().toLowerCase();
    return _allMatches.where((m) {
      final okEquipe =
          _filtresEquipes.isEmpty || _filtresEquipes.contains(m.equipe);
      final okCompet =
          _filtresCompet.isEmpty || _filtresCompet.contains(m.competition);
      final okAdversaire =
          adversaireQuery.isEmpty ||
          m.adversaire.toLowerCase().contains(adversaireQuery);
      final okLieu =
          _filtresLieux.isEmpty || _filtresLieux.contains(_lieuCode(m.lieu));
      return okEquipe && okCompet && okAdversaire && okLieu;
    }).toList();
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

  String? _categoriePourDb(String? categorie) {
    switch (categorie) {
      case 'U14 - U15':
        return 'U14-15';
      case 'U16 - U17 - U18':
        return 'U16-17-18';
      case 'SENIORS':
      case 'Seniors':
        return 'Seniors';
    }
    return categorie;
  }

  bool _categorieMatches(String? selected, dynamic dbValue) {
    if (selected == null) return true;
    final db = dbValue?.toString();
    return db == selected || db == _categoriePourDb(selected);
  }

  List<String> _valeursUniques(Iterable<String> values) {
    final list =
        values.where((value) => value.trim().isNotEmpty).toSet().toList()
          ..sort();
    return list;
  }

  String _lieuCode(String? lieu) {
    final value = lieu?.trim().toUpperCase() ?? '';
    if (value.startsWith('DOM')) return 'DOM';
    if (value.startsWith('EXT')) return 'EXT';
    return value;
  }

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

  Map<String, int> _compterOccurrences(List<String> liste) {
    Map<String, int> count = {};
    for (var nom in liste) {
      count[nom] = (count[nom] ?? 0) + 1;
    }
    return count;
  }

  Widget _buildResultBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color == Colors.grey ? Colors.grey[700] : color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDetailsDivider() {
    return Container(width: 1, height: 30, color: Colors.grey.shade200);
  }

  Widget _buildTabTireursSection(List<TabTireur> tireurs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.adjust, size: 14, color: Colors.black54),
            SizedBox(width: 4),
            Text(
              "Séance TAB",
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (tireurs.isEmpty)
          const Text("-", style: TextStyle(fontSize: 12, color: Colors.grey))
        else
          ...tireurs.map((tireur) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tireur.reussi ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      tireur.nom,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
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
          CompactFilterButton(
            equipes: _listeEquipes,
            competitions: _listeCompet,
            selectedEquipes: _filtresEquipes,
            selectedCompetitions: _filtresCompet,
            selectedLieux: _filtresLieux,
            competitionColor: _getColorForCompet,
            onApply: (equipes, competitions, lieux) {
              _filtresEquipes = equipes;
              _filtresCompet = competitions;
              _filtresLieux = lieux;
              _appliquerFiltres();
            },
            trailing: AdversaireSearchField(
              value: _filtreAdversaire,
              adversaires: _listeAdversaires,
              onChanged: (value) {
                _filtreAdversaire = value;
                _appliquerFiltres();
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredMatches.isEmpty
                ? const Center(
                    child: Text(
                      "Aucun résultat trouvé.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
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
                          Container(
                            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(255, 79, 133, 213),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  size: 18,
                                  color: Color.fromARGB(255, 255, 255, 255),
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
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
                          ...matchesInMonth.map(
                            (match) => _buildResultCard(match),
                          ),
                        ],
                      );
                    },
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
    final hasTab = match.hasTab;
    final tabWin = hasTab && match.tabFcpb! > match.tabAdv!;
    final tabLose = hasTab && match.tabFcpb! < match.tabAdv!;

    Map<String, int> buteursCount = _compterOccurrences(match.buteurs);
    Map<String, int> passeursCount = _compterOccurrences(match.passeurs);
    final buteursSorted = buteursCount.entries.toList()
      ..sort(
        (a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key),
      );
    final passeursSorted = passeursCount.entries.toList()
      ..sort(
        (a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key),
      );

    bool hasStats =
        match.buteurs.isNotEmpty ||
        match.passeurs.isNotEmpty ||
        match.hasTab ||
        match.tabTireurs.isNotEmpty;
    bool isAway = match.lieu.toUpperCase().startsWith('EXT');
    final tabScore = hasTab
        ? (isAway
              ? "${match.tabAdv}-${match.tabFcpb}"
              : "${match.tabFcpb}-${match.tabAdv}")
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: barColor),
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 12,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        DateFormat(
                                          'dd/MM/yyyy',
                                        ).format(match.date),
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  match.competition,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: barColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Wrap(
                                    spacing: 4,
                                    runSpacing: 3,
                                    alignment: WrapAlignment.end,
                                    children: [
                                      _buildResultBadge(
                                        label: hasTab
                                            ? 'NUL'
                                            : (isWin
                                                  ? 'VICTOIRE'
                                                  : (isDraw
                                                        ? 'NUL'
                                                        : 'DÉFAITE')),
                                        color: hasTab || isDraw
                                            ? Colors.grey
                                            : (isWin
                                                  ? Colors.green
                                                  : Colors.red),
                                      ),
                                      if (tabWin)
                                        _buildResultBadge(
                                          label: 'VICTOIRE TAB',
                                          color: Colors.green,
                                        ),
                                      if (tabLose)
                                        _buildResultBadge(
                                          label: 'DÉFAITE TAB',
                                          color: Colors.red,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  // CORRECTION : Changement de GJPB en FCPB
                                  isAway
                                      ? match.adversaire
                                      : "FCPB ${match.equipe}",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isAway
                                        ? FontWeight.w500
                                        : FontWeight.bold,
                                    color: isAway
                                        ? Colors.black
                                        : AppTheme.bleuMarine,
                                  ),
                                  textAlign: TextAlign.left,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 52,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        isAway
                                            ? "${match.butsAdv}-${match.butsGjpb}"
                                            : "${match.butsGjpb}-${match.butsAdv}",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (tabScore != null) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      't.a.b ($tabScore)',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  // CORRECTION : Changement de GJPB en FCPB
                                  isAway
                                      ? "FCPB ${match.equipe}"
                                      : match.adversaire,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isAway
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isAway
                                        ? AppTheme.bleuMarine
                                        : Colors.black,
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
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade200),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                size: 16,
                                color: AppTheme.bleuMarine,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isExpanded
                                    ? "Masquer les joueurs décisifs"
                                    : "Voir les joueurs décisifs",
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.bleuMarine,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isExpanded && hasStats)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.sports_soccer,
                                        size: 14,
                                        color: Colors.black54,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Buteurs",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (match.buteurs.isEmpty)
                                    const Text(
                                      "-",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    )
                                  else
                                    ...buteursSorted.map((entry) {
                                      final nom = entry.key;
                                      final count = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                nom,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            if (count >= 3)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.dore,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                            _buildDetailsDivider(),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: const [
                                      Icon(
                                        Icons.start,
                                        size: 14,
                                        color: Colors.black54,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        "Passeurs",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (match.passeurs.isEmpty)
                                    const Text(
                                      "-",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    )
                                  else
                                    ...passeursSorted.map((entry) {
                                      final nom = entry.key;
                                      final count = entry.value;
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                nom,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              ),
                                            ),
                                            if (count >= 3)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.dore,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                ],
                              ),
                            ),
                            if (match.hasTab ||
                                match.tabTireurs.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              _buildDetailsDivider(),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTabTireursSection(
                                  match.tabTireurs,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
