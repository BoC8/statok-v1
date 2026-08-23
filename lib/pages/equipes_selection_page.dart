import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/equipe_service.dart';
import '../theme/app_theme.dart';
import 'equipe_dashboard_page.dart';

class EquipesSelectionPage extends StatefulWidget {
  const EquipesSelectionPage({super.key});

  @override
  State<EquipesSelectionPage> createState() => _EquipesSelectionPageState();
}

class _EquipesSelectionPageState extends State<EquipesSelectionPage> {
  final SupabaseClient _client = Supabase.instance.client;

  List<String> _equipes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chargerEquipes();
  }

  Future<void> _chargerEquipes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final categorie = prefs.getString('selected_category');
      final saison = prefs.getString('selected_season');
      final equipes = await EquipeService(
        _client,
      ).chargerEquipes(categorie: categorie, saison: saison);

      if (mounted) {
        setState(() {
          _equipes = equipes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NOS \u00c9QUIPES'),
        backgroundColor: AppTheme.bleuMarine,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[50],
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _equipes.isEmpty
            ? const Center(child: Text("Aucune \u00e9quipe trouv\u00e9e."))
            : ListView.separated(
                itemCount: _equipes.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final equipe = _equipes[index];
                  return _buildTeamCard(context, equipe);
                },
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
                  "\u00c9quipe $equipe",
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
