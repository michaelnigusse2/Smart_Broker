import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/widgets/constrained_layout.dart';
import '../../../core/repositories/note_repository.dart';
import '../../../core/utils/reminder_time.dart';
import '../../../models/note_with_contact.dart';

class NotesListScreen extends StatefulWidget {
  const NotesListScreen({super.key});

  @override
  State<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends State<NotesListScreen> {
  final NoteRepository _noteRepo = NoteRepository();
  List<NoteWithContact> _allNotes = [];
  List<NoteWithContact> _filteredNotes = [];

  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadNotes();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    final notes = await _noteRepo.getAll();
    if (mounted) {
      setState(() {
        _allNotes = notes;
        _filteredNotes = notes;
        _isLoading = false;
        if (_searchQuery.isNotEmpty) {
          _performSearch(_searchQuery);
        }
      });
    }
  }

  void _onSearchChanged() {
    if (_searchQuery != _searchController.text) {
      _searchQuery = _searchController.text;
      _performSearch(_searchQuery);
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _filteredNotes = _allNotes;
      });
    } else {
      final results = await _noteRepo.search(query);
      // The user may have typed more (or left) while this query ran.
      if (!mounted || query != _searchQuery) return;
      setState(() {
        _filteredNotes = results;
      });
    }
  }

  Future<bool> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text(
          'This will permanently delete this note. Linked todos and reminders will not be deleted but will no longer be associated with this note.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  String _getGroupForDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final noteDate = DateTime(date.year, date.month, date.day);
    final diff = today.difference(noteDate).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This Week';
    return 'Earlier';
  }

  List<dynamic> _buildListItems() {
    if (_searchQuery.isNotEmpty) {
      // Don't group when searching, just return the items
      return _filteredNotes;
    }

    final items = <dynamic>[];
    String? currentGroup;

    for (final note in _filteredNotes) {
      final group = _getGroupForDate(note.note.createdAt);
      if (group != currentGroup) {
        items.add(group);
        currentGroup = group;
      }
      items.add(note);
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notes'),
        elevation: 0,
      ),
      body: ConstrainedLayout(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(LucideIcons.search, color: AppColors.textTertiary),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(LucideIcons.x, color: AppColors.textTertiary),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.card,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredNotes.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty ? 'No notes found' : 'No notes yet',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotes,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                        itemCount: _buildListItems().length,
                        itemBuilder: (context, index) {
                          final item = _buildListItems()[index];

                          if (item is String) {
                            // Header
                            return Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.lg,
                                bottom: AppSpacing.sm,
                                left: AppSpacing.xs,
                              ),
                              child: Text(
                                item,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.textTertiary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }

                          // Note Card
                          final noteContact = item as NoteWithContact;
                          final note = noteContact.note;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: Dismissible(
                              key: Key(note.id),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => _confirmDelete(),
                              onDismissed: (_) async {
                                await _noteRepo.delete(note.id);
                                _loadNotes(); // Refresh list silently
                              },
                              background: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: AppRadius.card,
                                ),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: AppSpacing.xl),
                                child: const Icon(LucideIcons.trash2, color: Colors.white),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.noteDetail,
                                    arguments: note.id,
                                  ).then((_) => _loadNotes());
                                },
                                borderRadius: AppRadius.card,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceElevated,
                                    borderRadius: AppRadius.card,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 12,
                                            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                            foregroundColor: AppColors.primary,
                                            child: Text(
                                              noteContact.contactInitials,
                                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Text(
                                              noteContact.contactName,
                                              style: Theme.of(context).textTheme.titleMedium,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Text(
                                            _formatTime(note.createdAt),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall?.copyWith(color: AppColors.textTertiary),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      Text(
                                        note.aiSummary.isEmpty ? 'Not processed by AI yet' : note.aiSummary,
                                        style: note.aiSummary.isEmpty
                                            ? Theme.of(
                                                context,
                                              ).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary)
                                            : Theme.of(context).textTheme.bodyMedium,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: AppSpacing.sm),
                                      Text(
                                        '"${note.rawText}"',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          fontStyle: FontStyle.italic,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inHours < 1) {
      if (difference.inMinutes == 0) return 'Just now';
      return '${difference.inMinutes}m ago';
    }
    if (isSameCalendarDay(date, now)) {
      return DateFormat.jm().format(date);
    }
    if (difference.inDays < 7) {
      return DateFormat.E().format(date);
    }
    return DateFormat.MMMd().format(date);
  }
}
