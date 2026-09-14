import 'package:flutter/material.dart';

import '../models/joueur.dart';
import '../models/rencontre.dart';
import '../theme/app_theme.dart';
import 'communs.dart';

/// Une rencontre jouée, dépliable sur sa feuille de match.
///
/// LA FEUILLE NE MONTRE PAS QUI A SERVI QUI
///   Buteurs et passeurs sont comptés dans deux colonnes séparées. Ce
///   n'est pas un raccourci d'affichage : l'ancienne base enregistrait
///   buts et passes comme des lignes indépendantes, et l'appariement
///   reconstruit lors de la migration serait une invention. Les totaux,
///   eux, sont exacts.
class LigneMatch extends StatefulWidget {
  const LigneMatch({
    super.key,
    required this.rencontre,
    required this.nomEquipe,
    this.buts = const [],
    this.tirsAuBut = const [],
    this.joueurs = const {},
    this.depliable = true,
  });

  final Rencontre rencontre;
  final String nomEquipe;
  final List<But> buts;
  final List<TirAuBut> tirsAuBut;
  final Map<String, Joueur> joueurs;
  final bool depliable;

  @override
  State<LigneMatch> createState() => _LigneMatchState();
}

class _LigneMatchState extends State<LigneMatch> {
  bool _ouvert = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.rencontre;
    final aDuDetail = widget.buts.isNotEmpty || widget.tirsAuBut.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(13, 11, 6, 11),
          child: Row(
            children: [
              _Date(date: r.date),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      r.libelleCompetition,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                    ),
                    const SizedBox(height: 7),
                    _Affiche(
                      rencontre: r,
                      nomEquipe: widget.nomEquipe,
                      milieu: ScoreAffiche(rencontre: r),
                    ),
                    if (r.auxTirsAuBut) ...[
                      const SizedBox(height: 6),
                      Text(
                        'tirs au but ${r.tabPour}–${r.tabContre}',
                        style: Typo.texte(
                          taille: 10.5,
                          graisse: 600,
                          couleur: Couleurs.gris2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.depliable && aDuDetail)
                IconButton(
                  onPressed: () => setState(() => _ouvert = !_ouvert),
                  visualDensity: VisualDensity.compact,
                  tooltip: _ouvert ? 'Masquer le détail' : 'Voir le détail',
                  icon: AnimatedRotation(
                    turns: _ouvert ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.expand_more,
                      size: 20,
                      color: Couleurs.gris2,
                    ),
                  ),
                )
              else
                const SizedBox(width: 40),
            ],
          ),
        ),
        if (_ouvert)
          _Feuille(
            buts: widget.buts,
            tirsAuBut: widget.tirsAuBut,
            joueurs: widget.joueurs,
          ),
      ],
    );
  }
}

/// Une rencontre à venir : même mise en page, l'heure à la place du score.
class LigneProgrammation extends StatelessWidget {
  const LigneProgrammation({
    super.key,
    required this.rencontre,
    required this.nomEquipe,
  });

  final Rencontre rencontre;
  final String nomEquipe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      child: Row(
        children: [
          _Date(date: rencontre.date),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              children: [
                Text(
                  rencontre.libelleCompetition,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                ),
                const SizedBox(height: 7),
                _Affiche(
                  rencontre: rencontre,
                  nomEquipe: nomEquipe,
                  milieu: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Couleurs.nuit,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      heureDe(rencontre.date),
                      style: Typo.texte(
                        taille: 11,
                        graisse: 800,
                        couleur: Colors.white,
                        hauteurLigne: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Le jour et le mois, à gauche, séparés par un filet.
class _Date extends StatelessWidget {
  const _Date({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 49,
      padding: const EdgeInsets.only(right: 11),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Couleurs.ligne)),
      ),
      child: Column(
        children: [
          Text('${date.day}', style: Typo.chiffres(taille: 15.5)),
          const SizedBox(height: 2),
          Text(
            jourEtMois(date).split(' ').last,
            style: Typo.texte(taille: 9.5, couleur: Couleurs.gris2),
          ),
        ],
      ),
    );
  }
}

/// L'affiche : notre équipe et l'adversaire, dans l'ordre du terrain.
class _Affiche extends StatelessWidget {
  const _Affiche({
    required this.rencontre,
    required this.nomEquipe,
    required this.milieu,
  });

  final Rencontre rencontre;
  final String nomEquipe;
  final Widget milieu;

  @override
  Widget build(BuildContext context) {
    final nous = Text(
      nomEquipe,
      textAlign: rencontre.domicile ? TextAlign.right : TextAlign.left,
      style: Typo.texte(taille: 12.5, graisse: 700),
    );
    final eux = Text(
      rencontre.adversaire,
      textAlign: rencontre.domicile ? TextAlign.left : TextAlign.right,
      style: Typo.texte(taille: 12.5, graisse: 600, couleur: Couleurs.gris),
    );

    return Row(
      children: [
        Expanded(child: rencontre.domicile ? nous : eux),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: milieu,
        ),
        Expanded(child: rencontre.domicile ? eux : nous),
      ],
    );
  }
}

/// Le détail d'une rencontre : buteurs, passeurs, séance de tirs au but.
class _Feuille extends StatelessWidget {
  const _Feuille({
    required this.buts,
    required this.tirsAuBut,
    required this.joueurs,
  });

  final List<But> buts;
  final List<TirAuBut> tirsAuBut;
  final Map<String, Joueur> joueurs;

  /// Compte les occurrences d'un joueur et trie du plus prolifique au
  /// moins, à égalité par ordre alphabétique.
  List<({String nom, int nombre})> _compter(Iterable<String?> ids) {
    final compte = <String, int>{};
    for (final id in ids) {
      if (id == null) continue;
      compte[id] = (compte[id] ?? 0) + 1;
    }
    final lignes =
        compte.entries
            .map(
              (e) => (
                nom: joueurs[e.key]?.nomComplet ?? 'Joueur retiré',
                nombre: e.value,
              ),
            )
            .toList()
          ..sort((a, b) {
            final parNombre = b.nombre.compareTo(a.nombre);
            return parNombre != 0 ? parNombre : a.nom.compareTo(b.nom);
          });
    return lignes;
  }

  @override
  Widget build(BuildContext context) {
    final buteurs = _compter(buts.map((b) => b.joueurId));
    final passeurs = _compter(buts.map((b) => b.passeurId));
    final csc = buts.where((b) => b.csc).length;
    final tirs = [...tirsAuBut]..sort((a, b) => a.ordre.compareTo(b.ordre));

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Couleurs.blanc,
        border: Border(top: BorderSide(color: Couleurs.ligne)),
      ),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Colonne(
              icone: Icons.sports_soccer,
              titre: 'Buteurs',
              lignes: [
                for (final b in buteurs) (b.nom, b.nombre, false),
                if (csc > 0) ('csc adverse', csc, true),
              ],
            ),
          ),
          const _Filet(),
          Expanded(
            child: _Colonne(
              icone: Icons.ads_click,
              titre: 'Passeurs',
              italique: true,
              lignes: [for (final p in passeurs) (p.nom, p.nombre, false)],
            ),
          ),
          if (tirs.isNotEmpty) ...[
            const _Filet(),
            Expanded(
              child: _ColonneTirs(tirs: tirs, joueurs: joueurs),
            ),
          ],
        ],
      ),
    );
  }
}

class _Filet extends StatelessWidget {
  const _Filet();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 58,
    margin: const EdgeInsets.symmetric(horizontal: 9),
    color: Couleurs.ligne,
  );
}

class _Colonne extends StatelessWidget {
  const _Colonne({
    required this.icone,
    required this.titre,
    required this.lignes,
    this.italique = false,
  });

  final IconData icone;
  final String titre;

  /// (nom, nombre, estUnCsc)
  final List<(String, int, bool)> lignes;
  final bool italique;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icone, size: 12, color: Couleurs.gris2),
            const SizedBox(width: 5),
            Text(
              titre,
              style: Typo.texte(
                taille: 11,
                graisse: 600,
                couleur: Couleurs.gris2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (lignes.isEmpty)
          Text('—', style: Typo.texte(taille: 12.5, couleur: Couleurs.gris2)),
        for (final (nom, nombre, estCsc) in lignes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    nom,
                    style: Typo.texte(
                      taille: 12.5,
                      graisse: italique ? 500 : 700,
                      couleur: estCsc ? Couleurs.gris2 : Couleurs.nuit,
                    ).copyWith(
                      fontStyle: italique || estCsc
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ),
                if (nombre > 1) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Couleurs.or,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '×$nombre',
                      style: Typo.texte(
                        taille: 10.5,
                        graisse: 800,
                        couleur: Colors.white,
                        hauteurLigne: 1.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ColonneTirs extends StatelessWidget {
  const _ColonneTirs({required this.tirs, required this.joueurs});

  final List<TirAuBut> tirs;
  final Map<String, Joueur> joueurs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.adjust, size: 12, color: Couleurs.gris2),
            const SizedBox(width: 5),
            Text(
              'Séance TAB',
              style: Typo.texte(
                taille: 11,
                graisse: 600,
                couleur: Couleurs.gris2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final t in tirs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 4, right: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.marque ? Couleurs.vert : Couleurs.rouge,
                  ),
                ),
                Expanded(
                  child: Text(
                    joueurs[t.joueurId]?.nomCourt ?? 'Joueur retiré',
                    style: Typo.texte(taille: 12.5, graisse: 500),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// La carte sombre du prochain match, avec son compte à rebours.
class CarteProchainMatch extends StatelessWidget {
  const CarteProchainMatch({
    super.key,
    required this.rencontre,
    required this.nomEquipe,
    required this.maintenant,
  });

  final Rencontre rencontre;
  final String nomEquipe;
  final DateTime maintenant;

  String get _compteARebours {
    final jours = rencontre.joursAvant(maintenant);
    if (jours <= 0) return "Aujourd'hui";
    if (jours == 1) return 'Demain';
    return 'J−$jours';
  }

  @override
  Widget build(BuildContext context) {
    final nous = Text(
      nomEquipe,
      textAlign: TextAlign.center,
      style: Typo.titre(taille: 13.5, graisse: 700, couleur: Colors.white),
    );
    final eux = Text(
      rencontre.adversaire,
      textAlign: TextAlign.center,
      style: Typo.titre(
        taille: 13.5,
        graisse: 600,
        couleur: const Color(0xFF8FA3C2),
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Couleurs.nuit,
        borderRadius: BorderRadius.circular(AppTheme.rayonCarte),
      ),
      padding: const EdgeInsets.fromLTRB(13, 9, 13, 9),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  rencontre.libelleCompetition,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Typo.texte(
                    taille: 10.5,
                    couleur: const Color(0xFF9DB0CE),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Couleurs.or,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  _compteARebours,
                  style: Typo.texte(
                    taille: 11,
                    graisse: 800,
                    couleur: const Color(0xFF3A2600),
                    hauteurLigne: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          rencontre.domicile ? nous : eux,
          Text(
            'VS',
            style: Typo.texte(
              taille: 9,
              graisse: 800,
              couleur: const Color(0xFF8FA3C2),
            ).copyWith(letterSpacing: 1.2),
          ),
          rencontre.domicile ? eux : nous,
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0x21FFFFFF))),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              children: [
                _Info(
                  icone: Icons.calendar_today,
                  texte: avecMajuscule(dateLongue(rencontre.date)),
                ),
                _Info(
                  icone: Icons.schedule,
                  texte: heureDe(rencontre.date),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icone, size: 13, color: const Color(0xFFC6D3E6)),
        const SizedBox(width: 5),
        Text(
          texte,
          style: Typo.texte(taille: 11, couleur: const Color(0xFFC6D3E6)),
        ),
      ],
    );
  }
}
