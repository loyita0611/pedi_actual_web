// lib/features/schedule/domain/usecases/book_appointment.dart

import '../entities/appointment_entity.dart';
import '../repositories/appointment_repository.dart';

class BookAppointment {
  final AppointmentRepository repository;

  BookAppointment(this.repository);

  Future<void> call(AppointmentEntity appointment) async {
    // Aquí puedes agregar validaciones de negocio adicionales si lo requieres
    return await repository.bookAppointment(appointment);
  }
}