// lib/features/schedule/domain/usecases/book_appointment.dart
import '../../../../core/config/clinic_config.dart';
import '../entities/appointment_entity.dart';
import '../repositories/appointment_repository.dart';

class CitaInvalidaException implements Exception {
  const CitaInvalidaException(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

class BookAppointment {
  const BookAppointment(this.repository);
  final AppointmentRepository repository;

  Future<String> call(AppointmentEntity appointment) async {
    final config = ClinicConfigService.actual;
    final cuando = appointment.appointmentDateTime;

    // Validaciones que antes no existian en ningun lado: se podia reservar
    // para el mes pasado, un domingo o a la hora del almuerzo.
    if (appointment.esNueva && cuando.isBefore(DateTime.now())) {
      throw const CitaInvalidaException('No se puede agendar una cita en una fecha que ya paso.');
    }
    if (!config.esDiaHabil(cuando)) {
      throw const CitaInvalidaException('Ese dia la consulta no atiende.');
    }
    if (cuando.hour >= config.almuerzoInicio && cuando.hour < config.almuerzoFin) {
      throw const CitaInvalidaException('Ese bloque corresponde al horario de almuerzo.');
    }
    if (cuando.hour < config.horaInicio || cuando.hour >= config.horaFin) {
      throw const CitaInvalidaException('Ese horario esta fuera de la jornada de atencion.');
    }
    if (appointment.patientName.trim().isEmpty) {
      throw const CitaInvalidaException('Falta el nombre del paciente.');
    }

    return repository.bookAppointment(appointment);
  }
}
