import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'google_client_ids.dart';

part 'auth_service.g.dart';

/// Filbert's own folder on the user's Drive (m3-design §6.2).
const driveAppDataScope = 'https://www.googleapis.com/auth/drive.appdata';

/// A signed-in Google account.
@immutable
class AuthAccount {
  const AuthAccount(this.email);

  final String email;

  @override
  bool operator ==(Object other) =>
      other is AuthAccount && other.email == email;

  @override
  int get hashCode => email.hashCode;

  @override
  String toString() => 'AuthAccount($email)';
}

/// The user backed out of a sign-in or permission screen.
class AuthCancelled implements Exception {
  const AuthCancelled();
}

/// Sign-in failed for another reason (offline, misconfigured client, …).
class AuthFailed implements Exception {
  const AuthFailed(this.message);

  final String message;

  @override
  String toString() => 'AuthFailed: $message';
}

/// Google sign-in and Drive authorization (m3-design §6.7). Tokens stay with
/// the platform's sign-in SDK; Filbert stores only the email for display.
abstract interface class AuthService {
  /// The account signed in before, restored without any UI; null if there's
  /// none or it needs the user.
  Future<AuthAccount?> restore();

  /// Signs in, showing Google's account picker. Throws [AuthCancelled] or
  /// [AuthFailed].
  Future<AuthAccount> signIn();

  /// Asks the signed-in user for [driveAppDataScope], showing Google's
  /// consent screen if it isn't granted yet. False if the user declines.
  /// Throws [AuthFailed].
  Future<bool> authorizeDrive();

  /// An access token for [driveAppDataScope] without any UI; null if the
  /// user has to sign in or grant access again (T8, T9).
  Future<String?> driveAccessToken();

  /// Forgets the account on this device. Local data stays.
  Future<void> signOut();
}

/// [AuthService] on `google_sign_in` 7: Credential Manager on Android, the
/// GoogleSignIn SDK and the keychain on macOS.
class GoogleAuthService implements AuthService {
  GoogleAuthService([GoogleSignIn? signIn])
    : _signIn = signIn ?? GoogleSignIn.instance;

  final GoogleSignIn _signIn;
  Future<void>? _initialized;
  GoogleSignInAccount? _account;

  static const _scopes = [driveAppDataScope];

  /// `initialize` must run exactly once, before anything else.
  Future<void> _ready() => _initialized ??= _signIn.initialize(
    // Apple platforms need their own client id; Android identifies the app
    // by package and signing key, and needs the web client as the server.
    clientId: _isApple ? GoogleClientIds.apple : null,
    serverClientId: _isApple ? null : GoogleClientIds.web,
  );

  static bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<AuthAccount?> restore() async {
    try {
      await _ready();
      _account = await _signIn.attemptLightweightAuthentication();
    } on GoogleSignInException catch (e) {
      debugPrint('Restoring sign-in failed: ${e.code} ${e.description}');
      _account = null;
    }
    return _toAccount(_account);
  }

  @override
  Future<AuthAccount> signIn() async {
    await _guard(() async {
      await _ready();
      _account = await _signIn.authenticate(scopeHint: _scopes);
    });
    return _toAccount(_account)!;
  }

  @override
  Future<bool> authorizeDrive() async {
    final account = _account;
    if (account == null) throw const AuthFailed('Not signed in');
    final client = account.authorizationClient;
    if (await client.authorizationForScopes(_scopes) != null) return true;
    try {
      await _guard(() => client.authorizeScopes(_scopes));
      return true;
    } on AuthCancelled {
      return false;
    }
  }

  @override
  Future<String?> driveAccessToken() async =>
      (await _account?.authorizationClient.authorizationForScopes(_scopes))
          ?.accessToken;

  @override
  Future<void> signOut() async {
    await _ready();
    await _signIn.signOut();
    _account = null;
  }

  static AuthAccount? _toAccount(GoogleSignInAccount? account) =>
      account == null ? null : AuthAccount(account.email);

  /// Turns the plugin's exceptions into [AuthCancelled] and [AuthFailed].
  static Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        throw const AuthCancelled();
      }
      debugPrint('Google sign-in failed: ${e.code} ${e.description}');
      throw AuthFailed('${e.code.name}: ${e.description}');
    }
  }
}

@Riverpod(keepAlive: true)
AuthService authService(Ref ref) => GoogleAuthService();
