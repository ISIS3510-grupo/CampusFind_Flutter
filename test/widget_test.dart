import 'package:campusfind_flutter/app/campus_find_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App starts without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusFindApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
