import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/equipe.dart';
import '../../models/generations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';
import 'champs.dart';

/// La fiche d'une équipe.
///
/// ON NE SUPPRIME PAS UNE ÉQUIPE, ON LA DISSOUT
///   Ses rencontres la référencent. L'effacer emporterait des matchs
///   joués, des buts, des classements entiers — et la base le refusera
///   de toute façon. Une équipe qui n'est plus alignée passe à
///   « dissoute » : elle disparaît des écrans du jour et garde tout son
///   passé.
class FormEquipePage extends ConsumerStatefulWidget {
  const FormEquipePage({super.key, this.equipe});

  final Equipe? equipe;

  static Future<bool?> ouvrir(BuildContext context, {Equipe? equipe}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FormEquipePage(equipe: equipe)),
    );
  }

  @override
  ConsumerState<FormEquipePage> createState() => _FormEquipePageState();
}

class _FormEquipePageState extends ConsumerState<FormEquipePage> {
  final _nom = TextEditingController();
  final _ordre = TextEditingController();
  String? _categorieId;
  String _genre = 'M';
  String? _generationMax;
  bool _actif = true;

  bool _enregistre = false;
  String? _erreur;

  /// Vrai dès que l'ordre a été saisi à la main : on cesse alors de le
  /// proposer tout seul.
  bool _ordreTouche = false;

  bool get _creation => widget.equipe == null;

  @override
  void initState() {
    super.initState();
    final e = widget.equipe;
    if (e != null) {
      _nom.text = e.nom;
      _ordre.text = '${e.ordre}';
      _categorieId = e.categorieId;
      _genre = e.genre;
      _generationMax = e.generationMax;
      _actif = e.actif;
    } else {
      _ordre.text = '1';
    }
  }

  @override
  void dispose() {
    _nom.dispose();
    _ordre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).value;
    final toutes = ref.watch(toutesLesEquipesProvider).value;

    if (categories == null || toutes == null) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: SafeArea(
          child: Column(
            children: [
              BandeauRetour(titre: 'Équipe'),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    if (categories.isEmpty) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: SafeArea(
          child: Column(
            children: [
              BandeauRetour(titre: 'Équipe'),
              Padding(
                padding: EdgeInsets.all(14),
                child: CarteBlanche(
                  enfant: Vide(
                    message: "Créez d'abord une catégorie : une équipe "
                        'appartient toujours à l’une d’elles.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    _categorieId ??= categories.first.id;
    final categorie = categories.firstWhere(
      (c) => c.id == _categorieId,
      orElse: () => categories.first,
    );

    // Le plafond d'âge se choisit dans les générations de la catégorie :
    // un U17 du groupe U16–U18 accepte jusqu'à la 17, pas au-delà.
    final plafonds = [...categorie.generations]
      ..sort((a, b) => rangGeneration(a).compareTo(rangGeneration(b)));
    if (_generationMax == null || !plafonds.contains(_generationMax)) {
      _generationMax = plafonds.isEmpty ? 'senior' : plafonds.last;
    }

    // L'ordre proposé : à la suite de son groupe.
    if (_creation) {
      final duGroupe = toutes.where(
        (e) => e.categorieId == categorie.id && e.genre == _genre,
      );
      final suivant = duGroupe.isEmpty
          ? 1
          : duGroupe.map((e) => e.ordre).reduce((a, b) => a > b ? a : b) + 1;
      if (_ordre.text != '$suivant' && !_ordreTouche) {
        _ordre.text = '$suivant';
      }
    }

    final pret =
        _nom.text.trim().isNotEmpty && (int.tryParse(_ordre.text) ?? 0) > 0;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BandeauRetour(
              titre: _creation ? 'Nouvelle équipe' : "Modifier l'équipe",
              sousTitre: _creation
                  ? 'Catégorie, genre, nom, plafond d’âge'
                  : widget.equipe!.nom,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                children: [
                  Section(
                    dense: true,
                    titre: 'Rattachement',
                    enfant: CarteBlanche(
                      rognage: false,
                      enfant: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 12, 13, 3),
                        child: Column(
                          children: [
                            ChampListe<String>(
                              libelle: 'Catégorie',
                              valeur: _categorieId,
                              options: [
                                for (final c in categories) (c.id, c.libelle),
                              ],
                              onChange: (v) => setState(() {
                                _categorieId = v;
                                _generationMax = null;
                              }),
                            ),
                            ChampSegments(
                              libelle: 'Genre',
                              valeur: _genre,
                              options: const [
                                ('M', 'Masculine'),
                                ('F', 'Féminine'),
                              ],
                              onChange: (v) => setState(() => _genre = v),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Section(
                    dense: true,
                    titre: 'Identité',
                    enfant: CarteBlanche(
                      rognage: false,
                      enfant: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 12, 13, 3),
                        child: Column(
                          children: [
                            ChampTexte(
                              libelle: 'Nom',
                              controleur: _nom,
                              majusculesAutomatiques: false,
                              onChange: () => setState(() {}),
                            ),
                            ChampNombre(
                              libelle: 'Ordre dans son groupe',
                              controleur: _ordre,
                              onChange: () => setState(() {
                                _ordreTouche = true;
                              }),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                "Une position d'affichage, pas un niveau : "
                                'chez les U16–U18, U18 A passe avant U17.',
                                style: Typo.texte(
                                  taille: 11,
                                  couleur: Couleurs.gris,
                                  hauteurLigne: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Section(
                    dense: true,
                    titre: 'Plafond d’âge',
                    enfant: CarteBlanche(
                      enfant: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 7,
                              runSpacing: 7,
                              children: [
                                for (final g in plafonds)
                                  PuceFiltre(
                                    libelle: libelleGeneration(g),
                                    choisi: _generationMax == g,
                                    onTap: () =>
                                        setState(() => _generationMax = g),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'La génération la plus âgée admise ici. Un 18 '
                              "n'a rien à faire chez les U17 ; le "
                              'surclassement reste permis dans l’autre '
                              'sens.',
                              style: Typo.texte(
                                taille: 11,
                                couleur: Couleurs.gris,
                                hauteurLigne: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  if (!_creation)
                    Section(
                      dense: true,
                      titre: 'Existence',
                      enfant: CarteBlanche(
                        enfant: Padding(
                          padding: const EdgeInsets.fromLTRB(13, 8, 4, 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _actif ? 'Alignée' : 'Dissoute',
                                      style: Typo.texte(
                                        taille: 13,
                                        graisse: 600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _actif
                                          ? 'Peut recevoir des rencontres.'
                                          : 'Disparaît des écrans du jour ; '
                                                'son passé reste intact.',
                                      style: Typo.texte(
                                        taille: 11.5,
                                        couleur: Couleurs.gris,
                                        hauteurLigne: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _actif,
                                activeThumbColor: Couleurs.bleu,
                                onChanged: (v) => setState(() => _actif = v),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  if (_erreur != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBE3E1),
                          border: Border.all(color: const Color(0xFFF3CFCB)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _erreur!,
                          style: Typo.texte(
                            taille: 12,
                            couleur: const Color(0xFF8A2B22),
                            hauteurLigne: 1.5,
                          ),
                        ),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Couleurs.bleu,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: pret && !_enregistre ? _enregistrer : null,
                      child: Text(
                        _enregistre ? 'Enregistrement…' : 'Enregistrer',
                        style: Typo.texte(
                          taille: 14,
                          graisse: 700,
                          couleur: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enregistrer() async {
    setState(() {
      _enregistre = true;
      _erreur = null;
    });
    try {
      await ref.read(adminRepositoryProvider).enregistrerEquipe(
        id: widget.equipe?.id,
        categorieId: _categorieId!,
        genre: _genre,
        nom: _nom.text,
        ordre: int.parse(_ordre.text),
        generationMax: _generationMax!,
        actif: _actif,
      );
      if (!mounted) return;
      rafraichirApresStructure(ref);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enregistre = false;
        _erreur = _traduire(e);
      });
    }
  }

  String _traduire(Object e) {
    final t = e.toString();
    if (t.contains('equipes_categorie_id_genre_ordre_key')) {
      return 'Une autre équipe de ce groupe occupe déjà cette position. '
          'Changez le numéro, ou déplacez l’autre équipe d’abord.';
    }
    if (t.contains('equipes_categorie_id_genre_nom_key')) {
      return 'Ce nom est déjà pris dans ce groupe.';
    }
    if (t.contains('row-level security')) {
      return 'Seul le super administrateur peut toucher à la structure du '
          "club. Ce refus vient de la base, pas de l'application.";
    }
    return "L'enregistrement a échoué : $t";
  }
}
