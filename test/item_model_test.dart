import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:campusfind_flutter/models/item_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/firebase_core'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'Firebase#initializeCore') {
              return [
                {
                  'name': '[DEFAULT]',
                  'options': {
                    'apiKey': 'fake',
                    'appId': 'fake',
                    'messagingSenderId': 'fake',
                    'projectId': 'fake',
                  },
                  'pluginConstants': {},
                },
              ];
            }

            if (methodCall.method == 'Firebase#initializeApp') {
              return {
                'name': methodCall.arguments['appName'],
                'options': methodCall.arguments['options'],
                'pluginConstants': {},
              };
            }

            return null;
          },
        );
  });

  group('ItemModel Unit Tests', () {
    test('ItemModel creates instance and converts to map correctly', () {
      const geoPoint = GeoPoint(4.6014, -74.0661);
      final now = DateTime.now();

      final item = ItemModel(
        id: 'test-id-123',
        title: 'Billetera',
        description: 'Perdida cerca a ML',
        category: 'Accesorios',
        location: geoPoint,
        userEmail: 'estudiante@uniandes.edu.co',
        createdAt: now,
      );

      expect(item.id, 'test-id-123');
      expect(item.title, 'Billetera');
      expect(item.location.latitude, 4.6014);
      expect(item.location.longitude, -74.0661);

      final map = item.toMap();
      expect(map['title'], 'Billetera');
      expect(map['description'], 'Perdida cerca a ML');
      expect(map['category'], 'Accesorios');
      expect(map['location'], isA<GeoPoint>());
      expect(map['userEmail'], 'estudiante@uniandes.edu.co');
      expect(map['createdAt'], now);
    });

    test('ItemModel handles default createdAt in toMap', () {
      const geoPoint = GeoPoint(4.6014, -74.0661);

      final item = ItemModel(
        title: 'Sombrilla',
        description: 'Olvidada en el SD',
        category: 'Otros',
        location: geoPoint,
        userEmail: 'estudiante@uniandes.edu.co',
      );

      final map = item.toMap();
      expect(map['createdAt'], isA<FieldValue>());
    });
  });
}
