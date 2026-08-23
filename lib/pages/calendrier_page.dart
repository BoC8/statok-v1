import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_filter_button.dart';
import '../repositories/match_repository.dart';

// --- MODÈLES DE DONNÉES ---
class TabTireur {
  final String nom;
  final bool reussi;

  TabTireur({required this.nom, required this.reussi});
}

class MatchEvent {
  final String id;
  final DateTime date;
  final String equipe;
  final String adversaire;
  final String competition;
  final String lieu;
  final bool isPlayed;

  final String? heure;
  final int? butsGjpb;
  final int? butsAdv;
  final int? tabFcpb;
  final int? tabAdv;

  final List<String> buteurs;
  final List<String> passeurs;
  final List<TabTireur> tabTireurs;

  MatchEvent({
    required this.id,
    required this.date,
    required this.equipe,
    required this.adversaire,
    required this.competition,
    required this.lieu,
    required this.isPlayed,
    this.heure,
    this.butsGjpb,
    this.butsAdv,
    this.tabFcpb,
    this.tabAdv,
    this.buteurs = const [],
    this.passeurs = const [],
    this.tabTireurs = const [],
  });

  bool get hasTab => tabFcpb != null && tabAdv != null;
}

class CalendrierPage extends StatefulWidget {
  const CalendrierPage({super.key});

  @override
  State<CalendrierPage> createState() => _CalendrierPageState();
}

class _CalendrierPageState extends State<CalendrierPage> {
  final MatchRepository _matchRepo = MatchRepository();
  final ScrollController _scrollController = ScrollController();

  // Calendrier
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Données
  List<MatchEvent> _allEvents = [];
  Map<DateTime, List<MatchEvent>> _events = {};
  List<MatchEvent> _selectedDayEvents = [];
  List<MatchEvent> _nextMatches = [];
  bool _isLoading = true;

  // Filtres
  Set<String> _filtresEquipes = {};
  Set<String> _filtresCompet = {};
  Set<String> _filtresLieux = {};
  String _filtreAdversaire = '';
  List<String> _listeEquipes = [];
  List<String> _listeCompet = [];
  List<String> _listeAdversaires = [];

  // État d'expansion des cartes
  Set<String> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categorie = prefs.getString('selected_category');
      final saison = prefs.getString('selected_season');
      final resProgs = await _matchRepo.programmations(
        categorie: categorie,
        saison: saison,
      );
      final resMatchs = await _matchRepo.matchsJoues(
        categorie: categorie,
        saison: saison,
      );

      List<MatchEvent> allEvents = [];

      // Programmations
      for (var p in resProgs) {
        allEvents.add(
          MatchEvent(
            id: p['id'].toString(),
            date: DateTime.parse(p['date']),
            equipe: p['equipe'] ?? '',
            adversaire: _nomAdversaire(p),
            competition: p['competition'] ?? 'Championnat',
            lieu: p['lieu'] ?? '',
            isPlayed: false,
            heure: p['heure'],
          ),
        );
      }

      // Matchs Joués
      for (var m in resMatchs) {
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

        allEvents.add(
          MatchEvent(
            id: m['id'].toString(),
            date: DateTime.parse(m['date']),
            equipe: m['equipe'] ?? '',
            adversaire: _nomAdversaire(m),
            competition: m['competition'] ?? 'Championnat',
            lieu: m['lieu'] ?? '',
            isPlayed: true,
            butsGjpb: m['buts_gjpb'],
            butsAdv: m['buts_adv'],
            tabFcpb: int.tryParse(m['tab_fcpb']?.toString() ?? ''),
            tabAdv: int.tryParse(m['tab_adv']?.toString() ?? ''),
            buteurs: goals,
            passeurs: assists,
            tabTireurs: tabTireurs,
          ),
        );
      }

      _allEvents = allEvents;
      _organiserDonnees(_allEvents);
    } catch (e) {
      print("Erreur chargement: $e");
      setState(() => _isLoading = false);
    }
  }

  void _organiserDonnees(List<MatchEvent> rawList) {
    final equipes = _valeursUniques(rawList.map((e) => e.equipe));
    final competitions = _valeursUniques(rawList.map((e) => e.competition));
    final adversaires = _valeursUniques(rawList.map((e) => e.adversaire));
    _filtresEquipes = _filtresEquipes.intersection(equipes.toSet());
    _filtresCompet = _filtresCompet.intersection(competitions.toSet());
    _filtresLieux = _filtresLieux.intersection({'DOM', 'EXT'});

    // Filtres
    final adversaireQuery = _filtreAdversaire.trim().toLowerCase();
    List<MatchEvent> filtered = rawList.where((e) {
      bool okEquipe =
          _filtresEquipes.isEmpty || _filtresEquipes.contains(e.equipe);
      bool okCompet =
          _filtresCompet.isEmpty || _filtresCompet.contains(e.competition);
      bool okAdversaire =
          adversaireQuery.isEmpty ||
          e.adversaire.toLowerCase().contains(adversaireQuery);
      bool okLieu =
          _filtresLieux.isEmpty || _filtresLieux.contains(_lieuCode(e.lieu));
      return okEquipe && okCompet && okAdversaire && okLieu;
    }).toList();

    // Map pour calendrier
    Map<DateTime, List<MatchEvent>> eventsMap = {};
    for (var event in filtered) {
      final key = DateTime(event.date.year, event.date.month, event.date.day);
      if (eventsMap[key] == null) eventsMap[key] = [];
      eventsMap[key]!.add(event);
    }

    // Prochains matchs
    final now = DateTime.now();
    List<MatchEvent> futures = filtered
        .where(
          (e) =>
              !e.isPlayed &&
              e.date.isAfter(now.subtract(const Duration(days: 1))),
        )
        .toList();
    futures.sort((a, b) => a.date.compareTo(b.date));
    List<MatchEvent> nextBanner = futures.take(5).toList();

    setState(() {
      _listeEquipes = equipes;
      _listeCompet = competitions;
      _listeAdversaires = adversaires;
      _events = eventsMap;
      _nextMatches = nextBanner;
      if (_selectedDay != null) {
        _selectedDayEvents = _getEventsForDay(_selectedDay!);
      }
      _isLoading = false;
    });
  }

  List<MatchEvent> _getEventsForDay(DateTime day) {
    final key = DateTime(day.year, day.month, day.day);
    return _events[key] ?? [];
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

  Color _getColorForCompet(String compet) {
    if (compet.contains('Coupe')) return AppTheme.dore;
    if (compet.contains('Amical')) return Colors.grey;
    return AppTheme.bleuMarine; // Phase 1, 2, 3 -> Bleu
  }

  // Compter les occurrences d'un joueur
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

  void _scrollToDetails() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          380,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CALENDRIER'),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              controller: _scrollController,
              slivers: [
                // --- 1. FILTRES STYLISÉS ---
                SliverToBoxAdapter(
                  child: CompactFilterButton(
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
                      _organiserDonnees(_allEvents);
                    },
                    trailing: AdversaireSearchField(
                      value: _filtreAdversaire,
                      adversaires: _listeAdversaires,
                      onChanged: (value) {
                        _filtreAdversaire = value;
                        _organiserDonnees(_allEvents);
                      },
                    ),
                  ),
                ),

                // --- 2. BANNIÈRE À VENIR ---
                if (_nextMatches.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.calendar_month,
                            size: 18,
                            color: AppTheme.bleuMarine,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "À VENIR",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.bleuMarine,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _nextMatches.length,
                        itemBuilder: (ctx, idx) =>
                            _buildNextMatchCardColored(_nextMatches[idx]),
                      ),
                    ),
                  ),
                ],

                // --- 3. CALENDRIER ---
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TableCalendar<MatchEvent>(
                        locale: 'fr_FR',
                        firstDay: DateTime.utc(2023, 1, 1),
                        lastDay: DateTime.utc(2030, 12, 31),
                        focusedDay: _focusedDay,
                        calendarFormat: _calendarFormat,
                        startingDayOfWeek: StartingDayOfWeek.monday,

                        headerStyle: const HeaderStyle(
                          formatButtonVisible: false,
                          titleCentered: true,
                          titleTextStyle: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.bleuMarine,
                          ),
                        ),
                        calendarStyle: CalendarStyle(
                          todayDecoration: BoxDecoration(
                            color: AppTheme.bleuClair.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: AppTheme.bleuMarine.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          markersMaxCount: 0,
                        ),
                        eventLoader: _getEventsForDay,

                        // Marqueurs A, B, 17
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, date, events) {
                            if (events.isEmpty) return const SizedBox();
                            return Positioned(
                              bottom: 1,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: events.take(3).map((event) {
                                  String label = "17";
                                  if (event.equipe == "18A") label = "A";
                                  if (event.equipe == "18B") label = "B";
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: _getColorForCompet(
                                        event.competition,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        label,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                        selectedDayPredicate: (day) =>
                            isSameDay(_selectedDay, day),
                        onDaySelected: (selectedDay, focusedDay) {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                            _selectedDayEvents = _getEventsForDay(selectedDay);
                          });
                          _scrollToDetails();
                        },
                        onFormatChanged: (format) {
                          if (_calendarFormat != format)
                            setState(() => _calendarFormat = format);
                        },
                        onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                      ),
                    ),
                  ),
                ),

                // --- 4. LISTE DÉTAILS ---
                if (_selectedDay != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8,
                      ),
                      child: Text(
                        "MATCHS DU ${DateFormat('dd MMMM', 'fr_FR').format(_selectedDay!).toUpperCase()}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),

                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final event = _selectedDayEvents[index];
                    return _buildDetailedEventCard(event);
                  }, childCount: _selectedDayEvents.length),
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
              ],
            ),
    );
  }

  // --- WIDGETS ---

  Widget _buildNextMatchCardColored(MatchEvent event) {
    Color bgColor = _getColorForCompet(event.competition);
    Color textColor = Colors.white;
    Color subTextColor = Colors.white.withOpacity(0.9);
    final isAway = event.lieu.toUpperCase().startsWith('EXT');

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bgColor.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isAway ? event.adversaire : "FCPB ${event.equipe}",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  event.competition.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Center(
            child: Column(
              children: [
                Text(
                  "CONTRE",
                  style: TextStyle(color: subTextColor, fontSize: 9),
                ),
                const SizedBox(height: 2),
                Text(
                  isAway ? "FCPB ${event.equipe}" : event.adversaire,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.access_time, color: subTextColor, size: 12),
              const SizedBox(width: 4),
              Text(
                "${DateFormat('dd/MM').format(event.date)} - ${_formatHeure(event.heure)} - ${event.lieu}",
                style: TextStyle(
                  color: subTextColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedEventCard(MatchEvent event) {
    Color barColor = _getColorForCompet(event.competition);
    bool isExpanded = _expandedCards.contains(event.id);
    final isWin =
        event.isPlayed && (event.butsGjpb ?? 0) > (event.butsAdv ?? 0);
    final isDraw =
        event.isPlayed && (event.butsGjpb ?? 0) == (event.butsAdv ?? 0);
    final hasTab = event.hasTab;
    final tabWin = hasTab && event.tabFcpb! > event.tabAdv!;
    final tabLose = hasTab && event.tabFcpb! < event.tabAdv!;

    // Compter les occurrences pour détecter les triplés
    Map<String, int> buteursCount = _compterOccurrences(event.buteurs);
    Map<String, int> passeursCount = _compterOccurrences(event.passeurs);

    final buteursSorted = buteursCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final passeursSorted = passeursCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    bool hasStats =
        event.isPlayed &&
        (event.buteurs.isNotEmpty ||
            event.passeurs.isNotEmpty ||
            event.hasTab ||
            event.tabTireurs.isNotEmpty);
    bool isAway = event.lieu.toUpperCase().startsWith('EXT');
    final tabScore = hasTab
        ? (isAway
              ? "${event.tabAdv}-${event.tabFcpb}"
              : "${event.tabFcpb}-${event.tabAdv}")
        : null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    // Partie principale (toujours visible)
                    Padding(
                      padding: const EdgeInsets.all(14),
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
                                        ).format(event.date),
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
                                  event.competition,
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
                                  child: event.isPlayed
                                      ? Wrap(
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
                                        )
                                      : Text(
                                          _formatHeure(event.heure),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.bleuMarine,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isAway
                                      ? event.adversaire
                                      : "FCPB ${event.equipe}",
                                  style: TextStyle(
                                    fontSize: 15,
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
                              const SizedBox(width: 12),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 55,
                                    height: 45,
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Center(
                                      child: event.isPlayed
                                          ? Text(
                                              isAway
                                                  ? "${event.butsAdv}-${event.butsGjpb}"
                                                  : "${event.butsGjpb}-${event.butsAdv}",
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            )
                                          : Text(
                                              _formatHeure(event.heure),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: AppTheme.bleuMarine,
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isAway
                                      ? "FCPB ${event.equipe}"
                                      : event.adversaire,
                                  style: TextStyle(
                                    fontSize: 15,
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

                    // Bouton pour afficher les détails
                    if (hasStats)
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedCards.remove(event.id);
                            } else {
                              _expandedCards.add(event.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
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
                                size: 18,
                                color: AppTheme.bleuMarine,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isExpanded
                                    ? "Masquer les joueurs décisifs"
                                    : "Voir les joueurs décisifs",
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
                                  if (event.buteurs.isEmpty)
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
                            // Passeurs
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
                                  if (event.passeurs.isEmpty)
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
                            if (event.hasTab ||
                                event.tabTireurs.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              _buildDetailsDivider(),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTabTireursSection(
                                  event.tabTireurs,
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

  String _formatHeure(String? heure) {
    if (heure == null || heure.trim().isEmpty) return '?';
    final clean = heure.trim();
    final parts = clean.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return clean;
  }
}
