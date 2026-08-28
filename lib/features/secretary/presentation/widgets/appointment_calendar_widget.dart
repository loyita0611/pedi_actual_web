// lib/features/secretary/presentation/widgets/appointment_calendar_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../schedule/data/models/appointment_model.dart';
import 'appointment_actions_menu.dart';

/// Agenda general, dia por dia.
class AppointmentCalendarWidget extends StatefulWidget {
  const AppointmentCalendarWidget({super.key});

  @override
  State<AppointmentCalendarWidget> createState() => _AppointmentCalendarWidgetState();
}

class _AppointmentCalendarWidgetState extends State<AppointmentCalendarWidget> {
  DateTime _dia = DateTime.now();
  CitaStatus? _filtro;

  void _mover(int dias) => setState(() => _dia = _dia.add(Duration(days: dias)));

  Future<void> _elegirDia() async {
    final elegido = await showDatePicker(
      context: context,
      initialDate: _dia,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 730)),
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
    if (elegido != null) setState(() => _dia = elegido);
  }

  @override
  Widget build(BuildContext context) {
    final inicio = DateTime(_dia.year, _dia.month, _dia.day);
    final fin = DateTime(_dia.year, _dia.month, _dia.day, 23, 59, 59, 999);
    final esHabil = ClinicConfigService.actual.esDiaHabil(_dia);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: AppColors.primary),
                onPressed: () => _mover(-1),
                tooltip: 'Dia anterior',
              ),
              InkWell(
                onTap: _elegirDia,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat("EEEE d 'de' MMMM", 'es').format(_dia),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      if (!esHabil)
                        const Text('La consulta no atiende este dia',
                            style: TextStyle(fontSize: 11.5, color: AppColors.warning)),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: AppColors.primary),
                onPressed: () => _mover(1),
                tooltip: 'Dia siguiente',
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => setState(() => _dia = DateTime.now()),
                child: const Text('Hoy'),
              ),
              const Spacer(),
              DropdownButton<CitaStatus?>(
                value: _filtro,
                hint: const Text('Todos los estados', style: TextStyle(fontSize: 13)),
                underline: const SizedBox.shrink(),
                items: [
                  const DropdownMenuItem<CitaStatus?>(
                      value: null, child: Text('Todos los estados', style: TextStyle(fontSize: 13))),
                  for (final e in CitaStatus.values)
                    DropdownMenuItem<CitaStatus?>(
                        value: e, child: Text(e.label, style: const TextStyle(fontSize: 13))),
                ],
                onChanged: (v) => setState(() => _filtro = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ColeccionView<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('citas')
                  .where('appointmentDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
                  .where('appointmentDateTime', isLessThanOrEqualTo: Timestamp.fromDate(fin))
                  .snapshots(),
              estaVacio: (s) => s.docs.isEmpty,
              vacio: EstadoVacio(
                icono: Icons.event_busy,
                titulo: 'No hay citas el ${DateFormat('d/MM/y').format(_dia)}',
              ),
              builder: (context, snap) {
                var citas = snap.docs.map((d) => AppointmentModel.fromJson(d.data(), d.id)).toList()
                  ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));

                if (_filtro != null) {
                  citas = citas.where((c) => c.status == _filtro).toList();
                }
                if (citas.isEmpty) {
                  return EstadoVacio(
                    icono: Icons.filter_alt_off_outlined,
                    titulo: 'Ninguna cita con el estado "${_filtro!.label}"',
                    accion: OutlinedButton(
                      onPressed: () => setState(() => _filtro = null),
                      child: const Text('Quitar filtro'),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: citas.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = citas[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      leading: CircleAvatar(
                        backgroundColor: c.status.background,
                        child: Icon(Icons.person, color: c.status.color),
                      ),
                      title: Text(c.patientName.isEmpty ? 'Sin nombre' : c.patientName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                      subtitle: Text(
                        [
                          DateFormat('h:mm a').format(c.appointmentDateTime),
                          if (c.motivo.isNotEmpty) c.motivo,
                          if (c.representativeName.isNotEmpty) 'Rep.: ${c.representativeName}',
                        ].join('  ·  '),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusPill.cita(c.status, dense: true),
                          const SizedBox(width: 8),
                          AppointmentActionsMenu(cita: c),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
