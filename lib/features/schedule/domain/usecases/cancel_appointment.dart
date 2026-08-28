// lib/features/schedule/domain/usecases/cancel_appointment.dart
import '../entities/appointment_entity.dart';
import '../repositories/appointment_repository.dart';
import 'book_appointment.dart' show CitaInvalidaException;

/// Cancelar existia en las tres capas y ninguna pantalla lo llamaba nunca:
/// el paciente no tenia forma de cancelar su propia cita.
class CancelAppointment {
  const CancelAppointment(this.repository);
  final AppointmentRepository repository;

  /// Horas minimas de antelacion para que el representante pueda cancelar solo.
  static const int antelacionMinimaHoras = 2;

  Future<void> call(AppointmentEntity cita, {bool esPersonal = false}) async {
    if (cita.id.isEmpty) {
      throw const CitaInvalidaException('La cita no existe.');
    }
    if (!esPersonal) {
      final margen = cita.appointmentDateTime.difference(DateTime.now());
      if (margen.isNegative) {
        throw const CitaInvalidaException(
            'Esta cita ya paso. Comunicate con la clinica si necesitas ayuda.');
      }
      if (margen.inHours < antelacionMinimaHoras) {
        throw const CitaInvalidaException(
            'Faltan menos de $antelacionMinimaHoras horas. Llama a la clinica para cancelarla.');
      }
    }
    await repository.cancelAppointment(cita.id);
  }
}
