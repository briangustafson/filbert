import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/auth/auth_service.dart';
import '../../../core/db/app_database.dart';
import '../../../core/db/app_meta_keys.dart';

part 'sync_settings.g.dart';

/// What Settings → Sync shows (m3-design §7.1). Local to this device.
@immutable
class SyncSettings {
  const SyncSettings({this.enabled = false, this.account, this.deviceName});

  final bool enabled;

  /// The email of the account whose Drive this device last synced with.
  /// Kept after Turn off and Sign out, so turning on again with another
  /// account can start afresh (§6.7).
  final String? account;

  /// Shown to other devices in conflicts (proposal 5).
  final String? deviceName;

  @override
  bool operator ==(Object other) =>
      other is SyncSettings &&
      other.enabled == enabled &&
      other.account == account &&
      other.deviceName == deviceName;

  @override
  int get hashCode => Object.hash(enabled, account, deviceName);

  @override
  String toString() => 'SyncSettings($enabled, $account, $deviceName)';
}

/// Reads and writes [SyncSettings] (`app_meta`).
abstract interface class SyncSettingsStore {
  Stream<SyncSettings> watch();

  /// Turns sync on with [account]. If this device last synced with another
  /// account, its sync bookkeeping is cleared first, so everything here is
  /// pushed to the new account's Drive (§6.7).
  Future<void> turnOn(String account);

  /// Turns sync off. Local data and what's on Drive stay.
  Future<void> turnOff();

  Future<void> setDeviceName(String name);
}

class DriftSyncSettingsStore implements SyncSettingsStore {
  DriftSyncSettingsStore(this._db);

  final AppDatabase _db;

  static const _keys = [
    AppMetaKeys.syncEnabled,
    AppMetaKeys.syncAccount,
    AppMetaKeys.deviceName,
  ];

  @override
  Stream<SyncSettings> watch() =>
      (_db.select(_db.appMeta)..where((m) => m.key.isIn(_keys))).watch().map((
        rows,
      ) {
        final values = {for (final r in rows) r.key: r.value};
        return SyncSettings(
          enabled: values[AppMetaKeys.syncEnabled] == 'true',
          account: values[AppMetaKeys.syncAccount],
          deviceName: values[AppMetaKeys.deviceName],
        );
      });

  @override
  Future<void> turnOn(String account) => _db.transaction(() async {
    final previous =
        (await (_db.select(_db.appMeta)
                  ..where((m) => m.key.equals(AppMetaKeys.syncAccount)))
                .getSingleOrNull())
            ?.value;
    if (previous != null && previous != account) await _forgetRemote();
    await _put(AppMetaKeys.syncAccount, account);
    await _put(AppMetaKeys.syncEnabled, 'true');
  });

  /// Clears what this device knows about a Drive: record and photo states,
  /// conflicts, the changes token and the last sync time. Records and photos
  /// themselves stay; with no state they are pushed as new.
  Future<void> _forgetRemote() async {
    await _db.delete(_db.syncStates).go();
    await _db.delete(_db.blobSyncs).go();
    await _db.delete(_db.syncConflicts).go();
    await (_db.delete(_db.appMeta)..where(
          (m) => m.key.isIn([
            AppMetaKeys.changesPageToken,
            AppMetaKeys.lastSyncAt,
          ]),
        ))
        .go();
  }

  @override
  Future<void> turnOff() => _put(AppMetaKeys.syncEnabled, 'false');

  @override
  Future<void> setDeviceName(String name) => _put(AppMetaKeys.deviceName, name);

  Future<void> _put(String key, String value) => _db
      .into(_db.appMeta)
      .insertOnConflictUpdate(AppMetaCompanion.insert(key: key, value: value));
}

@Riverpod(keepAlive: true)
SyncSettingsStore syncSettingsStore(Ref ref) =>
    DriftSyncSettingsStore(ref.watch(databaseProvider));

@Riverpod(keepAlive: true)
Stream<SyncSettings> syncSettings(Ref ref) =>
    ref.watch(syncSettingsStoreProvider).watch();

/// How Turn on ended.
enum TurnOnResult {
  on,

  /// The user backed out of Google's account picker.
  cancelled,

  /// The user declined Drive access.
  driveDeclined,
}

/// Settings → Sync's actions (m3-design §7.1), on [AuthService] and
/// [SyncSettingsStore].
class SyncSetup {
  SyncSetup(this._auth, this._store);

  final AuthService _auth;
  final SyncSettingsStore _store;

  /// Signs in if needed, asks for Drive access, then turns sync on. Throws
  /// [AuthFailed].
  Future<TurnOnResult> turnOn() async {
    final AuthAccount account;
    try {
      account = await _auth.restore() ?? await _auth.signIn();
    } on AuthCancelled {
      return TurnOnResult.cancelled;
    }
    if (!await _auth.authorizeDrive()) return TurnOnResult.driveDeclined;
    await _store.turnOn(account.email);
    return TurnOnResult.on;
  }

  Future<void> turnOff() => _store.turnOff();

  /// Turns sync off and forgets the account on this device.
  Future<void> signOut() async {
    await _store.turnOff();
    await _auth.signOut();
  }

  /// Trims [name]; a blank name is ignored.
  Future<void> setDeviceName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) await _store.setDeviceName(trimmed);
  }
}

@Riverpod(keepAlive: true)
SyncSetup syncSetup(Ref ref) => SyncSetup(
  ref.watch(authServiceProvider),
  ref.watch(syncSettingsStoreProvider),
);
