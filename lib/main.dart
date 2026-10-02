import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:campusfind_flutter/app/campus_find_app.dart';
import 'package:campusfind_flutter/firebase_options.dart';
import 'package:campusfind_flutter/viewmodels/item_viewmodel.dart';

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
