import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:statok/pages/admin/matchs_tab.dart';
import '../../theme/app_theme.dart';
import 'equipes_admin_tab.dart';
import 'joueurs_tab.dart';
import 'programmations_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  String _categorieActuelle = 'Catégorie';
  String? _selectedSeason;
  List<String> _availableSeasons = [];
  int _equipesVersion = 0;

  @override
  void initState() {
    super.initState();
    _chargerContexte();
  }

  Future<void> _chargerContexte() async {
    final prefs = await SharedPreferences.getInstance();
    final seasons = _buildAvailableSeasons();
    final savedSeason = prefs.getString('selected_season');
    final selectedSeason = seasons.contains(savedSeason)
        ? savedSeason!
        : seasons.first;

    await prefs.setString('selected_season', selectedSeason);

    if (!mounted) return;
    setState(() {
      _categorieActuelle = prefs.getString('selected_category') ?? 'Catégorie';
      _availableSeasons = seasons;
      _selectedSeason = selectedSeason;
    });
  }

  List<String> _buildAvailableSeasons() {
    const int firstSeasonStart = 2025;
    final now = DateTime.now();
    final currentSeasonStart = now.isBefore(DateTime(now.year, 5, 28))
        ? now.year - 1
        : now.year;

    return [
      for (int year = currentSeasonStart; year >= firstSeasonStart; year--)
        '$year-${year + 1}',
    ];
  }

  Future<void> _onSeasonChanged(String? saison) async {
    if (saison == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_season', saison);
    if (mounted) setState(() => _selectedSeason = saison);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('DASHBOARD - $_categorieActuelle'),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SizedBox(height: 42, child: _buildSeasonSelector()),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildTabButton('Matchs', 0),
                  _buildTabButton('Programmations', 1),
                  _buildTabButton('Joueurs(euses)', 2),
                  _buildTabButton('Paramètres', 3),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          Expanded(child: _getContent()),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.bleuMarine : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    const BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppTheme.dore : Colors.grey[700],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _getContent() {
    final selectedSeason = _selectedSeason;
    if (selectedSeason == null) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_selectedIndex) {
      case 0:
        return MatchsTab(
          key: ValueKey('matchs-$selectedSeason-$_equipesVersion'),
          selectedSeason: selectedSeason,
          categorie: _categorieActuelle,
        );
      case 1:
        return ProgrammationsTab(
          key: ValueKey('programmations-$selectedSeason-$_equipesVersion'),
          selectedSeason: selectedSeason,
          categorie: _categorieActuelle,
        );
      case 2:
        return JoueursTab(categorie: _categorieActuelle);
      case 3:
        return EquipesAdminTab(
          categorie: _categorieActuelle,
          onEquipesChanged: () => setState(() => _equipesVersion++),
        );
      default:
        return const SizedBox();
    }
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
