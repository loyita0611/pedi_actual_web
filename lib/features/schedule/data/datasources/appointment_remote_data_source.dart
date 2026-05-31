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
    // Calculamos el inicio y fin del día seleccionado para el filtro de Firestore
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snapshot = await firestore
        .collection('appointments')
        .where('appointmentDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('appointmentDateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    // Mapeamos los documentos devueltos por Firebase a nuestro AppointmentModel
    return snapshot.docs
        .map((doc) => AppointmentModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> bookAppointment(AppointmentModel appointment) async {
    // Agregamos un nuevo documento. Firestore generará el ID automáticamente.
    await firestore.collection('appointments').add(appointment.toJson());
  }

  @override
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await firestore
          .collection('appointments')
          .doc(appointmentId)
          .update({'status': 'cancelled'});
    } catch (e) {
      //throw ServerException(); // O el manejo de excepciones que tengas configurado
    }
  }

}