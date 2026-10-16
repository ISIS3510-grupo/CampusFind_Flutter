import 'package:campusfind_flutter/core/widgets/storage_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _placeholder = Icon(Icons.image, key: Key('placeholder'));

Future<void> _pump(WidgetTester tester, StorageImage image) =>
    tester.pumpWidget(MaterialApp(home: Scaffold(body: image)));

String? _networkUrl(WidgetTester tester) {
  final images = tester.widgetList<Image>(find.byType(Image));
  if (images.isEmpty) return null;
  return (images.first.image as NetworkImage).url;
}

void main() {
  setUp(StorageImage.clearCache);

  testWidgets('resolves a Storage path to its download URL', (tester) async {
    final requested = <String>[];
    await _pump(
      tester,
      StorageImage(
        path: 'lostReports/r1.jpg',
        placeholder: _placeholder,
        resolveUrl: (path) async {
          requested.add(path);
          return 'https://storage.example/r1.jpg';
        },
      ),
    );
    await tester.pump();

    expect(requested, ['lostReports/r1.jpg']);
    expect(_networkUrl(tester), 'https://storage.example/r1.jpg');
  });

  testWidgets('reuses the resolved URL instead of asking Storage again', (
    tester,
  ) async {
    var calls = 0;
    Future<String> resolve(String path) async {
      calls++;
      return 'https://storage.example/r2.jpg';
    }

    for (var i = 0; i < 2; i++) {
      await _pump(
        tester,
        StorageImage(
          key: ValueKey(i),
          path: 'lostReports/r2.jpg',
          placeholder: _placeholder,
          resolveUrl: resolve,
        ),
      );
      await tester.pump();
    }

    expect(calls, 1);
  });

  testWidgets('a failed lookup shows the placeholder and is retried later', (
    tester,
  ) async {
    var calls = 0;
    Future<String> failing(String path) async {
      calls++;
      throw Exception('offline');
    }

    for (var i = 0; i < 2; i++) {
      await _pump(
        tester,
        StorageImage(
          key: ValueKey(i),
          path: 'lostReports/r3.jpg',
          placeholder: _placeholder,
          resolveUrl: failing,
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('placeholder')), findsOneWidget);
    }

    expect(calls, 2);
  });

  testWidgets('no photo shows the placeholder without calling Storage', (
    tester,
  ) async {
    for (final path in <String?>[null, '', '   ']) {
      await _pump(
        tester,
        StorageImage(
          path: path,
          placeholder: _placeholder,
          resolveUrl: (_) => fail('should not resolve'),
        ),
      );
      expect(find.byKey(const Key('placeholder')), findsOneWidget);
    }
  });

  testWidgets('a full URL is used directly', (tester) async {
    await _pump(
      tester,
      StorageImage(
        path: 'https://example.com/a.jpg',
        placeholder: _placeholder,
        resolveUrl: (_) => fail('should not resolve'),
      ),
    );
    await tester.pump();
    expect(_networkUrl(tester), 'https://example.com/a.jpg');
  });
}
