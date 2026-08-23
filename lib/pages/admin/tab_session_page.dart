import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/joueur_model.dart';
import '../../theme/app_theme.dart';

/// Saisie d'une séance de tirs au but.
///
/// Extrait de `matchs_tab.dart` le 23/08/2026 : le fichier faisait 2 228 lignes
/// et mélangeait trois écrans sans rapport direct.
///
/// `TabSessionResult` et `TabSessionPage` sont publics parce qu'ils traversent
/// la frontière du fichier — `MatchsTab` les utilise. Le reste demeure privé.

class TabSessionResult {
  final String fcpbScore;
  final String advScore;
  final List<Map<String, dynamic>> tireurs;

  const TabSessionResult({
    required this.fcpbScore,
    required this.advScore,
    required this.tireurs,
  });
}

class _TabTireurEntry {
  final int id;
  final TextEditingController controller;
  String? joueurId;
  bool reussi;

  _TabTireurEntry({
    required this.id,
    required String nom,
    required this.joueurId,
    required this.reussi,
  }) : controller = TextEditingController(text: nom);

  void dispose() {
    controller.dispose();
  }
}

class TabSessionPage extends StatefulWidget {
  final String fcpbScore;
  final String advScore;
  final List<Map<String, dynamic>> tireurs;
  final List<JoueurModel> joueurs;

  const TabSessionPage({
    required this.fcpbScore,
    required this.advScore,
    required this.tireurs,
    required this.joueurs,
  });

  @override
  State<TabSessionPage> createState() => _TabSessionPageState();
}

class _TabSessionPageState extends State<TabSessionPage> {
  late final TextEditingController _fcpbCtrl;
  late final TextEditingController _advCtrl;
  final ScrollController _scrollController = ScrollController();
  late List<_TabTireurEntry> _tireurs;
  int _nextTireurId = 0;

  @override
  void initState() {
    super.initState();
    _fcpbCtrl = TextEditingController(text: widget.fcpbScore);
    _advCtrl = TextEditingController(text: widget.advScore);
    final initialTireurs = widget.tireurs.isEmpty
        ? List.generate(3, (index) => {'nom': '', 'reussi': true})
        : widget.tireurs;
    _tireurs = initialTireurs
        .map(
          (tireur) => _TabTireurEntry(
            id: _nextTireurId++,
            nom: tireur['nom']?.toString() ?? '',
            joueurId: tireur['joueur_id']?.toString(),
            reussi: tireur['reussi'] != false,
          ),
        )
        .toList();
    while (_tireurs.length < 3) {
      _tireurs.add(
        _TabTireurEntry(
          id: _nextTireurId++,
          nom: '',
          joueurId: null,
          reussi: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _fcpbCtrl.dispose();
    _advCtrl.dispose();
    _scrollController.dispose();
    for (final tireur in _tireurs) {
      tireur.dispose();
    }
    super.dispose();
  }

  void _ajouterTireur() {
    setState(() {
      _tireurs.add(
        _TabTireurEntry(
          id: _nextTireurId++,
          nom: '',
          joueurId: null,
          reussi: true,
        ),
      );
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void _supprimerTireur(_TabTireurEntry tireur) {
    setState(() {
      _tireurs.remove(tireur);
    });
    tireur.dispose();
  }

  void _valider() {
    Navigator.pop(
      context,
      TabSessionResult(
        fcpbScore: _fcpbCtrl.text.trim(),
        advScore: _advCtrl.text.trim(),
        tireurs: [
          for (final tireur in _tireurs)
            {
              'joueur_id': tireur.joueurId,
              'nom': tireur.controller.text.trim(),
              'reussi': tireur.reussi,
            },
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Séance de tir au but'),
      content: SizedBox(
        width: 560,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.72,
          ),
          child: SingleChildScrollView(
            controller: _scrollController,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _fcpbCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'TAB FCPB',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '-',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _advCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'TAB adversaire',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _ajouterTireur,
                    icon: const Icon(Icons.add),
                    label: const Text('Ajouter un tireur'),
                  ),
                ),
                const SizedBox(height: 12),
                for (int index = 0; index < _tireurs.length; index++) ...[
                  KeyedSubtree(
                    key: ValueKey(_tireurs[index].id),
                    child: _buildTireurRow(_tireurs[index], index),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _valider,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.bleuMarine,
            foregroundColor: Colors.white,
          ),
          child: const Text('Valider la séance'),
        ),
      ],
    );
  }

  Widget _buildTireurRow(_TabTireurEntry tireur, int index) {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Autocomplete<JoueurModel>(
            optionsBuilder: (value) {
              final query = value.text.trim().toLowerCase();
              if (query.isEmpty) return const Iterable<JoueurModel>.empty();
              return widget.joueurs.where(
                (joueur) => joueur.nom.toLowerCase().contains(query),
              );
            },
            displayStringForOption: (joueur) => joueur.nom,
            onSelected: (joueur) {
              tireur.joueurId = joueur.id;
              tireur.controller.text = joueur.nom;
            },
            fieldViewBuilder: (context, textController, focusNode, onSubmit) {
              if (textController.text != tireur.controller.text) {
                textController.text = tireur.controller.text;
              }
              textController.addListener(() {
                tireur.controller.text = textController.text;
                final selected = widget.joueurs.where(
                  (joueur) =>
                      joueur.nom.toLowerCase() ==
                      textController.text.trim().toLowerCase(),
                );
                tireur.joueurId = selected.isEmpty ? null : selected.first.id;
              });
              return TextField(
                controller: textController,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: 'Tireur ${index + 1}',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: true, label: Text('Mis')),
            ButtonSegment(value: false, label: Text('Raté')),
          ],
          selected: {tireur.reussi},
          onSelectionChanged: (value) {
            setState(() => tireur.reussi = value.first);
          },
        ),
        IconButton(
          tooltip: 'Retirer',
          onPressed: () => _supprimerTireur(tireur),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }
}
