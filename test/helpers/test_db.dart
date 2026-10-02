import 'package:smart_broker/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _ffiReady = false;

/// Points [DatabaseHelper] at a fresh, empty in-memory SQLite database
/// (desktop ffi, no device needed). Call from `setUp`.
Future<void> useFreshTestDatabase() async {
  if (!_ffiReady) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _ffiReady = true;
  }
  DatabaseHelper.pathOverride = inMemoryDatabasePath;
  // Closing an in-memory database discards it; the next access starts empty.
  await DatabaseHelper.deleteLocalDatabase();
}

/// Call from `tearDown` so the next test file starts clean.
Future<void> closeTestDatabase() => DatabaseHelper.deleteLocalDatabase();
