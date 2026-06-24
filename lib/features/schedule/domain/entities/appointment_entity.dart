// lib/features/schedule/domain/entities/appointment_entity.dart

import 'package:equatable/equatable.dart';

class AppointmentEntity extends Equatable {
  final String id;
  final String patientName;       
  final DateTime patientBirthDate; 
  final String address;           
  final String representativeName;
  final String email;             
  final DateTime appointmentDateTime; 
  final String status;            

  // Datos del Pago Integrados
  final String? pagoReferencia;
  final double? pagoMonto;
  final String? pagoBanco;
  final String? pagoMetodo;
  final String? pagoEstado;
  final String? pagoCedula;    // 🚀 NUEVO
  final String? pagoTelefono;  // 🚀 NUEVO

  const AppointmentEntity({
    required this.id,
    required this.patientName,
    required this.patientBirthDate,
    required this.address,
    required this.representativeName,
    required this.email,
    required this.appointmentDateTime,
    required this.status,
    this.pagoReferencia,
    this.pagoMonto,
    this.pagoBanco,
    this.pagoMetodo,
    this.pagoEstado,
    this.pagoCedula,    // 🚀 NUEVO
    this.pagoTelefono,  // 🚀 NUEVO
  });

  @override
  List<Object?> get props => [
        id,
        patientName,
        patientBirthDate,
        address,
        representativeName,
        email,
        appointmentDateTime,
        status,
        pagoReferencia,
        pagoMonto,
        pagoBanco,
        pagoMetodo,
        pagoEstado,
        pagoCedula,   
        pagoTelefono,  
      ];
}