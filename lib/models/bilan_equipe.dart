/// L'issue d'une rencontre, du point de vue du FCPB.
enum Issue {
  victoire,
  nul,
  defaite;

  /// La lettre affichée dans les pastilles de forme.
  String get lettre => switch (this) {
    Issue.victoire => 'V',
    Issue.nul => 'N',
    Issue.defaite => 'D',
  };
}

/// Le résultat d'une rencontre, réduit à ce dont les écrans ont besoin.
class Resultat {
  const Resultat({
    required this.equipeId,
    required this.date,
    required this.scorePour,
    required this.scoreContre,
    this.tabPour,
    this.tabContre,
  });

  final String equipeId;
  final DateTime date;
  final int scorePour;
  final int scoreContre;
  final int? tabPour;
  final int? tabContre;

  bool get auxTirsAuBut => tabPour != null && tabContre != null;

  /// UNE RÈGLE, PAS DEUX.
  ///
  /// Un match nul remporté aux tirs au but reste **un match nul**, ici
  /// comme dans le bilan chiffré et dans les séries en cours. C'est le
  /// choix qu'on avait arrêté après le bug de la série de victoires :
  /// seul le score du temps réglementaire décide.
  ///
  /// La maquette, elle, affichait une victoire dans la ligne de forme
  /// tout en comptant un nul dans le bilan. Pour revenir à ce
  /// comportement, il suffit d'ajouter ici une branche sur
  /// [auxTirsAuBut] — mais alors la pastille et le compteur ne diront
  /// plus la même chose.
  Issue get issue {
    if (scorePour > scoreContre) return Issue.victoire;
    if (scorePour < scoreContre) return Issue.defaite;
    return Issue.nul;
  }

  factory Resultat.depuisJson(Map<String, dynamic> j) => Resultat(
    equipeId: j['equipe_id'] as String,
    date: DateTime.parse(j['date_heure'] as String).toLocal(),
    scorePour: j['score_pour'] as int,
    scoreContre: j['score_contre'] as int,
    tabPour: j['tab_pour'] as int?,
    tabContre: j['tab_contre'] as int?,
  );
}

/// Le bilan d'une équipe sur une saison.
class BilanEquipe {
  const BilanEquipe({
    required this.joues,
    required this.victoires,
    required this.nuls,
    required this.defaites,
    required this.butsPour,
    required this.butsContre,
    required this.cleanSheets,
    required this.forme,
  });

  final int joues;
  final int victoires;
  final int nuls;
  final int defaites;
  final int butsPour;
  final int butsContre;

  /// Les matchs terminés sans encaisser le moindre but.
  final int cleanSheets;

  /// Les cinq derniers résultats, **du plus ancien au plus récent** :
  /// c'est le sens de lecture naturel d'une ligne de forme.
  final List<Issue> forme;

  static const vide = BilanEquipe(
    joues: 0,
    victoires: 0,
    nuls: 0,
    defaites: 0,
    butsPour: 0,
    butsContre: 0,
    cleanSheets: 0,
    forme: [],
  );

  int get difference => butsPour - butsContre;

  int get pourcentageVictoires =>
      joues == 0 ? 0 : (victoires * 100 / joues).round();

  /// Construit le bilan à partir des rencontres d'une équipe.
  ///
  /// [resultats] doit être trié du plus récent au plus ancien — c'est ce
  /// que renvoie le repository.
  factory BilanEquipe.depuis(List<Resultat> resultats) {
    var v = 0, n = 0, d = 0, bp = 0, bc = 0, cs = 0;
    for (final r in resultats) {
      final issue = r.issue;
      if (issue == Issue.victoire) {
        v++;
      } else if (issue == Issue.nul) {
        n++;
      } else {
        d++;
      }
      bp += r.scorePour;
      bc += r.scoreContre;
      if (r.scoreContre == 0) cs++;
    }
    return BilanEquipe(
      joues: resultats.length,
      victoires: v,
      nuls: n,
      defaites: d,
      butsPour: bp,
      butsContre: bc,
      cleanSheets: cs,
      forme: resultats.take(5).map((r) => r.issue).toList().reversed.toList(),
    );
  }
}
