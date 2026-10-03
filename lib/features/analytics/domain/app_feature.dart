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

  // Name shown in the analytics dashboard.
  String get label => switch (this) {
    AppFeature.searchFoundItems => 'Search found items',
    AppFeature.reportLostItem => 'Open "I lost an item"',
    AppFeature.submitLostReport => 'Send a lost report',
    AppFeature.reportFoundItem => 'Open "I found an item"',
    AppFeature.viewMyReport => 'View my report',
    AppFeature.passwordLogin => 'Password login',
    AppFeature.biometricLogin => 'Biometric login',
  };

  static AppFeature? fromId(String id) {
    for (final feature in values) {
      if (feature.id == id) return feature;
    }
    return null;
  }
}
