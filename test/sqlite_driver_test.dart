// The sqlite driver: open, read, write, close, and roll back.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_driver_forge/sqlite3_driver_forge.dart';

Future<void> _create(SqliteDriver db) async {
  await db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, v TEXT NOT NULL)');
}

void main() {
  test('an in-memory database round-trips rows', () async {
    final db = SqliteDriver.inMemory();
    await db.connect();
    try {
      await _create(db);

      final rowid = await db.insert('INSERT INTO t (v) VALUES (?)', ['hi']);
      expect(rowid, 1);

      final rows = await db.query('SELECT id, v FROM t');
      expect(rows, [
        {'id': 1, 'v': 'hi'},
      ]);
    } finally {
      await db.disconnect();
    }
  });

  test('a file database survives disconnect', () async {
    final dir = await Directory.systemTemp.createTemp('stashify-driver.');
    addTearDown(() => dir.delete(recursive: true));
    final path = p.join(dir.path, 's.db');

    final first = SqliteDriver.file(path);
    await first.connect();
    try {
      await _create(first);
      await first.insert('INSERT INTO t (v) VALUES (?)', ['kept']);
    } finally {
      await first.disconnect();
    }

    final second = SqliteDriver.file(path);
    await second.connect();
    try {
      final rows = await second.query('SELECT v FROM t');
      expect(rows, [
        {'v': 'kept'},
      ]);
    } finally {
      await second.disconnect();
    }
  });

  test('a transaction rolls back when the body throws', () async {
    final db = SqliteDriver.inMemory();
    await db.connect();
    try {
      await _create(db);

      await expectLater(
        db.transaction((txn) async {
          await txn.execute("INSERT INTO t (v) VALUES ('lost')");
          throw StateError('boom');
        }),
        throwsStateError,
      );

      expect(await db.query('SELECT v FROM t'), isEmpty);
    } finally {
      await db.disconnect();
    }
  });
}
