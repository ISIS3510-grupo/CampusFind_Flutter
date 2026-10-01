import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart'; // Importante importar provider

import 'app/campus_find_app.dart';
import 'firebase_options.dart';
import 'viewmodels/item_viewmodel.dart'; // Importa tu ViewModel

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initializes Firebase before starting the app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ItemViewModel()),
      ],
      child: const CampusFindApp(),
    ),
  );
}
