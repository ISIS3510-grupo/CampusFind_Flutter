import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

Future<void> loadTestFonts() async {
  // Use SDK fonts so layout tests have normal Android text dimensions.
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
}
