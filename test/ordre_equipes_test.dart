import 'package:flutter_test/flutter_test.dart';
import 'package:statok/models/categorie.dart';
import 'package:statok/models/equipe.dart';

Categorie categorie({
  required String id,
  required String libelle,
  required int ordre,
  required List<String> generations,
}) => Categorie(
  id: id,
  libelle: libelle,
  ordre: ordre,
  generations: generations,
);

Equipe equipe({
  required String categorieId,
  required String genre,
  required String nom,
  int ordre = 1,
}) => Equipe(
  id: '$nom-$genre',
  categorieId: categorieId,
  genre: genre,
  nom: nom,
  ordre: ordre,
  generationMax: 'senior',
  actif: true,
);

void main() {
  // Le club tel qu'il est : trois catégories, dont l'ordre d'affichage
  // va du plus jeune au plus vieux — l'inverse de ce qu'on veut ici.
  final seniors = categorie(
    id: 'c-seniors',
    libelle: 'Seniors',
    ordre: 3,
    generations: ['senior'],
  );
  final u18 = categorie(
    id: 'c-u18',
    libelle: 'U16 – U18',
    ordre: 2,
    generations: ['16', '17', '18'],
  );
  final u15 = categorie(
    id: 'c-u15',
    libelle: 'U14 – U15',
    ordre: 1,
    generations: ['13', '14', '15'],
  );
  final categories = [u15, u18, seniors];

  test('les équipes sortent dans l’ordre du club', () {
    // Volontairement en désordre, comme la base les rend.
    final desordre = [
      equipe(categorieId: u15.id, genre: 'F', nom: 'U15 F'),
      equipe(categorieId: seniors.id, genre: 'M', nom: 'Seniors B', ordre: 2),
      equipe(categorieId: u18.id, genre: 'F', nom: 'U18 F'),
      equipe(categorieId: u15.id, genre: 'M', nom: 'U15'),
      equipe(categorieId: seniors.id, genre: 'F', nom: 'Seniors F'),
      equipe(categorieId: u18.id, genre: 'M', nom: 'U18 A'),
      equipe(categorieId: seniors.id, genre: 'M', nom: 'Seniors A'),
    ];

    expect(rangerEquipes(desordre, categories).map((e) => e.nom).toList(), [
      'Seniors A',
      'Seniors B',
      'Seniors F',
      'U18 A',
      'U18 F',
      'U15',
      'U15 F',
    ]);
  });

  test('l’ordre interne au groupe est respecté, pas l’alphabet', () {
    // Le cas qui a motivé la colonne `ordre` : U18 A passe avant U17,
    // alors que « U17 » vient avant « U18 A » dans l'alphabet.
    final duGroupe = [
      equipe(categorieId: u18.id, genre: 'M', nom: 'U17', ordre: 2),
      equipe(categorieId: u18.id, genre: 'M', nom: 'U18 A', ordre: 1),
    ];
    expect(rangerEquipes(duGroupe, categories).map((e) => e.nom).toList(), [
      'U18 A',
      'U17',
    ]);
  });

  test('une catégorie inconnue se range en dernier sans faire tomber le tri', () {
    final avecOrpheline = [
      equipe(categorieId: 'c-disparue', genre: 'M', nom: 'Vétérans'),
      equipe(categorieId: seniors.id, genre: 'M', nom: 'Seniors A'),
    ];
    expect(
      rangerEquipes(avecOrpheline, categories).map((e) => e.nom).toList(),
      ['Seniors A', 'Vétérans'],
    );
  });

  test('la liste reçue n’est pas modifiée', () {
    final origine = [
      equipe(categorieId: u15.id, genre: 'M', nom: 'U15'),
      equipe(categorieId: seniors.id, genre: 'M', nom: 'Seniors A'),
    ];
    final copie = [...origine];
    rangerEquipes(origine, categories);
    expect(origine.map((e) => e.nom), copie.map((e) => e.nom));
  });
}
