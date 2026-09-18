import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/fiche_joueur.dart';
import '../models/generations.dart';
import '../providers/donnees_saison.dart';
import '../theme/app_theme.dart';
import '../widgets/communs.dart';
import '../widgets/entete.dart';

/// La fiche d'un licencié, sur la saison consultée.
///
/// ON Y ARRIVE DE PARTOUT
///   Depuis un classement, depuis l'accueil, depuis l'écran d'une
///   équipe, depuis la feuille de match d'une rencontre. Chaque fois que
///   le nom d'un joueur est écrit quelque part, il mène ici.
///
/// TOUJOURS LA SAISON ENTIÈRE
///   On peut arriver depuis le classement des U15 féminines. La fiche
///   n'en tient pas compte : elle montre tout ce que le joueur a fait
///   cette saison. Le périmètre était la fenêtre par laquelle on l'a
///   aperçu, pas le sujet.
///
/// ET ON CHANGE DE SAISON SANS SORTIR DE LA FICHE
///   Le sélecteur du bandeau est celui de toute l'application : il
///   modifie la saison consultée, pas seulement l'affichage de cette
///   page. On reste donc sur le même licencié en passant d'une année à
///   l'autre — c'est ce qu'on veut quand on cherche à voir si un joueur
///   a progressé. Il reste présent même quand la fiche est vide : sans
///   lui, une saison où le joueur n'a rien inscrit serait un cul-de-sac.
class JoueurPage extends ConsumerWidget {
  const JoueurPage({super.key, required this.joueurId});

  final String joueurId;

  static Future<void> ouvrir(BuildContext context, String joueurId) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JoueurPage(joueurId: joueurId)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(donneesSaisonProvider).value;

    if (d == null) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: SafeArea(
          child: Column(
            children: [
              BandeauRetour(titre: 'Licencié', action: SelecteurSaison()),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    final joueur = d.joueurs[joueurId];
    if (joueur == null) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: SafeArea(
          child: Column(
            children: [
              BandeauRetour(titre: 'Licencié', action: SelecteurSaison()),
              Padding(
                padding: EdgeInsets.all(14),
                child: CarteBlanche(
                  enfant: Vide(
                    message: "Ce licencié n'est plus dans l'effectif du "
                        'club. Ses buts restent au crédit des équipes pour '
                        'lesquelles il les a marqués.',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final fiche = FicheJoueur.depuis(
      joueur: joueur,
      categories: d.categories,
      equipes: d.equipes,
      rencontres: d.rencontres,
      buts: d.buts,
    );

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BandeauRetour(
              titre: joueur.nomComplet,
              // Le bandeau porte toute l'identité, puisque la carte
              // sombre n'affiche plus que des chiffres. La saison, elle,
              // a quitté cette ligne : elle est désormais dans le
              // sélecteur, à droite, et l'écrire deux fois à trente
              // pixels d'écart ne servait personne. Reste la mention du
              // départ, qu'il faut savoir en premier devant une fiche
              // qui semble s'être arrêtée.
              sousTitre: joueur.actif
                  ? '${libelleGeneration(joueur.generation)} · '
                        '${joueur.genre == 'F' ? 'Féminine' : 'Masculin'}'
                  : '${libelleGeneration(joueur.generation)} · '
                        '${joueur.genre == 'F' ? 'Féminine' : 'Masculin'} · '
                        'a quitté le club',
              action: const SelecteurSaison(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 30),
                children: [
                  _Compteurs(fiche: fiche),
                  // Sans titre de section : l'en-tête de la première
                  // colonne — « Équipe », « Compétition » — dit déjà de
                  // quoi le tableau parle. Un titre au-dessus le
                  // répéterait à trois pixels d'écart.
                  if (fiche.parEquipe.isNotEmpty)
                    _Detail(colonne: 'Équipe', lignes: fiche.parEquipe),
                  if (fiche.parCompetition.isNotEmpty)
                    _Detail(
                      colonne: 'Compétition',
                      lignes: fiche.parCompetition,
                    ),
                  _sectionRencontres(fiche),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionRencontres(FicheJoueur f) {
    return Section(
      titre: 'Rencontres décisives',
      enfant: f.apparitions.isEmpty
          ? CarteBlanche(
              enfant: Vide(
                message: f.joueur.actif
                    ? "Aucun but ni passe décisive cette saison. "
                          "L'application ne note pas qui a joué, seulement "
                          'qui a été décisif : une saison sans statistique '
                          'ne veut pas dire une saison sans match.'
                    : 'Ce licencié a quitté le club et n’a rien inscrit '
                          'sur cette saison.',
              ),
            )
          : Column(
              children: [
                for (final (i, a) in f.apparitions.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 0 : 9),
                    child: _CarteRencontre(apparition: a),
                  ),
              ],
            ),
    );
  }
}

/// Les trois chiffres de la saison, en haut de la fiche.
///
/// RIEN QUE LES CHIFFRES
///   La carte portait aussi le nom et la catégorie du joueur — tous
///   deux déjà écrits dans le bandeau, à quelques pixels au-dessus. Ce
///   qui reste est ce qu'on vient chercher.
class _Compteurs extends StatelessWidget {
  const _Compteurs({required this.fiche});

  final FicheJoueur fiche;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Couleurs.nuit,
          borderRadius: BorderRadius.circular(AppTheme.rayonCarte),
        ),
        padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
        child: Column(
          children: [
            Row(
              children: [
                _Chiffre(
                  valeur: fiche.matchsDecisifs,
                  libelle: fiche.matchsDecisifs > 1
                      ? 'matchs décisifs'
                      : 'match décisif',
                  accent: true,
                ),
                const _Separateur(),
                _Chiffre(
                  valeur: fiche.buts,
                  libelle: fiche.buts > 1 ? 'buts' : 'but',
                  icone: iconeBut,
                ),
                const _Separateur(),
                _Chiffre(
                  valeur: fiche.passes,
                  libelle: fiche.passes > 1 ? 'passes' : 'passe',
                  icone: iconePasse,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Chiffre extends StatelessWidget {
  const _Chiffre({
    required this.valeur,
    required this.libelle,
    this.accent = false,
    this.icone,
  });

  final int valeur;
  final String libelle;
  final bool accent;
  final IconData? icone;

  @override
  Widget build(BuildContext context) {
    const encre = Color(0xFF9DB0CE);

    return Expanded(
      child: Column(
        children: [
          Text(
            '$valeur',
            style: Typo.chiffres(
              taille: 26,
              couleur: accent ? Couleurs.or : Colors.white,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icone != null) ...[
                Icon(icone, size: 11, color: encre),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  libelle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Typo.texte(taille: 10.5, couleur: encre),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Separateur extends StatelessWidget {
  const _Separateur();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 38, color: const Color(0x21FFFFFF));
}

/// Un tableau de détail : une ligne par équipe ou par compétition, avec
/// les trois mêmes colonnes que la carte du haut.
///
/// LES TROIS COLONNES SONT ALIGNÉES D'UNE LIGNE À L'AUTRE
///   C'est tout l'intérêt d'un tableau sur des barres : on compare en
///   descendant la colonne, sans rien lire. Un en-tête discret rappelle
///   ce qu'on regarde, puisque deux des trois colonnes sont des
///   pictogrammes.
class _Detail extends StatelessWidget {
  const _Detail({required this.colonne, required this.lignes});

  /// L'en-tête de la première colonne : « Équipe », « Compétition ».
  /// Il tient lieu de titre — le tableau n'en a pas d'autre.
  final String colonne;

  final List<LigneRepartition> lignes;

  @override
  Widget build(BuildContext context) {
    return Section(
      enfant: CarteBlanche(
        enfant: Column(
          children: [
            // L'en-tête.
            Container(
              decoration: const BoxDecoration(
                color: Couleurs.craie,
                border: Border(bottom: BorderSide(color: Couleurs.ligne)),
              ),
              padding: const EdgeInsets.fromLTRB(13, 7, 13, 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      colonne,
                      style: Typo.texte(
                        taille: 10,
                        graisse: 700,
                        couleur: Couleurs.gris2,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 58,
                    child: Text(
                      'Matchs\ndécisifs',
                      textAlign: TextAlign.center,
                      style: Typo.texte(
                        taille: 9.5,
                        graisse: 700,
                        couleur: Couleurs.gris2,
                        hauteurLigne: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(
                    width: 34,
                    child: Icon(iconeBut, size: 12, color: Couleurs.gris2),
                  ),
                  const SizedBox(
                    width: 34,
                    child: Icon(iconePasse, size: 12, color: Couleurs.gris2),
                  ),
                ],
              ),
            ),
            for (final (i, l) in lignes.indexed) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.libelle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Typo.texte(taille: 13, graisse: 600),
                      ),
                    ),
                    _Colonne(valeur: l.matchs, largeur: 58, accent: true),
                    _Colonne(valeur: l.buts),
                    _Colonne(valeur: l.passes),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Colonne extends StatelessWidget {
  const _Colonne({
    required this.valeur,
    this.largeur = 34,
    this.accent = false,
  });

  final int valeur;
  final double largeur;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: largeur,
      child: Text(
        '$valeur',
        textAlign: TextAlign.center,
        style: Typo.chiffres(
          taille: 14,
          // Un zéro n'a rien à revendiquer : il s'efface pour que les
          // chiffres qui comptent ressortent de la colonne.
          couleur: valeur == 0
              ? Couleurs.gris2
              : (accent ? Couleurs.bleu : Couleurs.nuit),
        ),
      ),
    );
  }
}

/// Une rencontre décisive.
///
/// TROIS BLOCS, DE GAUCHE À DROITE
///   La date, l'affiche avec sa compétition, le score. Les statistiques
///   du joueur se posent sous l'affiche, en pictogrammes : c'est ce
///   qu'on vient chercher, mais ça n'a de sens qu'appuyé sur le match
///   qui les porte. Le score garde la couleur de l'issue — vert, gris,
///   rouge — donc la carte se lit d'un coup d'œil avant même d'être lue.
class _CarteRencontre extends StatelessWidget {
  const _CarteRencontre({required this.apparition});

  final Apparition apparition;

  @override
  Widget build(BuildContext context) {
    final a = apparition;
    final r = a.rencontre;

    return CarteBlanche(
      enfant: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              padding: const EdgeInsets.only(right: 11),
              decoration: const BoxDecoration(
                border: Border(right: BorderSide(color: Couleurs.ligne)),
              ),
              child: Column(
                children: [
                  Text('${r.date.day}', style: Typo.chiffres(taille: 16)),
                  const SizedBox(height: 1),
                  Text(
                    jourEtMois(r.date).split(' ').last,
                    style: Typo.texte(taille: 9.5, couleur: Couleurs.gris2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.domicile
                        ? '${a.nomEquipe} — ${r.adversaire}'
                        : '${r.adversaire} — ${a.nomEquipe}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.texte(taille: 13, graisse: 700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    r.libelleCompetition,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                  ),
                  const SizedBox(height: 7),
                  RangeeStats(buts: a.buts, passes: a.passes),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ScoreAffiche(rencontre: r),
          ],
        ),
      ),
    );
  }
}
