import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/classement.dart';
import '../providers/club_providers.dart';
import '../providers/donnees_saison.dart';
import '../theme/app_theme.dart';
import '../widgets/classement_liste.dart';
import '../widgets/communs.dart';
import '../widgets/entete.dart';
import '../widgets/filtres.dart';

/// Les classements du club : buteurs, passeurs, cumul.
///
/// Le sous-titre rappelle en permanence ce qui est compté. Un classement
/// sans son périmètre est un chiffre sans unité — on avait eu le cas
/// avec l'ancienne application, où l'on ne savait plus si l'on regardait
/// une équipe ou toute une catégorie.
class ClassementsPage extends ConsumerStatefulWidget {
  const ClassementsPage({super.key});

  @override
  ConsumerState<ClassementsPage> createState() => _ClassementsPageState();
}

class _ClassementsPageState extends ConsumerState<ClassementsPage> {
  TypeClassement _type = TypeClassement.buteurs;
  FiltreClub _filtre = const FiltreClub();

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(donneesSaisonProvider);
    final saison = ref.watch(saisonCouranteProvider).value;

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            EnteteSimple(
              titre: 'Classements',
              sousTitre: _resume(async.value, saison?.libelle),
              selecteur: const SelecteurSaison(),
              dessous: Segments(
                options: const [
                  ('buteurs', 'Buteurs'),
                  ('passeurs', 'Passeurs'),
                  ('decisifs', 'Buts + passes'),
                ],
                actif: _type.name,
                onChoix: (v) =>
                    setState(() => _type = TypeClassement.values.byName(v)),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErreurChargement(
                  message: '$e',
                  reessayer: () => ref.invalidate(donneesSaisonProvider),
                ),
                data: (d) => Column(
                  children: [
                    ChipsGroupes(
                      categories: d.categories,
                      filtre: _filtre,
                      onChange: (f) => setState(() => _filtre = f),
                      avant: BoutonCompetitions(
                        nombre: _filtre.nombreFiltresCompetition,
                        onTap: () async {
                          final choix = await choisirCompetitions(
                            context,
                            donnees: d,
                            filtre: _filtre,
                          );
                          if (choix != null) setState(() => _filtre = choix);
                        },
                      ),
                    ),
                    ChipsEquipes(
                      donnees: d,
                      filtre: _filtre,
                      onChange: (f) => setState(() => _filtre = f),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
                        children: [
                          Section(
                            enfant: ClassementListe(
                              lignes: construireClassement(
                                buts: d.butsFiltres(_filtre),
                                joueurs: d.joueurs,
                                type: _type,
                              ),
                              type: _type,
                              messageVide: _messageVide,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// « 26/27 · U16 – U18 M · toutes compétitions »
  String _resume(DonneesSaison? d, String? saison) {
    final morceaux = <String>[];
    if (saison != null) morceaux.add(saison);

    if (d != null) {
      if (_filtre.equipeId != null) {
        morceaux.add(d.nomEquipe(_filtre.equipeId!));
      } else if (_filtre.categorieId != null) {
        final c = d.categorie(_filtre.categorieId!);
        morceaux.add(
          '${c?.libelle ?? ''} ${_filtre.genre == 'F' ? 'F' : 'M'}'.trim(),
        );
      } else {
        morceaux.add('tout le club');
      }
    }

    if (_filtre.competitions.isNotEmpty) {
      morceaux.add(_filtre.competitions.join(', '));
    } else if (_filtre.types.isNotEmpty) {
      morceaux.add(_filtre.types.join(', '));
    } else {
      morceaux.add('toutes compétitions');
    }

    return morceaux.join(' · ');
  }

  String get _messageVide => switch (_type) {
    TypeClassement.buteurs => 'Aucun but enregistré pour cette sélection.',
    TypeClassement.passeurs =>
      'Aucune passe décisive enregistrée. Pensez à renseigner les '
          'passeurs : sans eux ce classement reste vide.',
    TypeClassement.decisifs => 'Aucune action décisive pour cette sélection.',
  };
}
