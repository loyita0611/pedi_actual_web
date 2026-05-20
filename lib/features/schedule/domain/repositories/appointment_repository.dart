// lib/features/schedule/domain/repositories/appointment_repository.dart

import '../entities/appointment_entity.dart';

abstract class AppointmentRepository {
  // Obtener citas de un día específico (Esencial para la cuadrícula estilo NeoGaleno)
  Future<List<AppointmentEntity>> getAppointmentsByDate(DateTime date);

  // Reservar una nueva cita
  Future<void> bookAppointment(AppointmentEntity appointment);

  // Cancelar una cita
  Future<void> cancelAppointment(String appointmentId);
}