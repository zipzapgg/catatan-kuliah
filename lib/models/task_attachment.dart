import 'academic_schedule.dart';

class TaskAttachment {
  final String id;
  final String name;
  final String? url;
  const TaskAttachment({required this.id, required this.name, this.url});
  bool get isLink => url != null;
  String get extension => name.split('.').last.toLowerCase();
  String get fileName => '$id.$extension';
  void validate() {
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(id) ||
        name.trim().isEmpty ||
        name.length > 255 ||
        name.contains('/') ||
        name.contains('\\') ||
        (isLink
            ? !isWebLink(url!)
            : !['pdf', 'png', 'jpg', 'jpeg'].contains(extension))) {
      throw const FormatException(
        'Lampiran harus berupa foto, PDF, atau tautan web yang valid.',
      );
    }
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'url': url};
  factory TaskAttachment.fromJson(Map<String, dynamic> json) => TaskAttachment(
    id: json['id'] as String,
    name: json['name'] as String,
    url: json['url'] as String?,
  )..validate();
}
