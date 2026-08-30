// lib/features/schedule/presentation/pages/mis_citas_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../data/models/appointment_model.dart';
import '../../domain/entities/appointment_entity.dart';
import '../../domain/usecases/cancel_appointment.dart';
import '../../domain/usecases/reschedule_appointment.dart';
import '../widgets/slot_picker_dialog.dart';

/// Mis citas.
///
/// El representante no tenia ninguna pantalla donde ver sus propias citas, ni
/// forma de cancelarlas: `cancelAppointment` estaba implementado en las tres
/// capas y ninguna vista lo llamaba.
class MisCitasPage extends StatefulWidget {
  const MisCitasPage({super.key});

  @override
  State<MisCitasPage> createState() => _MisCitasPageState();
}

class _MisCitasPageState extends State<MisCitasPage> {
  final _uid = FirebaseAuth.instance.currentUser?.uid;
  final _correo = FirebaseAuth.instance.currentUser?.email;
  String? _procesando;

  Stream<List<AppointmentEntity>> _misCitas() {
    if (_uid == null) return Stream.value(const []);
    // Se consulta por uid; las citas viejas se enlazaban solo por correo.
    return FirebaseFirestore.instance
        .collection('citas')
        .where('representativeId', isEqualTo: _uid)
        .snapshots()
        .map((s) => s.docs.map((d) => AppointmentModel.fromJson(d.data(), d.id)).toList());
  }

  Stream<List<AppointmentEntity>> _porCorreo() {
    if ((_correo ?? '').isEmpty) return Stream.value(const []);
    return FirebaseFirestore.instance
        .collection('citas')
        .where('email', isEqualTo: _correo)
        .snapshots()
        .map((s) => s.docs.map((d) => AppointmentModel.fromJson(d.data(), d.id)).toList());
  }

  Future<void> _cancelar(AppointmentEntity cita) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Expanded(
              child: Text('Esta seguro que desea cancelar la cita?',
                  style: TextStyle(fontSize: 17)),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cita de ${cita.patientName}, '
              '${DateFormat("d 'de' MMMM 'a las' h:mm a", 'es').format(cita.appointmentDateTime)}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerSoft,
                borderRadius: BorderRadius.circular(9),
                border:
                    Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
              ),
              child: const Text(
                'Al hacerlo perdera su cita y se tendra que comunicar con el '
                'consultorio para el reembolso del dinero.',
                style: TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, conservar mi cita',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Si, cancelar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() => _procesando = cita.id);
    try {
      await di.sl<CancelAppointment>()(cita);
      if (mounted) mostrarAviso(context, 'Tu cita fue cancelada.', esExito: true);
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''), esError: true);
      }
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  Future<void> _reprogramar(AppointmentEntity cita) async {
    final nueva = await SlotPickerDialog.mostrar(
      context,
      fechaInicial: cita.appointmentDateTime,
      titulo: 'Nueva fecha para ${cita.patientName}',
    );
    if (nueva == null || !mounted) return;

    setState(() => _procesando = cita.id);
    try {
      await di.sl<RescheduleAppointment>()(cita, nueva);
      // El correo lo manda el servidor al ver el cambio en Firestore.
      if (mounted) {
        mostrarAviso(
          context,
          'Cita reprogramada para el ${DateFormat("d 'de' MMMM 'a las' h:mm a", 'es').format(nueva)}.',
          esExito: true,
        );
      }
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''), esError: true);
      }
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const EstadoVacio(icono: Icons.lock_outline, titulo: 'Inicia sesion para ver tus citas');
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mis Citas',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 6),
            const Text('Tus proximas consultas y el historial de las anteriores.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            Expanded(
              child: StreamBuilder<List<AppointmentEntity>>(
                stream: _misCitas(),
                builder: (context, porUid) {
                  return StreamBuilder<List<AppointmentEntity>>(
                    stream: _porCorreo(),
                    builder: (context, porCorreo) {
                      if (porUid.hasError) return EstadoError(error: porUid.error);
                      if (!porUid.hasData && !porCorreo.hasData) return const CargandoCentrado();

                      // Se unen ambas fuentes sin duplicar.
                      final mapa = <String, AppointmentEntity>{
                        for (final c in porUid.data ?? const <AppointmentEntity>[]) c.id: c,
                        for (final c in porCorreo.data ?? const <AppointmentEntity>[]) c.id: c,
                      };

                      final ahora = DateTime.now();
                      final proximas = mapa.values
                          .where((c) => c.appointmentDateTime.isAfter(ahora) && c.status.esActiva)
                          .toList()
                        ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
                      final pasadas = mapa.values
                          .where((c) => !(c.appointmentDateTime.isAfter(ahora) && c.status.esActiva))
                          .toList()
                        ..sort((a, b) => b.appointmentDateTime.compareTo(a.appointmentDateTime));

                      if (mapa.isEmpty) {
                        return const EstadoVacio(
                          icono: Icons.event_note_outlined,
                          titulo: 'Todavia no tienes citas',
                          detalle: 'Usa "Agendar cita" en el menu para reservar la primera.',
                        );
                      }

                      return ListView(
                        children: [
                          if (proximas.isNotEmpty) ...[
                            _titulo('Proximas', proximas.length),
                            for (final c in proximas) _tarjeta(c, proxima: true),
                            const SizedBox(height: 24),
                          ],
                          if (pasadas.isNotEmpty) ...[
                            _titulo('Anteriores', pasadas.length),
                            for (final c in pasadas) _tarjeta(c, proxima: false),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titulo(String texto, int cantidad) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text('$texto ($cantidad)',
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
      );

  Widget _tarjeta(AppointmentEntity cita, {required bool proxima}) {
    final ocupado = _procesando == cita.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: proxima ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 62,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: proxima ? AppColors.primarySoft : const Color(0xFFF3F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(DateFormat('MMM', 'es').format(cita.appointmentDateTime).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                Text('${cita.appointmentDateTime.day}',
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cita.patientName.isEmpty ? 'Sin nombre' : cita.patientName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 3),
                Text(
                  [
                    DateFormat('h:mm a').format(cita.appointmentDateTime),
                    if (cita.motivo.isNotEmpty) cita.motivo,
                  ].join('  ·  '),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusPill.cita(cita.status, dense: true),
                    const SizedBox(width: 7),
                    StatusPill.pago(cita.pagoEstado, dense: true),
                  ],
                ),
                if ((cita.pagoMotivoRechazo ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text('Pago rechazado: ${cita.pagoMotivoRechazo}',
                        style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                  ),
                ],
              ],
            ),
          ),
          if (proxima)
            ocupado
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                // Antes eran dos iconos pegados y sin texto: nadie sabia cual
                // era cual, y el de cancelar quedaba a un pixel del otro.
                : Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _reprogramar(cita),
                        icon: const Icon(Icons.event_repeat, size: 17),
                        label: const Text('Reprogramar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _cancelar(cita),
                        icon: const Icon(Icons.cancel_outlined, size: 17),
                        label: const Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(color: AppColors.danger),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                        ),
                      ),
                    ],
                  ),
        ],
      ),
    );
  }
}
