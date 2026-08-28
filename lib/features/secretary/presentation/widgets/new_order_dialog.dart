// lib/features/secretary/presentation/widgets/new_order_dialog.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../../orders/data/medical_order_service.dart';
import '../../../orders/domain/medical_order.dart';
import '../../../schedule/domain/entities/appointment_entity.dart';

/// Crea una indicacion sobre una cita.
///
/// El panel de la doctora todavia no existe, asi que la secretaria puede
/// registrar aqui lo que la doctora le dicta. Cuando ese panel se construya,
/// escribira en la misma subcoleccion y esta pantalla seguira funcionando igual.
class NewOrderDialog extends StatefulWidget {
  const NewOrderDialog({super.key, required this.cita});

  final AppointmentEntity cita;

  static Future<bool?> mostrar(BuildContext context, {required AppointmentEntity cita}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => NewOrderDialog(cita: cita),
    );
  }

  @override
  State<NewOrderDialog> createState() => _NewOrderDialogState();
}

class _NewOrderDialogState extends State<NewOrderDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descripcion = TextEditingController();
  TipoOrden _tipo = TipoOrden.receta;
  DateTime? _fechaSugerida;
  bool _guardando = false;

  @override
  void dispose() {
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fechaSugerida ?? hoy.add(const Duration(days: 15)),
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: hoy.add(const Duration(days: 365)),
      selectableDayPredicate: (d) => ClinicConfigService.actual.esDiaHabil(d),
    );
    if (elegida != null && mounted) setState(() => _fechaSugerida = elegida);
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_tipo.requiereCita && _fechaSugerida == null) {
      mostrarAviso(context, 'Indica para cuando sugiere la doctora el control.', esError: true);
      return;
    }

    setState(() => _guardando = true);
    try {
      await di.sl<MedicalOrderService>().crear(
            citaId: widget.cita.id,
            patientId: widget.cita.patientId,
            patientName: widget.cita.patientName,
            representativeId: widget.cita.representativeId,
            tipo: _tipo,
            descripcion: _descripcion.text,
            fechaSugerida: _tipo.requiereCita ? _fechaSugerida : null,
            creadaPorNombre: FirebaseAuth.instance.currentUser?.displayName ?? 'Secretaria',
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      mostrarAviso(context, 'Indicacion registrada.', esExito: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarAviso(context, 'No se pudo guardar: $e', esError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Nueva indicacion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 470,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paciente: ${widget.cita.patientName}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 18),
              const Text('Tipo de indicacion',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in TipoOrden.values)
                    ChoiceChip(
                      avatar: Icon(t.icono, size: 16, color: _tipo == t ? t.color : AppColors.textMuted),
                      label: Text(t.label),
                      selected: _tipo == t,
                      onSelected: (_) => setState(() => _tipo = t),
                      selectedColor: t.color.withValues(alpha: 0.14),
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        color: _tipo == t ? t.color : AppColors.textSecondary,
                        fontWeight: _tipo == t ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _descripcion,
                autofocus: true,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Que indico la doctora',
                  hintText: switch (_tipo) {
                    TipoOrden.receta => 'Amoxicilina 250mg/5ml - 7 dias',
                    TipoOrden.control => 'Control de peso y talla',
                    TipoOrden.examen => 'Hematologia completa',
                    TipoOrden.nota => 'Recordar traer el carnet de vacunas',
                  },
                  prefixIcon: const Icon(Icons.notes),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Escribe la indicacion' : null,
              ),
              if (_tipo.requiereCita) ...[
                const SizedBox(height: 16),
                InkWell(
                  onTap: _elegirFecha,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha sugerida para el control',
                      prefixIcon: const Icon(Icons.event_outlined),
                      errorText: _fechaSugerida == null ? 'Requerida para un control' : null,
                    ),
                    child: Text(
                      _fechaSugerida == null
                          ? 'Toca para elegir'
                          : DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(_fechaSugerida!),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ],
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
              : const Text('Guardar indicacion'),
        ),
      ],
    );
  }
}
