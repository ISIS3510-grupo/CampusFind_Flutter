import 'package:cloud_firestore/cloud_firestore.dart';

import 'data/report_bottleneck_repository.dart';
import 'services/report_bottleneck_aggregation_service.dart';
import 'services/report_bottleneck_service.dart';
import 'viewmodel/report_bottleneck_view_model.dart';

ReportBottleneckViewModel createReportBottleneckViewModel({
  FirebaseFirestore? firestore,
}) {
  final database = firestore ?? FirebaseFirestore.instance;
  return ReportBottleneckViewModel(
    repository: ReportBottleneckRepository(firestore: database),
    aggregationService: ReportBottleneckAggregationService(
      firestore: database,
      bottleneckService: const ReportBottleneckService(),
    ),
  );
}
