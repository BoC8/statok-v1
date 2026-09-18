import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/club_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';

/// Les réglages du club — réservés au super administrateur.
///
/// Deux choses seulement, mais de natures opposées : un texte qu'on
/// réécrit autant qu'on veut, et une opération qu'on ne fait qu'une fois
/// par an et qu'on ne peut pas défaire. L'écran les sépare franchement,
/// et met l'irréversible en bas, en rouge.
class ParametresPage extends ConsumerStatefulWidget {
  const ParametresPage({super.key});

  static Future<void> ouvrir(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const ParametresPage()));

  @override
  ConsumerState<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends ConsumerState<ParametresPage> {
  final _texte = TextEditingController();
  bool _repris = false;
  bool _enregistre = false;
  String? _message;
  bool _messageEstUneErreur = false;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final etatParametres = ref.watch(parametresProvider);
    final parametres = etatParametres.value;
    final saison = ref.watch(saisonActiveProvider).value;

    // On ne reprend le texte qu'une fois : sans ce garde-fou, chaque
    // reconstruction de l'écran écraserait ce qui est en train d'être
    // tapé.
    if (!_repris && parametres != null) {
      _repris = true;
      _texte.text = ref.read(bonASavoirProvider);
    }

    return Scaffold(
      backgroundColor: Couleurs.craie,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const BandeauRetour(
              titre: 'Paramètres',
              sousTitre: 'Réservé au super administrateur',
            ),
            Expanded(
              // La table `parametres` arrive avec le patch SQL : tant
              // qu'il n'est pas passé, la requête échoue. Le dire, plutôt
              // que de laisser tourner un rond indéfiniment.
              child: etatParametres.hasError
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 32),
                      children: [
                        _Avis(
                          texte:
                              'Les paramètres ne sont pas lisibles : la '
                              'table n\u2019existe pas encore, ou votre '
                              "compte n'est pas super administrateur. "
                              'Exécutez `docs/patch_super_admin.sql` sur '
                              'la base.',
                          erreur: true,
                        ),
                      ],
                    )
                  : parametres == null || saison == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 32),
                      children: [
                        _sectionTexte(),
                        _sectionMontee(saison.libelle, saison.monteeFaite),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  //  Le pavé « Bon à savoir »
  // -------------------------------------------------------------------

  Widget _sectionTexte() {
    return Section(
      titre: 'Le pavé « Bon à savoir »',
      enfant: CarteBlanche(
        rognage: false,
        enfant: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Le texte affiché en bas de l'espace coachs, pour tout le "
                'staff. Une ligne vide sépare deux paragraphes.',
                style: Typo.texte(
                  taille: 11.5,
                  couleur: Couleurs.gris,
                  hauteurLigne: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _texte,
                maxLines: 9,
                minLines: 5,
                onChanged: (_) => setState(() => _message = null),
                style: Typo.texte(taille: 13, hauteurLigne: 1.6),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Couleurs.craie,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _Avis(
                    texte: _message!,
                    erreur: _messageEstUneErreur,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Couleurs.bleu,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  onPressed: _enregistre ? null : _enregistrerTexte,
                  child: Text(
                    _enregistre ? 'Enregistrement…' : 'Enregistrer le texte',
                    style: Typo.texte(
                      taille: 13.5,
                      graisse: 700,
                      couleur: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enregistrerTexte() async {
    setState(() {
      _enregistre = true;
      _message = null;
    });
    try {
      await ref
          .read(adminRepositoryProvider)
          .enregistrerParametre('bon_a_savoir', _texte.text.trim());
      ref.invalidate(parametresProvider);
      if (!mounted) return;
      setState(() {
        _enregistre = false;
        _messageEstUneErreur = false;
        _message = 'Texte enregistré. Il est déjà visible par tout le staff.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enregistre = false;
        _messageEstUneErreur = true;
        _message = _traduire(e);
      });
    }
  }

  // -------------------------------------------------------------------
  //  La montée de catégorie
  // -------------------------------------------------------------------

  Widget _sectionMontee(String libelleSaison, bool dejaFaite) {
    return Section(
      titre: 'Montée de catégorie',
      enfant: CarteBlanche(
        enfant: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chaque licencié vieillit d’une génération : un U15 '
                'devient U16, un U18 devient séniors. À lancer une seule '
                'fois, au début de la saison.',
                style: Typo.texte(taille: 12.5, hauteurLigne: 1.6),
              ),
              const SizedBox(height: 10),
              Text(
                "Rien ne permet de revenir en arrière : l'ancienne "
                "génération n'est conservée nulle part. Les licenciés "
                'partis montent aussi, pour que leur fiche reste juste '
                "s'ils reviennent.",
                style: Typo.texte(
                  taille: 11.5,
                  couleur: Couleurs.gris,
                  hauteurLigne: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              if (dejaFaite)
                _Avis(
                  texte:
                      'Déjà faite pour la saison $libelleSaison. La base '
                      'refusera de la relancer : il faudra créer la '
                      'saison suivante pour y avoir droit de nouveau.',
                  erreur: false,
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Couleurs.rouge,
                      side: const BorderSide(color: Color(0xFFF3CFCB)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _enregistre
                        ? null
                        : () => _lancerMontee(libelleSaison),
                    icon: const Icon(Icons.arrow_upward, size: 18),
                    label: Text(
                      'Monter tout le club d’une génération',
                      style: Typo.texte(
                        taille: 13.5,
                        graisse: 700,
                        couleur: Couleurs.rouge,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Deux confirmations, et la seconde demande d'écrire.
  ///
  /// POURQUOI DEUX, ET POURQUOI LA SECONDE EST DIFFÉRENTE
  ///   Deux boîtes identiques ne protègent de rien : on appuie deux fois
  ///   sur « Oui » du même geste. La seconde demande donc de recopier un
  ///   mot — le seul moment de l'application où l'on exige un effort
  ///   délibéré, parce que c'est la seule action qu'on ne peut pas
  ///   défaire.
  Future<void> _lancerMontee(String libelleSaison) async {
    final premier = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Couleurs.blanc,
        title: Text(
          'Monter tout le club ?',
          style: Typo.texte(taille: 15, graisse: 700),
        ),
        content: Text(
          'Tous les licenciés vont vieillir d’une génération, d’un '
          'seul coup, pour la saison $libelleSaison.\n\n'
          "Cette opération ne s'annule pas.",
          style: Typo.texte(taille: 13, hauteurLigne: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Couleurs.rouge),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continuer'),
          ),
        ],
      ),
    );
    if (premier != true || !mounted) return;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (_) => const _DialogueRecopie(),
    );
    if (confirme != true || !mounted) return;

    setState(() {
      _enregistre = true;
      _message = null;
    });
    try {
      final bilan = await ref
          .read(adminRepositoryProvider)
          .monterLesGenerations();
      rafraichirApresEcriture(ref);
      ref.invalidate(saisonsProvider);
      if (!mounted) return;
      final promus = bilan['promus'] ?? 0;
      setState(() {
        _enregistre = false;
        _messageEstUneErreur = false;
        _message = promus == 0
            ? 'Personne à monter : tout le club était déjà en séniors.'
            : '$promus licencié${promus == 1 ? '' : 's'} '
                  '${promus == 1 ? 'a' : 'ont'} changé de génération.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enregistre = false;
        _messageEstUneErreur = true;
        _message = _traduire(e);
      });
    }
  }

  /// Les refus de la base, dits en français.
  String _traduire(Object e) {
    final t = e.toString();
    if (t.contains('déjà été faite')) {
      return 'La montée a déjà été faite pour cette saison. La relancer '
          'vieillirait tout le monde une seconde fois — la base a '
          'refusé, et elle a raison.';
    }
    if (t.contains('super administrateur') ||
        t.contains('row-level security') ||
        t.contains('42501')) {
      return "Votre compte n'est pas super administrateur. Ce refus vient "
          "de la base, pas de l'application.";
    }
    if (t.contains('Aucune saison en cours')) {
      return 'Aucune saison n’est marquée « en cours » : impossible de '
          'savoir à quelle année rattacher la montée.';
    }
    return "L'opération a échoué : $t";
  }
}

/// Le second verrou : recopier un mot.
class _DialogueRecopie extends StatefulWidget {
  const _DialogueRecopie();

  static const mot = 'MONTER';

  @override
  State<_DialogueRecopie> createState() => _DialogueRecopieState();
}

class _DialogueRecopieState extends State<_DialogueRecopie> {
  final _saisie = TextEditingController();

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _saisie.text.trim().toUpperCase() == _DialogueRecopie.mot;

    return AlertDialog(
      backgroundColor: Couleurs.blanc,
      title: Text(
        'Dernière vérification',
        style: Typo.texte(taille: 15, graisse: 700),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Écrivez « ${_DialogueRecopie.mot} » pour confirmer.',
            style: Typo.texte(taille: 13, hauteurLigne: 1.6),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _saisie,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            style: Typo.texte(taille: 14, graisse: 700),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Couleurs.craie,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Couleurs.rouge),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Lancer la montée'),
        ),
      ],
    );
  }
}

/// Un cadre de message, vert ou rouge.
class _Avis extends StatelessWidget {
  const _Avis({required this.texte, required this.erreur});

  final String texte;
  final bool erreur;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: erreur ? const Color(0xFFFBE3E1) : const Color(0xFFE4F3EC),
        border: Border.all(
          color: erreur ? const Color(0xFFF3CFCB) : const Color(0xFFC6E4D6),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        texte,
        style: Typo.texte(
          taille: 12,
          couleur: erreur ? const Color(0xFF8A2B22) : const Color(0xFF14603F),
          hauteurLigne: 1.5,
        ),
      ),
    );
  }
}
