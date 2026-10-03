class NotificationModel {
  final String id;
  final String channel;
  final String matchId;
  final String recipientUid;
  final DateTime? sentAt;

  NotificationModel({
    required this.id,
    required this.channel,
    required this.matchId,
    required this.recipientUid,
    this.sentAt,
  });

  factory NotificationModel.fromFirestore(Map<String, dynamic> data, String id) {
    return NotificationModel(
      id: id,
      channel: data['channel'] ?? '',
      matchId: data['matchId'] ?? '',
      recipientUid: data['recipientUid'] ?? '',
      sentAt: data['sentAt']?.toDate(),
    );
  }
}