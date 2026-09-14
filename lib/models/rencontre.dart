import 'bilan_equipe.dart';

/// Une rencontre, programmée ou jouée.
///
/// UNE SEULE TABLE POUR LES DEUX. Le coach saisit la rencontre une fois,
/// puis ajoute le score et bascule `statut`. C'est ce qui évite la double
/// saisie et les doublons qu'on avait avec `matchs` et `programmations`
/// séparées.
class Rencontre {
  const Rencontre({
    required this.id,
    required this.saisonId,
    required this.equipeId,
    required this.adversaire,
    required this.competition,
    required this.typeCompetition,
    required this.phase,
    required this.date,
    required this.domicile,
    required this.statut,
    this.scorePour,
    this.scoreContre,
    this.tabPour,
    this.tabContre,
  });

  final String id;

  /// La saison à laquelle la rencontre appartient.
  ///
  /// Indispensable à la modification : sans elle, rouvrir un match de
  /// 2025-2026 et l'enregistrer le ferait basculer dans la saison en
  /// cours, silencieusement.
  final String saisonId;

  final String equipeId;
  final String adversaire;
  final String competition;

  /// `'championnat'`, `'coupe'` ou `'amical'`.
  final String typeCompetition;

  /// 0 pour les seniors, les coupes et les amicaux ; 1 à 3 chez les
  /// jeunes, dont le championnat est découpé en trois phases.
  final int phase;

  final DateTime date;
  final bool domicile;

  /// `'programmee'`, `'jouee'`, `'reportee'` ou `'annulee'`.
  final String statut;

  final int? scorePour;
  final int? scoreContre;
  final int? tabPour;
  final int? tabContre;

  bool get jouee => statut == 'jouee';
  bool get programmee => statut == 'programmee';
  bool get auxTirsAuBut => tabPour != null && tabContre != null;

  /// Le libellé affiché : la compétition, suivie de la phase quand il y
  /// en a une. « Départemental 1 · phase 2 ».
  String get libelleCompetition =>
      phase > 0 ? '$competition · phase $phase' : competition;

  /// L'issue, ou `null` si le match n'est pas joué.
  ///
  /// Comme partout : seul le score du temps réglementaire décide, une
  /// qualification aux tirs au but reste un nul.
  Issue? get issue {
    if (!jouee || scorePour == null || scoreContre == null) return null;
    if (scorePour! > scoreContre!) return Issue.victoire;
    if (scorePour! < scoreContre!) return Issue.defaite;
    return Issue.nul;
  }

  /// Le nombre de jours qui nous séparent du coup d'envoi.
  /// Négatif si la rencontre est passée.
  int joursAvant(DateTime maintenant) {
    final jour = DateTime(date.year, date.month, date.day);
    final aujourdhui = DateTime(
      maintenant.year,
      maintenant.month,
      maintenant.day,
    );
    return jour.difference(aujourdhui).inDays;
  }

  /// Le résultat réduit, pour alimenter un bilan.
  Resultat? get resultat => jouee
      ? Resultat(
          equipeId: equipeId,
          date: date,
          scorePour: scorePour!,
          scoreContre: scoreContre!,
          tabPour: tabPour,
          tabContre: tabContre,
        )
      : null;

  /// Les noms de l'adversaire et de la compétition arrivent imbriqués,
  /// PostgREST rendant les tables liées sous forme d'objets.
  factory Rencontre.depuisJson(Map<String, dynamic> j) {
    final adv = j['adversaires'] as Map<String, dynamic>?;
    final comp = j['competitions'] as Map<String, dynamic>?;
    return Rencontre(
      id: j['id'] as String,
      saisonId: j['saison_id'] as String,
      equipeId: j['equipe_id'] as String,
      adversaire: adv?['nom'] as String? ?? 'Adversaire',
      competition: comp?['nom'] as String? ?? '',
      typeCompetition: comp?['type'] as String? ?? 'championnat',
      phase: j['phase'] as int? ?? 0,
      date: DateTime.parse(j['date_heure'] as String).toLocal(),
      domicile: j['domicile'] as bool? ?? true,
      statut: j['statut'] as String? ?? 'programmee',
      scorePour: j['score_pour'] as int?,
      scoreContre: j['score_contre'] as int?,
      tabPour: j['tab_pour'] as int?,
      tabContre: j['tab_contre'] as int?,
    );
  }
}

/// Un but marqué par le FCPB.
///
/// `csc` : but contre son camp d'un joueur adverse, qui compte pour nous.
/// Il n'y a alors ni buteur ni passeur à créditer.
class But {
  const But({
    required this.rencontreId,
    this.joueurId,
    this.passeurId,
    required this.csc,
  });

  final String rencontreId;
  final String? joueurId;
  final String? passeurId;
  final bool csc;

  factory But.depuisJson(Map<String, dynamic> j) => But(
    rencontreId: j['rencontre_id'] as String,
    joueurId: j['joueur_id'] as String?,
    passeurId: j['passeur_id'] as String?,
    csc: j['csc'] as bool? ?? false,
  );
}

/// Un tir au but du FCPB, dans son ordre de passage.
class TirAuBut {
  const TirAuBut({
    required this.rencontreId,
    required this.ordre,
    required this.joueurId,
    required this.marque,
  });

  final String rencontreId;
  final int ordre;
  final String joueurId;
  final bool marque;

  factory TirAuBut.depuisJson(Map<String, dynamic> j) => TirAuBut(
    rencontreId: j['rencontre_id'] as String,
    ordre: j['ordre'] as int,
    joueurId: j['joueur_id'] as String,
    marque: j['marque'] as bool? ?? false,
  );
}
