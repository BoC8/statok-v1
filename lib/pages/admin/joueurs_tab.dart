import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/joueur_model.dart';
import '../../theme/app_theme.dart';

class JoueursTab extends StatefulWidget {
  const JoueursTab({super.key});

  @override
  State<JoueursTab> createState() => _JoueursTabState();
}

class _JoueursTabState extends State<JoueursTab> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final SupabaseClient _client = Supabase.instance.client;

  String _rechercheTexte = ''; // Filtre local

  Future<void> _ajouterJoueur() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await _client.from('joueurs').insert({'nom': _nomController.text.trim()});
      _nomController.clear();
      // Pas besoin de recharger manuellement, le Stream le fera !
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joueur ajouté')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _supprimerJoueur(int id) async {
    try {
      await _client.from('joueurs').delete().eq('id', id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('Erreur suppression: $e');
    }
  }

  Future<void> _modifierJoueur(int id, String nouveauNom) async {
    try {
      await _client.from('joueurs').update({'nom': nouveauNom}).eq('id', id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('Erreur modification: $e');
    }
  }

  void _ouvrirDetails(JoueurModel joueur) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _JoueurDetailDialog(
          joueur: joueur,
          onDelete: () => _supprimerJoueur(joueur.id),
          onSave: (nom) => _modifierJoueur(joueur.id, nom),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // FORMULAIRE AJOUT
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(labelText: 'Nom du joueur'),
                        validator: (value) => value == null || value.isEmpty ? 'Requis' : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _ajouterJoueur,
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.bleuMarine, foregroundColor: Colors.white),
                      child: const Text('AJOUTER'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // BARRE DE RECHERCHE (FILTRE LOCAL)
          TextField(
            decoration: InputDecoration(
              labelText: 'Rechercher un joueur...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              fillColor: Colors.white,
              filled: true,
            ),
            onChanged: (val) => setState(() => _rechercheTexte = val),
          ),
          const SizedBox(height: 10),

          // LISTE EN REALTIME
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              // Écoute en temps réel
              stream: _client.from('joueurs').stream(primaryKey: ['id']).order('nom', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                var data = snapshot.data!;
                
                // Filtre local
                if (_rechercheTexte.isNotEmpty) {
                  data = data.where((j) => j['nom'].toString().toLowerCase().contains(_rechercheTexte.toLowerCase())).toList();
                }

                final joueurs = data.map((json) => JoueurModel.fromJson(json)).toList();

                if (joueurs.isEmpty) return const Center(child: Text("Aucun joueur trouvé"));

                return ListView.separated(
                  itemCount: joueurs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final joueur = joueurs[index];
                    return ListTile(
                      title: Text(joueur.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.bleuClair,
                        child: Text(joueur.nom[0], style: const TextStyle(color: Colors.white)),
                      ),
                      trailing: const Icon(Icons.edit, size: 20, color: Colors.grey),
                      onTap: () => _ouvrirDetails(joueur),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// MODALE DETAILS JOUEUR
class _JoueurDetailDialog extends StatefulWidget {
  final JoueurModel joueur;
  final VoidCallback onDelete;
  final Function(String) onSave;

  const _JoueurDetailDialog({required this.joueur, required this.onDelete, required this.onSave});

  @override
  State<_JoueurDetailDialog> createState() => _JoueurDetailDialogState();
}

class _JoueurDetailDialogState extends State<_JoueurDetailDialog> {
  bool _isEditing = false;
  late TextEditingController _editController;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.joueur.nom);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Modifier Joueur' : 'Détails Joueur'),
      content: _isEditing
          ? TextFormField(controller: _editController, decoration: const InputDecoration(labelText: 'Nom'))
          : Text('Nom : ${widget.joueur.nom}', style: const TextStyle(fontSize: 18)),
      actions: [
        if (_isEditing) ...[
          TextButton(onPressed: () => setState(() => _isEditing = false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => widget.onSave(_editController.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Enregistrer'),
          ),
        ] else ...[
          TextButton(
            onPressed: widget.onDelete,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
          
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),

          ElevatedButton(
            onPressed: () => setState(() => _isEditing = true),
            child: const Text('Modifier'),
          ),
        ]
      ],
    );
  }
}