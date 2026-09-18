import 'categorie.dart';
import 'classement.dart';
import 'equipe.dart';
import 'joueur.dart';
import 'rencontre.dart';

/// Ce qu'on peut dire d'un licencié sur une saison.
///
/// TOUT SE DÉDUIT DES BUTS
///   Il n'existe aucune table de feuilles de match : on ne saisit pas
///   qui a joué, seulement qui a été décisif. Un joueur n'a donc pas de
///   nombre de matchs disputés, et cette fiche ne prétend pas en
///   inventer un. Ce qu'elle compte, c'est le **match décisif** : une
///   rencontre où il a marqué ou fait marquer. C'est plus petit que la
///   vérité, mais c'est exact.
///
/// UN JOUEUR N'A PAS D'ÉQUIPE
///   Un licencié de génération 17 peut évoluer en U18 A un week-end et
///   en U17 le suivant. C'est la **rencontre** qui dit pour quelle
///   équipe un but a été marqué — jamais la fiche du joueur. Le détail
///   par équipe est donc la vraie information de cet écran : il raconte
///   où il a joué, ce qu'aucune colonne ne sait dire.
class FicheJoueur {
  const FicheJoueur({
    required this.joueur,
    required this.etiquette,
    required this.matchsDecisifs,
    required this.buts,
    required this.passes,
    required this.parEquipe,
    required this.parCompetition,
    required this.apparitions,
  });

  final Joueur joueur;

  /// « 18M », « SF » — la même étiquette que dans les classements.
  final String etiquette;

  /// Le nombre de rencontres où il a marqué ou fait marquer.
  final int matchsDecisifs;

  final int buts;
  final int passes;

  /// Ses compteurs équipe par équipe, de la plus fournie à la moins.
  final List<LigneRepartition> parEquipe;

  /// Idem par compétition.
  final List<LigneRepartition> parCompetition;

  /// Les rencontres où il a pesé, de la plus récente à la plus ancienne.
  final List<Apparition> apparitions;

  bool get aMarque => buts > 0 || passes > 0;

  /// Assemble la fiche à partir de la saison entière.
  ///
  /// Volontairement pas du périmètre consulté : on arrive ici depuis un
  /// classement de catégorie ou depuis l'accueil, mais ce qu'on veut
  /// voir, c'est le joueur — tout ce qu'il a fait cette saison, pas ce
  /// qu'il a fait dans la fenêtre par laquelle on l'a aperçu.
  factory FicheJoueur.depuis({
    required Joueur joueur,
    required List<Categorie> categories,
    required List<Equipe> equipes,
    required List<Rencontre> rencontres,
    required List<But> buts,
  }) {
    final parId = {for (final r in rencontres) r.id: r};

    var totalButs = 0;
    var totalPasses = 0;

    // On compte aussi les rencontres distinctes : un joueur qui marque
    // deux fois dans le même match a deux buts, mais un seul match
    // décisif. Additionner les buts par équipe ne donnerait donc jamais
    // le nombre de matchs.
    final parEquipeId = <String, _Cumul>{};
    final parCompet = <String, _Cumul>{};
    final parRencontre = <String, ({int buts, int passes})>{};

    for (final b in buts) {
      // Un csc adverse n'a ni buteur ni passeur à créditer.
      if (b.csc) continue;
      final estButeur = b.joueurId == joueur.id;
      final estPasseur = b.passeurId == joueur.id;
      if (!estButeur && !estPasseur) continue;

      final r = parId[b.rencontreId];
      if (r == null) continue;

      final but = estButeur ? 1 : 0;
      final passe = estPasseur ? 1 : 0;
      totalButs += but;
      totalPasses += passe;

      (parEquipeId[r.equipeId] ??= _Cumul()).ajouter(r.id, but, passe);
      (parCompet[r.competition] ??= _Cumul()).ajouter(r.id, but, passe);

      final a = parRencontre[r.id] ?? (buts: 0, passes: 0);
      parRencontre[r.id] = (buts: a.buts + but, passes: a.passes + passe);
    }

    String nomEquipe(String id) {
      for (final e in equipes) {
        if (e.id == id) return e.nom;
      }
      return 'FCPB';
    }

    List<LigneRepartition> trier(
      Map<String, _Cumul> m,
      String Function(String) libelle,
    ) {
      return m.entries
          .map(
            (e) => LigneRepartition(
              libelle: libelle(e.key),
              matchs: e.value.rencontres.length,
              buts: e.value.buts,
              passes: e.value.passes,
            ),
          )
          .toList()
        ..sort((a, b) {
          final parTotal = b.total.compareTo(a.total);
          if (parTotal != 0) return parTotal;
          final parMatchs = b.matchs.compareTo(a.matchs);
          return parMatchs != 0 ? parMatchs : a.libelle.compareTo(b.libelle);
        });
    }

    final apparitions =
        parRencontre.entries
            .where((e) => parId.containsKey(e.key))
            .map(
              (e) => Apparition(
                rencontre: parId[e.key]!,
                nomEquipe: nomEquipe(parId[e.key]!.equipeId),
                buts: e.value.buts,
                passes: e.value.passes,
              ),
            )
            .toList()
          ..sort((a, b) => b.rencontre.date.compareTo(a.rencontre.date));

    return FicheJoueur(
      joueur: joueur,
      etiquette: etiquetteCategorie(categories, joueur),
      matchsDecisifs: apparitions.length,
      buts: totalButs,
      passes: totalPasses,
      parEquipe: trier(parEquipeId, nomEquipe),
      parCompetition: trier(parCompet, (nom) => nom),
      apparitions: apparitions,
    );
  }
}

/// Un cumul en cours de construction : les rencontres vues, et les
/// compteurs. `rencontres` est un ensemble, ce qui règle le comptage des
/// matchs sans effort — un doublé n'y entre qu'une fois.
class _Cumul {
  final Set<String> rencontres = {};
  int buts = 0;
  int passes = 0;

  void ajouter(String rencontreId, int but, int passe) {
    rencontres.add(rencontreId);
    buts += but;
    passes += passe;
  }
}

/// Une ligne de détail : une équipe ou une compétition, et ce que le
/// joueur y a produit.
class LigneRepartition {
  const LigneRepartition({
    required this.libelle,
    required this.matchs,
    required this.buts,
    required this.passes,
  });

  final String libelle;

  /// Les rencontres de cette équipe (ou compétition) où il a été
  /// décisif.
  final int matchs;

  final int buts;
  final int passes;

  int get total => buts + passes;
}

/// Une rencontre où le joueur a pesé.
class Apparition {
  const Apparition({
    required this.rencontre,
    required this.nomEquipe,
    required this.buts,
    required this.passes,
  });

  final Rencontre rencontre;
  final String nomEquipe;
  final int buts;
  final int passes;
}
