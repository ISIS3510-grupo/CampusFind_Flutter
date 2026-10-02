// Data the student fills in the report form, before it is stored.
class LostReportDraft {
  const LostReportDraft({
    required this.title,
    required this.category,
    required this.description,
    required this.locationName,
    this.privateVerificationDetail,
    this.imagePath,
  });

  final String title;
  final String category;
  final String description;
  final String locationName;

  // Optional. Only the owner and the admin can read it (lostReportPrivate).
  // Null when the student leaves it empty, so no private doc is created.
  final String? privateVerificationDetail;

  // Local path of the photo taken with the camera, if any.
  final String? imagePath;

  Map<String, dynamic> toJson() => {
    'title': title,
    'category': category,
    'description': description,
    'locationName': locationName,
    'privateVerificationDetail': privateVerificationDetail,
    'imagePath': imagePath,
  };

  factory LostReportDraft.fromJson(Map<String, dynamic> json) {
    return LostReportDraft(
      title: json['title'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      locationName: json['locationName'] as String,
      privateVerificationDetail: json['privateVerificationDetail'] as String?,
      imagePath: json['imagePath'] as String?,
    );
  }
}

// A report already stored in Firestore (lostReports).
class LostReport {
  const LostReport({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.status,
    this.locationName,
    this.photoPath,
    this.reportedAt,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final String status;
  final String? locationName;
  final String? photoPath;
  final DateTime? reportedAt;

  bool get isActive => status != 'claimed' && status != 'closed';
}

enum SubmitStatus { submitted, queuedOffline }

class SubmitResult {
  const SubmitResult(this.reportId, this.status);

  final String reportId;
  final SubmitStatus status;
}
