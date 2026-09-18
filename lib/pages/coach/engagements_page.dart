import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/categorie.dart';
import '../../models/competition.dart';
import '../../models/equipe.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';

/// Les compétitions d'une équipe, pour une saison.
///
/// POURQUOI C'EST ICI QUE TOUT SE JOUE
///   La base n'impose pas qu'une rencontre corresponde à un engagement :
///   c'est cette liste qui alimente le formulaire de saisie. Une équipe
///   sans engagement ne peut recevoir aucun match — le coach tombe sur
///   « cette équipe n'est engagée dans aucune compétition ». Inversement,
///   un engagement de trop fait apparaître une compétition fantôme dans
///   le menu déroulant du dimanche soir.
///
/// LES TROIS PHASES
///   Chez les jeunes, le championnat se rejoue trois fois dans l'année et
///   l'équipe peut monter ou descendre entre deux. « Départemental 3
///   phase 1 » puis « Départemental 2 phase 2 » sont deux engagements
///   distincts de la même équipe : c'est exactement ce qui permet de
///   raconter une montée en cours de saison. Chez les seniors, un seul
///   championnat d'un bout à l'autre — la phase vaut 0 et ne s'affiche
///   pas.
class EngagementsPage extends ConsumerStatefulWidget {
  const EngagementsPage({super.key, required this.equipe});

  final Equipe equipe;

  static Future<void> ouvrir(
    BuildContext context, {
    required Equipe equipe,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EngagementsPage(equipe: equipe)),
    );
  }

  @override
  ConsumerState<EngagementsPage> createState() => _EngagementsPageState();
}

class _EngagementsPageState extends ConsumerState<EngagementsPage> {
  bool _travaille = false;
  String? _erreur;

  @override
  Widget build(BuildContext context) {
    final saison = ref.watch(saisonAtelierProvider).value;
    final categories = ref.watch(categoriesProvider).value;
    final competitions = ref.watch(competitionsProvider).value;

    if (saison == null || categories == null || competitions == null) {
      return Scaffold(
        backgroundColor: Couleurs.craie,
        body: SafeArea(
          child: Column(
            children: [
              BandeauRetour(titre: widget.equipe.nom),
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
        ),
      );
    }

    final categorie = categories.firstWhere(
      (c) => c.id == widget.equipe.categorieId,
      orElse: () => const Categorie(
        id: '',
        libelle: '',
        ordre: 0,
        generations: [],
      ),
    );
    final seniors = categorie.accueille('senior');

    final engagements = ref
        .watch(
          engagementsDetaillesProvider((
            equipeId: widget.equipe.id,
            saisonId: saison.id,
          )),
        )
        .value;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BandeauRetour(
              titre: widget.equipe.nom,
              sousTitre: 'Compétitions · saison ${saison.libelle}',
            ),
            Expanded(
              child: engagements == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
                      children: [
                        if (_erreur != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: _Alerte(texte: _erreur!),
                          ),

                        Section(
                          titre: 'Engagements de la saison',
                          enfant: CarteBlanche(
                            enfant: engagements.isEmpty
                                ? const Vide(
                                    message:
                                        "Cette équipe n'est engagée nulle "
                                        'part : aucun match ne pourra être '
                                        'saisi pour elle tant que rien '
                                        "n'est ajouté ci-dessous.",
                                  )
                                : Column(
                                    children: [
                                      for (final (i, e)
                                          in engagements.indexed) ...[
                                        if (i > 0) const Divider(height: 1),
                                        _LigneEngagement(
                                          engagement: e,
                                          onRetirer: _travaille
                                              ? null
                                              : () => _retirer(e),
                                        ),
                                      ],
                                    ],
                                  ),
                          ),
                        ),

                        _sectionAjout(
                          competitions: competitions,
                          dejaPris: engagements,
                          seniors: seniors,
                          saisonId: saison.id,
                        ),

                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            seniors
                                ? 'Les seniors ne disputent qu’un '
                                      'championnat sur toute la saison : pas '
                                      'de phase à renseigner.'
                                : 'Le championnat des jeunes se joue en trois '
                                      'phases, avec montées et descentes '
                                      'entre chacune. Ajoutez la phase 1 '
                                      "aujourd'hui ; revenez ajouter la 2 "
                                      'puis la 3 quand le district les '
                                      'communiquera — même si la division '
                                      'change.',
                            style: Typo.texte(
                              taille: 11.5,
                              couleur: Couleurs.gris2,
                              hauteurLigne: 1.5,
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

  // -------------------------------------------------------------------
  //  L'ajout
  // -------------------------------------------------------------------

  Widget _sectionAjout({
    required List<Competition> competitions,
    required List<Engagement> dejaPris,
    required bool seniors,
    required String saisonId,
  }) {
    const rang = {'championnat': 0, 'coupe': 1, 'amical': 2};
    final triees = [...competitions]..sort((a, b) {
      final parType = (rang[a.type] ?? 9).compareTo(rang[b.type] ?? 9);
      return parType != 0 ? parType : a.nom.compareTo(b.nom);
    });

    return Section(
      titre: 'Ajouter une compétition',
      action: 'Créer',
      onAction: _travaille ? null : _creerCompetition,
      enfant: CarteBlanche(
        enfant: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in triees) ...[
                _BlocCompetition(
                  competition: c,
                  seniors: seniors,
                  phasesPrises: {
                    for (final e in dejaPris)
                      if (e.competition.id == c.id) e.phase,
                  },
                  actif: !_travaille,
                  onAjouter: (phase) =>
                      _ajouter(c, phase, saisonId),
                ),
                const SizedBox(height: 12),
              ],
              if (triees.isEmpty)
                Text(
                  'Aucune compétition enregistrée. Touchez « Créer » '
                  'ci-dessus pour en ajouter une.',
                  style: Typo.texte(
                    taille: 12,
                    couleur: Couleurs.gris,
                    hauteurLigne: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _ajouter(
    Competition competition,
    int phase,
    String saisonId,
  ) async {
    setState(() {
      _travaille = true;
      _erreur = null;
    });
    try {
      await ref.read(adminRepositoryProvider).ajouterEngagement(
        equipeId: widget.equipe.id,
        competitionId: competition.id,
        saisonId: saisonId,
        phase: phase,
      );
      if (!mounted) return;
      rafraichirApresStructure(ref);
      setState(() => _travaille = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _travaille = false;
        _erreur = _traduire(e);
      });
    }
  }

  Future<void> _retirer(Engagement e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Couleurs.blanc,
        title: Text(
          'Retirer cet engagement ?',
          style: Typo.texte(taille: 15, graisse: 700),
        ),
        content: Text(
          '« ${e.libelle} » ne sera plus proposé à la saisie pour '
          '${widget.equipe.nom}.\n\n'
          'Les matchs déjà enregistrés dans cette compétition restent : '
          "ils ont eu lieu, qu'on se soit trompé d'inscription ou non.",
          style: Typo.texte(taille: 13, hauteurLigne: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Couleurs.rouge),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() {
      _travaille = true;
      _erreur = null;
    });
    try {
      await ref.read(adminRepositoryProvider).supprimerEngagement(e.id);
      if (!mounted) return;
      rafraichirApresStructure(ref);
      setState(() => _travaille = false);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _travaille = false;
        _erreur = _traduire(err);
      });
    }
  }

  Future<void> _creerCompetition() async {
    final resultat = await showDialog<(String, String)>(
      context: context,
      builder: (_) => const _DialogueCompetition(),
    );
    if (resultat == null || !mounted) return;

    setState(() {
      _travaille = true;
      _erreur = null;
    });
    try {
      await ref.read(adminRepositoryProvider).creerCompetition(
        nom: resultat.$1,
        type: resultat.$2,
      );
      if (!mounted) return;
      rafraichirApresStructure(ref);
      setState(() => _travaille = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _travaille = false;
        _erreur = _traduire(e);
      });
    }
  }

  String _traduire(Object e) {
    final t = e.toString();
    if (t.contains('engagements_equipe_id_competition_id_saison_id_phase')) {
      return 'Cette équipe est déjà inscrite à cette compétition pour '
          'cette phase.';
    }
    if (t.contains('row-level security')) {
      return "Votre compte n'est pas habilité sur cette équipe. Ce refus "
          "vient de la base, pas de l'application.";
    }
    return "L'opération a échoué : $t";
  }
}

/// Une compétition et les phases qu'on peut encore lui ajouter.
class _BlocCompetition extends StatelessWidget {
  const _BlocCompetition({
    required this.competition,
    required this.seniors,
    required this.phasesPrises,
    required this.actif,
    required this.onAjouter,
  });

  final Competition competition;
  final bool seniors;
  final Set<int> phasesPrises;
  final bool actif;
  final ValueChanged<int> onAjouter;

  @override
  Widget build(BuildContext context) {
    // Seul un championnat de jeunes se découpe. Une coupe ou un amical
    // n'a qu'un engagement, phase 0.
    final avecPhases = competition.admetDesPhases && !seniors;
    final phases = avecPhases ? const [1, 2, 3] : const [0];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                competition.nom,
                style: Typo.texte(taille: 13, graisse: 600),
              ),
            ),
            Text(
              competition.libelleType,
              style: Typo.texte(taille: 10.5, couleur: Couleurs.gris2),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [
            for (final p in phases)
              _BoutonPhase(
                libelle: p == 0 ? 'Engager' : 'Phase $p',
                deja: phasesPrises.contains(p),
                onTap: actif && !phasesPrises.contains(p)
                    ? () => onAjouter(p)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _BoutonPhase extends StatelessWidget {
  const _BoutonPhase({
    required this.libelle,
    required this.deja,
    required this.onTap,
  });

  final String libelle;
  final bool deja;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: deja ? Couleurs.bleuClair : Couleurs.blanc,
          border: Border.all(
            color: deja ? Couleurs.bleuClair : Couleurs.ligne,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              deja ? Icons.check : Icons.add,
              size: 13,
              color: deja ? Couleurs.bleu : Couleurs.nuit,
            ),
            const SizedBox(width: 5),
            Text(
              libelle,
              style: Typo.texte(
                taille: 12,
                graisse: 600,
                couleur: deja ? Couleurs.bleu : Couleurs.nuit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LigneEngagement extends StatelessWidget {
  const _LigneEngagement({required this.engagement, required this.onRetirer});

  final Engagement engagement;
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 8, 6, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  engagement.competition.nom,
                  style: Typo.texte(taille: 13, graisse: 600),
                ),
                const SizedBox(height: 3),
                Text(
                  engagement.phase > 0
                      ? '${engagement.competition.libelleType} · phase '
                            '${engagement.phase}'
                      : engagement.competition.libelleType,
                  style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Retirer',
            onPressed: onRetirer,
            icon: const Icon(
              Icons.close,
              size: 17,
              color: Couleurs.gris2,
            ),
          ),
        ],
      ),
    );
  }
}

/// La création d'une compétition, sans quitter l'écran.
class _DialogueCompetition extends StatefulWidget {
  const _DialogueCompetition();

  @override
  State<_DialogueCompetition> createState() => _DialogueCompetitionState();
}

class _DialogueCompetitionState extends State<_DialogueCompetition> {
  final _nom = TextEditingController();
  String _type = 'championnat';

  @override
  void dispose() {
    _nom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pret = _nom.text.trim().isNotEmpty;

    return AlertDialog(
      backgroundColor: Couleurs.blanc,
      title: Text(
        'Nouvelle compétition',
        style: Typo.texte(taille: 15, graisse: 700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nom,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            style: Typo.texte(taille: 14),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Départemental 2, Coupe du district…',
              hintStyle: Typo.texte(taille: 13, couleur: Couleurs.gris2),
              filled: true,
              fillColor: Couleurs.craie,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Segments(
            options: const [
              ('championnat', 'Championnat'),
              ('coupe', 'Coupe'),
              ('amical', 'Amical'),
            ],
            actif: _type,
            onChoix: (v) => setState(() => _type = v),
          ),
          const SizedBox(height: 10),
          Text(
            'Le nom ne porte pas la catégorie : « Départemental 2 » sert '
            'à toutes les équipes qui y jouent, quelle que soit leur '
            'année.',
            style: Typo.texte(
              taille: 11,
              couleur: Couleurs.gris2,
              hauteurLigne: 1.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: pret
              ? () => Navigator.of(context).pop((_nom.text, _type))
              : null,
          child: const Text('Créer'),
        ),
      ],
    );
  }
}

class _Alerte extends StatelessWidget {
  const _Alerte({required this.texte});

  final String texte;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE3E1),
        border: Border.all(color: const Color(0xFFF3CFCB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texte,
        style: Typo.texte(
          taille: 12,
          couleur: const Color(0xFF8A2B22),
          hauteurLigne: 1.5,
        ),
      ),
    );
  }
}
