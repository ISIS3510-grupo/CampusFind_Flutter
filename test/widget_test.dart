import 'dart:convert';
import 'dart:io';

import 'package:campusfind_flutter/app/campus_find_app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    // Uses the SDK font so text has normal Android dimensions in tests.
    final packageConfig = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(await packageConfig.readAsString())['packages'] as List;
    final flutterPackage = packages.firstWhere(
      (package) => package['name'] == 'flutter',
    );
    final flutterRoot = packageConfig.uri.resolve(
      '${flutterPackage['rootUri']}/',
    );
    for (final font in {
      'Roboto': 'roboto-regular.ttf',
      'MaterialIcons': 'materialicons-regular.otf',
    }.entries) {
      final fontFile = File.fromUri(
        flutterRoot.resolve(
          '../../bin/cache/artifacts/material_fonts/${font.value}',
        ),
      );
      final fontLoader = FontLoader(font.key);
      fontLoader.addFont(
        fontFile.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
      await fontLoader.load();
    }
  });

  testWidgets('Login screen displays the access options', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CampusFindApp());

    expect(find.text('Lost & Found'), findsOneWidget);
    expect(find.text('Enter with Uniandes'), findsOneWidget);
    expect(find.text('Staff access'), findsOneWidget);

    await tester.tap(find.text('Enter with Uniandes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Staff access'));
    await tester.pumpAndSettle();

    expect(find.text('Lost & Found'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Staff access'));
    await tester.pumpAndSettle();
    expect(find.text('Lost & Found'), findsOneWidget);
    expect(find.text('Enter with Uniandes'), findsOneWidget);
    expect(find.text('Staff access'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
