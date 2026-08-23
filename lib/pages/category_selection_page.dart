import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
// N'oublie pas d'importer ta page d'accueil
import 'home_page.dart';

class CategorySelectionPage extends StatelessWidget {
  const CategorySelectionPage({super.key});

  final List<String> _categories = const [
    'U14 - U15',
    'U16 - U17 - U18',
    'SENIORS',
  ];

  // Fonction asynchrone gérée lors du clic
  Future<void> _onCategorySelected(
    BuildContext context,
    String category,
  ) async {
    // 1. On sauvegarde le choix dans la mémoire du téléphone
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_category', category);

    // Sécurité recommandée par Flutter quand on utilise des contextes après un 'await'
    if (!context.mounted) return;

    // 2. On navigue vers la HomePage
    // On utilise pushReplacement pour empêcher l'utilisateur de revenir sur cette page via le bouton "Retour" de son téléphone
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'STATOK',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[50],
      body: LayoutBuilder(
        builder: (context, constraints) {
          const double logoHeight = 200;
          const double titleHeight = 44;
          const int cardCount = 3;
          final bool compact = constraints.maxHeight < 620;
          final double padding = compact ? 12 : 16;
          final double topSpacing = compact ? 8 : 20;
          final double logoBottomSpacing = compact ? 8 : 16;
          final double titleBottomSpacing = compact ? 12 : 24;
          final double cardSpacing = compact ? 10 : 14;
          final double footerHeight = compact ? 34 : 54;
          final double fixedHeight =
              topSpacing +
              logoHeight +
              logoBottomSpacing +
              titleHeight +
              titleBottomSpacing +
              (cardSpacing * (cardCount - 1)) +
              footerHeight +
              (padding * 2);
          final double cardHeight =
              ((constraints.maxHeight - fixedHeight) / cardCount).clamp(
                48.0,
                70.0,
              );

          return Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              children: [
                SizedBox(height: topSpacing),

                // Le Logo du club
                Image.asset(
                  'assets/images/logo-fcpb-sansfond.png',
                  height: logoHeight,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.sports_soccer,
                    size: 80,
                    color: AppTheme.bleuMarine,
                  ),
                ),
                SizedBox(height: logoBottomSpacing),

                // Le nom du club
                SizedBox(
                  height: titleHeight,
                  child: Center(
                    child: Text(
                      "FOOTBALL CLUB PIERRE BLEUE",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.bleuMarine,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: titleBottomSpacing),

                // La liste des boutons de catégories (prend l'espace disponible)
                Expanded(
                  child: ListView.separated(
                    itemCount: _categories.length,
                    physics: const NeverScrollableScrollPhysics(),
                    separatorBuilder: (ctx, i) => SizedBox(height: cardSpacing),
                    itemBuilder: (context, index) {
                      final categorie = _categories[index];
                      return _buildCategoryCard(context, categorie, cardHeight);
                    },
                  ),
                ),

                // La phrase de fin tout en bas
                SizedBox(
                  height: footerHeight,
                  child: const Center(
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
          );
        },
      ),
    );
  }

  // Le widget de la carte (identique à ta page des équipes)
  Widget _buildCategoryCard(
    BuildContext context,
    String categorie,
    double height,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _onCategorySelected(context, categorie),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: AppTheme.bleuMarine,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  categorie,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
