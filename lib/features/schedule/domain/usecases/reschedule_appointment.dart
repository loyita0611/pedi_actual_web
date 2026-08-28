// lib/features/schedule/domain/usecases/reschedule_appointment.dart
import '../../../../core/config/clinic_config.dart';
import '../entities/appointment_entity.dart';
import '../repositories/appointment_repository.dart';
import 'book_appointment.dart' show CitaInvalidaException;

class RescheduleAppointment {
  const RescheduleAppointment(this.repository);
  final AppointmentRepository repository;

  Future<void> call(AppointmentEntity cita, DateTime nuevaFecha) async {
    if (cita.id.isEmpty) {
      throw const CitaInvalidaException('La cita no existe.');
    }
    // Se podia mover una cita ya atendida, y hacia atras en el tiempo.
    if (cita.status.esCerrada) {
      throw CitaInvalidaException(
          'Una cita ${cita.status.label.toLowerCase()} ya no se puede reprogramar.');
    }
    if (nuevaFecha.isBefore(DateTime.now())) {
      throw const CitaInvalidaException('La nueva fecha debe ser posterior a hoy.');
    }
    if (!ClinicConfigService.actual.esDiaHabil(nuevaFecha)) {
      throw const CitaInvalidaException('Ese dia la consulta no atiende.');
    }
    await repository.rescheduleAppointment(cita.id, nuevaFecha);
  }
}
