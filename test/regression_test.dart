import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:catatan_tugas_kuliah/models/note_item.dart';
import 'package:catatan_tugas_kuliah/models/subject.dart';
import 'package:catatan_tugas_kuliah/models/task_item.dart';
import 'package:catatan_tugas_kuliah/providers/app_provider.dart';
import 'package:catatan_tugas_kuliah/screens/dashboard_screen.dart';
import 'package:catatan_tugas_kuliah/screens/subject_detail_screen.dart';
import 'package:catatan_tugas_kuliah/screens/widgets/add_note_dialog.dart';
import 'package:catatan_tugas_kuliah/screens/widgets/add_subject_dialog.dart';
import 'package:catatan_tugas_kuliah/screens/widgets/add_task_dialog.dart';
import 'package:catatan_tugas_kuliah/services/storage_service.dart';
import 'package:catatan_tugas_kuliah/theme/app_theme.dart';
import 'package:catatan_tugas_kuliah/utils/deadline_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Used to reproduce a platform write rejection, rather than a mocked provider.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

Subject sample({List<TaskItem>? tasks, bool longText = false}) => Subject(
  id: 'subject',
  name: longText
      ? 'Manajemen Proyek dan Pengembangan Perangkat Lunak'
      : 'Manajemen Proyek',
  colorValue: 0xFF2563EB,
  scheduleDay: 'Senin',
  scheduleTime: '08:00 - 10:30',
  room: 'Lab Komputer 304',
  lecturer: 'Dr. Supriyanto, M.M.',
  tasks:
      tasks ??
      [
        TaskItem(
          id: 'task',
          subjectId: 'subject',
          title: longText
              ? 'Susun makalah perencanaan proyek dengan referensi terbaru dan siapkan materi presentasi kelompok'
              : 'Susun makalah perencanaan proyek',
          deadline: '2026-12-25',
          priority: 'high',
          subTasks: [SubTask(id: 'step', title: 'Cari referensi jurnal')],
        ),
      ],
  notes: [
    NoteItem(
      id: 'note',
      subjectId: 'subject',
      content:
          'Bawa laporan cetak saat presentasi.\nSertakan referensi yang digunakan.',
    ),
  ],
);

Future<AppProvider> loadProvider(List<Subject> subjects) async {
  SharedPreferences.setMockInitialValues({
    'is_first_launch_done': true,
    'sample_data_version': 1,
    'saved_subjects_data': jsonEncode(subjects.map((s) => s.toJson()).toList()),
  });
  final provider = AppProvider();
  await provider.waitUntilReady();
  return provider;
}

class RejectingStore extends InMemorySharedPreferencesStore {
  RejectingStore(super.data) : super.withData();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

class DelayedStore extends InMemorySharedPreferencesStore {
  DelayedStore(super.data) : super.withData();
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (!entered.isCompleted) {
      entered.complete();
      await release.future;
    }
    return super.setValue(valueType, key, value);
  }
}

Future<void> loadFonts() async {
  var directory = Directory(
    Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.path,
  );
  for (int i = 0; i < 8; i++) {
    if (Directory(
      '${directory.path}/bin/cache/artifacts/material_fonts',
    ).existsSync()) {
      break;
    }
    directory = directory.parent;
  }
  final fontPath = '${directory.path}/bin/cache/artifacts/material_fonts';
  for (final entry in {
    'Roboto': ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf'],
    'MaterialIcons': ['materialicons-regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final font in entry.value) {
      loader.addFont(
        Future.value(
          ByteData.sublistView(await File('$fontPath/$font').readAsBytes()),
        ),
      );
    }
    await loader.load();
  }
}

Future<void> showApp(
  WidgetTester tester,
  AppProvider provider, {
  Size size = const Size(393, 852),
  double scale = 1,
  bool dark = false,
  Widget? home,
  GlobalKey? capture,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    RepaintBoundary(
      key: capture,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: const Locale('id', 'ID'),
        supportedLocales: const [Locale('id', 'ID')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: dark ? AppTheme.darkTheme() : AppTheme.lightTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home ?? DashboardScreen(provider: provider, initialTab: 1),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> snapshot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final captured = await boundary.toImage();
    final bytes = await captured.toByteData(format: ui.ImageByteFormat.png);
    final file = File('artifacts/ui_redesign/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    captured.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadFonts);

  test(
    'nullable fields clear, while omitted fields remain unchanged',
    () async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await provider.updateTask('subject', 'task', 'Judul baru');
      expect(provider.subjects.single.tasks.single.deadline, '2026-12-25');
      await provider.updateTask(
        'subject',
        'task',
        'Judul baru',
        newDeadline: '',
      );
      await provider.updateSubject(
        'subject',
        'Manajemen Proyek',
        0xFF2563EB,
        newScheduleDay: null,
        newScheduleTime: '',
        newRoom: '',
        newLecturer: null,
      );
      final subject = provider.subjects.single;
      expect(subject.tasks.single.deadline, isNull);
      expect([
        subject.scheduleDay,
        subject.scheduleTime,
        subject.room,
        subject.lecturer,
      ], everyElement(isNull));
      final reopened = AppProvider();
      addTearDown(reopened.dispose);
      await reopened.waitUntilReady();
      expect(reopened.subjects.single.tasks.single.deadline, isNull);
      expect(reopened.subjects.single.room, isNull);
    },
  );

  test(
    'delete and restore preserve subject, notes, other tasks and contiguous order',
    () async {
      final provider = await loadProvider([
        sample(
          tasks: [
            TaskItem(
              id: 'first',
              subjectId: 'subject',
              title: 'Pertama',
              order: 0,
            ),
            TaskItem(
              id: 'second',
              subjectId: 'subject',
              title: 'Kedua',
              order: 5,
            ),
            TaskItem(
              id: 'third',
              subjectId: 'subject',
              title: 'Ketiga',
              order: 9,
            ),
          ],
        ),
      ]);
      addTearDown(provider.dispose);
      final removed = provider.subjects.single.tasks.first;
      await provider.deleteTask('subject', 'first');
      expect(provider.subjects.single.notes, hasLength(1));
      expect(provider.subjects.single.tasks.map((t) => t.order), [0, 1]);
      await provider.reorderTasks('subject', 1, 0);
      expect(provider.subjects.single.tasks.first.id, 'third');
      await provider.restoreTask('subject', removed, 0);
      expect(provider.subjects.single.tasks.map((t) => t.id), [
        'first',
        'third',
        'second',
      ]);
      final reopened = AppProvider();
      addTearDown(reopened.dispose);
      await reopened.waitUntilReady();
      expect(reopened.subjects.single.tasks.map((t) => t.order), [0, 1, 2]);
    },
  );

  test(
    'relative deadline is frozen using the original calendar date',
    () async {
      final provider = await loadProvider([
        sample(
          tasks: [
            TaskItem(
              id: 'old',
              subjectId: 'subject',
              title: 'Lama',
              deadline: 'Besok',
              createdAt: DateTime(2025, 12, 31),
            ),
          ],
        ),
      ]);
      addTearDown(provider.dispose);
      expect(provider.subjects.single.tasks.single.deadline, '2026-01-01');
      expect(
        DeadlineHelper.normalize('Besok', reference: DateTime(2026, 10, 2)),
        '2026-10-03',
      );
      expect(DeadlineHelper.normalize('Sebelum UAS'), 'Sebelum UAS');
    },
  );

  test(
    'equal priority sorts by deadline; archived tasks are excluded',
    () async {
      final provider = await loadProvider([
        sample(
          tasks: [
            TaskItem(
              id: 'later',
              subjectId: 'subject',
              title: 'Nanti',
              deadline: '2026-12-25',
              createdAt: DateTime(2026, 1, 1),
            ),
            TaskItem(
              id: 'earlier',
              subjectId: 'subject',
              title: 'Lebih mendesak',
              deadline: '2026-10-03',
              createdAt: DateTime(2026, 1, 2),
            ),
          ],
        ),
      ]);
      addTearDown(provider.dispose);
      expect(provider.getAllTasksWithSubject().first.task.id, 'earlier');
      await provider.toggleArchiveSubject('subject');
      expect(provider.getAllTasksWithSubject(), isEmpty);
      expect(provider.subjects.single.tasks, hasLength(2));
    },
  );

  test('invalid import cannot replace stored data', () async {
    final provider = await loadProvider([sample()]);
    addTearDown(provider.dispose);
    final original = provider.exportData();
    for (final backup in [
      [sample().toJson(), sample().toJson()],
      [
        sample(
          tasks: [TaskItem(id: 'orphan', subjectId: 'other', title: 'Orphan')],
        ).toJson(),
      ],
      [
        sample(
          tasks: [
            TaskItem(id: 'duplicate', subjectId: 'subject', title: 'A'),
            TaskItem(id: 'duplicate', subjectId: 'subject', title: 'B'),
          ],
        ).toJson(),
      ],
      [
        sample(
          tasks: [
            TaskItem(
              id: 'bad',
              subjectId: 'subject',
              title: 'Bad',
              priority: 'invalid',
            ),
          ],
        ).toJson(),
      ],
    ]) {
      expect(await provider.importData(jsonEncode(backup)), isFalse);
      expect(provider.exportData(), original);
    }
  });

  test(
    'rejected write preserves published state and preferences cache',
    () async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      final original = provider.exportData();
      final store = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = RejectingStore(
        await store.getAll(),
      );
      addTearDown(() => SharedPreferencesStorePlatform.instance = store);
      await expectLater(
        provider.deleteTask('subject', 'task'),
        throwsA(isA<StorageException>()),
      );
      expect(provider.exportData(), original);
      expect(provider.isSaving, isFalse);
      final reopened = AppProvider();
      addTearDown(reopened.dispose);
      await reopened.waitUntilReady();
      expect(reopened.subjects.single.tasks.single.id, 'task');
      SharedPreferencesStorePlatform.instance = store;
      await provider.addNote('subject', 'Retry works');
      expect(provider.subjects.single.notes.first.content, 'Retry works');
    },
  );

  test(
    'concurrent changes queue and are published only after durable save',
    () async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      final store = SharedPreferencesStorePlatform.instance;
      final delayed = DelayedStore(await store.getAll());
      SharedPreferencesStorePlatform.instance = delayed;
      addTearDown(() => SharedPreferencesStorePlatform.instance = store);
      final first = provider.addNote('subject', 'First');
      await delayed.entered.future;
      final second = provider.addTask('subject', 'Second');
      expect(provider.subjects.single.notes, hasLength(1));
      expect(provider.isSaving, isTrue);
      delayed.release.complete();
      await Future.wait([first, second]);
      expect(provider.subjects.single.notes.first.content, 'First');
      expect(provider.subjects.single.tasks.last.title, 'Second');
      expect(
        jsonDecode(
          (await delayed.getAll())['flutter.saved_subjects_data'] as String,
        ).single['tasks'],
        hasLength(2),
      );
    },
  );

  for (final detail in [false, true]) {
    testWidgets(
      'visible task delete confirms and supports undo in ${detail ? 'subject detail' : 'dashboard'}',
      (tester) async {
        final provider = await loadProvider([sample()]);
        addTearDown(provider.dispose);
        await showApp(
          tester,
          provider,
          home: detail
              ? SubjectDetailScreen(provider: provider, subjectId: 'subject')
              : null,
        );
        await tester.scrollUntilVisible(
          find.byTooltip('Hapus tugas').first,
          180,
          scrollable: find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.byTooltip('Hapus tugas').first);
        await tester.pumpAndSettle();
        expect(find.text('Hapus tugas ini?'), findsOneWidget);
        await tester.tap(find.widgetWithText(TextButton, 'Batal'));
        await tester.pumpAndSettle();
        expect(provider.subjects.single.tasks, hasLength(1));
        await tester.tap(find.byTooltip('Hapus tugas').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
        await tester.pumpAndSettle();
        expect(provider.subjects.single.tasks, isEmpty);
        expect(provider.subjects.single.notes, hasLength(1));
        expect(provider.subjects.single.name, 'Manajemen Proyek');
        await tester.tap(find.text('Urungkan'));
        await tester.pumpAndSettle();
        expect(provider.subjects.single.tasks.single.id, 'task');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('swipe task delete follows the same confirmation and undo path', (
    tester,
  ) async {
    final provider = await loadProvider([sample()]);
    addTearDown(provider.dispose);
    await showApp(tester, provider);
    await tester.scrollUntilVisible(
      find.byTooltip('Hapus tugas'),
      180,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.drag(find.byType(Dismissible), const Offset(-320, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(provider.subjects.single.tasks, isEmpty);
    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();
    expect(provider.subjects.single.tasks, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('subject picker scrolls to the twelfth subject', (tester) async {
    final provider = await loadProvider(
      List.generate(
        12,
        (i) => Subject(
          id: 'subject_$i',
          name: 'Mata Kuliah ${i + 1}',
          colorValue: 0xFF2563EB,
        ),
      ),
    );
    addTearDown(provider.dispose);
    await showApp(tester, provider);
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Tugas baru'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('choose-subject_11')),
      240,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('choose-subject_11')));
    await tester.pumpAndSettle();
    expect(find.byType(AddTaskDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed task form save retains input and allows successful retry',
    (tester) async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await showApp(tester, provider);
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Tugas baru'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Tugas yang harus tetap tersimpan',
      );
      final store = SharedPreferencesStorePlatform.instance;
      SharedPreferencesStorePlatform.instance = RejectingStore(
        await store.getAll(),
      );
      addTearDown(() => SharedPreferencesStorePlatform.instance = store);
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Tambah tugas'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Tambah tugas'));
      await tester.pumpAndSettle();
      expect(find.byType(AddTaskDialog), findsOneWidget);
      expect(find.text('Tugas yang harus tetap tersimpan'), findsOneWidget);
      expect(provider.subjects.single.tasks, hasLength(1));
      SharedPreferencesStorePlatform.instance = store;
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Tambah tugas'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Tambah tugas'));
      await tester.pumpAndSettle();
      expect(find.byType(AddTaskDialog), findsNothing);
      expect(
        provider.subjects.single.tasks.last.title,
        'Tugas yang harus tetap tersimpan',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [
    const Size(320, 700),
    const Size(393, 852),
    const Size(800, 480),
    const Size(768, 1024),
  ]) {
    for (final scale in [1.0, 2.0]) {
      for (final dark in [false, true]) {
        testWidgets('all tabs and detail fit $size scale $scale dark=$dark', (
          tester,
        ) async {
          final provider = await loadProvider([sample(longText: true)]);
          addTearDown(provider.dispose);
          await showApp(tester, provider, size: size, scale: scale, dark: dark);
          for (int index = 0; index < 4; index++) {
            await tester.tap(find.byType(NavigationDestination).at(index));
            await tester.pumpAndSettle();
            await tester.drag(
              find.byType(CustomScrollView),
              const Offset(0, -700),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          await showApp(
            tester,
            provider,
            size: size,
            scale: scale,
            dark: dark,
            home: SubjectDetailScreen(provider: provider, subjectId: 'subject'),
          );
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -700),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets(
    'forms stay scrollable with keyboard and large text on a small phone',
    (tester) async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await showApp(tester, provider, size: const Size(320, 700), scale: 2);
      tester.view.viewInsets = const FakeViewPadding(bottom: 260);
      addTearDown(tester.view.resetViewInsets);
      for (final open in [
        (BuildContext ctx) => AddTaskDialog.show(ctx),
        (BuildContext ctx) => AddSubjectDialog.show(ctx),
        (BuildContext ctx) => AddNoteDialog.show(ctx),
      ]) {
        open(tester.element(find.byType(DashboardScreen)));
        await tester.pumpAndSettle();
        await tester.drag(
          find.byType(SingleChildScrollView).last,
          const Offset(0, -1800),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(FilledButton).last);
        await tester.pumpAndSettle();
        expect(find.byType(FilledButton).last.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.pop(tester.element(find.byType(Form)));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'dashboard and task controls meet Android accessibility guidelines',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await showApp(tester, provider);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    },
  );

  testWidgets(
    'saving form blocks accidental dismissal until persistence completes',
    (tester) async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await showApp(tester, provider);
      final save = Completer<void>();
      AddTaskDialog.show(
        tester.element(find.byType(DashboardScreen)),
        onSave: (_) => save.future,
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Tugas yang sedang disimpan',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Tambah tugas'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Tambah tugas'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.close).last,
            )
            .onPressed,
        isNull,
      );
      await Navigator.of(tester.element(find.byType(AddTaskDialog))).maybePop();
      await tester.pump();
      expect(find.byType(AddTaskDialog), findsOneWidget);
      expect(find.text('Tugas yang sedang disimpan'), findsOneWidget);
      save.complete();
      await tester.pumpAndSettle();
      expect(find.byType(AddTaskDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delete confirmation releases search focus instead of reopening the keyboard',
    (tester) async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await showApp(tester, provider);
      await tester.enterText(find.byType(TextField), 'Susun');
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.focusNode.hasFocus, isTrue);
      await tester.ensureVisible(find.byTooltip('Hapus tugas'));
      await tester.tap(find.byTooltip('Hapus tugas'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();
      expect(editable.focusNode.hasFocus, isFalse);
      expect(provider.subjects.single.tasks, hasLength(1));
    },
  );

  testWidgets('keyboard alone can focus and complete a task', (tester) async {
    final provider = await loadProvider([sample()]);
    addTearDown(provider.dispose);
    await showApp(tester, provider);
    bool checkboxFocused = false;
    for (int i = 0; i < 20; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      checkboxFocused =
          FocusManager.instance.primaryFocus?.context
              ?.findAncestorWidgetOfExactType<Checkbox>() !=
          null;
      if (checkboxFocused) break;
    }
    expect(checkboxFocused, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(provider.subjects.single.tasks.single.isDone, isTrue);
  });

  testWidgets(
    'note edit, copy, delete and undo work through the detail screen',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await showApp(
        tester,
        provider,
        home: SubjectDetailScreen(provider: provider, subjectId: 'subject'),
      );
      await tester.scrollUntilVisible(
        find.byTooltip('Edit catatan'),
        220,
        scrollable: find
            .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.ensureVisible(find.byTooltip('Edit catatan'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit catatan'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField),
        'Instruksi yang diperbarui',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Simpan catatan'),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Simpan catatan'));
      await tester.pumpAndSettle();
      expect(
        provider.subjects.single.notes.single.content,
        'Instruksi yang diperbarui',
      );
      await tester.ensureVisible(find.byTooltip('Salin catatan'));
      await tester.tap(find.byTooltip('Salin catatan'));
      await tester.pumpAndSettle();
      expect(clipboard, 'Instruksi yang diperbarui');
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Hapus catatan'));
      await tester.tap(find.byTooltip('Hapus catatan'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
      await tester.pumpAndSettle();
      expect(provider.subjects.single.notes, isEmpty);
      await tester.tap(find.text('Urungkan'));
      await tester.pumpAndSettle();
      expect(
        provider.subjects.single.notes.single.content,
        'Instruksi yang diperbarui',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'backup UI rejects invalid data and restores a valid clipboard backup',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await showApp(tester, provider, size: const Size(320, 700), scale: 2);
      await tester.tap(find.byTooltip('Pengaturan dan cadangan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Salin cadangan JSON'));
      await tester.pumpAndSettle();
      final backup = clipboard!;
      expect(jsonDecode(backup), hasLength(1));
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pengaturan dan cadangan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pulihkan cadangan JSON'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        '{bad json',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Ganti dan pulihkan'));
      await tester.pumpAndSettle();
      expect(provider.subjects.single.tasks, hasLength(1));
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        backup,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Ganti dan pulihkan'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(provider.subjects.single.tasks.single.id, 'task');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing controls, schedule pickers and archive persist through UI',
    (tester) async {
      final provider = await loadProvider([sample()]);
      addTearDown(provider.dispose);
      await showApp(tester, provider, size: const Size(768, 1024));
      Future<void> tap(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      await tap(find.byTooltip('Edit tugas'));
      await tap(find.widgetWithText(ActionChip, 'Besok'));
      await tap(find.byTooltip('Pilih tanggal'));
      await tap(find.text('Pilih'));
      await tap(find.widgetWithText(ActionChip, 'Tanpa deadline'));
      await tap(find.widgetWithText(ChoiceChip, 'Rendah'));
      await tap(find.byTooltip('Hapus langkah'));
      final stepInput = find
          .descendant(
            of: find.byType(AddTaskDialog),
            matching: find.byType(TextField),
          )
          .last;
      await tester.enterText(stepInput, 'Langkah sementara');
      await tap(find.byTooltip('Tambah langkah'));
      await tap(find.byTooltip('Hapus langkah'));
      await tester.enterText(stepInput, 'Langkah yang ikut disimpan');
      await tap(find.widgetWithText(FilledButton, 'Simpan perubahan'));
      final task = provider.subjects.single.tasks.single;
      expect(task.deadline, isNull);
      expect(task.priority, 'low');
      expect(task.subTasks.single.title, 'Langkah yang ikut disimpan');
      await tap(find.widgetWithText(TextButton, '0/1 langkah'));
      await tap(find.byType(Checkbox).last);
      expect(
        provider.subjects.single.tasks.single.subTasks.single.isDone,
        isTrue,
      );
      for (final label in [
        'Semua 1',
        'Penting 0',
        'Selesai 0',
        'Belum selesai 1',
      ]) {
        await tap(find.widgetWithText(FilterChip, label));
      }
      await tap(find.byType(NavigationDestination).at(3));
      await tap(find.byTooltip('Urutkan mata kuliah'));
      await tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is CheckedPopupMenuItem<SortOption> &&
              widget.value == SortOption.byRecent,
        ),
      );
      expect(provider.sortOption, SortOption.byRecent);
      await tester.enterText(find.byType(TextField), 'Tidak ditemukan');
      await tester.pumpAndSettle();
      expect(provider.filteredSubjects, isEmpty);
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();
      await tap(find.byTooltip('Opsi Manajemen Proyek'));
      await tap(find.text('Edit mata kuliah'));
      await tester.enterText(
        find.byType(TextFormField).first,
        'Manajemen Baru',
      );
      await tap(find.bySemanticsLabel('Warna Hijau'));
      await tap(find.widgetWithText(ChoiceChip, 'Sabtu'));
      await tap(find.byTooltip('Pilih jam kuliah'));
      await tap(find.text('Lanjut'));
      await tap(find.text('Pilih'));
      await tester.enterText(find.byType(TextFormField).at(2), '');
      await tester.enterText(find.byType(TextFormField).at(3), '');
      await tap(find.widgetWithText(FilledButton, 'Simpan perubahan'));
      final subject = provider.subjects.single;
      expect(subject.name, 'Manajemen Baru');
      expect(subject.scheduleDay, 'Sabtu');
      expect(subject.scheduleTime, '08:00 - 10:00');
      expect(subject.room, isNull);
      expect(subject.lecturer, isNull);
      await tap(find.byTooltip('Opsi Manajemen Baru'));
      await tap(find.text('Arsipkan mata kuliah'));
      expect(provider.subjects.single.isArchived, isTrue);
      await tap(find.widgetWithText(FilterChip, 'Arsip 1'));
      await tap(find.byTooltip('Opsi Manajemen Baru'));
      await tap(find.text('Keluarkan dari arsip'));
      expect(provider.subjects.single.isArchived, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('capture redesigned screens with real fonts', (tester) async {
    final provider = await loadProvider([
      sample(),
      Subject(
        id: 'mobile',
        name: 'Pemrograman Mobile',
        colorValue: 0xFF059669,
        scheduleDay: 'Jumat',
        scheduleTime: '10:30 - 12:00',
        room: 'Lab Mobile',
        tasks: [
          TaskItem(
            id: 'demo',
            subjectId: 'mobile',
            title: 'Siapkan demo aplikasi di HP',
            deadline: '2026-10-03',
          ),
        ],
      ),
    ]);
    addTearDown(provider.dispose);
    final capture = GlobalKey();
    await showApp(tester, provider, capture: capture);
    await snapshot(tester, capture, 'tugas_light');
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pumpAndSettle();
    await snapshot(tester, capture, 'mata_kuliah');
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pumpAndSettle();
    await snapshot(tester, capture, 'jadwal');
    await showApp(
      tester,
      provider,
      capture: capture,
      home: SubjectDetailScreen(provider: provider, subjectId: 'subject'),
    );
    await snapshot(tester, capture, 'detail_mata_kuliah');
    await tester.tap(find.widgetWithText(FloatingActionButton, 'Tugas baru'));
    await tester.pumpAndSettle();
    await snapshot(tester, capture, 'form_tugas');
    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();
    await showApp(tester, provider, capture: capture, dark: true);
    await snapshot(tester, capture, 'tugas_dark');
  });
}
