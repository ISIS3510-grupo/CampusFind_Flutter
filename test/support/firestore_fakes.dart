// Firestore SDK interfaces are implemented only as local test doubles.
// ignore_for_file: subtype_of_sealed_class

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFirestore extends Fake implements FirebaseFirestore {
  FakeFirestore({
    this.documents = const {},
    this.errors = const {},
    this.beforeRead,
  });

  final Map<String, Map<String, dynamic>> documents;
  final Map<String, Object> errors;
  final Future<void>? beforeRead;
  final queries = <Map<String, Object?>>[];
  final documentReads = <String>[];

  @override
  CollectionReference<Map<String, dynamic>> collection(String collectionPath) {
    return _Collection(this, collectionPath);
  }

  Future<void> read(String path) async {
    await beforeRead;
    if (errors.containsKey(path)) throw errors[path]!;
  }
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _Collection(this.database, this.path);

  final FakeFirestore database;
  @override
  final String path;

  @override
  Query<Map<String, dynamic>> where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    Iterable<Object?>? arrayContainsAny,
    Iterable<Object?>? whereIn,
    Iterable<Object?>? whereNotIn,
    bool? isNull,
  }) {
    database.queries.add({
      'collection': path,
      'field': field,
      'isEqualTo': isEqualTo,
    });
    return _Query(database, path, field as String, isEqualTo);
  }

  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) {
    return _DocumentReference(database, '${this.path}/$path');
  }
}

class _Query extends Fake implements Query<Map<String, dynamic>> {
  _Query(this.database, this.path, this.field, this.value);

  final FakeFirestore database;
  final String path;
  final String field;
  final Object? value;

  @override
  Future<QuerySnapshot<Map<String, dynamic>>> get([GetOptions? options]) async {
    await database.read(path);
    return _QuerySnapshot([
      for (final entry in database.documents.entries)
        if (entry.key.startsWith('$path/') && entry.value[field] == value)
          _QueryDocument(entry.key.split('/').last, entry.value),
    ]);
  }
}

class _QuerySnapshot extends Fake
    implements QuerySnapshot<Map<String, dynamic>> {
  _QuerySnapshot(this.docs);

  @override
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
}

class _QueryDocument extends Fake
    implements QueryDocumentSnapshot<Map<String, dynamic>> {
  _QueryDocument(this.id, this.fields);

  @override
  final String id;
  final Map<String, dynamic> fields;

  @override
  Map<String, dynamic> data() => fields;
}

class _DocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _DocumentReference(this.database, this.path);

  final FakeFirestore database;
  @override
  final String path;

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> get([
    GetOptions? options,
  ]) async {
    database.documentReads.add(path);
    await database.read(path);
    return _DocumentSnapshot(database.documents[path]);
  }
}

class _DocumentSnapshot extends Fake
    implements DocumentSnapshot<Map<String, dynamic>> {
  _DocumentSnapshot(this.fields);

  final Map<String, dynamic>? fields;

  @override
  Map<String, dynamic>? data() => fields;
}

Map<String, dynamic> lostReportData({
  String ownerUid = 'student-1',
  String title = 'Black Calculator',
  String locationName = 'Mario Laserna',
  String status = 'reported',
  DateTime? reportedAt,
  String? imageUrl,
}) => {
  'ownerUid': ownerUid,
  'category': 'electronics',
  'title': title,
  'description': 'Black Casio scientific calculator',
  'locationName': locationName,
  'latitude': 4.60275,
  'longitude': -74.06482,
  'status': status,
  'reportedAt': Timestamp.fromDate(reportedAt ?? DateTime.now()),
  'imageUrl': imageUrl,
};

Map<String, dynamic> foundItemData({
  String status = 'available',
  DateTime? createdAt,
}) => {
  'reporterUid': 'student-2',
  'category': 'electronics',
  'title': 'Black Calculator',
  'publicDescription': 'Black Casio scientific calculator found',
  'locationName': 'Mario Laserna',
  'latitude': 4.60275,
  'longitude': -74.06482,
  'status': status,
  'semesterId': '2026-2',
  'donationEligible': false,
  'donationStatus': 'not_eligible',
  'createdAt': Timestamp.fromDate(createdAt ?? DateTime.now()),
};
