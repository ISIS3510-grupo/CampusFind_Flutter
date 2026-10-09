import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class FoundItem {
  const FoundItem({
    required this.id,
    required this.reporterUid,
    required this.category,
    required this.title,
    required this.publicDescription,
    required this.status,
    required this.locationName,
    this.latitude,
    this.longitude,
    this.imageUrl,
    required this.semesterId,
    required this.donationEligible,
    required this.donationStatus,
    required this.createdAt,
  });

  factory FoundItem.fromFirestore(String id, Map<String, dynamic> data) {
    return FoundItem(
      id: id,
      reporterUid: data['reporterUid'] as String,
      category: data['category'] as String,
      title: data['title'] as String,
      publicDescription: data['publicDescription'] as String,
      status: data['status'] as String,
      locationName: data['locationName'] as String,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      imageUrl: data['imageUrl'] as String?,
      semesterId: data['semesterId'] as String,
      donationEligible: data['donationEligible'] as bool,
      donationStatus: data['donationStatus'] as String,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  // Firestore document ID, separate from the document fields.
  final String id;
  final String reporterUid;
  final String category;
  final String title;
  final String publicDescription;
  final String status;
  final String locationName;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String semesterId;
  final bool donationEligible;
  final String donationStatus;
  final DateTime createdAt;
}
