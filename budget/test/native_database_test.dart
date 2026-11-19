import 'dart:async';
import 'dart:io';

import 'package:budget/database/platform/native.dart' as native;
import 'package:budget/database/tables.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TemporaryDocumentsProvider extends PathProviderPlatform {
  _TemporaryDocumentsProvider(this.directory);

  final String directory;

  @override
  Future<String?> getApplicationDocumentsPath() async => directory;
}

Future<void> _storeSetting(FinanceDatabase database, String value) async {
  await database.into(database.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion(
          settingsPk: const Value(0),
          settingsJSON: Value(value),
          dateUpdated: Value(DateTime(2026, 1, 1)),
        ),
      );
}

Future<int> _schemaVersion(FinanceDatabase database) async {
  final row = await database.customSelect('PRAGMA user_version').getSingle();
  return row.read<int>('user_version');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late PathProviderPlatform originalPathProvider;
  final openDatabases = <FinanceDatabase>{};

  Future<FinanceDatabase> openDatabase(String name) async {
    final database = await native.constructDb(name);
    openDatabases.add(database);
    return database;
  }

  Future<void> closeDatabase(FinanceDatabase database) async {
    await database.close();
    openDatabases.remove(database);
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cashew-native-test-');
    originalPathProvider = PathProviderPlatform.instance;
    PathProviderPlatform.instance =
        _TemporaryDocumentsProvider(directory.path);
  });

  tearDown(() async {
    try {
      for (final database in openDatabases.toList().reversed) {
        await closeDatabase(database);
      }
    } finally {
      PathProviderPlatform.instance = originalPathProvider;
      await directory.delete(recursive: true);
    }
  });

  test('native connection reads writes and notifies watched queries', () async {
    final database = await openDatabase('watched');
    await _storeSetting(database, '{"probe":1}');
    expect((await database.getSettings()).settingsJSON, '{"probe":1}');

    final rows = StreamIterator(database.select(database.appSettings).watch());
    try {
      expect(await rows.moveNext().timeout(const Duration(seconds: 5)), isTrue);
      expect(rows.current.single.settingsJSON, '{"probe":1}');

      await _storeSetting(database, '{"probe":2}');
      expect(await rows.moveNext().timeout(const Duration(seconds: 5)), isTrue);
      expect(rows.current.single.settingsJSON, '{"probe":2}');
      expect((await database.getSettings()).settingsJSON, '{"probe":2}');
    } finally {
      await rows.cancel();
    }
  });

  test('failed transaction rolls back and later writes still work', () async {
    final database = await openDatabase('rollback');
    await _storeSetting(database, '{"state":"before"}');

    await expectLater(
      database.transaction(() async {
        await _storeSetting(database, '{"state":"uncommitted"}');
        throw StateError('Cancel the transaction');
      }),
      throwsA(isA<StateError>()),
    );

    expect((await database.getSettings()).settingsJSON,
        '{"state":"before"}');
    await _storeSetting(database, '{"state":"after"}');
    expect((await database.getSettings()).settingsJSON, '{"state":"after"}');
  });

  test('opens an existing database and preserves data across close and reopen',
      () async {
    // Seed a file with the foreground executor used by earlier app versions.
    final file = File(p.join(directory.path, 'existing.sqlite'));
    final previousDatabase = FinanceDatabase(NativeDatabase(file));
    openDatabases.add(previousDatabase);
    const savedSettings = '{"username":"existing-user","probe":42}';
    await _storeSetting(previousDatabase, savedSettings);
    final existingVersion = await _schemaVersion(previousDatabase);
    expect(existingVersion, schemaVersionGlobal);
    await closeDatabase(previousDatabase);
    expect(await file.exists(), isTrue);

    final database = await openDatabase('existing');
    expect((await database.getSettings()).settingsJSON, savedSettings);
    expect(await _schemaVersion(database), existingVersion);
    await _storeSetting(database, '{"username":"existing-user","probe":43}');
    await closeDatabase(database);

    final reopened = await openDatabase('existing');
    expect((await reopened.getSettings()).settingsJSON,
        '{"username":"existing-user","probe":43}');
    expect(await _schemaVersion(reopened), existingVersion);
    await closeDatabase(reopened);

    // Closing the background connection must release the database file too.
    final renamed = await file.rename(p.join(directory.path, 'closed.sqlite'));
    await renamed.delete();
  });

  test('a heavy SELECT leaves the main isolate event loop responsive', () async {
    final database = await openDatabase('responsive');
    // Warm the connection so opening the database cannot provide the only yield.
    await database.customSelect('SELECT 1 AS ready').getSingle();

    var heartbeats = 0;
    var queryFinished = false;
    final heartbeat = Timer.periodic(const Duration(milliseconds: 1), (_) {
      if (!queryFinished) heartbeats++;
    });
    try {
      // A SELECT is important: the former MultiExecutor already put writes in
      // the background, but ran reads synchronously on the main isolate.
      final row = await database.customSelect('''
        WITH RECURSIVE counter(value) AS (
          SELECT 1
          UNION ALL
          SELECT value + 1 FROM counter WHERE value < 1000000
        )
        SELECT SUM(value) AS total FROM counter
      ''').getSingle();
      queryFinished = true;
      expect(row.read<int>('total'), 500000500000);
      expect(heartbeats, greaterThan(0),
          reason: 'The UI isolate must process timer events while SQLite reads '
              'run; this checks event-loop progress, not a device FPS target.');
    } finally {
      queryFinished = true;
      heartbeat.cancel();
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
