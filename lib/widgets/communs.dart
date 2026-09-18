import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/bilan_equipe.dart';
import '../models/rencontre.dart';
import '../theme/app_theme.dart';

/// Les briques réutilisées d'un écran à l'autre.
///
/// Elles vivent ici plutôt que recopiées dans chaque page : c'est
/// exactement la duplication qu'on avait passé une séance entière à
/// éliminer dans l'ancienne version.

// =====================================================================
//  Dates
// =====================================================================

final _jourMois = DateFormat('d MMM', 'fr_FR');
final _moisAnnee = DateFormat('MMMM yyyy', 'fr_FR');
final _dateLongue = DateFormat('EEEE d MMMM', 'fr_FR');
final _heure = DateFormat('HH:mm', 'fr_FR');

String jourEtMois(DateTime d) => _jourMois.format(d);
String moisEtAnnee(DateTime d) => _moisAnnee.format(d);
String dateLongue(DateTime d) => _dateLongue.format(d);
String heureDe(DateTime d) => _heure.format(d).replaceFirst(':', 'h');

String avecMajuscule(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// =====================================================================
//  Résultats
// =====================================================================

const _fondIssue = {
  Issue.victoire: Couleurs.vert,
  Issue.nul: Couleurs.ardoise,
  Issue.defaite: Couleurs.rouge,
};

/// La pastille V / N / D.
class PastilleIssue extends StatelessWidget {
  const PastilleIssue({super.key, required this.issue, this.taille = 19});

  final Issue issue;
  final double taille;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: taille,
      height: taille,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _fondIssue[issue],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        issue.lettre,
        style: Typo.texte(
          taille: taille * 0.58,
          graisse: 800,
          couleur: Colors.white,
          hauteurLigne: 1,
        ),
      ),
    );
  }
}

/// Les cinq derniers résultats, du plus ancien au plus récent.
class LigneDeForme extends StatelessWidget {
  const LigneDeForme({super.key, required this.forme});

  final List<Issue> forme;

  @override
  Widget build(BuildContext context) {
    if (forme.isEmpty) {
      return Text(
        'Pas encore de match',
        style: Typo.texte(taille: 11, couleur: Couleurs.gris2),
      );
    }
    return Wrap(
      spacing: 4,
      children: [for (final i in forme) PastilleIssue(issue: i)],
    );
  }
}

/// Le score, dans l'ordre du terrain : à domicile le FCPB est à gauche,
/// à l'extérieur il est à droite.
class ScoreAffiche extends StatelessWidget {
  const ScoreAffiche({super.key, required this.rencontre});

  final Rencontre rencontre;

  @override
  Widget build(BuildContext context) {
    final issue = rencontre.issue;
    final nous = _Case(
      valeur: rencontre.scorePour ?? 0,
      fond: issue == null ? Couleurs.ardoise : _fondIssue[issue]!,
    );
    final eux = _Case(
      valeur: rencontre.scoreContre ?? 0,
      fond: Couleurs.ardoise,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: rencontre.domicile ? [nous, eux] : [eux, nous],
    );
  }
}

class _Case extends StatelessWidget {
  const _Case({required this.valeur, required this.fond});

  final int valeur;
  final Color fond;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      constraints: const BoxConstraints(minWidth: 22),
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$valeur',
        style: Typo.chiffres(taille: 12, couleur: Colors.white),
      ),
    );
  }
}

/// Les deux pictogrammes de l'application.
///
/// Un ballon veut dire « but » partout, une cible « passe décisive »
/// partout — feuille de match, classement, fiche de joueur. Les réunir
/// ici évite qu'ils divergent le jour où l'un des deux change.
const iconeBut = Icons.sports_soccer;
const iconePasse = Icons.ads_click;

/// Un pictogramme et son compte : « ⚽ 2 ».
///
/// POURQUOI UN JETON PLUTÔT QUE DES MOTS
///   « 2 buts · 1 passe » se lit ; « ⚽ 2  ◎ 1 » se reconnaît. Dans une
///   liste où la même paire revient à chaque ligne, le mot n'apporte
///   rien qu'on ne sache déjà, et il pousse le nom du joueur à
///   l'étroit.
class JetonStat extends StatelessWidget {
  const JetonStat({
    super.key,
    required this.icone,
    required this.nombre,
    required this.fond,
    required this.encre,
  });

  /// Le jeton des buts : or pâle sur brun.
  factory JetonStat.buts(int nombre) => JetonStat(
    icone: iconeBut,
    nombre: nombre,
    fond: Couleurs.orClair,
    encre: const Color(0xFF7A4F00),
  );

  /// Celui des passes décisives : bleu pâle sur bleu.
  factory JetonStat.passes(int nombre) => JetonStat(
    icone: iconePasse,
    nombre: nombre,
    fond: Couleurs.bleuClair,
    encre: Couleurs.bleu,
  );

  final IconData icone;
  final int nombre;
  final Color fond;
  final Color encre;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 8, 3),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 12, color: encre),
          const SizedBox(width: 5),
          Text(
            '$nombre',
            style: Typo.chiffres(taille: 12, couleur: encre, largeur: 100),
          ),
        ],
      ),
    );
  }
}

/// Les jetons d'un joueur sur une ligne : buts puis passes, et rien
/// quand il n'y a rien.
class RangeeStats extends StatelessWidget {
  const RangeeStats({super.key, required this.buts, required this.passes});

  final int buts;
  final int passes;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (buts > 0) JetonStat.buts(buts),
        if (buts > 0 && passes > 0) const SizedBox(width: 6),
        if (passes > 0) JetonStat.passes(passes),
      ],
    );
  }
}

// =====================================================================
//  Mise en page
// =====================================================================

/// Un titre de section, avec son action facultative à droite.
class Section extends StatelessWidget {
  const Section({
    super.key,
    this.titre,
    this.action,
    this.onAction,
    this.dense = false,
    required this.enfant,
  });

  final String? titre;
  final String? action;
  final VoidCallback? onAction;
  final Widget enfant;

  /// Resserre l'espacement, pour les écrans de saisie.
  ///
  /// Les pages de consultation respirent : on les parcourt du pouce, et
  /// l'air aide à séparer ce qui n'a pas de rapport. Un formulaire, lui,
  /// se remplit d'un bout à l'autre — tout y a rapport, et chaque
  /// intervalle est un défilement de plus pour le coach qui saisit son
  /// match le dimanche soir.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: dense ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (titre != null)
            Padding(
              padding: EdgeInsets.fromLTRB(2, 0, 2, dense ? 6 : 9),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titre!,
                      style: Typo.texte(taille: 13.5, graisse: 700),
                    ),
                  ),
                  if (action != null)
                    GestureDetector(
                      onTap: onAction,
                      child: Text(
                        action!,
                        style: Typo.texte(
                          taille: 12,
                          graisse: 600,
                          couleur: Couleurs.bleu,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          enfant,
        ],
      ),
    );
  }
}

/// Le cadre blanc standard.
class CarteBlanche extends StatelessWidget {
  const CarteBlanche({super.key, required this.enfant, this.rognage = true});

  final Widget enfant;
  final bool rognage;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.carte,
      clipBehavior: rognage ? Clip.antiAlias : Clip.none,
      child: enfant,
    );
  }
}

/// Le message affiché quand il n'y a rien à montrer.
class Vide extends StatelessWidget {
  const Vide({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Typo.texte(taille: 12.5, couleur: Couleurs.gris),
      ),
    );
  }
}

/// La rangée d'étiquettes qui défile — le filtre de toute l'application.
class RangeeChips extends StatelessWidget {
  const RangeeChips({
    super.key,
    required this.options,
    required this.actif,
    required this.onChoix,
  });

  /// Couples (valeur, libellé), dans l'ordre d'affichage.
  final List<(String, String)> options;
  final String actif;
  final ValueChanged<String> onChoix;

  @override
  Widget build(BuildContext context) {
    return Container(
      // Un Container n'accepte pas `color` et `decoration` en même temps :
      // la couleur passe dans la décoration.
      decoration: const BoxDecoration(
        color: Couleurs.blanc,
        border: Border(bottom: BorderSide(color: Couleurs.ligne)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            for (final (valeur, libelle) in options)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: PuceFiltre(
                  libelle: libelle,
                  choisi: valeur == actif,
                  onTap: () => onChoix(valeur),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Une puce de filtre : arrondie, sombre quand elle est choisie.
/// Publique parce que les trois écrans de filtre s'en servent.
class PuceFiltre extends StatelessWidget {
  const PuceFiltre({
    super.key,
    required this.libelle,
    required this.choisi,
    required this.onTap,
  });

  final String libelle;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: choisi ? Couleurs.nuit : Couleurs.blanc,
          border: Border.all(color: choisi ? Couleurs.nuit : Couleurs.ligne),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          libelle,
          style: Typo.texte(
            taille: 12,
            graisse: 600,
            couleur: choisi ? Colors.white : Couleurs.nuit,
          ),
        ),
      ),
    );
  }
}

/// Le sélecteur à deux ou trois positions, posé sur fond craie.
class Segments extends StatelessWidget {
  const Segments({
    super.key,
    required this.options,
    required this.actif,
    required this.onChoix,
  });

  final List<(String, String)> options;
  final String actif;
  final ValueChanged<String> onChoix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Couleurs.craie,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final (valeur, libelle) in options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChoix(valeur),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  alignment: Alignment.center,
                  decoration: valeur == actif
                      ? BoxDecoration(
                          color: Couleurs.blanc,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1F101E33),
                              blurRadius: 3,
                              offset: Offset(0, 1),
                            ),
                          ],
                        )
                      : null,
                  child: Text(
                    libelle,
                    style: Typo.texte(
                      taille: 12,
                      graisse: 600,
                      couleur: valeur == actif
                          ? Couleurs.nuit
                          : Couleurs.gris,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Le bandeau sombre avec bouton retour, pour les écrans de détail.
class BandeauRetour extends StatelessWidget {
  const BandeauRetour({
    super.key,
    required this.titre,
    this.sousTitre,
    this.action,
  });

  final String titre;
  final String? sousTitre;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Couleurs.nuit,
      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            tooltip: 'Retour',
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              minimumSize: const Size(34, 34),
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titre,
                  style: Typo.titre(taille: 15, couleur: Colors.white),
                ),
                if (sousTitre != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sousTitre!,
                    style: Typo.texte(
                      taille: 11,
                      couleur: const Color(0xFF9DB0CE),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
