// lib/features/orders/domain/medical_order.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Que le pide la doctora a la secretaria despues de una consulta.
enum TipoOrden {
  receta('receta', 'Receta medica', Icons.medication_outlined, AppColors.info, 'Subir receta (PDF)'),
  control('control', 'Cita de control', Icons.event_repeat_outlined, AppColors.accentDark, 'Agendar control'),
  examen('examen', 'Examen o estudio', Icons.biotech_outlined, Color(0xFF6D4C9F), 'Adjuntar orden'),
  nota('nota', 'Nota informativa', Icons.sticky_note_2_outlined, AppColors.textSecondary, 'Marcar como leida');

  const TipoOrden(this.key, this.label, this.icono, this.color, this.accion);

  final String key;
  final String label;
  final IconData icono;
  final Color color;

  /// Texto del boton que resuelve este tipo de orden.
  final String accion;

  bool get requiereArchivo => this == TipoOrden.receta || this == TipoOrden.examen;
  bool get requiereCita => this == TipoOrden.control;

  static TipoOrden fromRaw(Object? raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    return TipoOrden.values.firstWhere((t) => t.key == v, orElse: () => TipoOrden.nota);
  }
}

enum EstadoOrden {
  pendiente('pendiente', 'Pendiente', AppColors.warning, AppColors.warningSoft),
  hecha('hecha', 'Resuelta', AppColors.success, AppColors.successSoft),
  omitida('omitida', 'Omitida', AppColors.textMuted, Color(0xFFEDF0F0));

  const EstadoOrden(this.key, this.label, this.color, this.background);

  final String key;
  final String label;
  final Color color;
  final Color background;

  static EstadoOrden fromRaw(Object? raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    return EstadoOrden.values.firstWhere((e) => e.key == v, orElse: () => EstadoOrden.pendiente);
  }
}

/// Una indicacion colgada de una cita.
///
/// Es la pieza que faltaba en el sistema: sin ella la secretaria no tenia de
/// donde leer que le toca hacer despues de cada consulta, y el historial
/// clinico solo podia mostrar una lista de eventos que no se podian tocar.
class MedicalOrder extends Equatable {
  const MedicalOrder({
    required this.id,
    required this.citaId,
    required this.patientId,
    required this.patientName,
    required this.tipo,
    required this.descripcion,
    required this.estado,
    this.representativeId = '',
    this.fechaSugerida,
    this.creadaPor = '',
    this.creadaPorNombre = '',
    this.creadaEn,
    this.resueltaPor = '',
    this.resueltaEn,
    this.adjuntoUrl,
    this.adjuntoNombre,
    this.adjuntoRuta,
    this.citaGeneradaId,
    this.notaSecretaria,
  });

  final String id;
  final String citaId;
  final String patientId;
  final String patientName;
  final String representativeId;

  final TipoOrden tipo;
  final String descripcion;
  final EstadoOrden estado;

  /// Solo para las ordenes de tipo control.
  final DateTime? fechaSugerida;

  final String creadaPor;
  final String creadaPorNombre;
  final DateTime? creadaEn;
  final String resueltaPor;
  final DateTime? resueltaEn;

  /// Se llena cuando la secretaria sube la receta o el examen.
  final String? adjuntoUrl;
  final String? adjuntoNombre;
  final String? adjuntoRuta;

  /// Se llena cuando la secretaria agenda el control indicado.
  final String? citaGeneradaId;

  final String? notaSecretaria;

  bool get pendiente => estado == EstadoOrden.pendiente;
  bool get tieneAdjunto => (adjuntoUrl ?? '').isNotEmpty;

  bool get vencida {
    if (!pendiente || fechaSugerida == null) return false;
    final hoy = DateTime.now();
    return fechaSugerida!.isBefore(DateTime(hoy.year, hoy.month, hoy.day));
  }

  bool get esParaHoy {
    if (fechaSugerida == null) return false;
    final hoy = DateTime.now();
    return fechaSugerida!.year == hoy.year &&
        fechaSugerida!.month == hoy.month &&
        fechaSugerida!.day == hoy.day;
  }

  factory MedicalOrder.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    DateTime? ts(String k) => d[k] is Timestamp ? (d[k] as Timestamp).toDate() : null;

    return MedicalOrder(
      id: doc.id,
      // El id del padre: `citas/{citaId}/ordenes/{ordenId}`.
      citaId: d['citaId'] as String? ?? doc.reference.parent.parent?.id ?? '',
      patientId: d['patientId'] as String? ?? '',
      patientName: d['patientName'] as String? ?? '',
      representativeId: d['representativeId'] as String? ?? '',
      tipo: TipoOrden.fromRaw(d['tipo']),
      descripcion: d['descripcion'] as String? ?? '',
      estado: EstadoOrden.fromRaw(d['estado']),
      fechaSugerida: ts('fechaSugerida'),
      creadaPor: d['creadaPor'] as String? ?? '',
      creadaPorNombre: d['creadaPorNombre'] as String? ?? '',
      creadaEn: ts('creadaEn'),
      resueltaPor: d['resueltaPor'] as String? ?? '',
      resueltaEn: ts('resueltaEn'),
      adjuntoUrl: d['adjuntoUrl'] as String?,
      adjuntoNombre: d['adjuntoNombre'] as String?,
      adjuntoRuta: d['adjuntoRuta'] as String?,
      citaGeneradaId: d['citaGeneradaId'] as String?,
      notaSecretaria: d['notaSecretaria'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'citaId': citaId,
        'patientId': patientId,
        'patientName': patientName,
        'representativeId': representativeId,
        'tipo': tipo.key,
        'descripcion': descripcion,
        'estado': estado.key,
        'fechaSugerida': fechaSugerida == null ? null : Timestamp.fromDate(fechaSugerida!),
        'creadaPor': creadaPor,
        'creadaPorNombre': creadaPorNombre,
        'resueltaPor': resueltaPor,
        'adjuntoUrl': adjuntoUrl,
        'adjuntoNombre': adjuntoNombre,
        'adjuntoRuta': adjuntoRuta,
        'citaGeneradaId': citaGeneradaId,
        'notaSecretaria': notaSecretaria,
      };

  @override
  List<Object?> get props => [id, citaId, patientId, tipo, descripcion, estado, fechaSugerida, adjuntoUrl, citaGeneradaId];
}
