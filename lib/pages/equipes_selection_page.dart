import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'equipe_dashboard_page.dart'; // On va le créer juste après

class EquipesSelectionPage extends StatelessWidget {
  const EquipesSelectionPage({super.key});

  final List<String> _equipes = const ['18A', '18B', '17'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NOS ÉQUIPES'),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              " ",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: _equipes.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final equipe = _equipes[index];
                  return _buildTeamCard(context, equipe);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamCard(BuildContext context, String equipe) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          // Navigation vers le tableau de bord de l'équipe
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EquipeDashboardPage(equipeName: equipe),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 70,
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
                  "Équipe $equipe",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}