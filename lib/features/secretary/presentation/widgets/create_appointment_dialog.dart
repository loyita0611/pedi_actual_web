// lib/features/secretary/presentation/widgets/create_appointment_dialog.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/services/email_service.dart';
import '../../../../core/utils/search_utils.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../../schedule/domain/entities/appointment_entity.dart';
import '../../../schedule/domain/usecases/book_appointment.dart';
import '../../../schedule/presentation/widgets/slot_picker_dialog.dart';

/// Cita asistida (la que crea la secretaria por telefono).
///
/// La version anterior guardaba la cita sin correo y sin registro en `pagos`,
/// asi que no aparecia ni en el panel del representante ni en la pestana de
/// pagos; ademas dejaba elegir cualquier hora, incluida una ya ocupada.
class CreateAppointmentDialog extends StatefulWidget {
  const CreateAppointmentDialog({super.key});

  @override
  State<CreateAppointmentDialog> createState() => _CreateAppointmentDialogState();
}

class _CreateAppointmentDialogState extends State<CreateAppointmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _rep = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _motivo = TextEditingController();

  String? _patientId;
  String _representativeId = '';
  DateTime? _nacimiento;
  DateTime? _cuando;
  MetodoPago _metodo = MetodoPago.efectivo;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_nombre, _rep, _telefono, _correo, _motivo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _buscar(String consulta) async {
    final q = normalizarTexto(consulta);
    if (q.isEmpty) return const [];
    final snap = await FirebaseFirestore.instance
        .collection('patients')
        .where('nombreBusqueda', isGreaterThanOrEqualTo: q)
        .where('nombreBusqueda', isLessThanOrEqualTo: cotaSuperior(q))
        .limit(10)
        .get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }
    final legado = await FirebaseFirestore.instance
        .collection('patients')
        .orderBy('patientName')
        .limit(200)
        .get();
    return legado.docs
        .where((d) => normalizarTexto((d.data()['patientName'] ?? '').toString()).contains(q))
        .take(10)
        .map((d) => {'id': d.id, ...d.data()})
        .toList();
  }

  void _tomarPaciente(Map<String, dynamic> s) {
    setState(() {
      _patientId = s['id']?.toString();
      _nombre.text = s['patientName']?.toString() ?? '';
      _rep.text = s['representativeName']?.toString() ?? '';
      _telefono.text = s['phone']?.toString() ?? '';
      _correo.text = s['email']?.toString() ?? '';
      _representativeId = s['representativeId']?.toString() ?? '';
      final n = s['patientBirthDate'];
      if (n is Timestamp) _nacimiento = n.toDate();
    });
  }

  Future<void> _elegirHorario() async {
    final elegido = await SlotPickerDialog.mostrar(
      context,
      fechaInicial: _cuando ?? DateTime.now(),
      titulo: 'Elegir horario disponible',
    );
    if (elegido != null && mounted) setState(() => _cuando = elegido);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cuando == null) {
      mostrarAviso(context, 'Elige el horario de la cita.', esError: true);
      return;
    }

    setState(() => _guardando = true);
    try {
      final cita = AppointmentEntity(
        id: '',
        patientId: _patientId ?? '',
        representativeId: _representativeId,
        patientName: _nombre.text.trim(),
        // Si es un paciente nuevo del que no se sabe la fecha, se deja una
        // marca clara en vez de inventar la de hoy.
        patientBirthDate: _nacimiento ?? DateTime(2000),
        address: '',
        representativeName: _rep.text.trim(),
        email: _correo.text.trim(),
        phone: _telefono.text.trim(),
        appointmentDateTime: _cuando!,
        status: CitaStatus.confirmada,
        motivo: _motivo.text.trim(),
        pagoMetodo: _metodo.label,
        pagoMontoEsperado: ClinicConfigService.actual.tarifaUsd,
        pagoEstado: PagoStatus.pendiente,
      );

      await di.sl<BookAppointment>()(cita);

      // Ahora si se avisa al representante, si dejo correo.
      if (_correo.text.trim().isNotEmpty) {
        await di.sl<EmailService>().confirmacionCita(
              correo: _correo.text.trim(),
              paciente: _nombre.text.trim(),
              fecha: DateFormat('d/MM/y').format(_cuando!),
              hora: DateFormat('h:mm a').format(_cuando!),
              telefonoClinica: ClinicConfigService.actual.telefonoClinica,
            );
      }

      if (!mounted) return;
      Navigator.pop(context);
      mostrarAviso(context, 'Cita agendada con exito.', esExito: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarAviso(context, e.toString().replaceFirst('Exception: ', ''), esError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Row(
        children: [
          Icon(Icons.person_add_alt_1, color: AppColors.primary),
          SizedBox(width: 10),
          Text('Agendar cita asistida', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Un solo controlador, el del propio TypeAheadField: antes se
                // reescribia el texto en cada rebuild y el cursor saltaba.
                TypeAheadField<Map<String, dynamic>>(
                  controller: _nombre,
                  suggestionsCallback: _buscar,
                  emptyBuilder: (_) => const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('Paciente nuevo: se creara su ficha al guardar.',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ),
                  builder: (context, controller, focusNode) => TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Nombre del paciente',
                      helperText: _patientId == null
                          ? 'Escribe para buscar o crea uno nuevo'
                          : 'Paciente existente enlazado',
                      prefixIcon: const Icon(Icons.child_care),
                    ),
                    onChanged: (_) {
                      if (_patientId != null) setState(() => _patientId = null);
                    },
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  itemBuilder: (context, s) => ListTile(
                    dense: true,
                    title: Text(s['patientName']?.toString() ?? ''),
                    subtitle: Text('Rep.: ${s['representativeName'] ?? '-'}  ·  ${s['phone'] ?? ''}'),
                  ),
                  onSelected: _tomarPaciente,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _rep,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del representante', prefixIcon: Icon(Icons.family_restroom)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Telefono de contacto', prefixIcon: Icon(Icons.phone)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo del representante',
                    helperText: 'Sin correo, el representante no vera esta cita en su panel.',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _motivo,
                  decoration: const InputDecoration(
                      labelText: 'Motivo de la consulta', prefixIcon: Icon(Icons.medical_services_outlined)),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _elegirHorario,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha y hora',
                      prefixIcon: const Icon(Icons.event_available),
                      errorText: _cuando == null ? 'Elige un horario disponible' : null,
                    ),
                    child: Text(
                      _cuando == null
                          ? 'Toca para ver los horarios libres'
                          : DateFormat("EEEE d 'de' MMMM 'a las' h:mm a", 'es').format(_cuando!),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<MetodoPago>(
                  initialValue: _metodo,
                  decoration: const InputDecoration(
                      labelText: 'Forma de pago prevista', prefixIcon: Icon(Icons.payments_outlined)),
                  items: [
                    for (final m in MetodoPago.values)
                      DropdownMenuItem(value: m, child: Text(m.label)),
                  ],
                  onChanged: (v) => setState(() => _metodo = v ?? MetodoPago.efectivo),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirmar y reservar'),
        ),
      ],
    );
  }
}
