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
    final startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    // 🚀 AHORA LEE DE LA COLECCIÓN ÚNICA 'citas'
    final snapshot = await firestore
        .collection('citas')
        .where('appointmentDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('appointmentDateTime', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .get();

    return snapshot.docs
        .map((doc) => AppointmentModel.fromJson(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<void> bookAppointment(AppointmentModel appointment) async {
    if (appointment.id.isNotEmpty) {
      await firestore
          .collection('citas') // 🚀 ACTUALIZA EN 'citas'
          .doc(appointment.id)
          .set(appointment.toJson(), SetOptions(merge: true));
    } else {
      await firestore
          .collection('citas') // 🚀 CREA EN 'citas'
          .add(appointment.toJson());
    }
  }

  @override
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await firestore
          .collection('citas') // 🚀 CANCELA EN 'citas'
          .doc(appointmentId)
          .update({'status': 'cancelled'});
    } catch (e) {
      // Manejo de excepciones
    }
  }
}