import 'mtg_card.dart';

class Collection {
  const Collection({required this.id, required this.name});

  final int id;
  final String name;
}

/// Uma linha da coleção: quantas cópias de uma impressão, em que estado.
class CollectionEntry {
  const CollectionEntry({
    required this.id,
    required this.collectionId,
    required this.card,
    required this.quantity,
    required this.foil,
    required this.condition,
    required this.language,
    required this.addedAt,
  });

  final int id;
  final int collectionId;
  final MtgCard card;
  final int quantity;
  final bool foil;
  final String condition;
  final String language;
  final DateTime addedAt;

  double get valueUsd => (card.priceFor(foil: foil) ?? 0) * quantity;
}

/// Dados editáveis de uma entrada (usado ao adicionar e ao editar).
class EntryData {
  const EntryData({
    required this.collectionId,
    required this.quantity,
    required this.foil,
    required this.condition,
    required this.language,
  });

  final int collectionId;
  final int quantity;
  final bool foil;
  final String condition;
  final String language;
}

const conditions = {
  'NM': 'NM – Praticamente nova',
  'SP': 'SP – Levemente jogada',
  'MP': 'MP – Moderadamente jogada',
  'HP': 'HP – Muito jogada',
  'D': 'D – Danificada',
};

const languages = {
  'en': 'Inglês',
  'pt': 'Português',
  'es': 'Espanhol',
  'fr': 'Francês',
  'de': 'Alemão',
  'it': 'Italiano',
  'ja': 'Japonês',
  'ko': 'Coreano',
  'ru': 'Russo',
  'zhs': 'Chinês simplificado',
  'zht': 'Chinês tradicional',
  'ph': 'Phyrexiano',
};

const rarities = {
  'common': 'Comum',
  'uncommon': 'Incomum',
  'rare': 'Rara',
  'mythic': 'Mítica',
  'special': 'Especial',
  'bonus': 'Bônus',
};

/// Tipo exibido → texto procurado na linha de tipo (sempre em inglês).
const cardTypes = {
  'Criatura': 'Creature',
  'Instantânea': 'Instant',
  'Feitiço': 'Sorcery',
  'Artefato': 'Artifact',
  'Encantamento': 'Enchantment',
  'Planeswalker': 'Planeswalker',
  'Terreno': 'Land',
  'Batalha': 'Battle',
};
