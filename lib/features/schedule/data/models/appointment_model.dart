// lib/features/schedule/data/models/appointment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/appointment_entity.dart';

class AppointmentModel extends AppointmentEntity {
  const AppointmentModel({
    required super.id,
    required super.patientName,
    required super.patientBirthDate,
    required super.address,
    required super.representativeName,
    required super.email,
    required super.appointmentDateTime,
    required super.status,
  });

  // Convertir un documento de Firestore (Map) a nuestro modelo de Flutter
  factory AppointmentModel.fromJson(Map<String, dynamic> json, String documentId) {
    return AppointmentModel(
      id: documentId,
      patientName: json['patientName'] as String,
      // Se corrigió el error de tipeo 'paddress' por 'address'
      address: json['address'] as String, 
      // Mapeamos correctamente la fecha de nacimiento (si la guardas como Timestamp)
      patientBirthDate: (json['patientBirthDate'] as Timestamp).toDate(),
      representativeName: json['representativeName'] as String,
      email: json['email'] as String,
      // Se cambió 'dateTime' por 'appointmentDateTime' que es el nombre de la entidad
      appointmentDateTime: (json['appointmentDateTime'] as Timestamp).toDate(),
      status: json['status'] as String,
    );
  }

  // Convertir nuestro modelo a un Map de JSON para enviarlo a Firestore
  Map<String, dynamic> toJson() {
    return {
      // Usamos las propiedades exactas de la nueva entidad pediátrica
      'patientName': patientName,
      'patientBirthDate': Timestamp.fromDate(patientBirthDate),
      'address': address,
      'representativeName': representativeName,
      'email': email,
      'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
      'status': status,
    };
  }
}