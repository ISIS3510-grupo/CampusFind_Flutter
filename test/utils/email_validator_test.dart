import 'package:flutter_test/flutter_test.dart';
import '../../lib/utils/email_validator.dart';

void main() {
  group('EmailValidator - Uniandes Email Validation', () {
    test('Debe retornar true para correos válidos de Uniandes', () {
      expect(EmailValidator.isValidUniandesEmail('s.perez@uniandes.edu.co'), isTrue);
      expect(EmailValidator.isValidUniandesEmail('estudiante123@uniandes.edu.co'), isTrue);
    });

    test('Debe retornar false para otros dominios', () {
      expect(EmailValidator.isValidUniandesEmail('usuario@gmail.com'), isFalse);
      expect(EmailValidator.isValidUniandesEmail('usuario@unal.edu.co'), isFalse);
    });

    test('Debe validar correctamente en el formulario', () {
      expect(EmailValidator.validateUniandesEmail(''), 'Email is required');
      expect(EmailValidator.validateUniandesEmail('correo@gmail.com'), 'Use a valid @uniandes.edu.co email.');
      expect(EmailValidator.validateUniandesEmail('s.perez@uniandes.edu.co'), isNull);
    });
  });
}
