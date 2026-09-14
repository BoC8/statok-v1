import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/saison.dart';
import '../providers/club_providers.dart';
import '../theme/app_theme.dart';

/// Les en-têtes des écrans principaux — ceux qui n'ont pas de bouton
/// retour parce qu'ils sont à la racine d'un onglet.

/// Le bandeau de l'accueil, avec le blason.
class EnteteClub extends StatelessWidget {
  const EnteteClub({super.key, required this.sousTitre, this.selecteur});

  final String sousTitre;
  final Widget? selecteur;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Couleurs.nuit,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          const Blason(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FCPB',
                  style: Typo.titre(taille: 18, couleur: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  sousTitre,
                  style: Typo.texte(
                    taille: 11,
                    couleur: const Color(0xFF9DB0CE),
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
    required this.sousTitre,
    this.selecteur,
    this.dessous,
  });

  final String titre;
  final String sousTitre;
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
                    const SizedBox(height: 4),
                    Text(
                      sousTitre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.texte(
                        taille: 11,
                        couleur: const Color(0xFF9DB0CE),
                      ),
                    ),
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

/// Le blason du club, dessiné plutôt qu'importé : il reste net à toutes
/// les tailles et ne pèse rien dans le paquet.
class Blason extends StatelessWidget {
  const Blason({super.key, this.taille = 34});

  final double taille;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: taille,
      height: taille * 38 / 34,
      child: CustomPaint(painter: _BlasonPainter()),
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
