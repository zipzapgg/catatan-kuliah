import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/academic_schedule.dart';
import '../../models/tuition_payment.dart';
import '../../models/unpam_calendar.dart';
import '../../providers/app_provider.dart';
import '../../utils/app_actions.dart';
import 'app_widgets.dart';
import 'schedule_fields.dart';

String rupiah(int amount) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp',
  decimalDigits: 0,
).format(amount);

class PaymentsSheet {
  static Future<void> show(BuildContext context, AppProvider provider) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      builder: (ctx) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: ListenableBuilder(
            listenable: provider,
            builder: (ctx, _) => PopScope(
              canPop: !provider.isSaving,
              child: FormSheet(
                title: 'Bayaran & cicilan',
                subtitle:
                    'Catat tiap angsuran, lalu tandai setelah pembayaran berhasil. Status dicatat manual.',
                busy: provider.isSaving,
                children: [
                  const Text(
                    'UNPAM Reg. A/B: angsuran ke-3 & UTS 13 Oktober; pelunasan & UAS 8 Desember 2026. Nominal dan cicilan lainnya diisi sesuai tagihanmu.',
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: provider.isSaving
                        ? null
                        : () async {
                            if (await AppActions.run(
                              ctx,
                              provider.addUnpamPayments,
                            )) {
                              provider.setSemester(UnpamCalendar.semester);
                            }
                          },
                    icon: const Icon(Icons.event_available_outlined),
                    label: const Text('Isi tanggal Reg. A/B'),
                  ),
                  const Text(
                    'Jadwal yang sudah ada tidak ditimpa. Edit baris bayaran jika ada perubahan dari kampus.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: provider.isSaving
                        ? null
                        : () => edit(ctx, provider),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah cicilan'),
                  ),
                  const SizedBox(height: 16),
                  if (provider.visiblePayments.isEmpty)
                    const Text('Belum ada bayaran pada semester ini.'),
                  for (final payment in provider.visiblePayments) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: payment.isPaid,
                              semanticLabel:
                                  '${payment.isPaid ? 'Batalkan tanda lunas' : 'Tandai sudah dibayar'} ${payment.title}',
                              onChanged: provider.isSaving
                                  ? null
                                  : (v) => AppActions.run(
                                      ctx,
                                      () => provider.setPaymentPaid(
                                        payment.id,
                                        v!,
                                      ),
                                    ),
                            ),
                            Expanded(
                              child: InkWell(
                                onTap: provider.isSaving
                                    ? null
                                    : () =>
                                          edit(ctx, provider, payment: payment),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        payment.title,
                                        style: Theme.of(
                                          ctx,
                                        ).textTheme.titleSmall,
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        payment.dueAt == null
                                            ? 'Jatuh tempo belum diatur'
                                            : DateFormat(
                                                'd MMMM yyyy',
                                                'id',
                                              ).format(payment.dueAt!),
                                      ),
                                      if (payment.paidAt != null &&
                                          payment.isPaid)
                                        Text(
                                          'Dibayar ${DateFormat('d MMM yyyy', 'id').format(payment.paidAt!)}',
                                        ),
                                      Text(
                                        payment.amount == null
                                            ? 'Nominal belum diisi'
                                            : rupiah(payment.amount!),
                                      ),
                                      if (payment.semester.isNotEmpty)
                                        Text(
                                          payment.semester,
                                          style: Theme.of(
                                            ctx,
                                          ).textTheme.bodySmall,
                                        ),
                                      const SizedBox(height: 6),
                                      Text(
                                        payment.isPaid
                                            ? 'Sudah dibayar'
                                            : payment.isOverdue(DateTime.now())
                                            ? 'Lewat tanggal · cek status bayar'
                                            : 'Belum ditandai dibayar',
                                        style: TextStyle(
                                          color:
                                              payment.isOverdue(DateTime.now())
                                              ? Theme.of(ctx).colorScheme.error
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              enabled: !provider.isSaving,
                              tooltip: 'Opsi bayaran ${payment.title}',
                              onSelected: (v) {
                                if (v == 'edit') {
                                  edit(ctx, provider, payment: payment);
                                } else {
                                  AppActions.deletePayment(
                                    ctx,
                                    provider,
                                    payment,
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit bayaran'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Hapus bayaran'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> edit(
    BuildContext context,
    AppProvider provider, {
    TuitionPayment? payment,
    Future<void> Function(TuitionPayment)? onSave,
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: false,
      constraints: BoxConstraints(
        maxWidth: 640,
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      builder: (_) => ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: _PaymentEditor(
            provider: provider,
            payment: payment,
            onSave: onSave,
          ),
        ),
      ),
    );
  }
}

class _PaymentEditor extends StatefulWidget {
  final AppProvider provider;
  final TuitionPayment? payment;
  final Future<void> Function(TuitionPayment)? onSave;
  const _PaymentEditor({required this.provider, this.payment, this.onSave});
  @override
  State<_PaymentEditor> createState() => _PaymentEditorState();
}

class _PaymentEditorState extends State<_PaymentEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController title, amount, semester;
  late DateTime due;
  late List<int> reminders;
  bool saving = false;
  late bool hasDue;

  @override
  void initState() {
    super.initState();
    final p = widget.payment;
    hasDue = p == null || p.dueAt != null;
    final today = calendarDay(DateTime.now());
    title = TextEditingController(text: p?.title);
    amount = TextEditingController(text: p?.amount?.toString());
    semester = TextEditingController(
      text: p?.semester ?? widget.provider.semester ?? UnpamCalendar.semester,
    );
    due = p?.dueAt ?? DateTime(today.year, today.month, today.day + 1, 9);
    reminders = List.of(p?.reminderMinutes ?? [4320, 1440, 0]);
  }

  @override
  void dispose() {
    title.dispose();
    amount.dispose();
    semester.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    final payment = TuitionPayment(
      id:
          widget.payment?.id ??
          'payment_${DateTime.now().microsecondsSinceEpoch}',
      title: title.text.trim(),
      semester: semester.text.trim(),
      dueAt: hasDue ? due : null,
      paidAt: widget.payment?.paidAt,
      amount: amount.text.isEmpty ? null : int.parse(amount.text),
      isPaid: widget.payment?.isPaid ?? false,
      reminderMinutes: reminders,
    );
    final success = await AppActions.run(
      context,
      () =>
          widget.onSave?.call(payment) ?? widget.provider.savePayment(payment),
    );
    if (!mounted) return;
    setState(() => saving = false);
    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Form(
      key: form,
      child: FormSheet(
        title: widget.payment == null ? 'Cicilan baru' : 'Edit bayaran',
        subtitle: 'Satu catatan untuk setiap angsuran atau biaya kuliah.',
        busy: saving,
        children: [
          TextFormField(
            controller: title,
            enabled: !saving,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Nama bayaran',
              hintText: 'Mis. Angsuran ke-1',
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Nama bayaran wajib diisi'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: amount,
            enabled: !saving,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nominal rupiah (opsional)',
              prefixText: 'Rp ',
              hintText: 'Tanpa titik atau koma',
            ),
            validator: (v) =>
                v != null &&
                    v.isNotEmpty &&
                    (int.tryParse(v) == null || int.parse(v) > 1000000000000)
                ? 'Nominal terlalu besar atau tidak valid'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: semester,
            enabled: !saving,
            maxLength: 100,
            decoration: const InputDecoration(labelText: 'Semester'),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tanggal jatuh tempo diketahui'),
            subtitle: const Text(
              'Tanpa tanggal, bayaran dicatat tanpa pengingat.',
            ),
            value: hasDue,
            onChanged: saving ? null : (v) => setState(() => hasDue = v),
          ),
          if (hasDue)
            DateTimeField(
              label: 'Tanggal bayar & jam pengingat',
              value: due,
              onChanged: saving ? null : (v) => setState(() => due = v),
            ),
          const SizedBox(height: 12),
          const Text(
            'Jam hanya mengatur notifikasi aplikasi. Ikuti batas waktu pembayaran yang ditetapkan kampus.',
          ),
          const SizedBox(height: 16),
          if (hasDue) const Text('Ingatkan sebelum tanggal bayar'),
          if (hasDue)
            ReminderChoices(
              value: reminders,
              onChanged: saving ? null : (v) => setState(() => reminders = v),
            ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: saving ? null : save,
            child: Text(saving ? 'Menyimpan...' : 'Simpan bayaran'),
          ),
        ],
      ),
    ),
  );
}
