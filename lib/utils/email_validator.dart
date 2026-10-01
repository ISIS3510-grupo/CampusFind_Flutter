class EmailValidator {
  static final RegExp _uniandesEmailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@uniandes\.edu\.co$',
    caseSensitive: false,
  );

  static bool isValidUniandesEmail(String email) {
    return _uniandesEmailRegExp.hasMatch(email.trim());
  }

  static String? validateUniandesEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    if (!isValidUniandesEmail(value)) {
      return 'Use a valid @uniandes.edu.co email.';
    }
    return null;
  }
}
