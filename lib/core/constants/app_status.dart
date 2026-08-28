// lib/core/constants/app_status.dart
import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Estado de asistencia de una cita.
///
/// Las claves se mantienen en ingles porque son las que ya existen en la
/// coleccion `citas`; asi no hace falta migrar los documentos guardados.
/// Lo que se unifica es la lectura: antes cada widget interpretaba los
/// valores a su manera y ninguno coincidia.
enum CitaStatus {
  pendiente('pending', 'Pendiente', AppColors.textMuted, Color(0xFFEDF0F0)),
  confirmada('confirmed', 'Confirmada', AppColors.info, AppColors.infoSoft),
  enSala('in_room', 'En sala', AppColors.warning, AppColors.warningSoft),
  atendida('attended', 'Atendida', AppColors.success, AppColors.successSoft),
  noAsistio('no_show', 'No asistio', AppColors.accentDark, Color(0xFFFBEDE2)),
  cancelada('cancelled', 'Cancelada', AppColors.danger, AppColors.dangerSoft);

  const CitaStatus(this.key, this.label, this.color, this.background);

  final String key;
  final String label;
  final Color color;
  final Color background;

  bool get esActiva => this != CitaStatus.cancelada && this != CitaStatus.noAsistio;
  bool get esCerrada => this == CitaStatus.atendida || this == CitaStatus.cancelada || this == CitaStatus.noAsistio;

  static CitaStatus fromRaw(Object? raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    for (final s in CitaStatus.values) {
      if (s.key == v) return s;
    }
    // Tolerancia con valores heredados o escritos a mano.
    switch (v) {
      case 'confirmada':
        return CitaStatus.confirmada;
      case 'en_sala':
      case 'inconsultation':
        return CitaStatus.enSala;
      case 'atendida':
      case 'completed':
        return CitaStatus.atendida;
      case 'no_asistio':
      case 'noshow':
        return CitaStatus.noAsistio;
      case 'cancelada':
      case 'canceled':
        return CitaStatus.cancelada;
      default:
        return CitaStatus.pendiente;
    }
  }
}

/// Estado de verificacion de un pago.
///
/// Este si estaba roto de verdad: la secretaria escribia `approved` en `pagos`,
/// el paciente leia `pagoEstado` esperando `pagado`, y el panel diario esperaba
/// `verificado`. Ahora hay un solo vocabulario y el parser acepta los tres
/// dialectos viejos para no perder los registros existentes.
enum PagoStatus {
  pendiente('pending', 'Por verificar', AppColors.warning, AppColors.warningSoft),
  verificado('verified', 'Verificado', AppColors.success, AppColors.successSoft),
  rechazado('rejected', 'Rechazado', AppColors.danger, AppColors.dangerSoft);

  const PagoStatus(this.key, this.label, this.color, this.background);

  final String key;
  final String label;
  final Color color;
  final Color background;

  static PagoStatus fromRaw(Object? raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    switch (v) {
      case 'verified':
      case 'verificado':
      case 'approved':
      case 'aprobado':
      case 'pagado':
        return PagoStatus.verificado;
      case 'rejected':
      case 'rechazado':
        return PagoStatus.rechazado;
      default:
        return PagoStatus.pendiente;
    }
  }
}

/// Metodos de pago aceptados por la clinica.
enum MetodoPago {
  pagoMovil('Pago Movil'),
  transferencia('Transferencia Bancaria'),
  efectivo('Efectivo en consultorio');

  const MetodoPago(this.label);
  final String label;

  static MetodoPago fromRaw(Object? raw) {
    final v = (raw ?? '').toString().trim().toLowerCase();
    if (v.startsWith('transfer')) return MetodoPago.transferencia;
    if (v.startsWith('efectivo')) return MetodoPago.efectivo;
    return MetodoPago.pagoMovil;
  }
}

/// Chip reutilizable. Reemplaza los tres constructores de chip distintos que
/// habia repartidos entre los widgets de secretaria y la pantalla de pagos.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
    this.dense = false,
  });

  factory StatusPill.cita(CitaStatus s, {bool dense = false}) =>
      StatusPill(label: s.label, color: s.color, background: s.background, dense: dense);

  factory StatusPill.pago(PagoStatus s, {bool dense = false}) =>
      StatusPill(label: s.label, color: s.color, background: s.background, dense: dense);

  final String label;
  final Color color;
  final Color background;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12, vertical: dense ? 3 : 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: dense ? 10.5 : 12,
            ),
          ),
        ],
      ),
    );
  }
}
