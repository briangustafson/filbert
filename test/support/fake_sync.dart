import 'dart:async';

import 'package:filbert/core/auth/auth_service.dart';
import 'package:filbert/features/sync/data/blob_availability.dart';
import 'package:filbert/features/sync/data/blob_downloader.dart';
import 'package:filbert/features/sync/data/drive_purge.dart';
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

  /// Tokens Drive refused.
  final cleared = <String>[];

  @override
  Future<void> clearDriveToken(String accessToken) async =>
      cleared.add(accessToken);

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

  /// Subscribes to changes before sending the current settings, so none
  /// made in between is lost.
  @override
  Stream<SyncSettings> watch() {
    StreamSubscription<SyncSettings>? changes;
    late final StreamController<SyncSettings> out;
    out = StreamController<SyncSettings>(
      onListen: () {
        changes = _changes.stream.listen(out.add);
        out.add(_settings);
      },
      onCancel: () => changes?.cancel(),
    );
    return out.stream;
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

  @override
  Future<void> setLastSyncAt(int millis) async => _set(
    SyncSettings(
      enabled: _settings.enabled,
      account: _settings.account,
      deviceName: _settings.deviceName,
      lastSyncAt: millis,
    ),
  );

  void _set(SyncSettings settings) {
    _settings = settings;
    _changes.add(settings);
  }
}

/// Every photo's original is here unless a test says otherwise.
class FakeBlobAvailability implements BlobAvailabilityService {
  final byBlob = <String, StreamController<BlobAvailability>>{};

  /// Sets [blobId]'s availability (a broadcast to current watchers).
  void set(String blobId, BlobAvailability availability) {
    _latest[blobId] = availability;
    (byBlob[blobId] ??= StreamController.broadcast()).add(availability);
  }

  final _latest = <String, BlobAvailability>{};

  @override
  Stream<BlobAvailability> watch(String blobId, String mimeType) async* {
    yield _latest[blobId] ?? BlobAvailability.original;
    yield* (byBlob[blobId] ??= StreamController.broadcast()).stream;
  }
}

/// Records what the controller asks of the downloader.
class FakeBlobDownloader implements BlobDownloader {
  var runs = 0;
  final prioritized = <String>[];
  final _active = StreamController<bool>.broadcast();
  final _updates = StreamController<String>.broadcast();

  void setActive(bool active) => _active.add(active);

  @override
  Future<void> run() async => runs++;

  @override
  void prioritize(String blobId) => prioritized.add(blobId);

  @override
  Stream<bool> get active => _active.stream;

  @override
  bool get isActive => false;

  @override
  Stream<String> get updates => _updates.stream;

  @override
  void dispose() {}
}

class FakeDrivePurge implements DrivePurge {
  var runs = 0;

  @override
  Future<int> runIfDue() async {
    runs++;
    return 0;
  }

  @override
  Future<int> run() => runIfDue();
}
