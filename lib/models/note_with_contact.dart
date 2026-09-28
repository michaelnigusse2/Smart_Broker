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
    if (contactName.isEmpty) return '?';
    final parts = contactName.split(' ');
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return contactName[0].toUpperCase();
  }
}
