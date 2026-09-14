import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/equipe.dart';
import '../../models/joueur.dart';
import '../../models/profil.dart';
import '../../models/rencontre.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../providers/donnees_saison.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';
import 'champs.dart';

/// La saisie d'une rencontre, de la programmation au résultat complet.
///
/// UNE SEULE FICHE POUR TOUTE LA VIE DU MATCH
///   Le coach programme la rencontre en début de semaine, puis revient
///   après le match ajouter le score et les buteurs. C'est la même fiche,
///   on change seulement son statut. L'ancienne application demandait de
///   saisir deux fois — d'abord une programmation, puis un résultat — et
///   c'est comme ça qu'on se retrouvait avec des doublons.
class FormRencontrePage extends ConsumerStatefulWidget {
  const FormRencontrePage({super.key, this.rencontre});

  /// `null` pour une création.
  final Rencontre? rencontre;

  static Future<bool?> ouvrir(BuildContext context, {Rencontre? rencontre}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormRencontrePage(rencontre: rencontre),
      ),
    );
  }

  @override
  ConsumerState<FormRencontrePage> createState() => _FormRencontrePageState();
}

class _FormRencontrePageState extends ConsumerState<FormRencontrePage> {
  String? _equipeId;
  String? _cleCompetition;
  String? _adversaireId;
  late DateTime _date;
  bool _domicile = true;
  String _statut = 'programmee';
  final _scorePour = TextEditingController();
  final _scoreContre = TextEditingController();

  /// Les buts en cours de saisie. `joueurId` nul + `csc` vrai = but
  /// contre son camp adverse.
  final List<_ButBrouillon> _buts = [];
  final List<_TirBrouillon> _tirs = [];
  bool _avecTirsAuBut = false;
  final _tabContre = TextEditingController();

  bool _enregistre = false;
  bool _detailRepris = false;
  String? _erreur;

  bool get _creation => widget.rencontre == null;

  /// La saison dans laquelle on écrit.
  ///
  /// En modification, c'est celle de la rencontre : rouvrir un match de
  /// 2025-2026 ne doit jamais le faire basculer dans la saison en cours.
  /// En création, c'est la saison **active**, pas celle que l'écran
  /// public affiche — un coach qui vient de consulter les archives
  /// saisirait sinon le match de dimanche dans la mauvaise année.
  String? _saisonId(WidgetRef ref) =>
      widget.rencontre?.saisonId ??
      ref.watch(saisonActiveProvider).value?.id;

  @override
  void initState() {
    super.initState();
    final r = widget.rencontre;
    if (r == null) {
      // Par défaut le samedi ou dimanche qui vient, à 15 h.
      final maintenant = DateTime.now();
      _date = DateTime(maintenant.year, maintenant.month, maintenant.day, 15);
    } else {
      _equipeId = r.equipeId;
      _date = r.date;
      _domicile = r.domicile;
      _statut = r.statut;
      _scorePour.text = r.scorePour?.toString() ?? '';
      _scoreContre.text = r.scoreContre?.toString() ?? '';
      _avecTirsAuBut = r.auxTirsAuBut;
      _tabContre.text = r.tabContre?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _scorePour.dispose();
    _scoreContre.dispose();
    _tabContre.dispose();
    super.dispose();
  }

  /// Reprend le contenu d'une rencontre existante.
  ///
  /// IMPOSSIBLE À FAIRE DANS `initState`
  ///   L'engagement, l'adversaire et la feuille de match ne se
  ///   retrouvent qu'une fois les listes chargées — et elles arrivent
  ///   après le premier rendu. On complète donc au premier build utile,
  ///   en se protégeant contre les suivants : sans ce garde-fou, chaque
  ///   reconstruction écraserait la saisie en cours.
  void _completerDepuisExistant(
    List<OptionCompetition> options,
    DonneesSaison donnees,
  ) {
    final r = widget.rencontre;
    if (r == null || _detailRepris) return;
    _detailRepris = true;

    for (final o in options) {
      if (o.nom == r.competition && o.phase == r.phase) {
        _cleCompetition = o.cle;
        break;
      }
    }

    final adversaires = ref.read(adversairesProvider).value ?? const [];
    for (final a in adversaires) {
      if (a.nom == r.adversaire) {
        _adversaireId = a.id;
        break;
      }
    }

    // La feuille de match : sans cette reprise, ouvrir puis enregistrer
    // une rencontre effacerait tous ses buts.
    for (final b in donnees.butsDe(r.id)) {
      _buts.add(
        _ButBrouillon()
          ..joueurId = b.joueurId
          ..passeurId = b.passeurId
          ..csc = b.csc,
      );
    }
    final tirs = [...donnees.tirsDe(r.id)]
      ..sort((a, b) => a.ordre.compareTo(b.ordre));
    for (final t in tirs) {
      _tirs.add(
        _TirBrouillon()
          ..joueurId = t.joueurId
          ..marque = t.marque,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final equipesAsync = ref.watch(equipesModifiablesProvider);
    final donneesAsync = ref.watch(donneesSaisonProvider);
    final saisons = ref.watch(saisonsProvider).value ?? const [];
    final saisonId = _saisonId(ref);

    String libelleSaison = '';
    for (final s in saisons) {
      if (s.id == saisonId) libelleSaison = s.libelle;
    }

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BandeauRetour(
              titre: _creation ? 'Nouvelle rencontre' : 'Modifier la rencontre',
              sousTitre: libelleSaison.isEmpty
                  ? 'Programmation, score et feuille de match'
                  : 'Saison $libelleSaison',
            ),
            Expanded(
              child:
                  (equipesAsync.value == null ||
                      donneesAsync.value == null ||
                      saisonId == null)
                  ? const Center(child: CircularProgressIndicator())
                  : _formulaire(
                      equipesAsync.value!,
                      donneesAsync.value!,
                      saisonId,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulaire(
    List<Equipe> equipes,
    DonneesSaison donnees,
    String saisonId,
  ) {
    if (equipes.isEmpty) {
      return const Vide(
        message: "Votre compte n'est habilité sur aucune équipe. "
            "Demandez à l'administrateur du club de vous attribuer une "
            'catégorie.',
      );
    }

    _equipeId ??= equipes.first.id;
    final options = ref
        .watch(
          engagementsProvider((equipeId: _equipeId!, saisonId: saisonId)),
        )
        .value;
    if (options != null) _completerDepuisExistant(options, donnees);

    final joueurs = donnees.joueurs.values.toList()
      ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

    // L'équipe choisie sert à ne proposer que les joueurs qui peuvent
    // réellement y évoluer.
    Equipe? equipeChoisie;
    for (final e in equipes) {
      if (e.id == _equipeId) equipeChoisie = e;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
      children: [
        Section(
          titre: 'La rencontre',
          enfant: CarteBlanche(
            rognage: false,
            enfant: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                children: [
                  ChampListe<String>(
                    libelle: 'Équipe du FCPB',
                    valeur: _equipeId,
                    options: [
                      for (final e in equipes) (e.id, e.nom),
                    ],
                    onChange: (v) => setState(() {
                      _equipeId = v;
                      // L'engagement dépend de l'équipe : il ne survit
                      // pas au changement.
                      _cleCompetition = null;
                      _buts.clear();
                      _tirs.clear();
                      _avecTirsAuBut = false;
                    }),
                  ),
                  if (options == null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: LinearProgressIndicator(minHeight: 2),
                    )
                  else if (options.isEmpty)
                    _Avertissement(
                      texte: "Cette équipe n'est engagée dans aucune "
                          'compétition cette saison. Ajoutez un engagement '
                          'avant de saisir un match.',
                    )
                  else
                    ChampListe<String>(
                      libelle: 'Compétition',
                      valeur: _cleCompetition,
                      options: [
                        for (final o in options) (o.cle, o.libelle),
                      ],
                      onChange: (v) => setState(() => _cleCompetition = v),
                    ),
                  ChampAdversaire(
                    valeur: _adversaireId,
                    onChange: (id) => setState(() => _adversaireId = id),
                  ),
                  ChampSegments(
                    libelle: 'Lieu',
                    valeur: _domicile ? 'dom' : 'ext',
                    options: const [
                      ('dom', 'À domicile'),
                      ('ext', "À l'extérieur"),
                    ],
                    onChange: (v) => setState(() => _domicile = v == 'dom'),
                  ),
                  ChampDateHeure(
                    valeur: _date,
                    onChange: (d) => setState(() => _date = d),
                  ),
                ],
              ),
            ),
          ),
        ),

        Section(
          titre: 'Où en est le match ?',
          enfant: CarteBlanche(
            rognage: false,
            enfant: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Column(
                children: [
                  ChampSegments(
                    libelle: 'Statut',
                    valeur: _statut,
                    options: const [
                      ('programmee', 'À venir'),
                      ('jouee', 'Joué'),
                      ('reportee', 'Reporté'),
                      ('annulee', 'Annulé'),
                    ],
                    onChange: (v) => setState(() => _statut = v),
                  ),
                  if (_statut == 'jouee') ...[
                    Row(
                      children: [
                        Expanded(
                          child: ChampNombre(
                            libelle: 'Buts FCPB',
                            controleur: _scorePour,
                            onChange: () => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChampNombre(
                            libelle: 'Buts adverses',
                            controleur: _scoreContre,
                            onChange: () => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (_scoresEgaux)
                      _blocTirsAuBut(joueurs, equipeChoisie),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _statut == 'programmee'
                            ? 'Le score et la feuille de match se '
                                  'renseigneront après la rencontre.'
                            : "Un match reporté ou annulé ne porte pas de "
                                  'score.',
                        style: Typo.texte(
                          taille: 11.5,
                          couleur: Couleurs.gris,
                          hauteurLigne: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        if (_statut == 'jouee') _blocButeurs(joueurs, equipeChoisie),

        const SizedBox(height: 22),
        if (_erreur != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _Avertissement(texte: _erreur!, rouge: true),
          ),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Couleurs.bleu,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _enregistre
                ? null
                : () => _enregistrer(options, saisonId),
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
                'Supprimer cette rencontre',
                style: Typo.texte(
                  taille: 13.5,
                  graisse: 700,
                  couleur: Couleurs.rouge,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool get _scoresEgaux {
    final a = int.tryParse(_scorePour.text);
    final b = int.tryParse(_scoreContre.text);
    return a != null && b != null && a == b;
  }

  // -------------------------------------------------------------------
  //  Buteurs et passeurs
  // -------------------------------------------------------------------

  Widget _blocButeurs(List<Joueur> joueurs, Equipe? equipe) {
    final score = int.tryParse(_scorePour.text);
    final ecart = score != null && score != _buts.length;

    return Section(
      titre: 'Buteurs et passeurs',
      enfant: CarteBlanche(
        rognage: false,
        enfant: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_buts.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Une ligne par but marqué par le FCPB. Le détail est '
                    'facultatif : le score fait foi.',
                    style: Typo.texte(
                      taille: 11.5,
                      couleur: Couleurs.gris,
                      hauteurLigne: 1.5,
                    ),
                  ),
                ),
              for (var i = 0; i < _buts.length; i++)
                _LigneBut(
                  numero: i + 1,
                  but: _buts[i],
                  joueurs: joueurs,
                  equipe: equipe,
                  onChange: () => setState(() {}),
                  onSupprimer: () => setState(() => _buts.removeAt(i)),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _buts.add(_ButBrouillon())),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter un but'),
                  style: TextButton.styleFrom(
                    foregroundColor: Couleurs.bleu,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              // On signale l'écart, on ne recalcule rien : le coach peut
              // très bien connaître le score sans se souvenir de tous
              // les buteurs.
              if (ecart)
                _Avertissement(
                  texte: '$score but${score > 1 ? 's' : ''} au score, '
                      '${_buts.length} saisi${_buts.length > 1 ? 's' : ''}. '
                      "Ce n'est pas bloquant, mais vérifiez.",
                ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  //  Tirs au but
  // -------------------------------------------------------------------

  Widget _blocTirsAuBut(List<Joueur> joueurs, Equipe? equipe) {
    if (!_avecTirsAuBut) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: Couleurs.nuit,
            side: const BorderSide(color: Couleurs.ligne),
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
          onPressed: () => setState(() => _avecTirsAuBut = true),
          child: Text(
            "La rencontre s'est terminée aux tirs au but",
            style: Typo.texte(taille: 13, graisse: 600),
          ),
        ),
      );
    }

    final reussis = _tirs.where((t) => t.marque).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Séance de tirs au but',
                  style: Typo.texte(taille: 13, graisse: 700),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _avecTirsAuBut = false;
                  _tirs.clear();
                  _tabContre.clear();
                }),
                icon: const Icon(Icons.close, size: 18),
                color: Couleurs.gris2,
              ),
            ],
          ),
          for (var i = 0; i < _tirs.length; i++)
            _LigneTir(
              numero: i + 1,
              tir: _tirs[i],
              joueurs: joueurs,
              equipe: equipe,
              onChange: () => setState(() {}),
              onSupprimer: () => setState(() => _tirs.removeAt(i)),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _tirs.add(_TirBrouillon())),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Ajouter un tireur'),
              style: TextButton.styleFrom(
                foregroundColor: Couleurs.bleu,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'FCPB : $reussis tir${reussis > 1 ? 's' : ''} réussi'
                    '${reussis > 1 ? 's' : ''}',
                    style: Typo.texte(
                      taille: 12.5,
                      graisse: 600,
                      couleur: Couleurs.gris,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 130,
                child: ChampNombre(
                  libelle: 'Tirs adverses',
                  controleur: _tabContre,
                  onChange: () => setState(() {}),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------
  //  Enregistrement
  // -------------------------------------------------------------------

  Future<void> _enregistrer(
    List<OptionCompetition>? options,
    String saisonId,
  ) async {
    final erreur = _valider(options);
    if (erreur != null) {
      setState(() => _erreur = erreur);
      return;
    }

    setState(() {
      _enregistre = true;
      _erreur = null;
    });

    try {
      final option = options!.firstWhere((o) => o.cle == _cleCompetition);
      final jouee = _statut == 'jouee';
      final reussis = _tirs.where((t) => t.marque).length;

      await ref.read(adminRepositoryProvider).enregistrerRencontre(
        id: widget.rencontre?.id,
        saisonId: saisonId,
        equipeId: _equipeId!,
        competitionId: option.competitionId,
        adversaireId: _adversaireId!,
        phase: option.phase,
        dateHeure: _date,
        domicile: _domicile,
        statut: _statut,
        scorePour: jouee ? int.parse(_scorePour.text) : null,
        scoreContre: jouee ? int.parse(_scoreContre.text) : null,
        tabPour: jouee && _avecTirsAuBut ? reussis : null,
        tabContre: jouee && _avecTirsAuBut
            ? int.parse(_tabContre.text)
            : null,
        buts: jouee
            ? [
                for (final b in _buts)
                  But(
                    rencontreId: '',
                    joueurId: b.csc ? null : b.joueurId,
                    passeurId: b.csc ? null : b.passeurId,
                    csc: b.csc,
                  ),
              ]
            : const [],
        tirsAuBut: jouee && _avecTirsAuBut
            ? [
                for (var i = 0; i < _tirs.length; i++)
                  TirAuBut(
                    rencontreId: '',
                    ordre: i + 1,
                    joueurId: _tirs[i].joueurId!,
                    marque: _tirs[i].marque,
                  ),
              ]
            : const [],
      );

      if (!mounted) return;
      rafraichirApresEcriture(ref);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enregistre = false;
          _erreur = _messageErreur(e);
        });
      }
    }
  }

  /// Traduit les refus de la base en phrases lisibles.
  ///
  /// Un coach qui voit « new row violates row-level security policy »
  /// n'apprend rien. Il doit comprendre qu'il touche à une équipe qui
  /// n'est pas la sienne.
  String _messageErreur(Object e) {
    final texte = e.toString();
    if (texte.contains('row-level security')) {
      return "Votre compte n'est pas habilité à modifier cette équipe.";
    }
    if (texte.contains('rencontres_tab_coherent')) {
      return 'Une séance de tirs au but suppose un score de parité, et un '
          'vainqueur : les deux totaux ne peuvent pas être égaux.';
    }
    if (texte.contains('rencontres_score_coherent')) {
      return 'Un match joué doit porter un score, et un match non joué ne '
          'doit pas en avoir.';
    }
    return "L'enregistrement a échoué : $texte";
  }

  String? _valider(List<OptionCompetition>? options) {
    if (options == null || options.isEmpty) {
      return "Cette équipe n'est engagée dans aucune compétition.";
    }
    if (_cleCompetition == null) return 'Choisissez une compétition.';
    if (_adversaireId == null) return "Choisissez l'adversaire.";

    if (_statut == 'jouee') {
      final pour = int.tryParse(_scorePour.text);
      final contre = int.tryParse(_scoreContre.text);
      if (pour == null || contre == null) {
        return 'Renseignez les deux scores.';
      }
      if (_buts.any((b) => !b.csc && b.joueurId == null)) {
        return 'Un but est sans buteur : choisissez-le ou cochez « contre '
            'son camp ».';
      }
      if (_buts.any((b) => b.passeurId != null && b.passeurId == b.joueurId)) {
        return 'Un joueur ne peut pas se faire la passe à lui-même.';
      }
      if (_avecTirsAuBut) {
        if (pour != contre) {
          return 'Les tirs au but ne se jouent qu\'après un match nul.';
        }
        if (_tirs.any((t) => t.joueurId == null)) {
          return 'Un tireur est sans joueur.';
        }
        final adverses = int.tryParse(_tabContre.text);
        if (adverses == null) return 'Renseignez les tirs au but adverses.';
        if (_tirs.where((t) => t.marque).length == adverses) {
          return 'La séance de tirs au but doit désigner un vainqueur.';
        }
      }
    }
    return null;
  }

  Future<void> _confirmerSuppression() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Couleurs.blanc,
        title: Text(
          'Supprimer la rencontre ?',
          style: Typo.texte(taille: 15, graisse: 700),
        ),
        content: Text(
          'Les buts et les tirs au but enregistrés partiront avec elle. '
          "Cette action ne s'annule pas.",
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
          .supprimerRencontre(widget.rencontre!.id);
      if (!mounted) return;
      rafraichirApresEcriture(ref);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _enregistre = false;
          _erreur = _messageErreur(e);
        });
      }
    }
  }
}

// =====================================================================
//  Brouillons de saisie
// =====================================================================

class _ButBrouillon {
  String? joueurId;
  String? passeurId;
  bool csc = false;
}

class _TirBrouillon {
  String? joueurId;
  bool marque = true;
}

class _LigneBut extends StatelessWidget {
  const _LigneBut({
    required this.numero,
    required this.but,
    required this.joueurs,
    required this.equipe,
    required this.onChange,
    required this.onSupprimer,
  });

  final int numero;
  final _ButBrouillon but;
  final List<Joueur> joueurs;
  final Equipe? equipe;
  final VoidCallback onChange;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Couleurs.ligne, style: BorderStyle.solid),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'But $numero',
                  style: Typo.texte(taille: 12, graisse: 700),
                ),
              ),
              _CaseACocher(
                libelle: 'Contre son camp adverse',
                coche: but.csc,
                onChange: (v) {
                  but.csc = v;
                  if (v) {
                    but.joueurId = null;
                    but.passeurId = null;
                  }
                  onChange();
                },
              ),
              IconButton(
                onPressed: onSupprimer,
                icon: const Icon(Icons.close, size: 17),
                color: Couleurs.gris2,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (!but.csc) ...[
            ChampJoueur(
              libelle: 'Buteur',
              valeur: but.joueurId,
              joueurs: joueurs,
              equipe: equipe,
              onChange: (v) {
                but.joueurId = v;
                onChange();
              },
            ),
            ChampJoueur(
              libelle: 'Passeur',
              valeur: but.passeurId,
              joueurs: joueurs,
              equipe: equipe,
              facultatif: true,
              exclu: but.joueurId,
              onChange: (v) {
                but.passeurId = v;
                onChange();
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _LigneTir extends StatelessWidget {
  const _LigneTir({
    required this.numero,
    required this.tir,
    required this.joueurs,
    required this.equipe,
    required this.onChange,
    required this.onSupprimer,
  });

  final int numero;
  final _TirBrouillon tir;
  final List<Joueur> joueurs;
  final Equipe? equipe;
  final VoidCallback onChange;
  final VoidCallback onSupprimer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$numero',
              style: Typo.chiffres(taille: 12, couleur: Couleurs.gris2),
            ),
          ),
          Expanded(
            child: ChampJoueur(
              libelle: 'Tireur',
              valeur: tir.joueurId,
              joueurs: joueurs,
              equipe: equipe,
              compact: true,
              onChange: (v) {
                tir.joueurId = v;
                onChange();
              },
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              tir.marque = !tir.marque;
              onChange();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: tir.marque ? Couleurs.vert : Couleurs.blanc,
                border: Border.all(
                  color: tir.marque ? Couleurs.vert : Couleurs.rouge,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                tir.marque ? 'Marqué' : 'Manqué',
                style: Typo.texte(
                  taille: 12,
                  graisse: 600,
                  couleur: tir.marque ? Colors.white : Couleurs.rouge,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onSupprimer,
            icon: const Icon(Icons.close, size: 16),
            color: Couleurs.gris2,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _CaseACocher extends StatelessWidget {
  const _CaseACocher({
    required this.libelle,
    required this.coche,
    required this.onChange,
  });

  final String libelle;
  final bool coche;
  final ValueChanged<bool> onChange;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChange(!coche),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            coche ? Icons.check_box : Icons.check_box_outline_blank,
            size: 18,
            color: coche ? Couleurs.bleu : Couleurs.gris2,
          ),
          const SizedBox(width: 5),
          Text(
            libelle,
            style: Typo.texte(
              taille: 11,
              graisse: 600,
              couleur: coche ? Couleurs.bleu : Couleurs.gris,
            ),
          ),
        ],
      ),
    );
  }
}

class _Avertissement extends StatelessWidget {
  const _Avertissement({required this.texte, this.rouge = false});

  final String texte;
  final bool rouge;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: rouge ? const Color(0xFFFBE3E1) : Couleurs.orClair,
        border: Border.all(
          color: rouge ? const Color(0xFFF3CFCB) : const Color(0xFFF3DFAE),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            rouge ? Icons.error_outline : Icons.warning_amber_rounded,
            size: 17,
            color: rouge ? Couleurs.rouge : Couleurs.or,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              texte,
              style: Typo.texte(
                taille: 12,
                couleur: rouge ? const Color(0xFF8A2B22) : const Color(0xFF7A4F00),
                hauteurLigne: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
