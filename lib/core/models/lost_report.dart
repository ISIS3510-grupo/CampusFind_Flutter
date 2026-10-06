import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class LostReport {
  const LostReport({
    required this.id,
    required this.ownerUid,
    required this.category,
    required this.title,
    required this.description,
    required this.status,
    required this.locationName,
    this.latitude,
    this.longitude,
    this.imageUrl,
    required this.reportedAt,
    this.statusChangedAt,
    this.foundAt,
    this.readyForPickupAt,
    this.claimedAt,
    this.closedAt,
  });

  factory LostReport.fromFirestore(String id, Map<String, dynamic> data) {
    return LostReport(
      id: id,
      ownerUid: data['ownerUid'] as String,
      category: data['category'] as String,
      title: data['title'] as String,
      description: data['description'] as String,
      status: data['status'] as String,
      locationName: data['locationName'] as String,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      imageUrl: data['imageUrl'] as String?,
      reportedAt: (data['reportedAt'] as Timestamp).toDate(),
      statusChangedAt: (data['statusChangedAt'] as Timestamp?)?.toDate(),
      foundAt: (data['foundAt'] as Timestamp?)?.toDate(),
      readyForPickupAt: (data['readyForPickupAt'] as Timestamp?)?.toDate(),
      claimedAt: (data['claimedAt'] as Timestamp?)?.toDate(),
      closedAt: (data['closedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Firestore document ID, separate from the document fields.
  final String id;
  final String ownerUid;
  final String category;
  final String title;
  final String description;
  final String status;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final DateTime reportedAt;
  final DateTime? statusChangedAt;
  final DateTime? foundAt;
  final DateTime? readyForPickupAt;
  final DateTime? claimedAt;
  final DateTime? closedAt;
}
