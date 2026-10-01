import 'note.dart';

class NoteWithContact {
  final Note note;
  final String contactName;
  final String contactAvatarUrl;

  const NoteWithContact({
    required this.note,
    required this.contactName,
    required this.contactAvatarUrl,
  });

  String get contactInitials {
    // Split on any whitespace and drop empty parts: "John ", "  Ann" or
    // "John  Smith" would otherwise index an empty string and crash.
    final parts = contactName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }
}
