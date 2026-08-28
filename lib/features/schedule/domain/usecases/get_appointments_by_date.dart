// lib/features/schedule/domain/usecases/get_appointments_by_date.dart
import '../entities/appointment_entity.dart';
import '../repositories/appointment_repository.dart';

class GetAppointmentsByDate {
  const GetAppointmentsByDate(this.repository);
  final AppointmentRepository repository;

  Future<List<AppointmentEntity>> call(DateTime date) async {
    final citas = await repository.getAppointmentsByDate(date);
    citas.sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
    return citas;
  }
}
