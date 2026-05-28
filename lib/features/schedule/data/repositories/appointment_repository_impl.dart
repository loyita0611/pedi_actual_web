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
      // Llamamos a la fuente de datos y retornamos la lista (los modelos son entidades de forma implícita)
      return await remoteDataSource.getAppointmentsByDate(date);
    } catch (e) {
      // Aquí podrías lanzar una excepción personalizada de tu core (ej: ServerException())
      throw Exception('Error al obtener las citas de Firestore: $e');
    }
  }

  @override
  Future<void> bookAppointment(AppointmentEntity appointment) async {
    try {
      // Convertimos la entidad pura en un modelo para poder usar el .toJson()
      final model = AppointmentModel(
        id: appointment.id,
        patientName: appointment.patientName,
        patientBirthDate: appointment.patientBirthDate,
        address: appointment.address,
        representativeName: appointment.representativeName,
        email: appointment.email,
        appointmentDateTime: appointment.appointmentDateTime,
        status: appointment.status,
      );
      return await remoteDataSource.bookAppointment(model);
    } catch (e) {
      throw Exception('Error al reservar la cita en Firestore: $e');
    }
  }

  @override
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      return await remoteDataSource.cancelAppointment(appointmentId);
    } catch (e) {
      throw Exception('Error al cancelar la cita en Firestore: $e');
    }
  }
}