import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';

import 'crud_exceptions.dart';

const dbName = "notes.db";

class NotesService {
  Database? _db;

  Future<void> open() async {
    if (_db != null) {
      throw DatabaseAlreadyOpenException();
    }
    try {
      final docsPath = await getApplicationDocumentsDirectory();
      final dbPath = join(docsPath.path, dbName);
      final db = await openDatabase(dbPath);

      _db = db;
      const createUserTable = '''CREATE TABLE IF NOT EXISTS "user" (
          "id"	INTEGER NOT NULL,
          "email"	TEXT NOT NULL UNIQUE,
          PRIMARY KEY("id" AUTOINCREMENT)
        );
      ''';
      await db.execute(createUserTable);
      const createNoteTable = '''CREATE TABLE "note" (
	    "id"	INTEGER NOT NULL,
	    "user_id"	INTEGER NOT NULL,
	    "text"	TEXT,
	    "is_synced_with_cloud"	INTEGER NOT NULL,
	    FOREIGN KEY("user_id") REFERENCES "user"("id"),
	    PRIMARY KEY("id" AUTOINCREMENT)
     );''';
      await db.execute(createNoteTable);
    } on MissingPlatformDirectoryException {
      throw UnableToGetDocumentsDirectory();
    }
  }

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    } else {
      throw DatabaseClosedException();
    }
  }

  Future<DatabaseUser> getUser(String email) async {
    final db = _getDatabaseOrThrow();
    final results = await db.query(DatabaseUser.userTable,
        limit: 1, where: 'email = ?', whereArgs: [email.toLowerCase()]);
    if (results.isEmpty) {
      throw EntityNotFoundException(email);
    }
    return DatabaseUser.fromRow(results.first);
  }

  Future<DatabaseUser> createUser(String email) async {
    final db = _getDatabaseOrThrow();
    final results = await db.query(DatabaseUser.userTable,
        limit: 1, where: 'email = ?', whereArgs: [email.toLowerCase()]);
    if (results.isNotEmpty) {
      throw UserAlreadyExistsException("User $email already exists");
    }
    var userId = await db
        .insert(DatabaseUser.userTable, {DatabaseUser.emailColumn: email});
    return DatabaseUser(id: userId, email: email);
  }

  Future<void> deleteUser({required String email}) async {
    final db = _getDatabaseOrThrow();
    final deletedCount = await db.delete(DatabaseUser.userTable,
        where: 'email = ', whereArgs: [email.toLowerCase()]);
    if (deletedCount != 1) {
      throw DeleteException("Could not delete the user $email");
    }
  }

  Future<void> deleteNote({required int id}) async {
    final db = _getDatabaseOrThrow();
    final deletedCount = await db
        .delete(DatabaseNote.noteTable, where: 'id = ?', whereArgs: [id]);
    if (deletedCount == 0) {
      throw DeleteException("Could not delete note");
    }
  }

  Future<int> deleteAllNotes({required int id}) async {
    final db = _getDatabaseOrThrow();
    return await db
        .delete(DatabaseNote.noteTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<DatabaseNote> getNote({required int id}) async {
    final db = _getDatabaseOrThrow();
    final notes = await db.query(
      DatabaseNote.noteTable,
      limit: 1,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (notes.isEmpty) {
      throw EntityNotFoundException("Could not find note");
    } else {
      return DatabaseNote.fromRow(notes.first);
    }
  }

  Future<Iterable<DatabaseNote>> getAllNotes() async {
    final db = _getDatabaseOrThrow();
    final notes = await db.query(DatabaseNote.noteTable);
    return notes.map((noteRow) => DatabaseNote.fromRow(noteRow));
  }

  Future<DatabaseNote> createNote({required DatabaseUser owner}) async {
    final db = _getDatabaseOrThrow();
    final dbUser = getUser(owner.email);
    // Maker sure ower exists with the correct id
    if (dbUser != owner) {
      throw EntityNotFoundException("User id doesn't match");
    }
    const text = "";
    // Create the note
    final noteId = await db.insert(DatabaseNote.noteTable, {
      DatabaseNote.userIdColumn: owner.id,
      DatabaseNote.textColumn: text,
      DatabaseNote.isSyncedWithCloudColumn: 1,
    });
    return DatabaseNote(
        id: noteId, userId: owner.id, text: text, isSyncedWithCloud: true);
  }

  Future<DatabaseNote> updateNote(
      {required DatabaseNote note, required String text}) async {
    final db = _getDatabaseOrThrow();
    await getNote(id: note.id);
    final updatesCount = await db.update(
      DatabaseNote.noteTable,
      {
        DatabaseNote.textColumn: text,
        DatabaseNote.isSyncedWithCloudColumn: 0,
      },
      where: 'id = ?',
      whereArgs: [note.id],
    );
    if (updatesCount == 0) {
      throw EntityNotFoundException("No notes where found");
    } else {
      return await getNote(id: note.id);
    }
  }

  Database _getDatabaseOrThrow() {
    final db = _db;
    if (db == null) throw DatabaseClosedException();
    return db;
  }
}

class DatabaseUser {
  final int id;
  final String email;

  static const userTable = "user";
  static const idColumn = "id";
  static const emailColumn = "email";

  DatabaseUser({
    required this.id,
    required this.email,
  });

  DatabaseUser.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        email = map[emailColumn] as String;

  @override
  String toString() {
    // TODO: implement toString
    return 'Person, ID = $id, email = $email';
  }

  @override
  bool operator ==(covariant DatabaseUser other) {
    return id == other.id && email == other.email;
  }

  @override
  // TODO: implement hashCode
  int get hashCode => id.hashCode;
}

class DatabaseNote {
  static const noteTable = "note";
  static const idColumn = "id";
  static const userIdColumn = "user_id";
  static const textColumn = "text";
  static const isSyncedWithCloudColumn = "is_synced_with_cloud";

  final int id;
  final int userId;
  final String text;
  final bool isSyncedWithCloud;

  DatabaseNote({
    required this.id,
    required this.userId,
    required this.text,
    required this.isSyncedWithCloud,
  });

  DatabaseNote.fromRow(Map<String, Object?> map)
      : id = map[idColumn] as int,
        userId = map[userIdColumn] as int,
        text = map[textColumn] as String,
        isSyncedWithCloud = (map[isSyncedWithCloudColumn] as int) == 1;

  @override
  String toString() {
    return "Note, ID = $id, userId = $userId, isSyncedWithCloud = $isSyncedWithCloud, text = $text";
  }

  @override
  bool operator ==(covariant DatabaseNote other) {
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;
}