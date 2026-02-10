import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/menu_card.dart';

// Import des pages
import 'calendrier_page.dart';
import 'resultats_page.dart';
import 'stats_page.dart';
import 'videos_page.dart';
import 'club_page.dart';
import 'login_page.dart';
import 'equipes_selection_page.dart';
import 'admin/admin_dashboard.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GJPB'),
        centerTitle: true,
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        // LE BOUTON ADMIN EST ICI
        actions: [
          IconButton(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            tooltip: 'Espace Coach',
            onPressed: () {
              // Vérification de la session
              final session = Supabase.instance.client.auth.currentSession;
              if (session != null) {
                // Déjà connecté -> Dashboard
                _navigateTo(context, const AdminDashboard());
              } else {
                // Pas connecté -> Login
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
          const int menuCount = 6;
          final int columns = isDesktop ? 3 : 2;
          final int rows = (menuCount / columns).ceil();
          final double availableWidth = constraints.maxWidth - (padding * 2);
          final double availableHeight = constraints.maxHeight - (padding * 2);
          final double itemWidth = (availableWidth - (spacing * (columns - 1))) / columns;
          final double itemHeight = (availableHeight - (spacing * (rows - 1))) / rows;

          return Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Opacity(
                      opacity: 0.28,
                      child: Image.asset(
                        'assets/images/logo-gjpb.png',
                        fit: BoxFit.contain,
                        width: constraints.maxWidth * 0.8,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(padding),
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
              onTap: () => _navigateTo(context, const CalendrierPage()),
            ),
            MenuCard(
              title: 'Résultats',
              icon: Icons.emoji_events,
              onTap: () => _navigateTo(context, const ResultatsPage()),
            ),
            MenuCard(
              title: 'Stats Joueurs',
              icon: Icons.bar_chart,
              onTap: () => _navigateTo(context, const StatsPage()),
            ),
            MenuCard(
              title: 'Équipes',
              icon: Icons.groups,
              onTap: () => _navigateTo(context, const EquipesSelectionPage()),
            ),
            MenuCard(
              title: 'Vidéos',
              icon: Icons.play_circle_fill,
              onTap: () => _navigateTo(context, const VideosPage()),
            ),
                    MenuCard(
                      title: 'Le Club',
                      icon: Icons.info,
                      onTap: () => _navigateTo(context, const ClubPage()),
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => page),
    );
  }
}
