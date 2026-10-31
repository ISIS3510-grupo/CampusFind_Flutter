import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:msal_auth/msal_auth.dart';

// Signs the student in with their Uniandes Microsoft account and returns a
// Firebase custom token. Abstract so tests do not open MSAL or call Firebase.
abstract class MicrosoftSignIn {
  // Null when the student closes the Microsoft sign-in.
  Future<String?> firebaseCustomToken();

  // Forgets the Microsoft account, so the next sign-in starts clean.
  Future<void> signOut();
}

// Debug builds (the test APKs) also show the technical reason, so a failure
// on a phone without adb can be reported. Release builds keep the message.
String withDebugReason(String message, Object reason) {
  if (!kDebugMode) return message;
  final text = '$reason';
  return '$message\n(${text.length > 160 ? text.substring(0, 160) : text})';
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
      // MSAL keeps one account per app: a previous one left behind (a Firebase
      // sign-out alone does not clear it) fails the next interactive sign-in
      // with "the signed in account does not match the provided account".
      await _forget(app);
      final result = await app.acquireToken(
        scopes: const ['User.Read'],
        prompt: Prompt.selectAccount,
      );
      idToken = result.idToken;
    } on MsalUserCancelException {
      return null;
    } on MsalException catch (error) {
      // The full MSAL reason goes to the log; the student sees a short message.
      debugPrint('Microsoft sign in failed: $error');
      throw MicrosoftSignInException(
        withDebugReason(
          _msalErrorMessage(error),
          '${error.runtimeType}: ${error.message}',
        ),
      );
    }
    if (idToken == null || idToken.isEmpty) {
      debugPrint('Microsoft sign in failed: MSAL returned no ID token.');
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
        debugPrint('exchangeMicrosoftToken returned no custom token.');
        throw const MicrosoftSignInException(
          'Unable to sign in with Microsoft.',
        );
      }
      return token;
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'exchangeMicrosoftToken failed: ${error.code} ${error.message}',
      );
      throw MicrosoftSignInException(
        withDebugReason(
          error.code == 'unauthenticated'
              ? 'Use your @uniandes.edu.co Microsoft account.'
              : 'Unable to reach CampusFind. Check your connection.',
          error.code,
        ),
      );
    }
  }

  @override
  Future<void> signOut() async {
    await _forget(await _publicClient());
  }

  // No account to forget is not an error.
  static Future<void> _forget(SingleAccountPca app) async {
    try {
      await app.signOut();
    } on MsalException catch (error) {
      debugPrint('Microsoft sign out: ${error.runtimeType}');
    }
  }

  // Entra answers AADSTS65001 / 90094 / 90095 when the Uniandes tenant has
  // not approved CampusFind yet; only an administrator can fix that.
  static String _msalErrorMessage(MsalException error) {
    final reason = error.message;
    if (reason.contains('AADSTS65001') ||
        reason.contains('AADSTS90094') ||
        reason.contains('AADSTS90095')) {
      return 'Uniandes has not approved CampusFind for Microsoft sign in yet.';
    }
    return 'Unable to sign in with Microsoft. Please try again.';
  }
}
