import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/categorie.dart';
import '../../models/generations.dart';
import '../../models/joueur.dart';
import '../../models/profil.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';
import 'champs.dart';

/// La fiche d'un licencié.
///
/// TROIS CHOSES SEULEMENT
///   Un prénom, un nom, une génération, un genre. Pas d'équipe : un
///   joueur de génération 17 peut évoluer en U18 A un week-end et en
///   U17 le suivant. Les équipes avec lesquelles il a joué se lisent
///   sur ses buts.
class FormJoueurPage extends ConsumerStatefulWidget {
  const FormJoueurPage({super.key, this.joueur});

  /// `null` pour une création.
  final Joueur? joueur;

  static Future<bool?> ouvrir(BuildContext context, {Joueur? joueur}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FormJoueurPage(joueur: joueur)),
    );
  }

  @override
  ConsumerState<FormJoueurPage> createState() => _FormJoueurPageState();
}

class _FormJoueurPageState extends ConsumerState<FormJoueurPage> {
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  String? _generation;
  String _genre = 'M';
  bool _actif = true;

  bool _enregistre = false;
  String? _erreur;

  bool get _creation => widget.joueur == null;

  @override
  void initState() {
    super.initState();
    final j = widget.joueur;
    if (j != null) {
      _prenom.text = j.prenom;
      _nom.text = j.nom;
      _generation = j.generation;
      _genre = j.genre;
      _actif = j.actif;
    }
  }

  @override
  void dispose() {
    _prenom.dispose();
    _nom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider).value;
    final categories = ref.watch(categoriesProvider).value;

    if (profil == null || categories == null) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: SafeArea(
          child: Column(
            children: [
              BandeauRetour(titre: 'Licencié'),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    final generations = profil.generationsAutorisees(categories)
      ..sort((a, b) => rangGeneration(a).compareTo(rangGeneration(b)));
    final genres = profil.genresAutorises();

    _generation ??= generations.isEmpty ? null : generations.first;
    if (!genres.contains(_genre) && genres.isNotEmpty) _genre = genres.first;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BandeauRetour(
              titre: _creation ? 'Nouveau licencié' : 'Modifier la fiche',
              sousTitre: _creation
                  ? 'Prénom, nom et génération'
                  : widget.joueur!.nomComplet,
            ),
            Expanded(
              child: generations.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: CarteBlanche(
                        enfant: Vide(
                          message: "Votre compte n'est habilité sur aucune "
                              'catégorie : vous ne pouvez pas gérer de '
                              'licenciés.',
                        ),
                      ),
                    )
                  : _corps(profil, categories, generations, genres),
            ),
          ],
        ),
      ),
    );
  }

  Widget _corps(
    Profil profil,
    List<Categorie> categories,
    List<String> generations,
    List<String> genres,
  ) {
    final pret =
        _prenom.text.trim().isNotEmpty && _nom.text.trim().isNotEmpty;

    return ListView(
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
                    libelle: 'Prénom',
                    controleur: _prenom,
                    onChange: () => setState(() {}),
                  ),
                  ChampTexte(
                    libelle: 'Nom',
                    controleur: _nom,
                    onChange: () => setState(() {}),
                  ),
                ],
              ),
            ),
          ),
        ),

        Section(
          dense: true,
          titre: 'Catégorie',
          enfant: CarteBlanche(
            rognage: false,
            enfant: Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 3),
              child: Column(
                children: [
                  ChampSegments(
                    libelle: 'Génération',
                    valeur: _generation ?? generations.first,
                    options: [
                      for (final g in generations) (g, libelleGeneration(g)),
                    ],
                    onChange: (v) => setState(() => _generation = v),
                  ),
                  if (genres.length > 1)
                    ChampSegments(
                      libelle: 'Genre',
                      valeur: _genre,
                      options: const [
                        ('M', 'Masculin'),
                        ('F', 'Féminine'),
                      ],
                      onChange: (v) => setState(() => _genre = v),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'Un joueur est incrémenté d’une génération chaque '
                      'été par la montée de catégorie.',
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

        if (!_creation)
          Section(
            dense: true,
            titre: 'Effectif',
            enfant: CarteBlanche(
              enfant: Padding(
                padding: const EdgeInsets.fromLTRB(13, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _actif ? 'Au club' : 'A quitté le club',
                            style: Typo.texte(taille: 13, graisse: 600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _actif
                                ? 'Proposé à la saisie.'
                                : 'Ses buts restent acquis, mais il '
                                      "n'est plus proposé à la saisie.",
                            style: Typo.texte(
                              taille: 11,
                              couleur: Couleurs.gris,
                              hauteurLigne: 1.45,
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

        if (!_creation) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Couleurs.rouge,
                side: const BorderSide(color: Color(0xFFF3CFCB)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              onPressed: _enregistre ? null : _confirmerSuppression,
              child: Text(
                'Supprimer définitivement',
                style: Typo.texte(
                  taille: 13.5,
                  graisse: 700,
                  couleur: Couleurs.rouge,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              "Réservé aux fiches créées par erreur : un joueur qui a "
              "marqué ne s'efface pas, il se désactive.",
              textAlign: TextAlign.center,
              style: Typo.texte(
                taille: 10.5,
                couleur: Couleurs.gris2,
                hauteurLigne: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _enregistrer() async {
    setState(() {
      _enregistre = true;
      _erreur = null;
    });
    try {
      await ref.read(adminRepositoryProvider).enregistrerJoueur(
        id: widget.joueur?.id,
        prenom: _prenom.text,
        nom: _nom.text,
        generation: _generation!,
        genre: _genre,
        actif: _actif,
      );
      if (!mounted) return;
      rafraichirApresEcriture(ref);
      ref.invalidate(tousLesJoueursProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enregistre = false;
          _erreur = _message(e);
        });
      }
    }
  }

  Future<void> _confirmerSuppression() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Couleurs.blanc,
        title: Text(
          'Supprimer la fiche ?',
          style: Typo.texte(taille: 15, graisse: 700),
        ),
        content: Text(
          'La suppression sera refusée si ce licencié a marqué ou tiré au '
          "moins une fois. Dans ce cas, désactivez-le plutôt : c'est ce "
          'qui préserve ses statistiques.',
          style: Typo.texte(taille: 13, hauteurLigne: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Couleurs.rouge),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _enregistre = true);
    try {
      await ref
          .read(adminRepositoryProvider)
          .supprimerJoueur(widget.joueur!.id);
      if (!mounted) return;
      rafraichirApresEcriture(ref);
      ref.invalidate(tousLesJoueursProvider);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enregistre = false;
          _erreur = _message(e);
        });
      }
    }
  }

  /// Traduit les refus de la base.
  ///
  /// Le cas important est la clé étrangère : elle signifie que le joueur
  /// a marqué, et que la bonne action n'est pas la suppression.
  String _message(Object e) {
    final texte = e.toString();
    if (texte.contains('violates foreign key') ||
        texte.contains('still referenced')) {
      return 'Ce licencié a marqué ou tiré au moins une fois : sa fiche ne '
          "peut pas être effacée sans détruire ces buts. Désactivez-le "
          'plutôt avec l’interrupteur « Au club ».';
    }
    if (texte.contains('row-level security')) {
      return "Votre compte n'est pas habilité sur cette catégorie.";
    }
    return "L'enregistrement a échoué : $texte";
  }
}
