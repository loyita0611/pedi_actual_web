// lib/features/secretary/presentation/widgets/patient_directory_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/search_utils.dart';
import '../../../../core/widgets/async_states.dart';
import 'patient_history_panel.dart';

/// Directorio de pacientes.
class PatientDirectoryWidget extends StatefulWidget {
  const PatientDirectoryWidget({super.key});

  @override
  State<PatientDirectoryWidget> createState() => _PatientDirectoryWidgetState();
}

class _PatientDirectoryWidgetState extends State<PatientDirectoryWidget> {
  final _buscador = TextEditingController();
  String _consulta = '';

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _nuevoPaciente() async {
    final creado = await showDialog<bool>(
      context: context,
      builder: (_) => const _NuevoPacienteDialog(),
    );
    if (creado == true && mounted) {
      mostrarAviso(context, 'Paciente registrado.', esExito: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Directorio de Pacientes',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  SizedBox(height: 4),
                  Text(
                      'Abre el historial de un paciente para ver sus citas y lo que pidio la doctora.',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _nuevoPaciente,
              icon: const Icon(Icons.person_add_alt, size: 18),
              label: const Text('Nuevo paciente'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _buscador,
          decoration: InputDecoration(
            labelText: 'Buscar por nombre del niño o del representante',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _consulta.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _buscador.clear();
                      setState(() => _consulta = '');
                    },
                  ),
          ),
          onChanged: (v) => setState(() => _consulta = normalizarTexto(v)),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ColeccionView<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance.collection('patients').snapshots(),
            estaVacio: (s) => s.docs.isEmpty,
            vacio: const EstadoVacio(
              icono: Icons.people_outline,
              titulo: 'Todavia no hay pacientes',
              detalle:
                  'Se registran solos cuando un representante agenda su primera cita.',
            ),
            builder: (context, snap) {
              var docs = snap.docs.toList();

              if (_consulta.isNotEmpty) {
                docs = docs.where((d) {
                  final m = d.data();
                  final nombre =
                      normalizarTexto((m['patientName'] ?? '').toString());
                  final rep = normalizarTexto(
                      (m['representativeName'] ?? '').toString());
                  final tel = (m['phone'] ?? '').toString();
                  return nombre.contains(_consulta) ||
                      rep.contains(_consulta) ||
                      tel.contains(_consulta);
                }).toList();
              }

              docs.sort((a, b) => (a.data()['patientName'] ?? '')
                  .toString()
                  .toLowerCase()
                  .compareTo((b.data()['patientName'] ?? '')
                      .toString()
                      .toLowerCase()));

              if (docs.isEmpty) {
                return EstadoVacio(
                  icono: Icons.search_off,
                  titulo: 'Ningun paciente coincide',
                  detalle:
                      'Prueba con otra parte del nombre o con el telefono.',
                  accion: OutlinedButton(
                    onPressed: () {
                      _buscador.clear();
                      setState(() => _consulta = '');
                    },
                    child: const Text('Limpiar busqueda'),
                  ),
                );
              }

              return ListView.separated(
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final d = docs[i].data();
                  final nombre = (d['patientName'] ?? 'Sin nombre').toString();
                  final rep = (d['representativeName'] ?? '').toString();
                  final tel = (d['phone'] ?? '').toString();

                  return Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: ListTile(
                      onTap: () => PatientHistoryPanel.abrir(
                        context,
                        patientId: docs[i].id,
                        patientName: nombre,
                        representativeName: rep,
                        phone: tel,
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: AppColors.primarySoft,
                        child: Icon(Icons.child_care, color: AppColors.primary),
                      ),
                      title: Text(nombre,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      subtitle: Text(
                        [
                          if (rep.isNotEmpty) 'Rep.: $rep',
                          if (tel.isNotEmpty) tel,
                          if ((d['representativeId'] ?? '').toString().isEmpty)
                            'Sin cuenta enlazada',
                        ].join('  ·  '),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      trailing: OutlinedButton.icon(
                        onPressed: () => PatientHistoryPanel.abrir(
                          context,
                          patientId: docs[i].id,
                          patientName: nombre,
                          representativeName: rep,
                          phone: tel,
                        ),
                        icon: const Icon(Icons.history, size: 17),
                        label: const Text('Historial'),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NuevoPacienteDialog extends StatefulWidget {
  const _NuevoPacienteDialog();

  @override
  State<_NuevoPacienteDialog> createState() => _NuevoPacienteDialogState();
}

class _NuevoPacienteDialogState extends State<_NuevoPacienteDialog> {
  final _formKey = GlobalKey<FormState>();
  final _paciente = TextEditingController();
  final _rep = TextEditingController();
  final _cedula = TextEditingController();
  final _correo = TextEditingController();
  final _telefono = TextEditingController();
  DateTime? _nacimiento;
  bool _guardando = false;

  @override
  void dispose() {
    for (final c in [_paciente, _rep, _cedula, _correo, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_nacimiento == null) {
      mostrarAviso(context, 'La fecha de nacimiento es obligatoria.',
          esError: true);
      return;
    }

    setState(() => _guardando = true);
    try {
      // Si el correo corresponde a una cuenta ya registrada, se enlaza al
      // representante. Sin ese enlace la ficha no aparece en el desplegable del
      // padre y ademas no puede ver las recetas de su hijo.
      String representativeId = '';
      final correo = _correo.text.trim().toLowerCase();
      if (correo.isNotEmpty) {
        final usuarios = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: correo)
            .limit(1)
            .get();
        if (usuarios.docs.isNotEmpty) {
          representativeId = usuarios.docs.first.data()['uid']?.toString() ??
              usuarios.docs.first.id;
        }
      }

      await FirebaseFirestore.instance.collection('patients').add({
        'patientName': _paciente.text.trim(),
        'nombreBusqueda': normalizarTexto(_paciente.text),
        'patientBirthDate': Timestamp.fromDate(_nacimiento!),
        'representativeId': representativeId,
        'representativeName': _rep.text.trim(),
        'idDocument': _cedula.text.trim(),
        'email': correo,
        'phone': _telefono.text.trim(),
        'address': '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      if (representativeId.isEmpty && correo.isNotEmpty) {
        mostrarAviso(
          context,
          'Guardado. Ese correo aun no tiene cuenta: cuando el representante se registre, se enlazara.',
        );
      }
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
      title: const Text('Nuevo paciente',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _paciente,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del niño o niña',
                      prefixIcon: Icon(Icons.child_care)),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _nacimiento ??
                          DateTime.now().subtract(const Duration(days: 730)),
                      firstDate: DateTime(2005),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _nacimiento = d);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Fecha de nacimiento',
                      prefixIcon: const Icon(Icons.cake_outlined),
                      errorText: _nacimiento == null ? 'Requerida' : null,
                    ),
                    child: Text(
                      _nacimiento == null
                          ? 'Toca para elegir'
                          : '${_nacimiento!.day}/${_nacimiento!.month}/${_nacimiento!.year}',
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _rep,
                  decoration: const InputDecoration(
                      labelText: 'Nombre del representante',
                      prefixIcon: Icon(Icons.family_restroom)),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Telefono',
                      prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _correo,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo del representante',
                    helperText:
                        'Con el correo de su cuenta podra ver las recetas de su hijo.',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _cedula,
                  decoration: const InputDecoration(
                      labelText: 'Cedula del representante',
                      prefixIcon: Icon(Icons.badge_outlined)),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando ? null : () => Navigator.pop(context),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
