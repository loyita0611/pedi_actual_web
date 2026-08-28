// lib/features/orders/presentation/widgets/order_tile.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/medical_order.dart';

/// Una indicacion de la doctora con su boton de accion.
///
/// El boton cambia segun el tipo: "Subir receta (PDF)" para una receta,
/// "Agendar 12/09" para un control con la fecha que ella sugirio.
class OrderTile extends StatelessWidget {
  const OrderTile({
    super.key,
    required this.orden,
    required this.onResolver,
    this.onOmitir,
    this.onAbrirAdjunto,
    this.onReabrir,
    this.trabajando = false,
    this.mostrarPaciente = false,
  });

  final MedicalOrder orden;
  final VoidCallback onResolver;
  final VoidCallback? onOmitir;
  final VoidCallback? onAbrirAdjunto;
  final VoidCallback? onReabrir;
  final bool trabajando;
  final bool mostrarPaciente;

  @override
  Widget build(BuildContext context) {
    final vencida = orden.vencida;
    final hoy = orden.esParaHoy && orden.pendiente;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: vencida
              ? AppColors.danger.withValues(alpha: 0.45)
              : hoy
                  ? AppColors.accent
                  : AppColors.border,
          width: vencida || hoy ? 1.4 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: orden.tipo.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(orden.tipo.icono, size: 20, color: orden.tipo.color),
          ),
          const SizedBox(width: 13),
          Expanded(child: _Detalle(orden: orden, mostrarPaciente: mostrarPaciente, onAbrirAdjunto: onAbrirAdjunto)),
          const SizedBox(width: 12),
          _Acciones(
            orden: orden,
            trabajando: trabajando,
            onResolver: onResolver,
            onOmitir: onOmitir,
            onReabrir: onReabrir,
          ),
        ],
      ),
    );
  }
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.orden, required this.mostrarPaciente, this.onAbrirAdjunto});

  final MedicalOrder orden;
  final bool mostrarPaciente;
  final VoidCallback? onAbrirAdjunto;

  @override
  Widget build(BuildContext context) {
    final vencida = orden.vencida;
    final hoy = orden.esParaHoy && orden.pendiente;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              orden.tipo.label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: orden.tipo.color,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: orden.estado.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                orden.estado.label,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: orden.estado.color),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          orden.descripcion.isEmpty ? orden.tipo.label : orden.descripcion,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
        ),
        if (mostrarPaciente && orden.patientName.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text('Paciente: ${orden.patientName}',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
        if (orden.fechaSugerida != null) ...[
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                vencida ? Icons.warning_amber_rounded : Icons.event_outlined,
                size: 14,
                color: vencida ? AppColors.danger : AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  vencida
                      ? 'Vencida: era para el ${DateFormat('d/MM/y').format(orden.fechaSugerida!)}'
                      : hoy
                          ? 'Sugerida para HOY'
                          : 'Sugerida para el ${DateFormat("d 'de' MMMM", 'es').format(orden.fechaSugerida!)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: vencida || hoy ? FontWeight.bold : FontWeight.normal,
                    color: vencida
                        ? AppColors.danger
                        : hoy
                            ? AppColors.accentDark
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (orden.tieneAdjunto) ...[
          const SizedBox(height: 7),
          InkWell(
            onTap: onAbrirAdjunto,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.picture_as_pdf, size: 15, color: AppColors.danger),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    orden.adjuntoNombre ?? 'Ver archivo',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.primaryDark,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (orden.citaGeneradaId != null) ...[
          const SizedBox(height: 6),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 14, color: AppColors.success),
              SizedBox(width: 6),
              Text('Control ya agendado', style: TextStyle(fontSize: 12, color: AppColors.success)),
            ],
          ),
        ],
        if ((orden.notaSecretaria ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Nota: ${orden.notaSecretaria}',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textMuted)),
        ],
      ],
    );
  }
}

class _Acciones extends StatelessWidget {
  const _Acciones({
    required this.orden,
    required this.trabajando,
    required this.onResolver,
    this.onOmitir,
    this.onReabrir,
  });

  final MedicalOrder orden;
  final bool trabajando;
  final VoidCallback onResolver;
  final VoidCallback? onOmitir;
  final VoidCallback? onReabrir;

  @override
  Widget build(BuildContext context) {
    if (trabajando) {
      return const SizedBox(
        width: 172,
        height: 40,
        child: Center(
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    }

    if (!orden.pendiente) {
      return SizedBox(
        width: 172,
        child: Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onReabrir,
            icon: const Icon(Icons.undo, size: 15),
            label: const Text('Reabrir', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(foregroundColor: AppColors.textMuted),
          ),
        ),
      );
    }

    return SizedBox(
      width: 172,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onResolver,
              icon: Icon(orden.tipo.requiereCita ? Icons.event_available : Icons.upload_file, size: 16),
              label: Text(
                orden.tipo.requiereCita && orden.fechaSugerida != null
                    ? 'Agendar ${DateFormat('d/MM').format(orden.fechaSugerida!)}'
                    : orden.tipo.accion,
                style: const TextStyle(fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: orden.tipo.color,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              ),
            ),
          ),
          if (onOmitir != null)
            TextButton(
              onPressed: onOmitir,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textMuted,
                minimumSize: const Size(0, 28),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Omitir', style: TextStyle(fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}
