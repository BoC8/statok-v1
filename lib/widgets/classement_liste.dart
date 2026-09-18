import 'package:flutter/material.dart';

import '../models/classement.dart';
import '../theme/app_theme.dart';
import 'communs.dart';

/// Un classement de joueurs : rang, nom, valeur.
///
/// LES MÉDAILLES ET LES EX AEQUO
///   Deux joueurs à égalité partagent le rang : le second affiche un
///   tiret mais hérite de la médaille du premier, et le suivant reprend
///   à sa place réelle. Deux premiers à égalité donnent donc or, or,
///   bronze — jamais or, or, argent.
class ClassementListe extends StatelessWidget {
  const ClassementListe({
    super.key,
    required this.lignes,
    required this.type,
    this.onJoueur,
    this.messageVide = 'Aucun but enregistré pour l’instant.',
  });

  final List<LigneClassement> lignes;
  final TypeClassement type;
  final void Function(String joueurId)? onJoueur;
  final String messageVide;

  static const _medailles = {
    1: Color(0xFFE0A008),
    2: Color(0xFF95A1B2),
    3: Color(0xFFBC7B47),
  };

  @override
  Widget build(BuildContext context) {
    if (lignes.isEmpty) {
      return CarteBlanche(enfant: Vide(message: messageVide));
    }

    return CarteBlanche(
      enfant: Column(
        children: [
          for (var i = 0; i < lignes.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                // Un trait plus marqué sépare le podium du reste.
                thickness: lignes[i - 1].surLePodium && !lignes[i].surLePodium
                    ? 2
                    : 1,
              ),
            _Ligne(
              ligne: lignes[i],
              type: type,
              onTap: onJoueur == null
                  ? null
                  : () => onJoueur!(lignes[i].joueur.id),
            ),
          ],
        ],
      ),
    );
  }
}

class _Ligne extends StatelessWidget {
  const _Ligne({required this.ligne, required this.type, this.onTap});

  final LigneClassement ligne;
  final TypeClassement type;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final podium = ligne.surLePodium;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: podium ? 10 : 8),
        child: Row(
          children: [
            SizedBox(
              width: 23,
              child: podium
                  ? Container(
                      width: 23,
                      height: 23,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ClassementListe._medailles[ligne.rang],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ligne.exAequo ? '–' : '${ligne.rang}',
                        style: Typo.texte(
                          taille: 12.5,
                          graisse: 800,
                          couleur: Colors.white,
                          hauteurLigne: 1,
                        ),
                      ),
                    )
                  : Text(
                      ligne.exAequo ? '–' : '${ligne.rang}',
                      textAlign: TextAlign.center,
                      style: Typo.chiffres(
                        taille: 12,
                        couleur: Couleurs.gris2,
                        largeur: 100,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            _Etiquette(texte: ligne.etiquette, grand: podium),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ligne.joueur.nomComplet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.texte(
                      taille: podium ? 14 : 13,
                      graisse: podium ? 700 : 600,
                    ),
                  ),
                  // Le cumul affiche son détail : sans lui, deux joueurs
                  // à 8 points ne se distinguent pas. Les mêmes jetons
                  // que sur la fiche du joueur — on passe de l'un à
                  // l'autre d'un geste, autant que ça se ressemble.
                  if (type == TypeClassement.decisifs)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: RangeeStats(
                        buts: ligne.buts,
                        passes: ligne.passes,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '${ligne.valeur}',
              style: Typo.chiffres(taille: podium ? 18 : 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// L'étiquette de catégorie : « 18M », « 15F », « SM ».
///
/// POURQUOI PAS LES INITIALES
///   Dans un classement où tout le club se mélange, les initiales ne
///   disent rien qu'on ne lise déjà dans le nom juste à côté. La
///   catégorie, elle, répond à la vraie question : ce buteur, il joue
///   dans quelle tranche d'âge ?
///
///   L'étiquette est plus large que haute — trois caractères ne tiennent
///   pas dans un carré sans devenir illisibles.
class _Etiquette extends StatelessWidget {
  const _Etiquette({required this.texte, required this.grand});

  final String texte;
  final bool grand;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: grand ? 34 : 30),
      height: grand ? 26 : 23,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Couleurs.bleuClair,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texte,
        style: Typo.texte(
          taille: grand ? 11.5 : 10.5,
          graisse: 700,
          couleur: Couleurs.bleu,
          hauteurLigne: 1,
        ),
      ),
    );
  }
}
