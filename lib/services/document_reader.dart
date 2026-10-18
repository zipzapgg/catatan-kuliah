import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import '../models/document_draft.dart';

class DocumentReader {
  static Future<XFile?> pick() => openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Dokumen kuliah',
        extensions: ['pdf', 'jpg', 'jpeg', 'png'],
        mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'],
        uniformTypeIdentifiers: ['com.adobe.pdf', 'public.jpeg', 'public.png'],
      ),
    ],
  );

  Future<List<DocumentPage>> read(
    XFile file, {
    void Function(String)? onProgress,
    bool Function()? cancelled,
  }) async {
    if (await file.length() > 20 * 1024 * 1024) {
      throw const FormatException('Dokumen maksimal 20 MB.');
    }
    final bytes = await file.readAsBytes();
    final pdf =
        bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';
    final pages = <DocumentPage>[];
    TextRecognizer? recognizer;
    Directory? temporary;
    PdfDocument? document;

    Future<DocumentPage> recognize(ui.Image image, int number) async {
      temporary ??= await (await getTemporaryDirectory()).createTemp(
        'kuliah_ocr_',
      );
      final path = '${temporary!.path}/page.png';
      try {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        if (png == null) {
          throw const FormatException('Gambar tidak dapat dibaca.');
        }
        await File(path).writeAsBytes(png.buffer.asUint8List());
        recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
        final result = await recognizer!.processImage(
          InputImage.fromFilePath(path),
        );
        return DocumentPage(
          number,
          image.width.toDouble(),
          image.height.toDouble(),
          [
            for (final block in result.blocks)
              for (final line in block.lines)
                for (final word in line.elements)
                  DocumentWord(
                    word.text,
                    word.boundingBox.left,
                    word.boundingBox.top,
                    word.boundingBox.right,
                    word.boundingBox.bottom,
                  ),
          ],
          usedOcr: true,
        );
      } finally {
        image.dispose();
        final cache = File(path);
        if (await cache.exists()) await cache.delete();
      }
    }

    try {
      if (pdf) {
        await pdfrxFlutterInitialize();
        document = await PdfDocument.openData(bytes);
        if (document.pages.length > 20) {
          throw const FormatException(
            'Maksimal 20 halaman per dokumen. Pisahkan PDF yang lebih panjang.',
          );
        }
        for (var i = 0; i < document.pages.length; i++) {
          if (cancelled?.call() ?? false) return [];
          onProgress?.call('Membaca halaman ${i + 1}/${document.pages.length}');
          final page = await document.pages[i].ensureLoaded();
          final text = await page.loadText();
          final words = <DocumentWord>[];
          if (text != null) {
            for (final match in RegExp(r'\S+').allMatches(text.fullText)) {
              if (match.end > text.charRects.length) continue;
              final rects = text.charRects
                  .sublist(match.start, match.end)
                  .where((r) => r.isNotEmpty);
              if (rects.isEmpty) continue;
              final rect = rects.reduce((a, b) => a.merge(b));
              words.add(
                DocumentWord(
                  match.group(0)!,
                  rect.left,
                  page.height - rect.top,
                  rect.right,
                  page.height - rect.bottom,
                ),
              );
            }
          }
          if (words.length >= 8) {
            pages.add(DocumentPage(i + 1, page.width, page.height, words));
          } else {
            onProgress?.call(
              'Membaca scan halaman ${i + 1}/${document.pages.length}',
            );
            final scale = 3200 / math.max(page.width, page.height);
            final raster = await page.render(
              fullWidth: page.width * scale,
              fullHeight: page.height * scale,
            );
            if (raster == null) {
              throw const FormatException('Halaman PDF tidak dapat dirender.');
            }
            try {
              pages.add(await recognize(await raster.createImage(), i + 1));
            } finally {
              raster.dispose();
            }
          }
        }
      } else {
        onProgress?.call('Membaca teks pada gambar');
        final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        ui.ImageDescriptor? descriptor;
        ui.Codec? codec;
        try {
          descriptor = await ui.ImageDescriptor.encoded(buffer);
          final scale = math.min(
            3.0,
            3200 / math.max(descriptor.width, descriptor.height),
          );
          codec = await descriptor.instantiateCodec(
            targetWidth: (descriptor.width * scale).round(),
            targetHeight: (descriptor.height * scale).round(),
          );
          pages.add(await recognize((await codec.getNextFrame()).image, 1));
        } finally {
          codec?.dispose();
          descriptor?.dispose();
          buffer.dispose();
        }
      }
      if (pages.every((p) => p.words.isEmpty)) {
        throw const FormatException(
          'Teks belum terbaca. Gunakan PDF asli atau gambar yang lebih jelas.',
        );
      }
      return pages;
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Dokumen belum bisa dibaca. Pastikan PDF/gambar tidak rusak atau terkunci sandi.',
      );
    } finally {
      await document?.dispose();
      await recognizer?.close();
      if (temporary != null && await temporary!.exists()) {
        await temporary!.delete();
      }
    }
  }
}
