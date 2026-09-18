import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/categorie.dart';
import '../../models/generations.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';
import 'champs.dart';

/// La fiche d'une catégorie.
///
/// CE QU'UNE CATÉGORIE EST VRAIMENT
///   Ce n'est pas un intitulé d'affichage : c'est la clé des droits. Un
///   coach est habilité sur une catégorie, et un licencié est rattaché à
///   la sienne **par sa génération**, puisqu'il n'a pas d'équipe fixe.
///   Déplacer une génération d'une catégorie à l'autre déplace donc
///   silencieusement des licenciés et les droits qui vont avec — d'où
///   l'avertissement en bas de l'écran.
class FormCategoriePage extends ConsumerStatefulWidget {
  const FormCategoriePage({super.key, this.categorie});

  final Categorie? categorie;

  static Future<bool?> ouvrir(
    BuildContext context, {
    Categorie? categorie,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormCategoriePage(categorie: categorie),
      ),
    );
  }

  @override
  ConsumerState<FormCategoriePage> createState() => _FormCategoriePageState();
}

class _FormCategoriePageState extends ConsumerState<FormCategoriePage> {
  final _libelle = TextEditingController();
  final _ordre = TextEditingController();
  final _choisies = <String>{};

  bool _enregistre = false;
  String? _erreur;

  bool get _creation => widget.categorie == null;

  @override
  void initState() {
    super.initState();
    final c = widget.categorie;
    if (c != null) {
      _libelle.text = c.libelle;
      _ordre.text = '${c.ordre}';
      _choisies.addAll(c.generations);
    }
  }

  @override
  void dispose() {
    _libelle.dispose();
    _ordre.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toutes = ref.watch(categoriesProvider).value ?? const <Categorie>[];

    // L'ordre par défaut d'une nouvelle catégorie : après les autres.
    if (_creation && _ordre.text.isEmpty && toutes.isNotEmpty) {
      _ordre.text = '${toutes.map((c) => c.ordre).reduce((a, b) => a > b ? a : b) + 1}';
    }

    // Les générations déjà prises ailleurs : on les montre, on ne les
    // interdit pas — déplacer une génération est un acte légitime quand
    // le club se réorganise. Mais il faut le voir.
    final ailleurs = <String, String>{};
    for (final c in toutes) {
      if (c.id == widget.categorie?.id) continue;
      for (final g in c.generations) {
        ailleurs[g] = c.libelle;
      }
    }
    final conflits = _choisies.where(ailleurs.containsKey).toList();

    final pret = _libelle.text.trim().isNotEmpty &&
        _choisies.isNotEmpty &&
        (int.tryParse(_ordre.text) ?? 0) > 0;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BandeauRetour(
              titre: _creation ? 'Nouvelle catégorie' : 'Modifier la catégorie',
              sousTitre: _creation
                  ? "Son nom, sa place, les âges qu'elle accueille"
                  : widget.categorie!.libelle,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                children: [
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
                              libelle: 'Nom affiché',
                              controleur: _libelle,
                              majusculesAutomatiques: false,
                              onChange: () => setState(() {}),
                            ),
                            ChampNombre(
                              libelle: "Ordre d'affichage",
                              controleur: _ordre,
                              onChange: () => setState(() {}),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Text(
                                '1 en premier, les plus jeunes en haut. Deux '
                                'catégories ne peuvent pas partager le même '
                                'rang.',
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
                    titre: 'Tranches d’âge accueillies',
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
                                for (final g in generationsOrdonnees)
                                  PuceFiltre(
                                    libelle: ailleurs.containsKey(g)
                                        ? '${libelleGeneration(g)} ·'
                                              ' ${ailleurs[g]}'
                                        : libelleGeneration(g),
                                    choisi: _choisies.contains(g),
                                    onTap: () => setState(() {
                                      if (!_choisies.remove(g)) {
                                        _choisies.add(g);
                                      }
                                    }),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "C'est par cette liste qu'on retrouve la "
                              "catégorie d'un licencié : les catégories "
                              'doivent rester étanches.',
                              style: Typo.texte(
                                taille: 11,
                                couleur: Couleurs.gris,
                                hauteurLigne: 1.45,
                              ),
                            ),
                            if (conflits.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _Alerte(
                                texte:
                                    'En enregistrant, vous retirez '
                                    '${conflits.map(libelleGeneration).join(', ')} '
                                    "à ${conflits.map((g) => ailleurs[g]).toSet().join(', ')} "
                                    '— tous les licenciés de cet âge '
                                    'changeront de catégorie, et leurs '
                                    'coachs changeront avec.',
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  if (_erreur != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _Alerte(texte: _erreur!, erreur: true),
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
      await ref.read(adminRepositoryProvider).enregistrerCategorie(
        id: widget.categorie?.id,
        libelle: _libelle.text,
        ordre: int.parse(_ordre.text),
        generations: _choisies.toList()
          ..sort((a, b) => rangGeneration(a).compareTo(rangGeneration(b))),
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
    if (t.contains('categories_ordre_key')) {
      return "Une autre catégorie occupe déjà ce rang d'affichage. "
          'Choisissez-en un autre, ou déplacez l’autre d’abord.';
    }
    if (t.contains('categories_libelle_key')) {
      return 'Une catégorie porte déjà ce nom.';
    }
    if (t.contains('row-level security')) {
      return 'Seul le super administrateur peut toucher à la structure du '
          "club. Ce refus vient de la base, pas de l'application.";
    }
    return "L'enregistrement a échoué : $t";
  }
}

class _Alerte extends StatelessWidget {
  const _Alerte({required this.texte, this.erreur = false});

  final String texte;
  final bool erreur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: erreur ? const Color(0xFFFBE3E1) : Couleurs.orClair,
        border: Border.all(
          color: erreur ? const Color(0xFFF3CFCB) : const Color(0xFFF3DFAE),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texte,
        style: Typo.texte(
          taille: 12,
          couleur: erreur ? const Color(0xFF8A2B22) : const Color(0xFF7A4F00),
          hauteurLigne: 1.5,
        ),
      ),
    );
  }
}
