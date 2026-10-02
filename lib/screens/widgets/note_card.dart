import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/note_item.dart';
import '../../utils/app_actions.dart';

class NoteCard extends StatelessWidget {
  final NoteItem note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool busy;
  const NoteCard({
    super.key,
    required this.note,
    required this.onEdit,
    required this.onDelete,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final colors = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 4),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF302D1F) : const Color(0xFFFBF4DF),
        border: Border.all(
          color: dark ? const Color(0xFF5C5436) : const Color(0xFFE9DCB4),
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SelectableText(
              note.content,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            children: [
              IconButton(
                tooltip: 'Salin catatan',
                onPressed: () => AppActions.run(
                  context,
                  () => Clipboard.setData(ClipboardData(text: note.content)),
                  success: 'Catatan disalin.',
                ),
                icon: const Icon(Icons.copy_outlined, size: 21),
              ),
              IconButton(
                tooltip: 'Edit catatan',
                onPressed: busy ? null : onEdit,
                icon: const Icon(Icons.edit_outlined, size: 21),
              ),
              IconButton(
                tooltip: 'Hapus catatan',
                onPressed: busy ? null : onDelete,
                icon: Icon(Icons.delete_outline, size: 21, color: colors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
