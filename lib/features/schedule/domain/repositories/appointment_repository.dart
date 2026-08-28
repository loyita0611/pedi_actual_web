// lib/features/schedule/domain/repositories/appointment_repository.dart
import '../../../../core/constants/app_status.dart';
import '../entities/appointment_entity.dart';

abstract class AppointmentRepository {
  Future<List<AppointmentEntity>> getAppointmentsByDate(DateTime date);
  Future<List<AppointmentEntity>> getAppointmentsByRepresentative(String uid);
  Future<List<AppointmentEntity>> getAppointmentsByPatient(String patientId);
  Future<String> bookAppointment(AppointmentEntity appointment);
  Future<void> cancelAppointment(String appointmentId);
  Future<void> rescheduleAppointment(String appointmentId, DateTime nuevaFecha);
  Future<void> updateStatus(String appointmentId, CitaStatus status);
}
