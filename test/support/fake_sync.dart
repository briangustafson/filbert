import 'dart:async';

import 'package:filbert/core/auth/auth_service.dart';
import 'package:filbert/features/sync/data/sync_settings.dart';

/// An [AuthService] whose answers each test sets.
class FakeAuthService implements AuthService {
  /// Signed in already (restored without UI).
  AuthAccount? signedIn;

  /// Who picks in Google's account picker; null cancels.
  AuthAccount? picks = const AuthAccount('painter@example.com');

  /// Set to make sign-in fail.
  AuthFailed? failure;

  /// Whether the user grants Drive access.
  bool grantsDrive = true;

  /// What the user was asked, in order: `signIn`, `drive`, `signOut`.
  final calls = <String>[];

  @override
  Future<AuthAccount?> restore() async => signedIn;

  @override
  Future<AuthAccount> signIn() async {
    calls.add('signIn');
    if (failure case final f?) throw f;
    final account = picks;
    if (account == null) throw const AuthCancelled();
    return signedIn = account;
  }

  @override
  Future<bool> authorizeDrive() async {
    calls.add('drive');
    return grantsDrive;
  }

  @override
  Future<String?> driveAccessToken() async =>
      signedIn != null && grantsDrive ? 'token' : null;

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    signedIn = null;
  }
}

/// [SyncSettingsStore] in memory. [forgotRemote] counts account switches.
class FakeSyncSettingsStore implements SyncSettingsStore {
  FakeSyncSettingsStore([
    this._settings = const SyncSettings(deviceName: 'Pixel 11'),
  ]);

  SyncSettings _settings;
  final _changes = StreamController<SyncSettings>.broadcast();
  var forgotRemote = 0;

  SyncSettings get settings => _settings;

  @override
  Stream<SyncSettings> watch() async* {
    yield _settings;
    yield* _changes.stream;
  }

  @override
  Future<void> turnOn(String account) async {
    if (_settings.account != null && _settings.account != account) {
      forgotRemote++;
    }
    _set(
      SyncSettings(
        enabled: true,
        account: account,
        deviceName: _settings.deviceName,
      ),
    );
  }

  @override
  Future<void> turnOff() async => _set(
    SyncSettings(account: _settings.account, deviceName: _settings.deviceName),
  );

  @override
  Future<void> setDeviceName(String name) async => _set(
    SyncSettings(
      enabled: _settings.enabled,
      account: _settings.account,
      deviceName: name,
    ),
  );

  void _set(SyncSettings settings) {
    _settings = settings;
    _changes.add(settings);
  }
}
