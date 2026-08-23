// lib/features/schedule/data/datasources/appointment_remote_data_source.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🚀 IMPORTANTE: Para obtener el ID
import 'package:flutter/foundation.dart';
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
          .collection('citas')
          .doc(appointment.id)
          .set(appointment.toJson(), SetOptions(merge: true));
          
    } else {
      final batch = firestore.batch();

      final citaRef = firestore.collection('citas').doc();
      final patientRef = firestore.collection('patients').doc();
      final pagoRef = firestore.collection('pagos').doc();
      
      // Obtenemos el ID del usuario logueado para enlazar al paciente
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      // 1. Guardar en la colección 'citas'
      batch.set(citaRef, appointment.toJson());

      // 2. Guardar en la colección 'patients'
      batch.set(patientRef, {
        'representativeId': currentUserId, // 🚀 AHORA SÍ EL MENÚ DESPLEGABLE LO ENCONTRARÁ
        'patientName': appointment.patientName,
        'patientBirthDate': Timestamp.fromDate(appointment.patientBirthDate),
        'address': appointment.address,
        'representativeName': appointment.representativeName, // Se queda porque es útil para la secretaria
        'email': appointment.email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Guardar en la colección 'pagos'
      batch.set(pagoRef, {
        'appointmentId': citaRef.id,
        'patientName': appointment.patientName,
        'pagoReferencia': appointment.pagoReferencia,
        'pagoMonto': appointment.pagoMonto,
        'pagoBanco': appointment.pagoBanco,
        'pagoMetodo': appointment.pagoMetodo,
        'status': appointment.pagoEstado ?? 'pending',
        'pagoCedula': appointment.pagoCedula,
        'pagoTelefono': appointment.pagoTelefono,
        'date': FieldValue.serverTimestamp(),
      });

      await batch.commit();
    }
  }

  @override
  Future<void> cancelAppointment(String appointmentId) async {
    try {
      await firestore
          .collection('citas')
          .doc(appointmentId)
          .update({'status': 'cancelled'});
    } catch (e) {
      debugPrint("Error cancelando cita: $e");
    }
  }
}