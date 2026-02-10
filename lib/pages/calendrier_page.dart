import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_theme.dart';

// --- MODÈLES DE DONNÉES ---
class MatchEvent {
  final int id;
  final DateTime date;
  final String equipe;
  final String adversaire;
  final String competition;
  final String lieu;
  final bool isPlayed;
  
  final String? heure;
  final int? butsGjpb;
  final int? butsAdv;
  
  final List<String> buteurs; 
  final List<String> passeurs; 

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
    this.buteurs = const [],
    this.passeurs = const [],
  });
}

class CalendrierPage extends StatefulWidget {
  const CalendrierPage({super.key});

  @override
  State<CalendrierPage> createState() => _CalendrierPageState();
}

class _CalendrierPageState extends State<CalendrierPage> {
  final SupabaseClient _client = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  // Calendrier
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  // Données
  Map<DateTime, List<MatchEvent>> _events = {};
  List<MatchEvent> _selectedDayEvents = [];
  List<MatchEvent> _nextMatches = [];
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
    _selectedDay = _focusedDay;
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    try {
      final resProgs = await _client.from('programmations').select();
      final resMatchs = await _client.from('matchs').select('*, actions(type, joueurs(nom))');

      List<MatchEvent> allEvents = [];

      // Programmations
      for (var p in resProgs) {
        allEvents.add(MatchEvent(
          id: p['id'],
          date: DateTime.parse(p['date']),
          equipe: p['equipe'],
          adversaire: p['adversaire'],
          competition: p['competition'] ?? 'Championnat',
          lieu: p['lieu'],
          isPlayed: false,
          heure: p['heure'],
        ));
      }

      // Matchs Joués
      for (var m in resMatchs) {
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

        allEvents.add(MatchEvent(
          id: m['id'],
          date: DateTime.parse(m['date']),
          equipe: m['equipe'],
          adversaire: m['adversaire'],
          competition: m['competition'] ?? 'Championnat',
          lieu: m['lieu'],
          isPlayed: true,
          butsGjpb: m['buts_gjpb'],
          butsAdv: m['buts_adv'],
          buteurs: goals,
          passeurs: assists,
        ));
      }

      _organiserDonnees(allEvents);

    } catch (e) {
      print("Erreur chargement: $e");
      setState(() => _isLoading = false);
    }
  }

  void _organiserDonnees(List<MatchEvent> rawList) {
    // Filtres
    List<MatchEvent> filtered = rawList.where((e) {
      bool okEquipe = _filtreEquipe == 'Tout' || e.equipe == _filtreEquipe;
      bool okCompet = _filtreCompet == 'Tout' || e.competition == _filtreCompet;
      return okEquipe && okCompet;
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
    List<MatchEvent> futures = filtered.where((e) => !e.isPlayed && e.date.isAfter(now.subtract(const Duration(days: 1)))).toList();
    futures.sort((a, b) => a.date.compareTo(b.date));
    List<MatchEvent> nextBanner = futures.take(5).toList();

    setState(() {
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

  void _scrollToDetails() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(380, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(bottom: BorderSide(color: Colors.black12)),
                  ),
                  child: Row(
                    children: [
                      // Filtre Equipe
                      Expanded(
                        child: _buildPrettyFilter(
                          value: _filtreEquipe,
                          label: "Équipe",
                          icon: Icons.groups,
                          items: ['Tout', ..._listeEquipes],
                          onChanged: (v) { _filtreEquipe = v!; _chargerDonnees(); },
                        )
                      ),
                      const SizedBox(width: 12),
                      // Filtre Compet
                      Expanded(
                         child: _buildPrettyFilter(
                          value: _filtreCompet,
                          label: "Compétition",
                          icon: Icons.emoji_events,
                          items: ['Tout', ..._listeCompet],
                          onChanged: (v) { _filtreCompet = v!; _chargerDonnees(); },
                        )
                      ),
                    ],
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
                        Icon(Icons.calendar_month, size: 18, color: AppTheme.bleuMarine),
                        SizedBox(width: 8),
                        Text("À VENIR", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.bleuMarine)),
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
                      itemBuilder: (ctx, idx) => _buildNextMatchCardColored(_nextMatches[idx]),
                    ),
                  ),
                ),
              ],

              // --- 3. CALENDRIER ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 5))]),
                    child: TableCalendar<MatchEvent>(
                      locale: 'fr_FR',
                      firstDay: DateTime.utc(2023, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      startingDayOfWeek: StartingDayOfWeek.monday,
                      
                      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.bleuMarine)),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(color: AppTheme.bleuClair.withOpacity(0.3), shape: BoxShape.circle),
                        selectedDecoration: BoxDecoration(color: AppTheme.bleuMarine.withOpacity(0.15), shape: BoxShape.circle),
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
                                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                  width: 16, height: 16,
                                  decoration: BoxDecoration(color: _getColorForCompet(event.competition), shape: BoxShape.circle),
                                  child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                          _selectedDayEvents = _getEventsForDay(selectedDay);
                        });
                        _scrollToDetails();
                      },
                      onFormatChanged: (format) { if (_calendarFormat != format) setState(() => _calendarFormat = format); },
                      onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                    ),
                  ),
                ),
              ),

              // --- 4. LISTE DÉTAILS ---
              if (_selectedDay != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                    child: Text(
                      "MATCHS DU ${DateFormat('dd MMMM', 'fr_FR').format(_selectedDay!).toUpperCase()}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey),
                    ),
                  ),
                ),

              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final event = _selectedDayEvents[index];
                    return _buildDetailedEventCard(event);
                  },
                  childCount: _selectedDayEvents.length,
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
            ],
          ),
    );
  }

  // --- WIDGETS ---

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

  Widget _buildNextMatchCardColored(MatchEvent event) {
    Color bgColor = _getColorForCompet(event.competition);
    Color textColor = Colors.white;
    Color subTextColor = Colors.white.withOpacity(0.9);

    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: bgColor.withOpacity(0.4), blurRadius: 6, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("GJPB ${event.equipe}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                child: Text(event.competition.toUpperCase(), style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          Center(
            child: Column(
              children: [
                Text("CONTRE", style: TextStyle(color: subTextColor, fontSize: 9)),
                const SizedBox(height: 2),
                Text(event.adversaire, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.access_time, color: subTextColor, size: 12),
              const SizedBox(width: 4),
              Text("${DateFormat('dd/MM').format(event.date)} - ${event.heure} - ${event.lieu}", style: TextStyle(color: subTextColor, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildDetailedEventCard(MatchEvent event) {
    Color barColor = _getColorForCompet(event.competition);
    bool isExpanded = _expandedCards.contains(event.id);
    
    // Compter les occurrences pour détecter les triplés
    Map<String, int> buteursCount = _compterOccurrences(event.buteurs);
    Map<String, int> passeursCount = _compterOccurrences(event.passeurs);

    final buteursSorted = buteursCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final passeursSorted = passeursCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    bool hasStats = event.isPlayed && (event.buteurs.isNotEmpty || event.passeurs.isNotEmpty);
    bool isAway = event.lieu.toUpperCase().startsWith('EXT');
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("${event.competition} - ${event.lieu}", style: TextStyle(color: barColor, fontWeight: FontWeight.bold, fontSize: 12)),
                              if(event.isPlayed)
                                 Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: const Text("TERMINÉ", style: TextStyle(fontSize: 9, color: Colors.green, fontWeight: FontWeight.bold))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  isAway ? event.adversaire : "GJPB ${event.equipe}",
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
                                  child: event.isPlayed
                                      ? Text(
                                          isAway
                                              ? "${event.butsAdv}-${event.butsGjpb}"
                                              : "${event.butsGjpb}-${event.butsAdv}",
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                        )
                                      : Text(event.heure ?? '?', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.bleuMarine)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  isAway ? "GJPB ${event.equipe}" : event.adversaire,
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
                                  if (event.buteurs.isEmpty)
                                     const Text("-", style: TextStyle(fontSize: 12, color: Colors.grey))
                                  else
                                    ...buteursSorted.map((entry) {
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
                                   if (event.passeurs.isEmpty)
                                     const Text("-", style: TextStyle(fontSize: 12, color: Colors.grey))
                                  else
                                    ...passeursSorted.map((entry) {
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
