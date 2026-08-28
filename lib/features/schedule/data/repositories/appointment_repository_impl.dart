// lib/features/schedule/data/repositories/appointment_repository_impl.dart
import '../../../../core/constants/app_status.dart';
import '../../domain/entities/appointment_entity.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../datasources/appointment_remote_data_source.dart';
import '../models/appointment_model.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  AppointmentRepositoryImpl({required this.remoteDataSource});

  final AppointmentRemoteDataSource remoteDataSource;

  /// Envuelve las llamadas conservando las excepciones de dominio.
  ///
  /// Antes todo se re-lanzaba como `Exception('Error al ...: $e')`, asi que la
  /// interfaz no podia distinguir un horario ocupado de una caida de red y
  /// terminaba mostrando el volcado tecnico completo al paciente.
  Future<T> _ejecutar<T>(Future<T> Function() accion, String contexto) async {
    try {
      return await accion();
    } on HorarioOcupadoException {
      rethrow;
    } catch (e) {
      throw Exception('$contexto: $e');
    }
  }

  @override
  Future<List<AppointmentEntity>> getAppointmentsByDate(DateTime date) =>
      _ejecutar(() => remoteDataSource.getAppointmentsByDate(date), 'No se pudieron cargar las citas');

  @override
  Future<List<AppointmentEntity>> getAppointmentsByRepresentative(String uid) => _ejecutar(
      () => remoteDataSource.getAppointmentsByRepresentative(uid), 'No se pudieron cargar tus citas');

  @override
  Future<List<AppointmentEntity>> getAppointmentsByPatient(String patientId) => _ejecutar(
      () => remoteDataSource.getAppointmentsByPatient(patientId), 'No se pudo cargar el historial');

  @override
  Future<String> bookAppointment(AppointmentEntity appointment) => _ejecutar(
      () => remoteDataSource.bookAppointment(AppointmentModel.fromEntity(appointment)),
      'No se pudo guardar la cita');

  @override
  Future<void> cancelAppointment(String appointmentId) =>
      _ejecutar(() => remoteDataSource.cancelAppointment(appointmentId), 'No se pudo cancelar la cita');

  @override
  Future<void> rescheduleAppointment(String appointmentId, DateTime nuevaFecha) => _ejecutar(
      () => remoteDataSource.rescheduleAppointment(appointmentId, nuevaFecha),
      'No se pudo reprogramar la cita');

  @override
  Future<void> updateStatus(String appointmentId, CitaStatus status) => _ejecutar(
      () => remoteDataSource.updateStatus(appointmentId, status), 'No se pudo actualizar el estado');
}
