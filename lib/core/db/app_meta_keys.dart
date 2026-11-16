/// Keys in the local-only `app_meta` table (m1-design §4.1).
abstract final class AppMetaKeys {
  static const deviceId = 'device_id';
  static const deviceName = 'device_name';
  static const autoCropOnAdd = 'auto_crop_on_add';
  static const units = 'units';
  static const lastPurgeAt = 'last_purge_at';
  static const pendingCapture = 'pending_capture';
}
