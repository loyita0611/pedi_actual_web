// lib/features/schedule/data/models/appointment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_status.dart';
import '../../../../core/utils/search_utils.dart';
import '../../domain/entities/appointment_entity.dart';

class AppointmentModel extends AppointmentEntity {
  const AppointmentModel({
    required super.id,
    required super.patientName,
    required super.patientBirthDate,
    required super.address,
    required super.phone,
    required super.representativeName,
    required super.email,
    required super.appointmentDateTime,
    required super.status,
    super.patientId,
    super.representativeId,
    super.motivo,
    super.pagoId,
    super.pagoReferencia,
    super.pagoMonto,
    super.pagoMontoEsperado,
    super.pagoTasaBcv,
    super.pagoBanco,
    super.pagoMetodo,
    super.pagoEstado,
    super.pagoCedula,
    super.pagoTelefono,
    super.pagoComprobanteUrl,
    super.pagoMotivoRechazo,
    super.respuestaRecordatorio,
  });

  factory AppointmentModel.fromEntity(AppointmentEntity e) => AppointmentModel(
        id: e.id,
        patientId: e.patientId,
        representativeId: e.representativeId,
        patientName: e.patientName,
        patientBirthDate: e.patientBirthDate,
        address: e.address,
        representativeName: e.representativeName,
        email: e.email,
        phone: e.phone,
        appointmentDateTime: e.appointmentDateTime,
        status: e.status,
        motivo: e.motivo,
        pagoId: e.pagoId,
        pagoReferencia: e.pagoReferencia,
        pagoMonto: e.pagoMonto,
        pagoMontoEsperado: e.pagoMontoEsperado,
        pagoTasaBcv: e.pagoTasaBcv,
        pagoBanco: e.pagoBanco,
        pagoMetodo: e.pagoMetodo,
        pagoEstado: e.pagoEstado,
        pagoCedula: e.pagoCedula,
        pagoTelefono: e.pagoTelefono,
        pagoComprobanteUrl: e.pagoComprobanteUrl,
        pagoMotivoRechazo: e.pagoMotivoRechazo,
        respuestaRecordatorio: e.respuestaRecordatorio,
      );

  factory AppointmentModel.fromJson(Map<String, dynamic> json, String id) {
    DateTime fecha(String campo, DateTime porDefecto) {
      final v = json[campo];
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return porDefecto;
    }

    return AppointmentModel(
      id: id,
      patientId: json['patientId'] as String? ?? '',
      representativeId: json['representativeId'] as String? ?? '',
      patientName: json['patientName'] as String? ?? '',
      patientBirthDate: fecha('patientBirthDate', DateTime(2020)),
      address: json['address'] as String? ?? '',
      representativeName: json['representativeName'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String? ?? '',
      appointmentDateTime: fecha('appointmentDateTime', DateTime.now()),
      status: CitaStatus.fromRaw(json['status']),
      motivo: json['motivo'] as String? ?? '',
      pagoId: json['pagoId'] as String?,
      pagoReferencia: json['pagoReferencia'] as String?,
      pagoMonto: (json['pagoMonto'] as num?)?.toDouble(),
      pagoMontoEsperado: (json['pagoMontoEsperado'] as num?)?.toDouble(),
      pagoTasaBcv: (json['pagoTasaBcv'] as num?)?.toDouble(),
      pagoBanco: json['pagoBanco'] as String?,
      pagoMetodo: json['pagoMetodo'] as String?,
      pagoEstado: PagoStatus.fromRaw(json['pagoEstado']),
      pagoCedula: json['pagoCedula'] as String?,
      pagoTelefono: json['pagoTelefono'] as String?,
      pagoComprobanteUrl: json['pagoComprobanteUrl'] as String?,
      pagoMotivoRechazo: json['pagoMotivoRechazo'] as String?,
      respuestaRecordatorio: json['respuestaRecordatorio'] as String?,
    );
  }

  /// Documento de la coleccion `citas`.
  ///
  /// `createdAt` ya no va aqui: al usarse tambien en las actualizaciones,
  /// reescribia la fecha de creacion en cada edicion.
  Map<String, dynamic> toJson() => {
        'patientId': patientId,
        'representativeId': representativeId,
        'patientName': patientName,
        'nombreBusqueda': normalizarTexto(patientName),
        'patientBirthDate': Timestamp.fromDate(patientBirthDate),
        'address': address,
        'representativeName': representativeName,
        'email': email,
        'phone': phone,
        'appointmentDateTime': Timestamp.fromDate(appointmentDateTime),
        'status': status.key,
        'motivo': motivo,
        'pagoId': pagoId,
        'pagoReferencia': pagoReferencia,
        'pagoMonto': pagoMonto,
        'pagoMontoEsperado': pagoMontoEsperado,
        'pagoTasaBcv': pagoTasaBcv,
        'pagoBanco': pagoBanco,
        'pagoMetodo': pagoMetodo,
        'pagoEstado': pagoEstado.key,
        'pagoCedula': pagoCedula,
        'pagoTelefono': pagoTelefono,
        'pagoComprobanteUrl': pagoComprobanteUrl,
        'pagoMotivoRechazo': pagoMotivoRechazo,
      };

  /// Documento de la coleccion `pagos`.
  Map<String, dynamic> toPagoJson(String citaId) => {
        'appointmentId': citaId,
        'patientId': patientId,
        'representativeId': representativeId,
        'patientName': patientName,
        'representativeName': representativeName,
        'email': email,
        'pagoReferencia': pagoReferencia,
        'pagoMonto': pagoMonto,
        'pagoMontoEsperado': pagoMontoEsperado,
        'pagoTasaBcv': pagoTasaBcv,
        'pagoBanco': pagoBanco,
        'pagoMetodo': pagoMetodo,
        'pagoCedula': pagoCedula,
        'pagoTelefono': pagoTelefono,
        'comprobanteUrl': pagoComprobanteUrl,
        'status': pagoEstado.key,
        'date': FieldValue.serverTimestamp(),
      };

  /// Documento de la coleccion `patients`.
  Map<String, dynamic> toPatientJson() => {
        'representativeId': representativeId,
        'patientName': patientName,
        'nombreBusqueda': normalizarTexto(patientName),
        'patientBirthDate': Timestamp.fromDate(patientBirthDate),
        'address': address,
        'representativeName': representativeName,
        'email': email,
        // Faltaba: el formulario lo autocompletaba desde aqui y siempre venia vacio.
        'phone': phone,
      };
}
