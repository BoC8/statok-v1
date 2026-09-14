import 'package:flutter/material.dart';

/// La palette et la typographie de STATOK.
///
/// Les valeurs reprennent celles de la maquette, à l'identique. Les noms
/// sont ceux qu'elle employait (`nuit`, `craie`, `or`…) pour qu'on puisse
/// passer de l'une à l'autre sans traduire.
class Couleurs {
  const Couleurs._();

  /// Le bleu profond des bandeaux et des cartes sombres.
  static const nuit = Color(0xFF101E33);
  static const nuit2 = Color(0xFF1B2E4B);

  /// Le bleu d'action : liens, valeurs mises en avant, onglet actif.
  static const bleu = Color(0xFF2F5BEA);
  static const bleuClair = Color(0xFFE9EEFF);

  /// Le fond de l'application, à peine teinté.
  static const craie = Color(0xFFEFF1F5);
  static const blanc = Color(0xFFFFFFFF);

  /// L'or des accents : compte à rebours, badges, pastilles.
  static const or = Color(0xFFF6A609);
  static const orClair = Color(0xFFFEF3DC);

  /// Les résultats.
  static const vert = Color(0xFF15925E);
  static const rouge = Color(0xFFD63B2F);
  static const ardoise = Color(0xFF8894A6);

  /// Les traits de séparation et les textes secondaires.
  static const ligne = Color(0xFFE3E7ED);
  static const gris = Color(0xFF6B7688);
  static const gris2 = Color(0xFF98A2B3);
}

/// Archivo, en fonte variable.
///
/// POURQUOI LA FONTE EST EMBARQUÉE
///   Le paquet `google_fonts` télécharge des graisses figées au premier
///   lancement : il lui faut du réseau, et surtout il ne donne pas accès
///   à l'axe de largeur. Or la maquette étire ses titres à 125 % — c'est
///   ce qui leur donne leur allure de tableau d'affichage.
///
///   Le fichier `assets/fonts/Archivo.ttf` porte les deux axes :
///   `wght` de 100 à 900, `wdth` de 62 à 125. On les pilote nous-mêmes.
///
/// ATTENTION
///   Avec une fonte variable, `fontWeight` seul ne suffit pas toujours à
///   déplacer l'axe `wght` selon les plateformes. On déclare donc
///   toujours les deux : `fontWeight` pour la sémantique et le rendu de
///   secours, `FontVariation` pour la fonte elle-même.
class Typo {
  const Typo._();

  static const famille = 'Archivo';

  /// Le style des titres : large, dense, en capitales d'imprimerie.
  /// C'est lui qui porte l'identité visuelle.
  static TextStyle titre({
    required double taille,
    double graisse = 800,
    Color couleur = Couleurs.nuit,
    double largeur = 125,
    double hauteurLigne = 1.15,
  }) {
    return TextStyle(
      fontFamily: famille,
      fontSize: taille,
      height: hauteurLigne,
      color: couleur,
      fontWeight: _poids(graisse),
      fontVariations: [
        FontVariation('wght', graisse),
        FontVariation('wdth', largeur),
      ],
    );
  }

  /// Le style courant : largeur normale, pour tout le texte de lecture.
  static TextStyle texte({
    required double taille,
    double graisse = 400,
    Color couleur = Couleurs.nuit,
    double hauteurLigne = 1.35,
  }) {
    return TextStyle(
      fontFamily: famille,
      fontSize: taille,
      height: hauteurLigne,
      color: couleur,
      fontWeight: _poids(graisse),
      fontVariations: [FontVariation('wght', graisse)],
    );
  }

  /// Les nombres alignés en colonne : scores, compteurs, classements.
  /// `tnum` fixe la chasse des chiffres pour qu'ils ne dansent pas d'une
  /// ligne à l'autre.
  static TextStyle chiffres({
    required double taille,
    double graisse = 800,
    Color couleur = Couleurs.nuit,
    double largeur = 125,
  }) {
    return titre(
      taille: taille,
      graisse: graisse,
      couleur: couleur,
      largeur: largeur,
      hauteurLigne: 1.0,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  }

  static FontWeight _poids(double v) {
    final index = ((v / 100).round().clamp(1, 9)) - 1;
    return FontWeight.values[index];
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData get theme {
    final base = ThemeData(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: Couleurs.craie,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Couleurs.bleu,
        primary: Couleurs.bleu,
        secondary: Couleurs.or,
        surface: Couleurs.blanc,
      ),
      textTheme: base.textTheme.apply(fontFamily: Typo.famille),
      dividerTheme: const DividerThemeData(
        color: Couleurs.ligne,
        thickness: 1,
        space: 1,
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }

  /// Le rayon des cartes, partout le même.
  static const rayonCarte = 16.0;

  // -------------------------------------------------------------------
  //  ANCIENNE PALETTE — à ne plus utiliser
  //
  //  Ces trois couleurs sont celles d'avant la refonte. Elles ne sont
  //  conservées que pour que les écrans pas encore réécrits continuent
  //  de compiler : sans elles, `flutter analyze` noie les vraies erreurs
  //  sous cent cinquante « undefined_getter ».
  //
  //  Chaque écran refait doit passer à `Couleurs`. Quand l'analyse ne
  //  signalera plus aucun usage déprécié, ce bloc disparaîtra — et avec
  //  lui les derniers restes de l'ancienne application.
  // -------------------------------------------------------------------

  @Deprecated('Utiliser Couleurs.nuit')
  static const Color bleuMarine = Color(0xFF0F2C4C);

  @Deprecated('Utiliser Couleurs.bleu')
  static const Color bleuClair = Color(0xFF4DA6FF);

  @Deprecated('Utiliser Couleurs.or')
  static const Color dore = Color(0xFFD4AF37);

  /// L'encadrement blanc standard : fond blanc, coins arrondis, filet gris.
  static BoxDecoration get carte => BoxDecoration(
    color: Couleurs.blanc,
    borderRadius: BorderRadius.circular(rayonCarte),
    border: Border.all(color: Couleurs.ligne),
  );
}
