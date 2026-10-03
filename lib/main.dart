import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'package:campusfind_flutter/app/campus_find_app.dart';
import 'package:campusfind_flutter/core/network/connectivity_service.dart';
import 'package:campusfind_flutter/features/reports/data/lost_report_repository_impl.dart';
import 'package:campusfind_flutter/features/reports/data/pending_report_sync.dart';
import 'package:campusfind_flutter/firebase_options.dart';
import 'package:campusfind_flutter/viewmodels/item_viewmodel.dart';

import 'package:campusfind_flutter/views/match_analytics_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initializes Firebase before starting the app
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Sends the reports saved offline when the connection returns or on sign-in.
  final connectivity = DeviceConnectivityService();
  PendingReportSync(
    repository: LostReportRepositoryImpl(connectivity: connectivity),
    connectivity: connectivity,
    signedInChanges: FirebaseAuth.instance.authStateChanges().map(
      (user) => user != null,
    ),
  ).start();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ItemViewModel())],
      child: const CampusFindApp(),
    ),
  );
}
 

