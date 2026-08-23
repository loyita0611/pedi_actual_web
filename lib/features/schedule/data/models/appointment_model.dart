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
    super.pagoCedula,
    super.pagoTelefono,
  });

  factory AppointmentModel.fromJson(Map<String, dynamic> json, String id) {
    return AppointmentModel(
      id: id,
      patientName: json['patientName'] ?? '',
      patientBirthDate: (json['patientBirthDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      address: json['address'] ?? '',
      representativeName: json['representativeName'] ?? '',
      email: json['email'] ?? '',
      appointmentDateTime: (json['appointmentDateTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: json['status'] ?? 'pending',
      pagoReferencia: json['pagoReferencia'],
      pagoMonto: (json['pagoMonto'] as num?)?.toDouble(),
      pagoBanco: json['pagoBanco'],
      pagoMetodo: json['pagoMetodo'],
      pagoEstado: json['pagoEstado'],
      pagoCedula: json['pagoCedula'],
      pagoTelefono: json['pagoTelefono'],
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
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}