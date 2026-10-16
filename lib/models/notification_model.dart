class NotificationModel {
  final String id;
  final String channel;
  final String matchId;
  final String recipientUid;
  final DateTime? sentAt;
  final DateTime? viewedAt;

  NotificationModel({
    required this.id,
    required this.channel,
    required this.matchId,
    required this.recipientUid,
    this.sentAt,
    this.viewedAt,
  });

  factory NotificationModel.fromFirestore(Map<String, dynamic> data, String id) {
    return NotificationModel(
      id: id,
      channel: data['channel'] ?? '',
      matchId: data['matchId'] ?? '',
      recipientUid: data['recipientUid'] ?? '',
      sentAt: data['sentAt']?.toDate(),
      viewedAt: data['viewedAt']?.toDate(),
    );
  }
}