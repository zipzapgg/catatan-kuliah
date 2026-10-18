import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/task_attachment.dart';
import '../models/academic_schedule.dart';

class AttachmentService {
  static Future<File> fileFor(TaskAttachment attachment) async {
    attachment.validate();
    final root = await getApplicationDocumentsDirectory();
    return File('${root.path}/attachments/${attachment.fileName}');
  }

  static Future<TaskAttachment?> pick() async {
    final picked = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Foto atau PDF',
          extensions: ['pdf', 'png', 'jpg', 'jpeg'],
          mimeTypes: ['application/pdf', 'image/png', 'image/jpeg'],
          uniformTypeIdentifiers: [
            'com.adobe.pdf',
            'public.png',
            'public.jpeg',
          ],
        ),
      ],
    );
    if (picked == null) return null;
    if (await picked.length() > 10 * 1024 * 1024) {
      throw const FormatException('Ukuran lampiran maksimal 10 MB.');
    }
    final attachment = TaskAttachment(
      id: 'file_${DateTime.now().microsecondsSinceEpoch}',
      name: picked.name,
    );
    final target = await fileFor(attachment);
    await target.parent.create(recursive: true);
    await picked.saveTo(target.path);
    return attachment;
  }

  static Future<void> openLink(String value) async {
    if (!isWebLink(value)) {
      throw const FormatException('Tautan web tidak valid.');
    }
    if (!await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    )) {
      throw const FormatException(
        'Tautan belum bisa dibuka. Periksa aplikasi browser.',
      );
    }
  }

  static Future<void> open(TaskAttachment attachment) async {
    attachment.validate();
    if (attachment.isLink) return openLink(attachment.url!);
    final file = await fileFor(attachment);
    if (!await file.exists()) {
      throw const FormatException(
        'Berkas tidak tersedia di perangkat ini. Lampirkan kembali foto atau PDF-nya.',
      );
    }
    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw const FormatException(
        'Berkas belum bisa dibuka. Pastikan aplikasi pembaca PDF/foto tersedia.',
      );
    }
  }
}
