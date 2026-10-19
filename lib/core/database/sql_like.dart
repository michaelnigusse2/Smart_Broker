/// Builds a `LIKE ? ESCAPE '\'` argument that matches [query] anywhere,
/// treating `%` and `_` typed by the user as plain characters.
String likeContains(String query) {
  final escaped = query.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
  return '%$escaped%';
}
