import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/classement.dart';
import '../models/equipe.dart';
import '../models/perimetre.dart';
import '../models/rencontre.dart';
import '../providers/perimetre_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/classement_liste.dart';
import '../widgets/communs.dart';
import '../widgets/ligne_match.dart';
import 'joueur_page.dart';

/// L'écran d'un périmètre : **une équipe** ou **toute une catégorie**.
///
/// UN SEUL ÉCRAN POUR LES DEUX
///   « Les U18 A » et « Les U16 – U18 féminines » demandent les mêmes
///   chiffres. Écrire deux pages reviendrait à maintenir deux fois les
///   mêmes calculs — et à corriger deux fois chaque bug. Seule la liste
///   des équipes concernées change, et c'est le périmètre qui la porte.
class PerimetrePage extends ConsumerStatefulWidget {
  const PerimetrePage({super.key, required this.perimetre});

  final Perimetre perimetre;

  /// Ouvre l'écran pour une équipe.
  static Future<void> ouvrirEquipe(BuildContext context, String equipeId) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerimetrePage(perimetre: Perimetre.equipe(equipeId)),
      ),
    );
  }

  /// Ouvre l'écran pour une catégorie déclinée par genre.
  static Future<void> ouvrirCategorie(
    BuildContext context, {
    required String categorieId,
    required String genre,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PerimetrePage(
          perimetre: Perimetre.categorie(id: categorieId, genre: genre),
        ),
      ),
    );
  }

  @override
  ConsumerState<PerimetrePage> createState() => _PerimetrePageState();
}

class _PerimetrePageState extends ConsumerState<PerimetrePage> {
  String _onglet = 'resume';
  String _vueMatchs = 'avenir';
  TypeClassement _typeClassement = TypeClassement.buteurs;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(donneesPerimetreProvider(widget.perimetre));

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: async.when(
          loading: () => const Column(
            children: [
              BandeauRetour(titre: 'Chargement…'),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
          error: (e, _) => Column(
            children: [
              const BandeauRetour(titre: 'Indisponible'),
              Expanded(child: Center(child: Vide(message: '$e'))),
            ],
          ),
          data: (d) => Column(
            children: [
              BandeauRetour(titre: d.titre, sousTitre: d.sousTitre),
              RangeeChips(
                options: const [
                  ('resume', 'Résumé'),
                  ('matchs', 'Matchs'),
                  ('clt', 'Classements'),
                ],
                actif: _onglet,
                onChoix: (v) => setState(() => _onglet = v),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                  children: switch (_onglet) {
                    'matchs' => _ongletMatchs(d),
                    'clt' => _ongletClassements(d),
                    _ => _ongletResume(d),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  //  Résumé
  // -------------------------------------------------------------------

  List<Widget> _ongletResume(DonneesPerimetre d) {
    final maintenant = DateTime.now();
    final enCours = d.enCours(maintenant);
    final prochaine = d.prochaine(maintenant);
    final derniere = d.derniere;
    final decisifs = construireClassement(
      buts: d.buts,
      joueurs: d.joueurs,
      categories: d.categories,
      type: TypeClassement.decisifs,
    );

    return [
      Section(titre: 'Bilan de la saison', enfant: _Bilan(donnees: d)),

      if (enCours.isNotEmpty)
        Section(
          titre: enCours.length > 1 ? 'Matchs en cours' : 'Match en cours',
          enfant: CarteBlanche(
            enfant: Column(
              children: [
                for (final (i, r) in enCours.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  LigneProgrammation(
                    rencontre: r,
                    nomEquipe: _nomEquipe(d, r.equipeId),
                    enCours: true,
                  ),
                ],
              ],
            ),
          ),
        ),

      if (prochaine != null)
        Section(
          titre: 'Prochain match',
          enfant: CarteProchainMatch(
            rencontre: prochaine,
            nomEquipe: _nomEquipe(d, prochaine.equipeId),
            maintenant: maintenant,
          ),
        ),

      Section(
        titre: 'Dernier match',
        action: d.jouees.isEmpty ? null : 'Voir tout',
        onAction: () => setState(() {
          _onglet = 'matchs';
          _vueMatchs = 'resultats';
        }),
        enfant: CarteBlanche(
          enfant: derniere == null
              ? const Vide(message: 'Aucun match joué sur cette saison.')
              : LigneMatch(
                  onJoueur: (id) => JoueurPage.ouvrir(context, id),
                  rencontre: derniere,
                  nomEquipe: _nomEquipe(d, derniere.equipeId),
                  buts: d.butsDe(derniere.id),
                  tirsAuBut: d.tirsDe(derniere.id),
                  joueurs: d.joueurs,
                ),
        ),
      ),

      Section(
        titre: 'Les plus décisifs',
        action: decisifs.isEmpty ? null : 'Voir tout',
        onAction: () => setState(() {
          _onglet = 'clt';
          _typeClassement = TypeClassement.decisifs;
        }),
        enfant: ClassementListe(
          lignes: decisifs.take(3).toList(),
          type: TypeClassement.decisifs,
          onJoueur: (id) => JoueurPage.ouvrir(context, id),
        ),
      ),

      // Depuis une catégorie, on descend vers chacune de ses équipes.
      if (!widget.perimetre.estEquipe)
        Section(
          titre: 'Équipes de la catégorie',
          enfant: Column(
            children: [
              for (final e in d.equipes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _CarteEquipe(equipe: e, donnees: d),
                ),
            ],
          ),
        ),
    ];
  }

  // -------------------------------------------------------------------
  //  Matchs
  // -------------------------------------------------------------------

  List<Widget> _ongletMatchs(DonneesPerimetre d) {
    final liste = _vueMatchs == 'avenir' ? d.aVenir : d.jouees;

    // Regroupement par mois, dans l'ordre de la liste — les rencontres
    // à venir vont vers le futur, les résultats remontent le temps.
    final parMois = <String, List<Rencontre>>{};
    for (final r in liste) {
      parMois.putIfAbsent(moisEtAnnee(r.date), () => []).add(r);
    }

    return [
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Segments(
          options: const [('avenir', 'À venir'), ('resultats', 'Résultats')],
          actif: _vueMatchs,
          onChoix: (v) => setState(() => _vueMatchs = v),
        ),
      ),
      if (liste.isEmpty)
        Section(
          enfant: CarteBlanche(
            enfant: Vide(
              message: _vueMatchs == 'avenir'
                  ? 'Aucune rencontre programmée.'
                  : 'Aucun match joué sur cette saison.',
            ),
          ),
        ),
      for (final entree in parMois.entries)
        Section(
          titre: avecMajuscule(entree.key),
          enfant: CarteBlanche(
            enfant: Column(
              children: [
                for (var i = 0; i < entree.value.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  if (_vueMatchs == 'avenir')
                    LigneProgrammation(
                      rencontre: entree.value[i],
                      nomEquipe: _nomEquipe(d, entree.value[i].equipeId),
                    )
                  else
                    LigneMatch(
                      onJoueur: (id) => JoueurPage.ouvrir(context, id),
                      rencontre: entree.value[i],
                      nomEquipe: _nomEquipe(d, entree.value[i].equipeId),
                      buts: d.butsDe(entree.value[i].id),
                      tirsAuBut: d.tirsDe(entree.value[i].id),
                      joueurs: d.joueurs,
                    ),
                ],
              ],
            ),
          ),
        ),
    ];
  }

  // -------------------------------------------------------------------
  //  Classements
  // -------------------------------------------------------------------

  List<Widget> _ongletClassements(DonneesPerimetre d) {
    final lignes = construireClassement(
      buts: d.buts,
      joueurs: d.joueurs,
      categories: d.categories,
      type: _typeClassement,
    );

    return [
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Segments(
          options: const [
            ('buteurs', 'Buteurs'),
            ('passeurs', 'Passeurs'),
            ('decisifs', 'Décisifs'),
          ],
          actif: _typeClassement.name,
          onChoix: (v) => setState(
            () => _typeClassement = TypeClassement.values.byName(v),
          ),
        ),
      ),
      Section(
        enfant: ClassementListe(
          lignes: lignes,
          type: _typeClassement,
          onJoueur: (id) => JoueurPage.ouvrir(context, id),
          messageVide: switch (_typeClassement) {
            TypeClassement.buteurs => 'Aucun but enregistré sur cette saison.',
            TypeClassement.passeurs =>
              'Aucune passe décisive enregistrée. Pensez à renseigner les '
                  'passeurs : sans eux ce classement reste vide.',
            TypeClassement.decisifs => 'Aucune action décisive enregistrée.',
          },
        ),
      ),
    ];
  }

  String _nomEquipe(DonneesPerimetre d, String equipeId) {
    for (final e in d.equipes) {
      if (e.id == equipeId) return e.nom;
    }
    return 'FCPB';
  }
}

/// Les six chiffres de la saison, plus la ligne de forme.
class _Bilan extends StatelessWidget {
  const _Bilan({required this.donnees});

  final DonneesPerimetre donnees;

  @override
  Widget build(BuildContext context) {
    final b = donnees.bilan;
    final cases = <(String, String)>[
      ('${b.joues}', 'matchs joués'),
      ('${b.pourcentageVictoires}%', 'de victoires'),
      ('${b.cleanSheets}', 'clean sheets'),
      ('${b.victoires}–${b.nuls}–${b.defaites}', 'V · N · D'),
      ('${b.butsPour}', 'buts marqués'),
      ('${b.butsContre}', 'buts encaissés'),
    ];

    return CarteBlanche(
      enfant: Column(
        children: [
          // Le fond gris transparaît entre les cases : c'est lui qui
          // dessine la grille, sans une seule bordure à déclarer.
          Container(
            color: Couleurs.ligne,
            child: Column(
              children: [
                for (var rang = 0; rang < 2; rang++) ...[
                  if (rang > 0) const SizedBox(height: 1),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        for (var col = 0; col < 3; col++) ...[
                          if (col > 0) const SizedBox(width: 1),
                          Expanded(
                            child: _Case(
                              valeur: cases[rang * 3 + col].$1,
                              libelle: cases[rang * 3 + col].$2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Couleurs.blanc,
              border: Border(top: BorderSide(color: Couleurs.ligne)),
            ),
            padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '5 derniers matchs',
                    style: Typo.texte(
                      taille: 12.5,
                      graisse: 600,
                      couleur: Couleurs.gris,
                    ),
                  ),
                ),
                LigneDeForme(forme: b.forme),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Case extends StatelessWidget {
  const _Case({required this.valeur, required this.libelle});

  final String valeur;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Couleurs.blanc,
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(valeur, style: Typo.chiffres(taille: 18)),
          ),
          const SizedBox(height: 5),
          Text(
            libelle,
            textAlign: TextAlign.center,
            style: Typo.texte(
              taille: 10,
              couleur: Couleurs.gris,
              hauteurLigne: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

/// Une équipe de la catégorie, avec son bilan résumé.
class _CarteEquipe extends StatelessWidget {
  const _CarteEquipe({required this.equipe, required this.donnees});

  final Equipe equipe;
  final DonneesPerimetre donnees;

  @override
  Widget build(BuildContext context) {
    final b = donnees.bilanDe(equipe.id);

    return CarteBlanche(
      enfant: InkWell(
        onTap: () => PerimetrePage.ouvrirEquipe(context, equipe.id),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      equipe.nom,
                      style: Typo.texte(taille: 13, graisse: 700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${b.joues} match${b.joues > 1 ? 's' : ''} · '
                      '${b.pourcentageVictoires} % de victoires · '
                      '${b.butsPour}/${b.butsContre} buts',
                      style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                    ),
                  ],
                ),
              ),
              Text(
                'Voir',
                style: Typo.texte(
                  taille: 11.5,
                  graisse: 700,
                  couleur: Couleurs.bleu,
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 14,
                color: Couleurs.bleu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
