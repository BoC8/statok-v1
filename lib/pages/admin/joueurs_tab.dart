import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/joueur_model.dart';
import '../../theme/app_theme.dart';
import '../../utils/categorie_utils.dart';

class JoueursTab extends StatefulWidget {
  final String categorie;

  const JoueursTab({super.key, required this.categorie});

  @override
  State<JoueursTab> createState() => _JoueursTabState();
}

class _JoueursTabState extends State<JoueursTab> {
  final SupabaseClient _client = Supabase.instance.client;

  String _rechercheTexte = '';
  String _genreSelectionne = 'M';
  String? _categorieDetailSelectionnee;
  int _refreshTick = 0;

  @override
  void didUpdateWidget(covariant JoueursTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.categorie != widget.categorie) {
      setState(() => _categorieDetailSelectionnee = null);
    }
  }

  bool _joueurDansCategorie(Map<String, dynamic> joueur) {
    final details = detailsAffichesPourCategorie(widget.categorie);
    final detail = joueur['categorie_detail']?.toString();
    if (detail != null && details.contains(detail)) return true;

    final dbCategorie = joueur['categorie']?.toString();
    final selectedDbCategorie = categoriePourDb(widget.categorie);
    return dbCategorie == widget.categorie ||
        dbCategorie == selectedDbCategorie;
  }

  bool _joueurMatchFiltres(Map<String, dynamic> joueur) {
    final genre = (joueur['genre'] ?? 'M').toString();
    final detail = joueur['categorie_detail']?.toString();
    final nom = joueur['nom']?.toString().toLowerCase() ?? '';
    return _joueurDansCategorie(joueur) &&
        genre == _genreSelectionne &&
        (_categorieDetailSelectionnee == null ||
            detail == _categorieDetailSelectionnee) &&
        (_rechercheTexte.isEmpty ||
            nom.contains(_rechercheTexte.toLowerCase()));
  }

  Future<void> _ajouterJoueur(
    String nom,
    String genre,
    String categorieDetail,
  ) async {
    try {
      final existing = await _client
          .from('joueurs')
          .select('actif')
          .ilike('nom', nom.trim())
          .eq('categorie_detail', categorieDetail)
          .maybeSingle();

      if (existing != null) {
        final message = existing['actif'] == false
            ? 'Ce joueur existe déjà dans les joueurs désactivés. Vous pouvez le réactiver en dessous.'
            : 'Ce joueur existe déjà dans les joueurs actifs.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      await _client.from('joueurs').insert({
        'nom': nom.trim(),
        'genre': genre,
        'categorie_detail': categorieDetail,
        'categorie': categoriePourDetail(categorieDetail),
        'actif': true,
      });
      if (mounted) {
        setState(() {
          _genreSelectionne = genre;
          _categorieDetailSelectionnee = categorieDetail;
          _refreshTick++;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Joueur(euse) ajouté(e)')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _desactiverJoueur(JoueurModel joueur) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Retirer ${joueur.nom} de la liste active ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client
          .from('joueurs')
          .update({'actif': false})
          .eq('id', joueur.id);
      if (mounted) {
        setState(() => _refreshTick++);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _reactiverJoueur(JoueurModel joueur) async {
    try {
      await _client.from('joueurs').update({'actif': true}).eq('id', joueur.id);
      if (mounted) setState(() => _refreshTick++);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _modifierJoueur(
    String id,
    String nom,
    String genre,
    String categorieDetail,
  ) async {
    try {
      await _client
          .from('joueurs')
          .update({
            'nom': nom.trim(),
            'genre': genre,
            'categorie_detail': categorieDetail,
            'categorie': categoriePourDetail(categorieDetail),
          })
          .eq('id', id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _ouvrirAjout() {
    showDialog(
      context: context,
      builder: (context) => _JoueurFormDialog(
        categorieDetails: detailsAffichesPourCategorie(widget.categorie),
        onSave: _ajouterJoueur,
      ),
    );
  }

  void _ouvrirDetails(JoueurModel joueur) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _JoueurDetailDialog(
          joueur: joueur,
          categorieDetails: detailsAffichesPourCategorie(widget.categorie),
          onDelete: () => _desactiverJoueur(joueur),
          onSave: (nom, genre, categorieDetail) =>
              _modifierJoueur(joueur.id, nom, genre, categorieDetail),
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
          Row(
            children: [
              Expanded(child: _buildGenreCard('M', 'Joueurs')),
              const SizedBox(width: 10),
              Expanded(child: _buildGenreCard('F', 'Joueuses')),
            ],
          ),
          if (detailsAffichesPourCategorie(widget.categorie).length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: detailsAffichesPourCategorie(widget.categorie)
                  .map(
                    (detail) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: _buildCategorieDetailCard(detail),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _ouvrirAjout,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Ajouter un(e) joueur(euse)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.bleuMarine,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'Rechercher...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 0,
              ),
              fillColor: Colors.white,
              filled: true,
            ),
            onChanged: (val) => setState(() => _rechercheTexte = val),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              key: ValueKey(_refreshTick),
              stream: _client
                  .from('joueurs')
                  .stream(primaryKey: ['id'])
                  .order('nom', ascending: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final data = snapshot.data!.where(_joueurMatchFiltres).toList()
                  ..sort(
                    (a, b) => a['nom'].toString().toLowerCase().compareTo(
                      b['nom'].toString().toLowerCase(),
                    ),
                  );

                final joueurs = data
                    .where((j) => j['actif'] != false)
                    .map((json) => JoueurModel.fromJson(json))
                    .toList();
                final joueursDesactives = data
                    .where((j) => j['actif'] == false)
                    .map((json) => JoueurModel.fromJson(json))
                    .toList();

                if (joueurs.isEmpty && joueursDesactives.isEmpty) {
                  return const Center(child: Text('Aucun résultat'));
                }

                return ListView(
                  children: [
                    if (joueurs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Aucun joueur actif.'),
                      )
                    else
                      ...joueurs.map(
                        (joueur) => ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            joueur.nom,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: const Icon(
                            Icons.edit_note,
                            color: Colors.grey,
                          ),
                          onTap: () => _ouvrirDetails(joueur),
                        ),
                      ),
                    if (joueursDesactives.isNotEmpty) ...[
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        child: Text(
                          'Joueurs(euses) désactivé(e)s',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...joueursDesactives.map(
                        (joueur) => ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                          ),
                          title: Text(
                            joueur.nom,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: TextButton(
                            onPressed: () => _reactiverJoueur(joueur),
                            child: const Text('Réactiver'),
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenreCard(String genre, String label) {
    final selected = _genreSelectionne == genre;
    return InkWell(
      onTap: () => setState(() => _genreSelectionne = genre),
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: selected ? 3 : 0,
        color: selected ? AppTheme.bleuMarine : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(
                genre == 'F' ? Icons.woman : Icons.man,
                color: selected ? AppTheme.dore : AppTheme.bleuMarine,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : AppTheme.bleuMarine,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorieDetailCard(String detail) {
    final selected = _categorieDetailSelectionnee == detail;
    return InkWell(
      onTap: () => setState(() {
        _categorieDetailSelectionnee = selected ? null : detail;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Card(
        elevation: selected ? 3 : 0,
        color: selected ? AppTheme.bleuMarine : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppTheme.dore : AppTheme.bleuMarine,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _JoueurFormDialog extends StatefulWidget {
  final List<String> categorieDetails;
  final Future<void> Function(String nom, String genre, String categorieDetail)
  onSave;

  const _JoueurFormDialog({
    required this.categorieDetails,
    required this.onSave,
  });

  @override
  State<_JoueurFormDialog> createState() => _JoueurFormDialogState();
}

class _JoueurFormDialogState extends State<_JoueurFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  String? _genre;
  String? _categorieDetail;

  @override
  void initState() {
    super.initState();
    if (widget.categorieDetails.length == 1) {
      _categorieDetail = widget.categorieDetails.first;
    }
  }

  @override
  void dispose() {
    _nomController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() ||
        _genre == null ||
        _categorieDetail == null) {
      return;
    }
    await widget.onSave(_nomController.text, _genre!, _categorieDetail!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final details = widget.categorieDetails;
    return AlertDialog(
      title: const Text('Ajouter un(e) joueur(euse)'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _genre,
              decoration: const InputDecoration(labelText: 'Genre'),
              items: const [
                DropdownMenuItem(value: 'M', child: Text('M')),
                DropdownMenuItem(value: 'F', child: Text('F')),
              ],
              validator: (value) => value == null ? 'Requis' : null,
              onChanged: (value) => setState(() => _genre = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _categorieDetail,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: details
                  .map(
                    (detail) =>
                        DropdownMenuItem(value: detail, child: Text(detail)),
                  )
                  .toList(),
              validator: (value) => value == null ? 'Requis' : null,
              onChanged: (value) => setState(() => _categorieDetail = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Ajouter')),
      ],
    );
  }
}

class _JoueurDetailDialog extends StatefulWidget {
  final JoueurModel joueur;
  final List<String> categorieDetails;
  final VoidCallback onDelete;
  final Future<void> Function(String nom, String genre, String categorieDetail)
  onSave;

  const _JoueurDetailDialog({
    required this.joueur,
    required this.categorieDetails,
    required this.onDelete,
    required this.onSave,
  });

  @override
  State<_JoueurDetailDialog> createState() => _JoueurDetailDialogState();
}

class _JoueurDetailDialogState extends State<_JoueurDetailDialog> {
  bool _isEditing = false;
  late TextEditingController _editController;
  late String _genre;
  late String _categorieDetail;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.joueur.nom);
    _genre = widget.joueur.genre == 'F' ? 'F' : 'M';
    _categorieDetail =
        widget.categorieDetails.contains(widget.joueur.categorieDetail)
        ? widget.joueur.categorieDetail!
        : widget.categorieDetails.first;
  }

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Modifier' : 'Détails'),
      content: _isEditing
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _editController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _genre,
                  decoration: const InputDecoration(labelText: 'Genre'),
                  items: const [
                    DropdownMenuItem(value: 'M', child: Text('M')),
                    DropdownMenuItem(value: 'F', child: Text('F')),
                  ],
                  onChanged: (value) => setState(() => _genre = value ?? 'M'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _categorieDetail,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: widget.categorieDetails
                      .map(
                        (detail) => DropdownMenuItem(
                          value: detail,
                          child: Text(detail),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(
                    () => _categorieDetail =
                        value ?? widget.categorieDetails.first,
                  ),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nom : ${widget.joueur.nom}'),
                const SizedBox(height: 8),
                Text('Genre : ${widget.joueur.genre == 'F' ? 'F' : 'M'}'),
                const SizedBox(height: 8),
                Text(
                  'Catégorie : ${widget.joueur.categorieDetail ?? 'Non renseignée'}',
                ),
              ],
            ),
      actions: [
        if (_isEditing) ...[
          TextButton(
            onPressed: () => setState(() => _isEditing = false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () =>
                widget.onSave(_editController.text, _genre, _categorieDetail),
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
        ],
      ],
    );
  }
}
