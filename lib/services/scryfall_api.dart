import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/mtg_card.dart';

class ScryfallException implements Exception {
  ScryfallException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cliente da API pública do Scryfall (https://scryfall.com/docs/api).
/// O Scryfall pede User-Agent/Accept e no máximo ~10 requisições por segundo.
class ScryfallApi {
  ScryfallApi({http.Client? client}) : _client = client ?? http.Client();

  static const _host = 'api.scryfall.com';
  static const _headers = {
    'User-Agent': 'MtgColecao/1.0',
    'Accept': 'application/json',
  };
  static const _minInterval = Duration(milliseconds: 100);

  final http.Client _client;
  Future<void> _queue = Future.value();
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  Future<void> _throttle() {
    final next = _queue.then((_) async {
      final wait = _minInterval - DateTime.now().difference(_last);
      if (wait > Duration.zero) await Future.delayed(wait);
      _last = DateTime.now();
    });
    _queue = next;
    return next;
  }

  Future<Map<String, dynamic>?> _get(String path, Map<String, String> params) async {
    await _throttle();
    final res = await _client
        .get(Uri.https(_host, path, params), headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Map<String, dynamic>? _decode(http.Response res) {
    if (res.statusCode == 404) return null;
    final Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } on FormatException {
      throw ScryfallException('Resposta inválida do Scryfall (${res.statusCode})');
    }
    if (res.statusCode >= 400) {
      throw ScryfallException((body['details'] as String?) ?? 'Erro ${res.statusCode} no Scryfall');
    }
    return body;
  }

  List<MtgCard> _cards(Map<String, dynamic>? body) =>
      ((body?['data'] as List?) ?? const []).cast<Map<String, dynamic>>().map(MtgCard.fromScryfall).toList();

  /// Sugestões de nomes (em inglês) enquanto o usuário digita.
  Future<List<String>> autocomplete(String text) async {
    final body = await _get('/cards/autocomplete', {'q': text});
    return ((body?['data'] as List?) ?? const []).cast<String>();
  }

  /// Busca com a sintaxe completa do Scryfall (ex.: "t:dragon c:r").
  Future<List<MtgCard>> search(String query, {bool prints = false, bool multilingual = false}) async {
    final body = await _get('/cards/search', {
      'q': query,
      'unique': prints ? 'prints' : 'cards',
      'order': prints ? 'released' : 'name',
      if (multilingual) 'include_multilingual': 'true',
    });
    return _cards(body);
  }

  /// Todas as impressões (edições) de uma carta.
  Future<List<MtgCard>> printsOf(MtgCard card, {bool allLanguages = false}) {
    final base = card.oracleId != null ? 'oracleid:${card.oracleId}' : '!"${card.name}"';
    return search(allLanguages ? '$base lang:any' : base, prints: true);
  }

  /// Procura pelo nome aproximado (tolera erros de digitação/OCR).
  Future<MtgCard?> named(String fuzzyName) async {
    final body = await _get('/cards/named', {'fuzzy': fuzzyName});
    return body == null ? null : MtgCard.fromScryfall(body);
  }

  /// Dados atualizados (inclusive preços) de várias cartas pelo id.
  Future<List<MtgCard>> cardsByIds(List<String> ids) async {
    final result = <MtgCard>[];
    for (var i = 0; i < ids.length; i += 75) {
      final chunk = ids.sublist(i, i + 75 > ids.length ? ids.length : i + 75);
      await _throttle();
      final res = await _client
          .post(
            Uri.https(_host, '/cards/collection'),
            headers: {..._headers, 'Content-Type': 'application/json'},
            body: jsonEncode({
              'identifiers': [for (final id in chunk) {'id': id}],
            }),
          )
          .timeout(const Duration(seconds: 30));
      result.addAll(_cards(_decode(res)));
    }
    return result;
  }
}
