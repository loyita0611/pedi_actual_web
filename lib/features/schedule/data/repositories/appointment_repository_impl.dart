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
    // Buscamos los modelos desde Firebase y los retornamos (Dart los castsea automáticamente a Entity)
    return await remoteDataSource.getAppointmentsByDate(date);
  }

  @override
  Future<void> bookAppointment(AppointmentEntity appointment) async {
    // Convertimos la Entidad que viene de la UI en un Modelo serializable para Firebase
    final appointmentModel = AppointmentModel(
      id: appointment.id,
      patientName: appointment.patientName,
      patientBirthDate: appointment.patientBirthDate,
      address: appointment.address,
      representativeName: appointment.representativeName,
      email: appointment.email,
      appointmentDateTime: appointment.appointmentDateTime,
      status: appointment.status,
    );

    return await remoteDataSource.bookAppointment(appointmentModel);
  }
}