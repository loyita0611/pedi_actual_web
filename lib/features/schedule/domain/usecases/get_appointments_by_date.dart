import 'package:pedia_actual/features/schedule/domain/entities/appointment_entity.dart';
import 'package:pedia_actual/features/schedule/domain/repositories/appointment_repository.dart';

class GetAppointmentsByDate {
  final AppointmentRepository repository;
  GetAppointmentsByDate(this.repository);

  Future<List<AppointmentEntity>> call(DateTime date) async {
    // Aquí puedes meter lógica de negocio si fuera necesario antes de llamar al repositorio
    return await repository.getAppointmentsByDate(date);
  }
}