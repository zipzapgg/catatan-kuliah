import 'package:flutter/material.dart';
import '../../models/note_item.dart';
import '../../utils/app_actions.dart';
import 'app_widgets.dart';

class AddNoteDialog extends StatefulWidget {
  final NoteItem? initialNote;
  final Future<void> Function(Map<String, dynamic>)? onSave;
  const AddNoteDialog({super.key, this.initialNote, this.onSave});
  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    NoteItem? initialNote,
    Future<void> Function(Map<String, dynamic>)? onSave,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: false,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      builder: (_) => AddNoteDialog(initialNote: initialNote, onSave: onSave),
    );
  }

  @override
  State<AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<AddNoteDialog> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _content;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _content = TextEditingController(text: widget.initialNote?.content);
  }

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_key.currentState!.validate()) return;
    final values = <String, dynamic>{'content': _content.text.trim()};
    setState(() => _saving = true);
    final success =
        widget.onSave == null ||
        await AppActions.run(context, () => widget.onSave!(values));
    if (mounted) {
      setState(() => _saving = false);
      if (success) Navigator.pop(context, values);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Form(
      key: _key,
      child: FormSheet(
        title: widget.initialNote == null ? 'Catatan baru' : 'Edit catatan',
        subtitle:
            'Simpan instruksi dosen, referensi, atau hal yang perlu diingat.',
        busy: _saving,
        children: [
          TextFormField(
            controller: _content,
            enabled: !_saving,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              labelText: 'Isi catatan',
              alignLabelWithHint: true,
              hintText: 'Tuliskan catatanmu di sini',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Catatan wajib diisi'
                : null,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 20),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan catatan'),
            ),
          ),
        ],
      ),
    ),
  );
}
