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
    super.pagoReferencia,
    super.pagoMonto,
    super.pagoBanco,
    super.pagoMetodo,
    super.pagoEstado,
    super.pagoCedula,    // 🚀 NUEVO
    super.pagoTelefono,  // 🚀 NUEVO
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json, String documentId) {
    return AppointmentModel(
      id: documentId,
      patientName: json['patientName'] ?? '',
      address: json['address'] ?? '', 
      patientBirthDate: (json['patientBirthDate'] as Timestamp).toDate(),
      representativeName: json['representativeName'] ?? '',
      email: json['email'] ?? '',
      appointmentDateTime: (json['appointmentDateTime'] as Timestamp).toDate(),
      status: json['status'] ?? 'pending',
      
      pagoReferencia: json['pagoReferencia'] as String?,
      pagoMonto: (json['pagoMonto'] as num?)?.toDouble(),
      pagoBanco: json['pagoBanco'] as String?,
      pagoMetodo: json['pagoMetodo'] as String?,
      pagoEstado: json['pagoEstado'] as String?,
      pagoCedula: json['pagoCedula'] as String?,    // 🚀 NUEVO
      pagoTelefono: json['pagoTelefono'] as String?,// 🚀 NUEVO
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'patientName': patientName,
      'patientBirthDate': Timestamp.fromDate(patientBirthDate),
      'address': address,
      'representativeName': representativeName,
      'email': email,
      'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
      'status': status,
      
      'pagoReferencia': pagoReferencia,
      'pagoMonto': pagoMonto,
      'pagoBanco': pagoBanco,
      'pagoMetodo': pagoMetodo,
      'pagoEstado': pagoEstado,
      'pagoCedula': pagoCedula,    
      'pagoTelefono': pagoTelefono,
    };
  }
}