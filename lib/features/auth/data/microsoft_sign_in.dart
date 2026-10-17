import 'package:cloud_functions/cloud_functions.dart';
import 'package:msal_auth/msal_auth.dart';

// Signs the student in with their Uniandes Microsoft account and returns a
// Firebase custom token. Abstract so tests do not open MSAL or call Firebase.
abstract class MicrosoftSignIn {
  // Null when the student closes the Microsoft sign-in.
  Future<String?> firebaseCustomToken();
}

class MicrosoftSignInException implements Exception {
  const MicrosoftSignInException(this.message);
  final String message;
}

// MSAL signs in natively: with Microsoft Authenticator, Outlook or Teams on the
// phone the student only picks the account. Firebase does not accept the
// Microsoft ID token, so the exchangeMicrosoftToken Cloud Function verifies it
// and answers with a Firebase custom token.
class MsalMicrosoftSignIn implements MicrosoftSignIn {
  const MsalMicrosoftSignIn();

  static const _clientId = '5b31e76c-0ade-4ea2-bb00-9a3d180dfd4b';
  // Same signature hash as msalSignatureHash in android/app/build.gradle.kts.
  static const _signatureHash = String.fromEnvironment(
    'MSAL_SIGNATURE_HASH',
    defaultValue: 'Le5IXz2RQmCQU0/je+P+g4d4T7s=',
  );

  static Future<SingleAccountPca>? _app;

  Future<SingleAccountPca> _publicClient() => _app ??=
      SingleAccountPca.create(
        clientId: _clientId,
        androidConfig: AndroidConfig(
          configFilePath: 'assets/msal_config.json',
          redirectUri:
              'msauth://com.campusfind.flutter/'
              '${Uri.encodeComponent(_signatureHash)}',
        ),
      ).catchError((Object error) {
        // A failed setup is retried on the next attempt.
        _app = null;
        throw error;
      });

  @override
  Future<String?> firebaseCustomToken() async {
    final String? idToken;
    try {
      final app = await _publicClient();
      final result = await app.acquireToken(
        scopes: const ['User.Read'],
        prompt: Prompt.selectAccount,
      );
      idToken = result.idToken;
    } on MsalUserCancelException {
      return null;
    } on MsalException {
      throw const MicrosoftSignInException(
        'Unable to sign in with Microsoft. Please try again.',
      );
    }
    if (idToken == null || idToken.isEmpty) {
      throw const MicrosoftSignInException('Unable to sign in with Microsoft.');
    }

    try {
      final result = await FirebaseFunctions.instanceFor(region: 'us-east1')
          .httpsCallable(
            'exchangeMicrosoftToken',
            options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
          )
          .call({'idToken': idToken});
      final token = (result.data as Map?)?['customToken'];
      if (token is! String || token.isEmpty) {
        throw const MicrosoftSignInException(
          'Unable to sign in with Microsoft.',
        );
      }
      return token;
    } on FirebaseFunctionsException catch (error) {
      throw MicrosoftSignInException(
        error.code == 'unauthenticated'
            ? 'Use your @uniandes.edu.co Microsoft account.'
            : 'Unable to reach CampusFind. Check your connection.',
      );
    }
  }
}
