/// The gallery file name of an export (m2-design §3.5):
/// `<project name>-<yyyyMMdd-HHmmss>.jpg`, in local time. Characters not
/// allowed in file names (and control characters) are dropped, spaces
/// trimmed, and the name shortened so the whole stays well under the
/// usual 255-byte limit; an empty name becomes "Filbert".
String galleryFileName(String projectName, DateTime time) {
  var name = projectName
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Leading dots make hidden files.
  name = name.replaceFirst(RegExp(r'^\.+'), '').trim();
  if (name.runes.length > 100) {
    name = String.fromCharCodes(name.runes.take(100)).trim();
  }
  if (name.isEmpty) name = 'Filbert';
  String two(int n) => n.toString().padLeft(2, '0');
  final t = time.toLocal();
  final stamp =
      '${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
  return '$name-$stamp.jpg';
}
