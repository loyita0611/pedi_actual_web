// lib/features/schedule/presentation/pages/mis_pagos_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/utils/file_opener.dart';
import '../../../../core/widgets/async_states.dart';
import '../../data/models/appointment_model.dart';
import '../../domain/entities/appointment_entity.dart';

/// Historial de pagos del representante.
///
/// Dos arreglos importantes: ya no existe el correo de prueba que estaba
/// escrito en el codigo (si no habia sesion se consultaban los pagos de otra
/// persona), y el estado se lee con el mismo vocabulario que escribe la
/// secretaria, asi que un pago verificado por fin aparece como confirmado.
class MisPagosPage extends StatelessWidget {
  const MisPagosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario == null) {
      return const EstadoVacio(
        icono: Icons.lock_outline,
        titulo: 'Inicia sesion para ver tus pagos',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis Pagos',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 6),
            const Text('Estado de cada pago que has reportado.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Expanded(
              child: ColeccionView<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('citas')
                    .where('representativeId', isEqualTo: usuario.uid)
                    .snapshots(),
                estaVacio: (s) => s.docs.isEmpty,
                vacio: const EstadoVacio(
                  icono: Icons.account_balance_wallet_outlined,
                  titulo: 'Sin pagos reportados',
                  detalle: 'Tus reportes bancarios apareceran aqui al agendar una cita.',
                ),
                builder: (context, snap) {
                  final citas = snap.docs
                      .map((d) => AppointmentModel.fromJson(d.data(), d.id))
                      .where((c) => c.pagoMonto != null || c.pagoReferencia != null)
                      .toList()
                    ..sort((a, b) => b.appointmentDateTime.compareTo(a.appointmentDateTime));

                  final porVerificar =
                      citas.where((c) => c.pagoEstado == PagoStatus.pendiente).length;
                  final verificados =
                      citas.where((c) => c.pagoEstado == PagoStatus.verificado).length;
                  final rechazados =
                      citas.where((c) => c.pagoEstado == PagoStatus.rechazado).length;

                  return Column(
                    children: [
                      Row(
                        children: [
                          _kpi('Por verificar', porVerificar, PagoStatus.pendiente),
                          const SizedBox(width: 14),
                          _kpi('Verificados', verificados, PagoStatus.verificado),
                          if (rechazados > 0) ...[
                            const SizedBox(width: 14),
                            _kpi('Rechazados', rechazados, PagoStatus.rechazado),
                          ],
                        ],
                      ),
                      const SizedBox(height: 22),
                      Expanded(
                        child: ListView.separated(
                          itemCount: citas.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _FilaPago(cita: citas[i]),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String titulo, int valor, PagoStatus estado) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: estado.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: estado.color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Text('$valor',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: estado.color)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(titulo,
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      );
}

class _FilaPago extends StatelessWidget {
  const _FilaPago({required this.cita});
  final AppointmentEntity cita;

  @override
  Widget build(BuildContext context) {
    final rechazado = cita.pagoEstado == PagoStatus.rechazado;
    final telefono = ClinicConfigService.actual.telefonoClinica;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: rechazado ? AppColors.danger.withValues(alpha: 0.4) : AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cita.patientName.isEmpty ? 'Sin nombre' : cita.patientName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        'Cita del ${DateFormat('d/MM/y').format(cita.appointmentDateTime)}',
                        cita.pagoMetodo ?? 'Pago movil',
                        if ((cita.pagoBanco ?? '').isNotEmpty) cita.pagoBanco!,
                        if ((cita.pagoReferencia ?? '').isNotEmpty) 'Ref. ${cita.pagoReferencia}',
                      ].join('  ·  '),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    cita.pagoMonto == null
                        ? '-'
                        : '${cita.pagoMonto!.toStringAsFixed(2)} Bs.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  StatusPill.pago(cita.pagoEstado, dense: true),
                ],
              ),
            ],
          ),
          if (cita.tieneComprobante) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => abrirArchivo(context, cita.pagoComprobanteUrl),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_outlined, size: 15, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text('Ver mi comprobante',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.primaryDark,
                          decoration: TextDecoration.underline)),
                ],
              ),
            ),
          ],
          if (rechazado) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Por que se rechazo',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger)),
                  const SizedBox(height: 4),
                  // El motivo real, escrito por la secretaria. Antes el boton de
                  // "consultar el motivo" solo imprimia un texto en la consola.
                  Text(
                    (cita.pagoMotivoRechazo ?? '').isEmpty
                        ? 'La clinica no registro un motivo. Comunicate al $telefono.'
                        : cita.pagoMotivoRechazo!,
                    style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text('Puedes reportar el pago de nuevo o llamar al $telefono.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
