/// Keys in the local-only `app_meta` table (m1-design §4.1).
abstract final class AppMetaKeys {
  static const deviceId = 'device_id';

  /// Shown to other devices in conflicts; defaults to the model or the
  /// computer's name (m3-design proposal 5).
  static const deviceName = 'device_name';
  static const autoCropOnAdd = 'auto_crop_on_add';
  static const units = 'units';
  static const lastPurgeAt = 'last_purge_at';
  static const pendingCapture = 'pending_capture';

  // Sync (m3-design §4.4).
  static const syncEnabled = 'sync_enabled';

  /// The account's email, for display only.
  static const syncAccount = 'sync_account';
  static const changesPageToken = 'changes_page_token';
  static const lastSyncAt = 'last_sync_at';

  /// The folder of the last Save to file… (m3-design §3.5).
  static const exportFolder = 'export_folder';
}
