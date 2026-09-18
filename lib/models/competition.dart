/// Une compétition du district : un championnat, une coupe, ou le
/// fourre-tout des matchs amicaux.
///
/// Elle n'appartient à personne. « Départemental 3 » est la même ligne
/// pour les Seniors A cette année et pour une autre équipe l'an
/// prochain : c'est l'**engagement** qui rattache une équipe à une
/// compétition pour une saison donnée.
class Competition {
  const Competition({
    required this.id,
    required this.nom,
    required this.type,
  });

  final String id;
  final String nom;

  /// `'championnat'`, `'coupe'` ou `'amical'`.
  final String type;

  String get libelleType => switch (type) {
    'coupe' => 'Coupe',
    'amical' => 'Amical',
    _ => 'Championnat',
  };

  /// Les jeunes disputent trois phases ; les seniors une seule saison
  /// d'un bloc. Seul un championnat se découpe ainsi — une coupe se joue
  /// d'un bout à l'autre de l'année, un amical n'a pas de calendrier.
  bool get admetDesPhases => type == 'championnat';

  factory Competition.depuisJson(Map<String, dynamic> j) => Competition(
    id: j['id'] as String,
    nom: j['nom'] as String,
    type: j['type'] as String? ?? 'championnat',
  );
}

/// L'inscription d'une équipe à une compétition, pour une saison.
///
/// LA PHASE FAIT PARTIE DE L'IDENTITÉ
///   Chez les jeunes, le championnat se rejoue trois fois dans l'année,
///   et on peut monter ou descendre entre deux phases. « Départemental 3
///   phase 1 » et « Départemental 2 phase 2 » sont deux engagements
///   distincts de la même équipe — c'est voulu, et c'est ce qui permet
///   de raconter une montée en cours de saison.
///
///   Pour les seniors, un seul championnat toute l'année : la phase vaut
///   0, ce qui se lit « sans phase ».
class Engagement {
  const Engagement({
    required this.id,
    required this.equipeId,
    required this.saisonId,
    required this.competition,
    required this.phase,
  });

  final String id;
  final String equipeId;
  final String saisonId;
  final Competition competition;
  final int phase;

  String get libelle =>
      phase > 0 ? '${competition.nom} · phase $phase' : competition.nom;

  factory Engagement.depuisJson(Map<String, dynamic> j) => Engagement(
    id: j['id'] as String,
    equipeId: j['equipe_id'] as String,
    saisonId: j['saison_id'] as String,
    competition: Competition.depuisJson(
      (j['competitions'] as Map<String, dynamic>?) ??
          const {'id': '', 'nom': '', 'type': 'championnat'},
    ),
    phase: j['phase'] as int? ?? 0,
  );
}
