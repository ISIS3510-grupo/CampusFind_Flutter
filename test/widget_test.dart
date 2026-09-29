import 'dart:convert';
import 'dart:io';

import 'package:campusfind_flutter/app/campus_find_app.dart';
import 'package:campusfind_flutter/core/theme/app_theme.dart';
import 'package:campusfind_flutter/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
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
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );

    // Empty input is checked locally, without calling Firebase.
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Please enter your email and password.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
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

  testWidgets('Home displays the S02 content and inactive navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 42);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()),
    );

    for (final text in [
      'Lost & Found',
      'What do you need?',
      'Search found items',
      'I found an item',
      'My active report',
      'Scientific calculator',
      'Lost in ML · 2 days ago',
      'Possible match',
    ]) {
      expect(find.text(text), findsOneWidget);
    }

    for (final text in [
      'Search found items',
      'I found an item',
      'Search',
      'Alerts',
      'Profile',
    ]) {
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        tester
            .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
            .currentIndex,
        0,
      );
    }
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpAndSettle();
    expect(find.text('My active report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
