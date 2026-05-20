// lib/features/schedule/domain/entities/appointment_entity.dart

import 'package:equatable/equatable.dart';

class AppointmentEntity extends Equatable {
  final String id;
  final String patientId;
  final String patientName;
  final DateTime dateTime;
  final String status; // 'pending', 'confirmed', 'cancelled', 'completed'
  final String? notes;
  final String serviceType; // Ej: 'Consulta General', 'Control Pediátrico'

  const AppointmentEntity({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.dateTime,
    required this.status,
    this.notes,
    required this.serviceType,
  });

  // Equatable nos ayuda a comparar objetos por sus valores en los Blocs/State Management
  @override
  List<Object?> get props => [id, patientId, patientName, dateTime, status, notes, serviceType];
}