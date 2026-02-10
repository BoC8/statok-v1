import 'package:flutter/material.dart';
import 'package:statok/pages/admin/matchs_tab.dart';
import '../../theme/app_theme.dart';
import 'joueurs_tab.dart'; 
import 'programmations_tab.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // 0 = Matchs, 1 = Programmations, 2 = Joueurs
  int _selectedIndex = 0; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // BANNIÈRE BLEUE
      appBar: AppBar(
        title: const Text('DASHBOARD'), // [cite: 1]
        backgroundColor: AppTheme.bleuMarine, // [cite: 76]
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          
          // LES 3 BOUTONS DE NAVIGATION
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
                  _buildTabButton('Joueurs', 2),
                ],
              ),
            ),
          ),
          
          const Divider(height: 30),

          // CONTENU DYNAMIQUE
          Expanded(
            child: _getContent(),
          ),
        ],
      ),
    );
  }

  // Fonction pour construire un bouton d'onglet
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
            boxShadow: isSelected ? [const BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))] : null,
          ),
          child: Text(
            text.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppTheme.dore : Colors.grey[700], // [cite: 78]
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // Choix du contenu à afficher
  Widget _getContent() {
    switch (_selectedIndex) {
      case 0:
        return const MatchsTab();
      case 1:
        return const ProgrammationsTab(); // Placeholder
      case 2:
        return const JoueursTab();
      default:
        return const SizedBox();
    }
  }
}