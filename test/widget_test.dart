import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_colecao/models/mtg_card.dart';

void main() {
  test('converte carta simples do Scryfall', () {
    final card = MtgCard.fromScryfall({
      'id': 'abc',
      'oracle_id': 'o1',
      'name': 'Lightning Bolt',
      'lang': 'en',
      'set': 'm10',
      'set_name': 'Magic 2010',
      'collector_number': '146',
      'rarity': 'common',
      'type_line': 'Instant',
      'mana_cost': '{R}',
      'cmc': 1.0,
      'colors': ['R'],
      'finishes': ['nonfoil', 'foil'],
      'image_uris': {'small': 's.jpg', 'normal': 'n.jpg'},
      'prices': {'usd': '1.50', 'usd_foil': '10.00', 'eur': null},
      'released_at': '2009-07-17',
    });

    expect(card.priceFor(foil: false), 1.5);
    expect(card.priceFor(foil: true), 10.0);
    expect(card.priceEur, isNull);
    expect(card.hasFoil && card.hasNonFoil, isTrue);

    final restored = MtgCard.fromJson(card.toJson());
    expect(restored.name, 'Lightning Bolt');
    expect(restored.colors, ['R']);
  });

  test('carta de duas faces usa imagem e cores das faces', () {
    final card = MtgCard.fromScryfall({
      'id': 'dfc',
      'name': 'Delver of Secrets // Insectile Aberration',
      'set': 'isd',
      'set_name': 'Innistrad',
      'collector_number': '51',
      'rarity': 'common',
      'type_line': 'Creature — Human Wizard // Creature — Human Insect',
      'cmc': 1,
      'prices': {'usd': null, 'usd_foil': '3.00'},
      'card_faces': [
        {
          'oracle_id': 'o2',
          'mana_cost': '{U}',
          'colors': ['U'],
          'image_uris': {'small': 'front.jpg', 'normal': 'front_n.jpg'},
        },
        {'mana_cost': '', 'colors': ['U']},
      ],
    });

    expect(card.imageSmall, 'front.jpg');
    expect(card.colors, ['U']);
    expect(card.manaCost, '{U}');
    expect(card.oracleId, 'o2');
    expect(card.priceFor(foil: false), 3.0);
  });
}
