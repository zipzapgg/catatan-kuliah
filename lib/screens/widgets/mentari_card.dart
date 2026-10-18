import 'package:flutter/material.dart';
import '../../models/subject.dart';
import '../../models/academic_schedule.dart';
import '../../providers/app_provider.dart';
import '../../services/attachment_service.dart';
import '../../utils/app_actions.dart';
import 'schedule_fields.dart';

class MentariCard extends StatelessWidget {
  final Subject subject;
  final MentariOccurrence occurrence;
  final AppProvider provider;
  const MentariCard({
    super.key,
    required this.subject,
    required this.occurrence,
    required this.provider,
  });
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue =
        !occurrence.isDone && occurrence.deadline.isBefore(DateTime.now());
    return Card(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.laptop_mac_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MENTARI · ${subject.mentari!.intervalWeeks == 1 ? 'Mingguan' : '2 mingguan'}',
                    style: theme.textTheme.labelMedium,
                  ),
                ),
                if (occurrence.isDone)
                  const Icon(Icons.check_circle_outline, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            Text(subject.name, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Dibuka ${dateTimeLabel(occurrence.start)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              'Deadline ${dateTimeLabel(occurrence.deadline)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: overdue ? theme.colorScheme.error : null,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (subject.mentari!.url.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => AppActions.run(
                      context,
                      () => AttachmentService.openLink(subject.mentari!.url),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 17),
                    label: const Text('Buka Mentari'),
                  ),
                TextButton.icon(
                  icon: Icon(
                    occurrence.isDone ? Icons.undo : Icons.check,
                    size: 20,
                  ),
                  label: Text(
                    occurrence.isDone
                        ? 'Sudah dikerjakan · Urungkan'
                        : 'Tandai dikerjakan',
                  ),
                  onPressed: provider.isSaving
                      ? null
                      : () => AppActions.run(
                          context,
                          () => provider.setMentariDone(
                            subject.id,
                            occurrence.key,
                            !occurrence.isDone,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
