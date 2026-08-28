// lib/features/schedule/presentation/widgets/slot_picker_dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/async_states.dart';
import '../../data/models/appointment_model.dart';
import '../../domain/entities/appointment_entity.dart';
import 'time_slot_helper.dart';

/// Selector de horario reutilizable.
///
/// Lo usan la reprogramacion del paciente, la cita asistida de la secretaria y
/// el boton "Agendar control" de las indicaciones medicas. Antes cada uno tenia
/// su propia lista de horas escrita a mano y las tres eran distintas.
class SlotPickerDialog extends StatefulWidget {
  const SlotPickerDialog({
    super.key,
    required this.fechaInicial,
    this.titulo = 'Elegir horario',
    this.permitirCambiarFecha = true,
  });

  final DateTime fechaInicial;
  final String titulo;
  final bool permitirCambiarFecha;

  /// Devuelve el DateTime elegido, o null si se cancela.
  static Future<DateTime?> mostrar(
    BuildContext context, {
    required DateTime fechaInicial,
    String titulo = 'Elegir horario',
    bool permitirCambiarFecha = true,
  }) {
    return showDialog<DateTime>(
      context: context,
      builder: (_) => SlotPickerDialog(
        fechaInicial: fechaInicial,
        titulo: titulo,
        permitirCambiarFecha: permitirCambiarFecha,
      ),
    );
  }

  @override
  State<SlotPickerDialog> createState() => _SlotPickerDialogState();
}

class _SlotPickerDialogState extends State<SlotPickerDialog> {
  late DateTime _fecha;
  late Future<List<AppointmentEntity>> _futuro;

  @override
  void initState() {
    super.initState();
    final hoy = DateTime.now();
    final base = widget.fechaInicial.isBefore(DateTime(hoy.year, hoy.month, hoy.day))
        ? hoy
        : widget.fechaInicial;
    _fecha = DateTime(base.year, base.month, base.day);
    _futuro = _cargar(_fecha);
  }

  Future<List<AppointmentEntity>> _cargar(DateTime dia) async {
    final inicio = DateTime(dia.year, dia.month, dia.day);
    final fin = DateTime(dia.year, dia.month, dia.day, 23, 59, 59, 999);
    final snap = await FirebaseFirestore.instance
        .collection('citas')
        .where('appointmentDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
        .where('appointmentDateTime', isLessThanOrEqualTo: Timestamp.fromDate(fin))
        .get();
    return snap.docs.map((d) => AppointmentModel.fromJson(d.data(), d.id)).toList();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      // Ya no se puede retroceder un ano: solo de hoy en adelante.
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 365)),
      selectableDayPredicate: (d) => ClinicConfigService.actual.esDiaHabil(d),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (elegida != null && mounted) {
      setState(() {
        _fecha = DateTime(elegida.year, elegida.month, elegida.day);
        _futuro = _cargar(_fecha);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.titulo,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.event, size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 7),
              Text(
                DateFormat("EEEE d 'de' MMMM", 'es').format(_fecha),
                style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              if (widget.permitirCambiarFecha)
                TextButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 17),
                  label: const Text('Cambiar dia'),
                ),
            ],
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        height: 300,
        child: FutureBuilder<List<AppointmentEntity>>(
          future: _futuro,
          builder: (context, snap) {
            if (snap.hasError) return EstadoError(error: snap.error);
            if (snap.connectionState == ConnectionState.waiting) {
              return const CargandoCentrado(mensaje: 'Consultando disponibilidad...');
            }

            final slots = TimeSlotHelper.generateSlotsForDate(
              selectedDate: _fecha,
              bookedAppointments: snap.data ?? const [],
            );

            if (slots.isEmpty) {
              return const EstadoVacio(
                icono: Icons.event_busy,
                titulo: 'La consulta no atiende este dia',
                detalle: 'Elige otra fecha.',
              );
            }
            if (slots.every((s) => !s.disponible)) {
              return const EstadoVacio(
                icono: Icons.event_busy,
                titulo: 'No queda ningun cupo libre este dia',
                detalle: 'Prueba con el dia siguiente.',
              );
            }

            return GridView.builder(
              itemCount: slots.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 2.3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, i) {
                final s = slots[i];
                return OutlinedButton(
                  onPressed: s.disponible ? () => Navigator.pop(context, s.dateTime) : null,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: s.disponible ? Colors.transparent : const Color(0xFFF3F5F5),
                    side: BorderSide(color: s.disponible ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    s.timeString,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: s.disponible ? AppColors.primary : AppColors.textMuted,
                      decoration: s.isOccupied ? TextDecoration.lineThrough : null,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
        ),
      ],
    );
  }
}
