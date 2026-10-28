import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../models/collection.dart';
import '../models/mtg_card.dart';
import '../services/app_database.dart';
import '../services/scryfall_api.dart';

/// Estado do app: coleções e entradas em memória, sincronizadas com o SQLite.
class CollectionStore extends ChangeNotifier {
  CollectionStore(this._db, this.api);

  final AppDatabase _db;
  final ScryfallApi api;

  List<Collection> collections = const [];
  List<CollectionEntry> entries = const [];

  /// Cotação do dólar em reais definida pelo usuário (null = mostrar em US$).
  double? dollarRate;

  static final _usd = NumberFormat.currency(locale: 'en_US', symbol: r'US$ ');
  static final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$ ');

  Future<void> load() async {
    collections = await _db.collections();
    entries = await _db.entries();
    dollarRate = double.tryParse(await _db.setting('dollar_rate') ?? '');
    notifyListeners();
  }

  Collection? collectionById(int id) => collections.where((c) => c.id == id).firstOrNull;
  CollectionEntry? entryById(int id) => entries.where((e) => e.id == id).firstOrNull;

  /// Entradas de uma coleção, ou de todas quando [collectionId] é null.
  List<CollectionEntry> entriesOf(int? collectionId) =>
      collectionId == null ? entries : entries.where((e) => e.collectionId == collectionId).toList();

  int cardCount(int? collectionId) => entriesOf(collectionId).fold(0, (sum, e) => sum + e.quantity);
  double valueUsd(int? collectionId) => entriesOf(collectionId).fold(0.0, (sum, e) => sum + e.valueUsd);

  String formatMoney(double? usd) {
    if (usd == null) return 'sem preço';
    final rate = dollarRate;
    return rate == null ? _usd.format(usd) : _brl.format(usd * rate);
  }

  Future<void> setDollarRate(double? rate) async {
    await _db.setSetting('dollar_rate', rate?.toString());
    await load();
  }

  Future<int> createCollection(String name) async {
    final id = await _db.createCollection(name);
    await load();
    return id;
  }

  Future<void> renameCollection(int id, String name) async {
    await _db.renameCollection(id, name);
    await load();
  }

  Future<void> deleteCollection(int id) async {
    await _db.deleteCollection(id);
    await load();
  }

  Future<void> addEntry(MtgCard card, EntryData data) async {
    await _db.addEntry(card, data);
    await load();
  }

  Future<void> updateEntry(CollectionEntry entry, EntryData data) async {
    await _db.updateEntry(entry.id, entry.card.id, data);
    await load();
  }

  Future<void> deleteEntry(int id) async {
    await _db.deleteEntry(id);
    await load();
  }

  /// Baixa os preços atuais de todas as cartas da coleção. Retorna quantas foram atualizadas.
  Future<int> refreshPrices() async {
    final ids = entries.map((e) => e.card.id).toSet().toList();
    if (ids.isEmpty) return 0;
    final cards = await api.cardsByIds(ids);
    await _db.upsertCards(cards);
    await load();
    return cards.length;
  }
}
