import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/equipe.dart';
import '../../models/feuille_match.dart';
import '../../models/joueur.dart';
import '../../models/profil.dart';
import '../../models/rencontre.dart';
import '../../models/saison.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../providers/donnees_saison.dart' show joueursProvider;
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
  String? _saisonCreation;
  String? _cleCompetition;
  String? _adversaireId;
  late DateTime _date;
  bool _domicile = true;

  /// Où en est le match, tel que le coach le choisit.
  ///
  /// QUATRE CHOIX À L'ÉCRAN, DEUX COLONNES EN BASE
  ///   « Forfait nous » et « forfait eux » ne sont pas des statuts :
  ///   ce sont des matchs joués, avec leur 3–0 réglementaire et la
  ///   mention de qui ne s'est pas présenté. La traduction se fait au
  ///   moment d'enregistrer — voir `_enregistrer`.
  ///
  ///   Les faire apparaître comme quatre cases côte à côte est ce qui
  ///   compte pour le coach : le dimanche soir, il sait dans quel cas
  ///   il est, il ne veut pas avoir à composer un statut et un score.
  String _etat = 'programmee';

  /// Un match réellement disputé : c'est le seul cas où le coach saisit
  /// un score, une séance de tirs au but et une feuille de match.
  bool get _disputee => _etat == 'jouee';

  final _scorePour = TextEditingController();
  final _scoreContre = TextEditingController();

  /// La feuille de match, en compteurs : un joueur, un nombre.
  ///
  /// Le club ne note pas qui a servi qui — seuls les totaux comptent.
  /// La base garde malgré tout une ligne par but ; `feuille_match.dart`
  /// fait le passage entre les deux formes.
  final List<LigneCompteur> _buteurs = [];
  final List<LigneCompteur> _passeurs = [];

  /// Les buts contre leur camp inscrits par l'adversaire. Ils comptent
  /// au score du FCPB et n'ont ni buteur ni passeur à créditer.
  int _csc = 0;

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
  /// En création, c'est la saison de travail du staff — la saison en
  /// cours pour un coach, la saison consultée pour un administrateur.
  /// Voir `saisonAtelierProvider`.
  String? _saisonId(WidgetRef ref) =>
      widget.rencontre?.saisonId ??
      _saisonCreation ??
      ref.watch(saisonAtelierProvider).value?.id;

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
      // Un forfait revient en base comme un match joué : c'est la
      // colonne `forfait` qui le distingue, et elle qui redonne au
      // formulaire la case que le coach avait cochée.
      if (r.forfaitDeNous) {
        _etat = 'forfait_nous';
      } else if (r.forfaitDEux) {
        _etat = 'forfait_eux';
      } else {
        _etat = r.statut;
      }
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
    (List<But>, List<TirAuBut>) detail,
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
    //
    // On la relit en compteurs. L'appariement buteur ↔ passeur qui
    // existait en base est perdu au passage, et c'est sans conséquence :
    // personne ne le lit.
    final (butsLus, tirsLus) = detail;
    final feuille = decomposerButs(butsLus);
    _buteurs.addAll(feuille.buteurs);
    _passeurs.addAll(feuille.passeurs);
    _csc = feuille.csc;
    final tirs = [...tirsLus]..sort((a, b) => a.ordre.compareTo(b.ordre));
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
    final profil = ref.watch(profilProvider).value;
    final saisons = ref.watch(saisonsProvider).value ?? const [];
    final saisonId = _saisonId(ref);
    final equipesAsync = saisonId == null
        ? const AsyncValue<List<Equipe>>.loading()
        : ref.watch(equipesModifiablesProvider(saisonId));
    final joueursAsync = ref.watch(joueursProvider);

    // La feuille de match n'est relue qu'en modification.
    final detailAsync = _creation
        ? AsyncValue<(List<But>, List<TirAuBut>)>.data(
            (const <But>[], const <TirAuBut>[]),
          )
        : ref.watch(detailRencontreProvider(widget.rencontre!.id));

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
                      joueursAsync.value == null ||
                      detailAsync.value == null ||
                      profil == null ||
                      saisonId == null)
                  ? const Center(child: CircularProgressIndicator())
                  : _formulaire(
                      profil: profil,
                      equipes: equipesAsync.value!,
                      joueursDuClub: joueursAsync.value!.values.toList(),
                      detail: detailAsync.value!,
                      saisonId: saisonId,
                      saisons: saisons,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formulaire({
    required Profil profil,
    required List<Equipe> equipes,
    required List<Joueur> joueursDuClub,
    required (List<But>, List<TirAuBut>) detail,
    required String saisonId,
    required List<Saison> saisons,
  }) {
    // Le choix de la saison — RÉSERVÉ AUX ADMINISTRATEURS.
    //
    //   Un coach n'écrit que sur la saison en cours. Lui montrer un
    //   sélecteur serait lui promettre une correction des archives que
    //   la règle du club lui refuse. Il est rendu avant tout le reste :
    //   placé plus bas, il disparaissait quand l'administrateur n'avait
    //   aucune équipe sur la saison choisie, et le message l'invitait
    //   alors à en changer sans lui en donner le moyen.
    final choixSaison = profil.estAdmin && _creation && saisons.length > 1
        ? Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
            child: CarteBlanche(
              rognage: false,
              enfant: Padding(
                padding: const EdgeInsets.fromLTRB(13, 12, 13, 3),
                child: ChampListe<String>(
                  libelle: 'Saison',
                  valeur: saisonId,
                  options: [for (final s in saisons) (s.id, s.libelle)],
                  onChange: (v) => setState(() {
                    _saisonCreation = v;
                    _equipeId = null;
                    _cleCompetition = null;
                    _buteurs.clear();
                    _passeurs.clear();
                    _csc = 0;
                    _tirs.clear();
                    _avecTirsAuBut = false;
                  }),
                ),
              ),
            ),
          )
        : null;

    if (equipes.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
        children: [
          if (choixSaison != null) choixSaison,
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: CarteBlanche(
              enfant: Vide(
                message: choixSaison != null
                    ? "Aucune de vos équipes n'existait lors de cette "
                          'saison. Choisissez-en une autre ci-dessus, ou '
                          "créez l'engagement manquant."
                    : "Votre compte n'est habilité sur aucune équipe. "
                          "Demandez à l'administrateur du club de vous "
                          'attribuer une catégorie.',
              ),
            ),
          ),
        ],
      );
    }

    // L'équipe retenue doit exister dans la saison choisie : changer de
    // saison peut la faire disparaître.
    if (_equipeId == null || !equipes.any((e) => e.id == _equipeId)) {
      _equipeId = equipes.first.id;
    }
    final options = ref
        .watch(
          engagementsProvider((equipeId: _equipeId!, saisonId: saisonId)),
        )
        .value;
    if (options != null) _completerDepuisExistant(options, detail);

    final joueurs = [...joueursDuClub]
      ..sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));

    // L'équipe choisie sert à ne proposer que les joueurs qui peuvent
    // réellement y évoluer.
    Equipe? equipeChoisie;
    for (final e in equipes) {
      if (e.id == _equipeId) equipeChoisie = e;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      children: [
        if (choixSaison != null) choixSaison,
        Section(
          dense: true,
          titre: 'La rencontre',
          enfant: CarteBlanche(
            rognage: false,
            enfant: Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 5),
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
                      _buteurs.clear();
                      _passeurs.clear();
                      _csc = 0;
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
          dense: true,
          titre: 'Où en est le match ?',
          enfant: CarteBlanche(
            rognage: false,
            enfant: Padding(
              padding: const EdgeInsets.fromLTRB(13, 12, 13, 5),
              child: Column(
                children: [
                  ChampSegments(
                    libelle: 'Statut',
                    valeur: _etat,
                    options: const [
                      ('programmee', 'À venir'),
                      ('jouee', 'Joué'),
                      ('forfait_nous', 'Forfait nous'),
                      ('forfait_eux', 'Forfait eux'),
                    ],
                    onChange: (v) => setState(() => _etat = v),
                  ),
                  if (_disputee) ...[
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
                      padding: const EdgeInsets.only(bottom: 10),
                      // Sur un forfait, le score n'est pas une saisie
                      // mais une conséquence : on l'annonce plutôt que
                      // de laisser deux champs vides que personne ne
                      // saurait remplir.
                      child: Text(
                        switch (_etat) {
                          'forfait_nous' =>
                            'Le FCPB ne s’est pas présenté : la rencontre '
                                'est perdue 0–3, sans feuille de match.',
                          'forfait_eux' =>
                            'L’adversaire ne s’est pas présenté : la '
                                'rencontre est gagnée 3–0, sans feuille de '
                                'match.',
                          _ => 'Le score se renseignera après la rencontre.',
                        },
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

        if (_disputee) _blocButeurs(joueurs, equipeChoisie),

        const SizedBox(height: 16),
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
    final saisis =
        _buteurs.fold<int>(0, (t, l) => t + (l.complete ? l.nombre : 0)) +
        _csc;
    final ecart = score != null && score != saisis;

    return Section(
      dense: true,
      titre: 'Buteurs et passeurs',
      enfant: CarteBlanche(
        rognage: false,
        enfant: Padding(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // UN JOUEUR, UN NOMBRE
              //
              //   Un triplé se saisit une fois, avec un 3 — pas trois
              //   lignes. Le club ne note pas qui a servi qui : les deux
              //   listes sont donc indépendantes, et il n'y a rien à
              //   apparier.
              _Compteurs(
                titre: 'Buteurs',
                libelleJoueur: 'un buteur',
                icone: iconeBut,
                libelleAjout: 'Ajouter un buteur',
                lignes: _buteurs,
                joueurs: joueurs,
                equipe: equipe,
                onChange: () => setState(() {}),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              _Compteurs(
                titre: 'Passeurs',
                libelleJoueur: 'un passeur',
                icone: iconePasse,
                libelleAjout: 'Ajouter un passeur',
                lignes: _passeurs,
                joueurs: joueurs,
                equipe: equipe,
                onChange: () => setState(() {}),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Le csc adverse : il compte au score, sans personne à
              // créditer. Un compteur suffit, il n'a pas de nom.
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Buts contre son camp adverse',
                      style: Typo.texte(taille: 12.5, graisse: 600),
                    ),
                  ),
                  Compteur(
                    valeur: _csc,
                    minimum: 0,
                    onChange: (v) => setState(() => _csc = v),
                  ),
                ],
              ),

              // On signale l'écart, on ne recalcule rien : le coach peut
              // très bien connaître le score sans se souvenir de tous
              // les buteurs.
              if (ecart) ...[
                const SizedBox(height: 10),
                _Avertissement(
                  texte: '$score but${score > 1 ? 's' : ''} au score, '
                      '$saisis attribué${saisis > 1 ? 's' : ''}. '
                      "Ce n'est pas bloquant, mais vérifiez.",
                ),
              ],
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
      final reussis = _tirs.where((t) => t.marque).length;

      // Les quatre cases de l'écran redeviennent ici ce que la base
      // attend : un statut, un éventuel forfait, et un score.
      final statut = _etat == 'programmee' ? 'programmee' : 'jouee';
      final String? forfait = switch (_etat) {
        'forfait_nous' => 'nous',
        'forfait_eux' => 'eux',
        _ => null,
      };
      int? scorePour;
      int? scoreContre;
      if (_disputee) {
        scorePour = int.parse(_scorePour.text);
        scoreContre = int.parse(_scoreContre.text);
      } else if (_etat == 'forfait_nous') {
        scorePour = 0;
        scoreContre = 3;
      } else if (_etat == 'forfait_eux') {
        scorePour = 3;
        scoreContre = 0;
      }

      final avecTirs = _disputee && _avecTirsAuBut;

      // Les compteurs redeviennent une ligne par but, comme la base les
      // attend. Voir `feuille_match.dart`.
      final feuille = composerButs(
        buteurs: _buteurs,
        passeurs: _passeurs,
        csc: _csc,
      );

      await ref.read(adminRepositoryProvider).enregistrerRencontre(
        id: widget.rencontre?.id,
        saisonId: saisonId,
        equipeId: _equipeId!,
        competitionId: option.competitionId,
        adversaireId: _adversaireId!,
        phase: option.phase,
        dateHeure: _date,
        domicile: _domicile,
        statut: statut,
        forfait: forfait,
        scorePour: scorePour,
        scoreContre: scoreContre,
        tabPour: avecTirs ? reussis : null,
        tabContre: avecTirs ? int.parse(_tabContre.text) : null,
        // Un forfait n'a pas de buteur. Passer une liste vide efface
        // aussi ceux d'une saisie précédente, si le coach revient sur
        // un match d'abord enregistré comme disputé.
        buts: _disputee ? feuille.buts : const [],
        tirsAuBut: avecTirs
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

    if (_disputee) {
      final pour = int.tryParse(_scorePour.text);
      final contre = int.tryParse(_scoreContre.text);
      if (pour == null || contre == null) {
        return 'Renseignez les deux scores.';
      }
      // Une ligne sans joueur est une ligne qu'on a ouverte puis
      // oubliée : on la signale plutôt que de l'ignorer en silence.
      if (_buteurs.any((l) => l.joueurId == null)) {
        return 'Une ligne de buteur est vide : choisissez le joueur ou '
            'retirez la ligne.';
      }
      if (_passeurs.any((l) => l.joueurId == null)) {
        return 'Une ligne de passeur est vide : choisissez le joueur ou '
            'retirez la ligne.';
      }
      if (_buteurs.map((l) => l.joueurId).toSet().length != _buteurs.length) {
        return 'Un buteur figure deux fois : additionnez ses buts sur une '
            'seule ligne.';
      }
      if (_passeurs.map((l) => l.joueurId).toSet().length !=
          _passeurs.length) {
        return 'Un passeur figure deux fois : additionnez ses passes sur '
            'une seule ligne.';
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

class _TirBrouillon {
  String? joueurId;
  bool marque = true;
}

/// Une liste « joueur + nombre » : buteurs ou passeurs.
///
/// UN JOUEUR N'APPARAÎT QU'UNE FOIS
///   C'est tout l'intérêt du compteur. Le formulaire refuse d'ailleurs
///   d'enregistrer deux lignes pour le même joueur — mieux vaut le dire
///   que d'additionner en douce et laisser croire à une double saisie.
class _Compteurs extends StatelessWidget {
  const _Compteurs({
    required this.titre,
    required this.libelleJoueur,
    required this.icone,
    required this.libelleAjout,
    required this.lignes,
    required this.joueurs,
    required this.equipe,
    required this.onChange,
  });

  final String titre;

  /// « un buteur », « un passeur » — ce que dit la case vide.
  final String libelleJoueur;

  final IconData icone;
  final String libelleAjout;
  final List<LigneCompteur> lignes;
  final List<Joueur> joueurs;
  final Equipe? equipe;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final total = lignes.fold<int>(
      0,
      (t, l) => t + (l.complete ? l.nombre : 0),
    );
    // Ceux déjà nommés : on ne les repropose pas dans les autres lignes
    // de la même liste.
    final pris = lignes.map((l) => l.joueurId).whereType<String>().toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icone, size: 13, color: Couleurs.gris2),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                titre,
                style: Typo.texte(
                  taille: 11.5,
                  graisse: 700,
                  couleur: Couleurs.gris2,
                ),
              ),
            ),
            if (total > 0)
              Text(
                '$total au total',
                style: Typo.texte(taille: 11, couleur: Couleurs.gris2),
              ),
          ],
        ),
        for (var i = 0; i < lignes.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: ChampJoueur(
                    libelle: libelleJoueur,
                    valeur: lignes[i].joueurId,
                    joueurs: joueurs
                        .where(
                          (j) =>
                              j.id == lignes[i].joueurId ||
                              !pris.contains(j.id),
                        )
                        .toList(),
                    equipe: equipe,
                    compact: true,
                    onChange: (v) {
                      lignes[i].joueurId = v;
                      onChange();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Compteur(
                  valeur: lignes[i].nombre,
                  onChange: (v) {
                    lignes[i].nombre = v;
                    onChange();
                  },
                ),
                IconButton(
                  onPressed: () {
                    lignes.removeAt(i);
                    onChange();
                  },
                  icon: const Icon(Icons.close, size: 17),
                  color: Couleurs.gris2,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              lignes.add(LigneCompteur());
              onChange();
            },
            icon: const Icon(Icons.add, size: 16),
            label: Text(libelleAjout),
            style: TextButton.styleFrom(
              foregroundColor: Couleurs.bleu,
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
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
