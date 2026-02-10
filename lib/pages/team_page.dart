import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TeamPage extends StatelessWidget {
  const TeamPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Équipes'),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Text('Sélection des équipes à venir'),
      ),
    );
  }
}