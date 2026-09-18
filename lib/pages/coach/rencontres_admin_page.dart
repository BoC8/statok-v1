import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/equipe.dart';
import '../../models/rencontre.dart';
import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';
import 'form_rencontre_page.dart';

/// Toutes les rencontres du staff, programmées et jouées ensemble.
///
/// PROGRAMMÉES ET JOUÉES DANS LA MÊME LISTE
///   C'est la même fiche à deux moments de sa vie. Les séparer en deux
///   écrans obligerait le coach à savoir d'avance dans lequel chercher —
///   or ce qu'il cherche, c'est « le match contre Derval », pas « la
///   programmation contre Derval ». Un segment permet de réduire quand
///   la liste devient longue.
class RencontresAdminPage extends ConsumerStatefulWidget {
  const RencontresAdminPage({super.key});

  static Future<void> ouvrir(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const RencontresAdminPage()));

  @override
  ConsumerState<RencontresAdminPage> createState() =>
      _RencontresAdminPageState();
}

class _RencontresAdminPageState extends ConsumerState<RencontresAdminPage> {
  String _vue = 'tout';
  String? _equipeId;

  @override
  Widget build(BuildContext context) {
    final saison = ref.watch(saisonAtelierProvider).value;
    final rencontres = ref.watch(rencontresAtelierProvider).value;
    final toutesEquipes = ref.watch(equipesProvider).value ?? const <Equipe>[];
    final mesEquipes = saison == null
        ? null
        : ref.watch(equipesModifiablesProvider(saison.id)).value;

    if (saison == null || rencontres == null || mesEquipes == null) {
      return const Scaffold(
        backgroundColor: Couleurs.craie,
        body: SafeArea(
          child: Column(
            children: [
              BandeauRetour(titre: 'Rencontres'),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }

    final noms = {for (final e in toutesEquipes) e.id: e.nom};

    final ids = mesEquipes.map((e) => e.id).toSet();
    var liste = rencontres.where((r) => ids.contains(r.equipeId)).toList();
    if (_equipeId != null) {
      liste = liste.where((r) => r.equipeId == _equipeId).toList();
    }
    liste = switch (_vue) {
      'avenir' => liste.where((r) => !r.jouee).toList().reversed.toList(),
      'jouees' => liste.where((r) => r.jouee).toList(),
      _ => liste,
    };

    final parMois = <String, List<Rencontre>>{};
    for (final r in liste) {
      parMois.putIfAbsent(moisEtAnnee(r.date), () => []).add(r);
    }

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            BandeauRetour(
              titre: 'Rencontres',
              sousTitre:
                  '${liste.length} fiche${liste.length > 1 ? 's' : ''} · '
                  'saison ${saison.libelle}',
              action: IconButton(
                tooltip: 'Nouvelle rencontre',
                onPressed: () => FormRencontrePage.ouvrir(context),
                icon: const Icon(Icons.add, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  minimumSize: const Size(34, 34),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: Couleurs.blanc,
                border: Border(bottom: BorderSide(color: Couleurs.ligne)),
              ),
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              child: Segments(
                options: const [
                  ('tout', 'Tout'),
                  ('avenir', 'À venir'),
                  ('jouees', 'Joués'),
                ],
                actif: _vue,
                onChoix: (v) => setState(() => _vue = v),
              ),
            ),
            if (mesEquipes.length > 1)
              Container(
                decoration: const BoxDecoration(
                  color: Couleurs.blanc,
                  border: Border(bottom: BorderSide(color: Couleurs.ligne)),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: PuceFiltre(
                          libelle: 'Toutes mes équipes',
                          choisi: _equipeId == null,
                          onTap: () => setState(() => _equipeId = null),
                        ),
                      ),
                      for (final e in mesEquipes)
                        Padding(
                          padding: const EdgeInsets.only(right: 7),
                          child: PuceFiltre(
                            libelle: e.nom,
                            choisi: _equipeId == e.id,
                            onTap: () => setState(() => _equipeId = e.id),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: liste.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 28),
                      children: const [
                        CarteBlanche(
                          enfant: Vide(
                            message: 'Aucune rencontre pour cette sélection. '
                                'Touchez + pour en créer une.',
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                      children: [
                        for (final entree in parMois.entries)
                          Section(
                            titre: avecMajuscule(entree.key),
                            enfant: CarteBlanche(
                              enfant: Column(
                                children: [
                                  for (
                                    var i = 0;
                                    i < entree.value.length;
                                    i++
                                  ) ...[
                                    if (i > 0) const Divider(height: 1),
                                    _LigneFiche(
                                      rencontre: entree.value[i],
                                      nomEquipe:
                                          noms[entree.value[i].equipeId] ??
                                          'FCPB',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une ligne de la liste : ce qu'il faut pour reconnaître la rencontre,
/// et son état.
class _LigneFiche extends StatelessWidget {
  const _LigneFiche({required this.rencontre, required this.nomEquipe});

  final Rencontre rencontre;
  final String nomEquipe;

  @override
  Widget build(BuildContext context) {
    final r = rencontre;
    final enRetard = r.programmee && r.date.isBefore(DateTime.now());

    return InkWell(
      onTap: () => FormRencontrePage.ouvrir(context, rencontre: r),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text('${r.date.day}', style: Typo.chiffres(taille: 15.5)),
                  const SizedBox(height: 2),
                  Text(
                    jourEtMois(r.date).split(' ').last,
                    style: Typo.texte(taille: 9.5, couleur: Couleurs.gris2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$nomEquipe — ${r.adversaire}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.texte(taille: 13, graisse: 600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${r.libelleCompetition} · '
                    '${r.domicile ? 'domicile' : 'extérieur'} · '
                    '${heureDe(r.date)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Typo.texte(taille: 10.5, couleur: Couleurs.gris),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _Etat(rencontre: r, enRetard: enRetard),
            const Icon(Icons.chevron_right, size: 16, color: Couleurs.gris2),
          ],
        ),
      ),
    );
  }
}

/// Le score s'il existe, sinon l'état de la fiche.
///
/// La pastille orange marque les rencontres passées restées « à venir » :
/// c'est le travail qui attend le coach.
class _Etat extends StatelessWidget {
  const _Etat({required this.rencontre, required this.enRetard});

  final Rencontre rencontre;
  final bool enRetard;

  @override
  Widget build(BuildContext context) {
    if (rencontre.jouee) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScoreAffiche(rencontre: rencontre),
          const SizedBox(width: 4),
        ],
      );
    }

    final (texte, fond, encre) = switch (rencontre.statut) {
      'reportee' => ('reporté', Couleurs.craie, Couleurs.gris),
      'annulee' => ('annulé', Couleurs.craie, Couleurs.gris),
      _ when enRetard => (
        'à saisir',
        Couleurs.orClair,
        const Color(0xFF7A4F00),
      ),
      _ => ('à venir', Couleurs.bleuClair, Couleurs.bleu),
    };

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        texte,
        style: Typo.texte(taille: 10.5, graisse: 700, couleur: encre),
      ),
    );
  }
}
