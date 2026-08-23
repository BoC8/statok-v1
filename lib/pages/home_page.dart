import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_card.dart';

import 'admin/admin_dashboard.dart';
import 'calendrier_page.dart';
import 'category_selection_page.dart';
import 'equipes_selection_page.dart';
import 'login_page.dart';
import 'resultats_page.dart';
import 'stats_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _categorieActuelle = "Chargement...";
  String? _selectedSeason;
  List<String> _availableSeasons = [];

  @override
  void initState() {
    super.initState();
    _chargerAccueil();
  }

  Future<void> _chargerAccueil() async {
    final prefs = await SharedPreferences.getInstance();
    final categorieSauvegardee =
        prefs.getString('selected_category') ?? 'Cat\u00e9gorie';

    if (mounted) {
      setState(() {
        _categorieActuelle = categorieSauvegardee;
      });
    }

    await _chargerSaisons();
  }

  Future<void> _chargerSaisons() async {
    final seasons = _buildAvailableSeasons();
    final prefs = await SharedPreferences.getInstance();
    final selectedSeason = seasons.first;

    await prefs.setString('selected_season', selectedSeason);

    if (mounted) {
      setState(() {
        _availableSeasons = seasons;
        _selectedSeason = selectedSeason;
      });
    }
  }

  List<String> _buildAvailableSeasons() {
    const int firstSeasonStart = 2025;
    final now = DateTime.now();
    final currentSeasonStart = now.isBefore(DateTime(now.year, 5, 28))
        ? now.year - 1
        : now.year;

    final seasons = <String>[];
    for (int year = currentSeasonStart; year >= firstSeasonStart; year--) {
      seasons.add('$year-${year + 1}');
    }
    return seasons;
  }

  Future<void> _onSeasonChanged(String? saison) async {
    if (saison == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_season', saison);

    if (mounted) {
      setState(() {
        _selectedSeason = saison;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text('FCPB - $_categorieActuelle'),
        centerTitle: true,
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Retour',
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const CategorySelectionPage(),
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Espace Coach',
            onPressed: () {
              final session = Supabase.instance.client.auth.currentSession;
              if (session != null) {
                _navigateTo(context, const AdminDashboard());
              } else {
                _navigateTo(context, const LoginPage());
              }
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: LayoutBuilder(
        builder: (context, constraints) {
          const double padding = 16;
          const double spacing = 16;
          const double selectorHeight = 48;
          const double selectorBottomSpacing = 12;
          const double footerHeight = 54;
          const int menuCount = 4;

          final int columns = isDesktop ? 4 : 2;
          final int rows = (menuCount / columns).ceil();
          final double availableWidth = constraints.maxWidth - (padding * 2);
          final double availableHeight =
              constraints.maxHeight -
              (padding * 2) -
              selectorHeight -
              selectorBottomSpacing -
              footerHeight;
          final double itemWidth =
              (availableWidth - (spacing * (columns - 1))) / columns;
          final double itemHeight =
              (availableHeight - (spacing * (rows - 1))) / rows;

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: 0.4,
                      child: Image.asset(
                        'assets/images/logo-fcpb-sansfond.png',
                        fit: BoxFit.contain,
                        width: constraints.maxWidth * 0.7,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(padding),
                child: Column(
                  children: [
                    SizedBox(
                      height: selectorHeight,
                      child: _buildSeasonSelector(),
                    ),
                    const SizedBox(height: selectorBottomSpacing),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: columns,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                        childAspectRatio: itemWidth / itemHeight,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          MenuCard(
                            title: 'Calendrier',
                            icon: Icons.calendar_month,
                            onTap: () =>
                                _navigateTo(context, const CalendrierPage()),
                          ),
                          MenuCard(
                            title: 'R\u00e9sultats',
                            icon: Icons.emoji_events,
                            onTap: () =>
                                _navigateTo(context, const ResultatsPage()),
                          ),
                          MenuCard(
                            title: 'Stats Joueurs',
                            icon: Icons.bar_chart,
                            onTap: () =>
                                _navigateTo(context, const StatsPage()),
                          ),
                          MenuCard(
                            title: '\u00c9quipes',
                            icon: Icons.groups,
                            onTap: () => _navigateTo(
                              context,
                              const EquipesSelectionPage(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: footerHeight,
                      child: Center(
                        child: Text(
                          "Ensemble sous le même maillot",
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }

  Widget _buildSeasonSelector() {
    if (_selectedSeason == null) return const SizedBox.shrink();

    return Center(
      child: Container(
        width: 190,
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            const Text(
              'Saison',
              style: TextStyle(
                color: AppTheme.bleuMarine,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSeason,
                  isExpanded: true,
                  items: _availableSeasons
                      .map(
                        (saison) => DropdownMenuItem(
                          value: saison,
                          child: Text(saison, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  selectedItemBuilder: (context) => _availableSeasons
                      .map(
                        (saison) => Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            saison,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _onSeasonChanged,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
