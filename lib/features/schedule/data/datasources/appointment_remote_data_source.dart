// lib/features/schedule/data/datasources/appointment_remote_data_source.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment_model.dart';

abstract class AppointmentRemoteDataSource {
  Future<List<AppointmentModel>> getAppointmentsByDate(DateTime date);
  Future<void> bookAppointment(AppointmentModel appointment);
  Future<void> cancelAppointment(String appointmentId);
}

class AppointmentRemoteDataSourceImpl implements AppointmentRemoteDataSource {
  final FirebaseFirestore firestore;

  AppointmentRemoteDataSourceImpl({required this.firestore});

  @override
  Future<List<AppointmentModel>> getAppointmentsByDate(DateTime date) async {
    // Definimos el inicio y fin del día para filtrar correctamente en Firestore
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await firestore
        .collection('appointments')
        .where('dateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('dateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs
        .map((doc) => AppointmentModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> bookAppointment(AppointmentModel appointment) async {
    // Guardamos el documento en la colección de Firestore
    await firestore.collection('appointments').add(appointment.toJson());
  }

  @override
  Future<void> cancelAppointment(String appointmentId) async {
    // Actualizamos el estado de la cita a 'cancelled'
    await firestore.collection('appointments').doc(appointmentId).update({
      'status': 'cancelled',
    });
  }
}