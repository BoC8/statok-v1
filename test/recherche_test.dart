import 'package:flutter_test/flutter_test.dart';
import 'package:statok/models/recherche.dart';

void main() {
  group('sansAccents', () {
    test('replie les voyelles accentuées du français', () {
      expect(sansAccents('Guémené'), 'guemene');
      expect(sansAccents('Héric'), 'heric');
      expect(sansAccents('Loïc'), 'loic');
      expect(sansAccents('Clément'), 'clement');
      expect(sansAccents('Noël'), 'noel');
      expect(sansAccents('Françoise'), 'francoise');
    });

    test('replie aussi la forme décomposée', () {
      // « é » écrit en deux temps : un e, puis l'accent aigu combinant.
      expect(sansAccents('Guémené'), 'guemene');
    });

    test('les ligatures se déplient en deux lettres', () {
      expect(sansAccents('Sœur'), 'soeur');
      expect(sansAccents('Lætitia'), 'laetitia');
    });

    test('ce qui n’est pas une lettre accentuée ne bouge pas', () {
      expect(sansAccents('Nort sur Erdre 2'), 'nort sur erdre 2');
      expect(sansAccents('Vay-Marsac 1'), 'vay-marsac 1');
      expect(sansAccents(''), '');
    });
  });

  group('correspond', () {
    test('trouve un nom accentué sans taper les accents', () {
      expect(correspond('Guémené 2', 'guem'), isTrue);
      expect(correspond('Héric 1', 'heric'), isTrue);
      expect(correspond('Clément Bolomey', 'clement'), isTrue);
    });

    test('et l’inverse : le terme accentué trouve le nom nu', () {
      expect(correspond('Guemene 2', 'Guémé'), isTrue);
    });

    test('la casse et les espaces autour ne comptent pas', () {
      expect(correspond('Derval SC 1', '  DERVAL '), isTrue);
    });

    test('un terme vide laisse tout passer', () {
      expect(correspond('Nozay OS 2', ''), isTrue);
      expect(correspond('Nozay OS 2', '   '), isTrue);
    });

    test('ne trouve pas ce qui n’y est pas', () {
      expect(correspond('Guémené 2', 'nozay'), isFalse);
    });
  });

  group('memeNom', () {
    test('deux orthographes du même club sont le même nom', () {
      expect(memeNom('Guémené 2', 'Guemene 2'), isTrue);
      expect(memeNom('Héric 1', 'heric 1'), isTrue);
      expect(memeNom('Derval SC 1', ' derval sc 1 '), isTrue);
    });

    test('deux clubs différents restent différents', () {
      expect(memeNom('Guémené 1', 'Guémené 2'), isFalse);
      expect(memeNom('Vay-Marsac 1', 'Vay Marsac 1'), isFalse);
    });
  });
}
