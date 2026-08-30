// lib/features/schedule/domain/entities/appointment_entity.dart
import 'package:equatable/equatable.dart';

import '../../../../core/constants/app_status.dart';

class AppointmentEntity extends Equatable {
  const AppointmentEntity({
    required this.id,
    required this.patientName,
    required this.patientBirthDate,
    required this.address,
    required this.representativeName,
    required this.email,
    required this.phone,
    required this.appointmentDateTime,
    required this.status,
    this.patientId = '',
    this.representativeId = '',
    this.motivo = '',
    this.pagoId,
    this.pagoReferencia,
    this.pagoMonto,
    this.pagoMontoEsperado,
    this.pagoTasaBcv,
    this.pagoBanco,
    this.pagoMetodo,
    this.pagoEstado = PagoStatus.pendiente,
    this.pagoCedula,
    this.pagoTelefono,
    this.pagoComprobanteUrl,
    this.pagoMotivoRechazo,
    this.respuestaRecordatorio,
    this.ordenesPendientes = 0,
  });

  final String id;

  /// Enlace real al documento de `patients`.
  /// Antes no se guardaba, y por eso el historial clinico tenia que buscar por
  /// nombre en texto: dos ninos con el mismo nombre compartian expediente.
  final String patientId;

  /// uid del representante. Es lo que permite que las reglas de Firestore
  /// filtren por dueno en vez de dejar la coleccion abierta.
  final String representativeId;

  final String patientName;
  final DateTime patientBirthDate;
  final String address;
  final String representativeName;
  final String email;
  final String phone;
  final DateTime appointmentDateTime;
  final CitaStatus status;

  /// Motivo de la consulta. Se pedia en el formulario y se descartaba.
  final String motivo;

  // ------------------------------------------------------------------ pago
  final String? pagoId;
  final String? pagoReferencia;
  final double? pagoMonto;
  final double? pagoMontoEsperado;
  final double? pagoTasaBcv;
  final String? pagoBanco;
  final String? pagoMetodo;
  final PagoStatus pagoEstado;
  final String? pagoCedula;
  final String? pagoTelefono;

  /// Captura de la transferencia o del pago movil.
  final String? pagoComprobanteUrl;
  final String? pagoMotivoRechazo;

  /// Que contesto el representante al recordatorio de la vispera:
  /// `confirmada`, `reprogramar` o `cancelada`. Lo escribe el servidor cuando
  /// la persona pulsa en el correo, asi que la aplicacion solo lo lee.
  final String? respuestaRecordatorio;

  bool get confirmoAsistencia => respuestaRecordatorio == 'confirmada';
  bool get pidioReprogramar => respuestaRecordatorio == 'reprogramar';

  /// Cuantas indicaciones de la doctora siguen sin resolver.
  /// No se persiste: lo calcula el servicio de ordenes al armar el historial.
  final int ordenesPendientes;

  bool get esNueva => id.isEmpty;
  bool get tieneComprobante => (pagoComprobanteUrl ?? '').isNotEmpty;

  int get edadMeses {
    final ahora = DateTime.now();
    return (ahora.year - patientBirthDate.year) * 12 + (ahora.month - patientBirthDate.month);
  }

  String get edadLegible {
    final meses = edadMeses;
    if (meses < 1) return 'Recien nacido';
    if (meses < 24) return '$meses ${meses == 1 ? 'mes' : 'meses'}';
    final anios = meses ~/ 12;
    return '$anios ${anios == 1 ? 'ano' : 'anos'}';
  }

  AppointmentEntity copyWith({
    String? id,
    String? patientId,
    String? representativeId,
    String? patientName,
    DateTime? patientBirthDate,
    String? address,
    String? representativeName,
    String? email,
    String? phone,
    DateTime? appointmentDateTime,
    CitaStatus? status,
    String? motivo,
    String? pagoId,
    String? pagoReferencia,
    double? pagoMonto,
    double? pagoMontoEsperado,
    double? pagoTasaBcv,
    String? pagoBanco,
    String? pagoMetodo,
    PagoStatus? pagoEstado,
    String? pagoCedula,
    String? pagoTelefono,
    String? pagoComprobanteUrl,
    String? pagoMotivoRechazo,
    String? respuestaRecordatorio,
    int? ordenesPendientes,
  }) {
    return AppointmentEntity(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      representativeId: representativeId ?? this.representativeId,
      patientName: patientName ?? this.patientName,
      patientBirthDate: patientBirthDate ?? this.patientBirthDate,
      address: address ?? this.address,
      representativeName: representativeName ?? this.representativeName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      appointmentDateTime: appointmentDateTime ?? this.appointmentDateTime,
      status: status ?? this.status,
      motivo: motivo ?? this.motivo,
      pagoId: pagoId ?? this.pagoId,
      pagoReferencia: pagoReferencia ?? this.pagoReferencia,
      pagoMonto: pagoMonto ?? this.pagoMonto,
      pagoMontoEsperado: pagoMontoEsperado ?? this.pagoMontoEsperado,
      pagoTasaBcv: pagoTasaBcv ?? this.pagoTasaBcv,
      pagoBanco: pagoBanco ?? this.pagoBanco,
      pagoMetodo: pagoMetodo ?? this.pagoMetodo,
      pagoEstado: pagoEstado ?? this.pagoEstado,
      pagoCedula: pagoCedula ?? this.pagoCedula,
      pagoTelefono: pagoTelefono ?? this.pagoTelefono,
      pagoComprobanteUrl: pagoComprobanteUrl ?? this.pagoComprobanteUrl,
      pagoMotivoRechazo: pagoMotivoRechazo ?? this.pagoMotivoRechazo,
      respuestaRecordatorio:
          respuestaRecordatorio ?? this.respuestaRecordatorio,
      ordenesPendientes: ordenesPendientes ?? this.ordenesPendientes,
    );
  }

  /// `phone` faltaba en esta lista: dos citas que solo se diferenciaran en el
  /// telefono se consideraban iguales y el bloc no redibujaba al cambiarlo.
  @override
  List<Object?> get props => [
        id,
        patientId,
        representativeId,
        patientName,
        patientBirthDate,
        address,
        representativeName,
        email,
        phone,
        appointmentDateTime,
        status,
        motivo,
        pagoId,
        pagoReferencia,
        pagoMonto,
        pagoMontoEsperado,
        pagoTasaBcv,
        pagoBanco,
        pagoMetodo,
        pagoEstado,
        pagoCedula,
        pagoTelefono,
        pagoComprobanteUrl,
        pagoMotivoRechazo,
        respuestaRecordatorio,
        ordenesPendientes,
      ];
}
