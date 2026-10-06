// Features whose usage is counted to answer the BQ "Which app features are
// used most frequently by students?". The ids are shared with the Kotlin app
// (Proyecto/firebase/schema.md), so do not rename them.
enum AppFeature {
  searchFoundItems('search_found_items'),
  reportLostItem('report_lost_item'),
  submitLostReport('submit_lost_report'),
  reportFoundItem('report_found_item'),
  viewMyReport('view_my_report'),
  passwordLogin('password_login'),
  biometricLogin('biometric_login');

  const AppFeature(this.id);

  final String id;
}
