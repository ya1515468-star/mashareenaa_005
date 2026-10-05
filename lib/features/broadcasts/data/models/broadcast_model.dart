import '../../../../core/data/supabase_document_compat.dart';
import '../../domain/entities/broadcast_entity.dart';

class BroadcastModel extends BroadcastEntity {
  static DateTime _parseCreatedAt(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is Timestamp) return value.toDate();
    if (value is num) {
      final millis = value.toInt();
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true).toLocal();
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) return parsed.toLocal();
    }
    return DateTime.now();
  }

  const BroadcastModel({
    required super.id,
    required super.message,
    required super.sentByUid,
    required super.createdAt,
    required super.targetUserIds,
  });

  factory BroadcastModel.fromMap(String id, Map<String, dynamic> map) {
    final rawTargetIds = map['targetUserIds'];

    final targetIds = <String>[
      if (rawTargetIds is List)
        ...rawTargetIds
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty),
    ];

    return BroadcastModel(
      id: id,
      message: map['message'] as String? ?? '',
      sentByUid: map['sentByUid'] as String? ?? '',
      createdAt: _parseCreatedAt(map['createdAt']),
      targetUserIds: List<String>.unmodifiable(targetIds),
    );
  }
}
