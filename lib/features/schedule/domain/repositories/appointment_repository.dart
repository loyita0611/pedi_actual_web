// lib/features/schedule/domain/repositories/appointment_repository.dart

import '../entities/appointment_entity.dart';

abstract class AppointmentRepository {
  Future<List<AppointmentEntity>> getAppointmentsByDate(DateTime date);
  Future<void> bookAppointment(AppointmentEntity appointment);
}