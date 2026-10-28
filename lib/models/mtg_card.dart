/// Uma impressão específica de uma carta (edição + número + idioma),
/// com os dados que o app usa vindos da API do Scryfall.
class MtgCard {
  const MtgCard({
    required this.id,
    required this.oracleId,
    required this.name,
    this.printedName,
    required this.lang,
    required this.setCode,
    required this.setName,
    required this.collectorNumber,
    required this.rarity,
    required this.typeLine,
    required this.manaCost,
    required this.cmc,
    required this.colors,
    required this.finishes,
    this.imageSmall,
    this.imageNormal,
    this.priceUsd,
    this.priceUsdFoil,
    this.priceEur,
    required this.releasedAt,
  });

  final String id;
  final String? oracleId;
  final String name;
  final String? printedName;
  final String lang;
  final String setCode;
  final String setName;
  final String collectorNumber;
  final String rarity;
  final String typeLine;
  final String manaCost;
  final double cmc;
  final List<String> colors;
  final List<String> finishes;
  final String? imageSmall;
  final String? imageNormal;
  final double? priceUsd;
  final double? priceUsdFoil;
  final double? priceEur;
  final String releasedAt;

  /// Converte o JSON de uma carta do Scryfall. Cartas de duas faces
  /// guardam imagem, cores e custo dentro de `card_faces`.
  factory MtgCard.fromScryfall(Map<String, dynamic> j) {
    final faces = (j['card_faces'] as List?)?.cast<Map<String, dynamic>>();
    final firstFace = (faces != null && faces.isNotEmpty) ? faces.first : null;

    final images = (j['image_uris'] ?? firstFace?['image_uris']) as Map<String, dynamic>?;

    List<String> colors;
    if (j['colors'] is List) {
      colors = (j['colors'] as List).cast<String>();
    } else if (faces != null) {
      colors = faces.expand((f) => ((f['colors'] as List?) ?? const []).cast<String>()).toSet().toList();
    } else {
      colors = const [];
    }

    var manaCost = j['mana_cost'] as String?;
    if ((manaCost == null || manaCost.isEmpty) && faces != null) {
      manaCost = faces.map((f) => (f['mana_cost'] as String?) ?? '').where((c) => c.isNotEmpty).join(' // ');
    }

    final prices = (j['prices'] as Map<String, dynamic>?) ?? const {};
    double? price(String key) => double.tryParse('${prices[key] ?? ''}');

    return MtgCard(
      id: j['id'] as String,
      oracleId: (j['oracle_id'] ?? firstFace?['oracle_id']) as String?,
      name: j['name'] as String,
      printedName: (j['printed_name'] ?? firstFace?['printed_name']) as String?,
      lang: (j['lang'] as String?) ?? 'en',
      setCode: (j['set'] as String?) ?? '',
      setName: (j['set_name'] as String?) ?? '',
      collectorNumber: (j['collector_number'] as String?) ?? '',
      rarity: (j['rarity'] as String?) ?? 'common',
      typeLine: (j['type_line'] ?? firstFace?['type_line'] ?? '') as String,
      manaCost: manaCost ?? '',
      cmc: ((j['cmc'] as num?) ?? 0).toDouble(),
      colors: colors,
      finishes: ((j['finishes'] as List?) ?? const ['nonfoil']).cast<String>(),
      imageSmall: images?['small'] as String?,
      imageNormal: images?['normal'] as String?,
      priceUsd: price('usd'),
      priceUsdFoil: price('usd_foil') ?? price('usd_etched'),
      priceEur: price('eur'),
      releasedAt: (j['released_at'] as String?) ?? '',
    );
  }

  /// Formato compacto salvo no banco local.
  Map<String, dynamic> toJson() => {
        'id': id,
        'oracleId': oracleId,
        'name': name,
        'printedName': printedName,
        'lang': lang,
        'setCode': setCode,
        'setName': setName,
        'collectorNumber': collectorNumber,
        'rarity': rarity,
        'typeLine': typeLine,
        'manaCost': manaCost,
        'cmc': cmc,
        'colors': colors,
        'finishes': finishes,
        'imageSmall': imageSmall,
        'imageNormal': imageNormal,
        'priceUsd': priceUsd,
        'priceUsdFoil': priceUsdFoil,
        'priceEur': priceEur,
        'releasedAt': releasedAt,
      };

  factory MtgCard.fromJson(Map<String, dynamic> j) => MtgCard(
        id: j['id'] as String,
        oracleId: j['oracleId'] as String?,
        name: j['name'] as String,
        printedName: j['printedName'] as String?,
        lang: j['lang'] as String,
        setCode: j['setCode'] as String,
        setName: j['setName'] as String,
        collectorNumber: j['collectorNumber'] as String,
        rarity: j['rarity'] as String,
        typeLine: j['typeLine'] as String,
        manaCost: j['manaCost'] as String,
        cmc: (j['cmc'] as num).toDouble(),
        colors: (j['colors'] as List).cast<String>(),
        finishes: (j['finishes'] as List).cast<String>(),
        imageSmall: j['imageSmall'] as String?,
        imageNormal: j['imageNormal'] as String?,
        priceUsd: (j['priceUsd'] as num?)?.toDouble(),
        priceUsdFoil: (j['priceUsdFoil'] as num?)?.toDouble(),
        priceEur: (j['priceEur'] as num?)?.toDouble(),
        releasedAt: j['releasedAt'] as String,
      );

  /// Nome impresso (ex.: em português) quando existir.
  String get displayName => printedName ?? name;

  bool get hasFoil => finishes.contains('foil') || finishes.contains('etched');
  bool get hasNonFoil => finishes.contains('nonfoil');

  /// Preço em dólar da versão normal ou foil, usando a outra como reserva.
  double? priceFor({required bool foil}) => foil ? (priceUsdFoil ?? priceUsd) : (priceUsd ?? priceUsdFoil);
}
