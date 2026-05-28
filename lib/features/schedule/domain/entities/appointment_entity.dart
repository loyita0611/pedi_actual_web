// lib/features/schedule/domain/entities/appointment_entity.dart

import 'package:equatable/equatable.dart';

class AppointmentEntity extends Equatable {
  final String id;
  final String patientName;       // Nombre y apellido del paciente (niño)
  final DateTime patientBirthDate; // Fecha de nacimiento del niño
  final String address;           // Dirección
  final String representativeName;// Nombre y apellido del representante (adulto)
  final String email;             // Correo electrónico de contacto
  final DateTime appointmentDateTime; // Fecha y hora de la cita
  final String status;            // 'pending', 'confirmed', 'cancelled'

  const AppointmentEntity({
    required this.id,
    required this.patientName,
    required this.patientBirthDate,
    required this.address,
    required this.representativeName,
    required this.email,
    required this.appointmentDateTime,
    required this.status,
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
      ];
}