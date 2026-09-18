import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saison.dart';
import '../providers/club_providers.dart';
import '../theme/app_theme.dart';

/// Les en-têtes des écrans principaux — ceux qui n'ont pas de bouton
/// retour parce qu'ils sont à la racine d'un onglet.

/// Le bandeau de l'accueil : le blason et le nom du club.
///
/// LE SOUS-TITRE NE BOUGE PLUS
///   Il portait la saison consultée, qui se lit déjà dans le sélecteur
///   juste à droite — la même information deux fois, à trente pixels
///   d'écart. C'est maintenant le nom du club en toutes lettres : une
///   carte de visite, pas un état.
///
///   Le sigle et le nom complet se répondent : « FCPB » se lit d'un
///   coup d'œil pour qui connaît, le nom déplié est là pour les autres.
class EnteteClub extends StatelessWidget {
  const EnteteClub({super.key, this.selecteur});

  final Widget? selecteur;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Couleurs.nuit,
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      child: Row(
        children: [
          const Blason(taille: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FCPB',
                  style: Typo.titre(taille: 21, couleur: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(
                  'Football Club de la Pierre Bleue',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.texte(
                    taille: 11.5,
                    couleur: const Color(0xFF9DB0CE),
                    hauteurLigne: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (selecteur != null) selecteur!,
        ],
      ),
    );
  }
}

/// Le bandeau d'un écran de liste : titre, sous-titre, et ce qu'on veut
/// en dessous — un sélecteur de saison, une rangée de segments.
class EnteteSimple extends StatelessWidget {
  const EnteteSimple({
    super.key,
    required this.titre,
    this.sousTitre,
    this.selecteur,
    this.dessous,
  });

  final String titre;

  /// Facultatif : `null` laisse le titre seul.
  ///
  /// Plusieurs écrans n'avaient rien d'utile à y mettre — la saison s'y
  /// répétait alors qu'elle est déjà dans le sélecteur d'à côté. Une
  /// ligne qui ne dit rien coûte de la hauteur et se lit quand même.
  final String? sousTitre;

  final Widget? selecteur;
  final Widget? dessous;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Couleurs.nuit,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titre,
                      style: Typo.titre(taille: 18, couleur: Colors.white),
                    ),
                    if (sousTitre != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        sousTitre!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Typo.texte(
                          taille: 11,
                          couleur: const Color(0xFF9DB0CE),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (selecteur != null) selecteur!,
            ],
          ),
          if (dessous != null) ...[const SizedBox(height: 12), dessous!],
        ],
      ),
    );
  }
}

/// Le choix de la saison. Ne s'affiche que s'il y a plus d'une saison.
class SelecteurSaison extends ConsumerWidget {
  const SelecteurSaison({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saisons = ref.watch(saisonsProvider).value;
    final courante = ref.watch(saisonCouranteProvider).value;
    if (saisons == null || courante == null || saisons.length < 2) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: courante.id,
          isDense: true,
          dropdownColor: Couleurs.nuit2,
          icon: const Icon(Icons.expand_more, size: 18, color: Colors.white),
          style: Typo.texte(taille: 12.5, graisse: 700, couleur: Colors.white),
          items: [
            for (final Saison s in saisons)
              DropdownMenuItem(value: s.id, child: Text(s.libelle)),
          ],
          onChanged: (id) =>
              ref.read(saisonChoisieProvider.notifier).state = id,
        ),
      ),
    );
  }
}

/// Le blason du club.
///
/// LE VRAI LOGO, AVEC UN FILET DE SECOURS
///   C'était un dessin vectoriel — approximatif mais increvable. C'est
///   maintenant le logo officiel, `assets/images/logo-fcpb-sansfond.png`.
///
///   Le dessin est conservé comme `errorBuilder` : si le fichier
///   disparaît du paquet — un renommage, une ligne oubliée dans
///   `pubspec.yaml` —, le bandeau montre l'ancien écusson au lieu du
///   carré gris de Flutter. Une dégradation qu'on peut ne pas remarquer
///   tout de suite vaut mieux qu'un écran cassé en production.
///
///   `filterQuality` compte ici : l'image fait 256 px et s'affiche à 34.
///   Sans elle, la réduction se fait au plus vite et le blason
///   scintille.
class Blason extends StatelessWidget {
  const Blason({super.key, this.taille = 34});

  final double taille;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille,
      child: Image.asset(
        'assets/images/logo-fcpb-sansfond.png',
        width: taille,
        height: taille,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, erreur, pile) => SizedBox(
          width: taille,
          height: taille * 38 / 34,
          child: CustomPaint(painter: _BlasonPainter()),
        ),
      ),
    );
  }
}

class _BlasonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final e = size.width / 34;

    Path ecusson(double x, double y, double l, double h, double creux) {
      return Path()
        ..moveTo(x * e, y * e)
        ..lineTo((x + l) * e, y * e)
        ..lineTo((x + l) * e, (y + h) * e)
        ..quadraticBezierTo(
          (x + l) * e,
          (y + h + creux) * e,
          (x + l / 2) * e,
          (y + h + creux + 3) * e,
        )
        ..quadraticBezierTo(
          x * e,
          (y + h + creux) * e,
          x * e,
          (y + h) * e,
        )
        ..close();
    }

    canvas.drawPath(
      ecusson(2, 3, 30, 20, 5),
      Paint()..color = Colors.white,
    );
    canvas.drawPath(
      ecusson(5, 6, 24, 17, 4),
      Paint()..color = Couleurs.bleu,
    );

    // Le chevron central
    final chevron = Path()
      ..moveTo(17 * e, 10 * e)
      ..lineTo(23 * e, 14.4 * e)
      ..lineTo(20.7 * e, 21.4 * e)
      ..lineTo(13.3 * e, 21.4 * e)
      ..lineTo(11 * e, 14.4 * e)
      ..close();
    canvas.drawPath(chevron, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// L'écran d'erreur, avec son bouton de reprise.
class ErreurChargement extends StatelessWidget {
  const ErreurChargement({
    super.key,
    required this.message,
    required this.reessayer,
  });

  final String message;
  final VoidCallback reessayer;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, size: 34, color: Couleurs.gris2),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Typo.texte(taille: 12.5, couleur: Couleurs.gris),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: reessayer,
              style: FilledButton.styleFrom(backgroundColor: Couleurs.bleu),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}
