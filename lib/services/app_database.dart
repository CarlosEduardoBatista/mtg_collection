import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/collection.dart';
import '../models/mtg_card.dart';

/// Banco SQLite local com coleções, cartas (cache do Scryfall) e entradas.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static Future<AppDatabase> open() async {
    final path = p.join(await getDatabasesPath(), 'mtg_colecao.db');
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE collections(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE cards(
            id TEXT PRIMARY KEY,
            data TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE entries(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            collection_id INTEGER NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
            card_id TEXT NOT NULL REFERENCES cards(id),
            quantity INTEGER NOT NULL,
            foil INTEGER NOT NULL,
            condition TEXT NOT NULL,
            language TEXT NOT NULL,
            added_at INTEGER NOT NULL,
            UNIQUE(collection_id, card_id, foil, condition, language)
          )''');
        await db.execute('CREATE TABLE settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
      },
    );
    return AppDatabase._(db);
  }

  // ---- Coleções ----

  Future<List<Collection>> collections() async {
    final rows = await _db.query('collections', orderBy: 'name COLLATE NOCASE');
    return [for (final r in rows) Collection(id: r['id'] as int, name: r['name'] as String)];
  }

  Future<int> createCollection(String name) =>
      _db.insert('collections', {'name': name, 'created_at': DateTime.now().millisecondsSinceEpoch});

  Future<void> renameCollection(int id, String name) =>
      _db.update('collections', {'name': name}, where: 'id = ?', whereArgs: [id]);

  Future<void> deleteCollection(int id) => _db.delete('collections', where: 'id = ?', whereArgs: [id]);

  // ---- Cartas ----

  Future<void> upsertCards(Iterable<MtgCard> cards, [DatabaseExecutor? exec]) async {
    final batch = (exec ?? _db).batch();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final card in cards) {
      batch.insert('cards', {'id': card.id, 'data': jsonEncode(card.toJson()), 'updated_at': now},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  // ---- Entradas ----

  Future<List<CollectionEntry>> entries() async {
    final rows = await _db.rawQuery('''
      SELECT e.*, c.data AS card_data FROM entries e JOIN cards c ON c.id = e.card_id
    ''');
    return [
      for (final r in rows)
        CollectionEntry(
          id: r['id'] as int,
          collectionId: r['collection_id'] as int,
          card: MtgCard.fromJson(jsonDecode(r['card_data'] as String) as Map<String, dynamic>),
          quantity: r['quantity'] as int,
          foil: r['foil'] == 1,
          condition: r['condition'] as String,
          language: r['language'] as String,
          addedAt: DateTime.fromMillisecondsSinceEpoch(r['added_at'] as int),
        )
    ];
  }

  /// Adiciona cópias; se já existir a mesma carta/estado na coleção, soma a quantidade.
  Future<void> addEntry(MtgCard card, EntryData data) => _db.transaction((txn) async {
        await upsertCards([card], txn);
        await _mergeInto(txn, card.id, data, data.quantity);
      });

  /// Edita uma entrada. Se ela passar a ser igual a outra, as duas são unidas.
  Future<void> updateEntry(int entryId, String cardId, EntryData data) => _db.transaction((txn) async {
        final existing = await _findSame(txn, cardId, data, excludeId: entryId);
        if (existing != null) {
          await txn.rawUpdate('UPDATE entries SET quantity = quantity + ? WHERE id = ?', [data.quantity, existing]);
          await txn.delete('entries', where: 'id = ?', whereArgs: [entryId]);
        } else {
          await txn.update('entries', _values(data), where: 'id = ?', whereArgs: [entryId]);
        }
      });

  Future<void> deleteEntry(int entryId) => _db.delete('entries', where: 'id = ?', whereArgs: [entryId]);

  Future<void> _mergeInto(Transaction txn, String cardId, EntryData data, int quantity) async {
    final existing = await _findSame(txn, cardId, data);
    if (existing != null) {
      await txn.rawUpdate('UPDATE entries SET quantity = quantity + ? WHERE id = ?', [quantity, existing]);
    } else {
      await txn.insert('entries', {
        ..._values(data),
        'card_id': cardId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
  }

  Future<int?> _findSame(Transaction txn, String cardId, EntryData data, {int? excludeId}) async {
    final rows = await txn.query(
      'entries',
      columns: ['id'],
      where: 'collection_id = ? AND card_id = ? AND foil = ? AND condition = ? AND language = ? AND id != ?',
      whereArgs: [data.collectionId, cardId, data.foil ? 1 : 0, data.condition, data.language, excludeId ?? -1],
    );
    return rows.isEmpty ? null : rows.first['id'] as int;
  }

  Map<String, Object> _values(EntryData data) => {
        'collection_id': data.collectionId,
        'quantity': data.quantity,
        'foil': data.foil ? 1 : 0,
        'condition': data.condition,
        'language': data.language,
      };

  // ---- Configurações ----

  Future<String?> setting(String key) async {
    final rows = await _db.query('settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setSetting(String key, String? value) async {
    if (value == null) {
      await _db.delete('settings', where: 'key = ?', whereArgs: [key]);
    } else {
      await _db.insert('settings', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}
