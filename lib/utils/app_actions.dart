import 'package:flutter/material.dart';
import '../models/subject.dart';
import '../models/task_item.dart';
import '../models/note_item.dart';
import '../providers/app_provider.dart';
import '../services/storage_service.dart';

class AppActions {
  static Future<bool> run(
    BuildContext context,
    Future<void> Function() action, {
    String? success,
  }) async {
    try {
      await action();
      if (context.mounted && success != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(success)));
      }
      return true;
    } catch (error) {
      if (context.mounted) {
        final message = error is StorageException
            ? error.message
            : error is FormatException
            ? error.message.toString()
            : 'Perubahan belum tersimpan. Coba lagi.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String action = 'Hapus',
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            scrollable: true,
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  foregroundColor: Theme.of(ctx).colorScheme.onError,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  static void _undo(
    BuildContext context,
    String message,
    Future<void> Function() restore,
  ) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Urungkan',
          onPressed: () {
            run(context, restore);
          },
        ),
      ),
    );
  }

  static Future<void> deleteTask(
    BuildContext context,
    AppProvider provider,
    Subject subject,
    TaskItem task,
  ) async {
    if (!await confirm(
      context,
      title: 'Hapus tugas ini?',
      message:
          '"${task.title}" akan dihapus. Mata kuliah dan tugas lain tetap tersimpan.',
    )) {
      return;
    }
    if (!context.mounted) return;
    final index = subject.tasks.indexWhere((t) => t.id == task.id);
    if (await run(context, () => provider.deleteTask(subject.id, task.id)) &&
        context.mounted) {
      _undo(
        context,
        'Tugas dihapus',
        () => provider.restoreTask(subject.id, task, index),
      );
    }
  }

  static Future<void> deleteNote(
    BuildContext context,
    AppProvider provider,
    Subject subject,
    NoteItem note,
  ) async {
    if (!await confirm(
      context,
      title: 'Hapus catatan?',
      message: 'Catatan ini akan dihapus dari ${subject.name}.',
    )) {
      return;
    }
    if (!context.mounted) return;
    final index = subject.notes.indexWhere((n) => n.id == note.id);
    if (await run(context, () => provider.deleteNote(subject.id, note.id)) &&
        context.mounted) {
      _undo(
        context,
        'Catatan dihapus',
        () => provider.restoreNote(subject.id, note, index),
      );
    }
  }

  static Future<bool> deleteSubject(
    BuildContext context,
    AppProvider provider,
    Subject subject,
  ) async {
    if (!await confirm(
      context,
      title: 'Hapus mata kuliah?',
      message:
          '"${subject.name}" beserta ${subject.totalTasks} tugas dan ${subject.notes.length} catatan akan dihapus.',
    )) {
      return false;
    }
    if (!context.mounted) return false;
    final index = provider.subjects.indexWhere((s) => s.id == subject.id);
    final success = await run(
      context,
      () => provider.deleteSubject(subject.id),
    );
    if (success && context.mounted) {
      _undo(
        context,
        'Mata kuliah dihapus',
        () => provider.restoreSubject(subject, index),
      );
    }
    return success;
  }
}
