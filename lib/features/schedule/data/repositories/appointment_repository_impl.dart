// lib/features/schedule/data/repositories/appointment_repository_impl.dart

import '../../domain/entities/appointment_entity.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../datasources/appointment_remote_data_source.dart';
import '../models/appointment_model.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  final AppointmentRemoteDataSource remoteDataSource;

  AppointmentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<AppointmentEntity>> getAppointmentsByDate(DateTime date) async {
    try {
      final appointmentModels = await remoteDataSource.getAppointmentsByDate(date);
      return appointmentModels; // AppointmentModel hereda de AppointmentEntity, por lo que es compatible
    } catch (e) {
      throw Exception('Error al obtener las citas: $e');
    }
  }

  @override
  Future<void> bookAppointment(AppointmentEntity appointment) async {
    try {
      // Convertimos la entidad a modelo para enviarla al datasource
      final appointmentModel = AppointmentModel(
        id: appointment.id,
        patientName: appointment.patientName,
        patientBirthDate: appointment.patientBirthDate,
        address: appointment.address,
        representativeName: appointment.representativeName,
        phone: appointment.phone,
        email: appointment.email,
        appointmentDateTime: appointment.appointmentDateTime,
        status: appointment.status,
        pagoReferencia: appointment.pagoReferencia,
        pagoMonto: appointment.pagoMonto,
        pagoBanco: appointment.pagoBanco,
        pagoMetodo: appointment.pagoMetodo,
        pagoEstado: appointment.pagoEstado,
        pagoCedula: appointment.pagoCedula,
        pagoTelefono: appointment.pagoTelefono,
      );

      await remoteDataSource.bookAppointment(appointmentModel);
    } catch (e) {
      throw Exception('Error al agendar la cita: $e');
    }
  }

  @override
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await remoteDataSource.cancelAppointment(appointmentId);
    } catch (e) {
      throw Exception('Error al cancelar la cita: $e');
    }
  }
}