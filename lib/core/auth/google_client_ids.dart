/// OAuth client ids of the Filbert Google Cloud project
/// (docs/google-cloud-setup.md). Public identifiers that ship inside the
/// app, not secrets (m3-design §6.7).
abstract final class GoogleClientIds {
  /// The web client: Android's `serverClientId`.
  static const web =
      '556213409118-mi72vgc57vhls12kl7asrus6gbl8s47s.apps.googleusercontent.com';

  /// The iOS client, used by the Mac app. Its reversed form is the Mac's
  /// URL scheme (`macos/Runner/Configs/AppInfo.xcconfig`).
  static const apple =
      '556213409118-1ccfukqr2ustd3f6gl4rd1tu7mk7s4i6.apps.googleusercontent.com';
}
