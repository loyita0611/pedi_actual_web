// lib/features/secretary/presentation/widgets/patient_history_panel.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/utils/file_opener.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../../orders/data/medical_order_service.dart';
import '../../../orders/domain/medical_order.dart';
import '../../../orders/presentation/widgets/order_actions.dart';
import '../../../orders/presentation/widgets/order_tile.dart';
import '../../../schedule/data/models/appointment_model.dart';
import '../../../schedule/domain/entities/appointment_entity.dart';
import 'new_order_dialog.dart';

/// Historial clinico del paciente, en dos columnas.
///
/// El historial anterior mezclaba citas y pagos en una linea de tiempo que no
/// se podia tocar, y buscaba por `patientName` en texto plano ignorando el
/// `patientId` que ya recibia: dos ninos con el mismo nombre compartian
/// expediente. Ahora la izquierda lista las citas con su fecha y la derecha
/// muestra, al seleccionar una, lo que la doctora pidio que se haga.
class PatientHistoryPanel extends StatefulWidget {
  const PatientHistoryPanel({
    super.key,
    required this.patientId,
    required this.patientName,
    this.representativeName = '',
    this.phone = '',
  });

  final String patientId;
  final String patientName;
  final String representativeName;
  final String phone;

  static Future<void> abrir(
    BuildContext context, {
    required String patientId,
    required String patientName,
    String representativeName = '',
    String phone = '',
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: PatientHistoryPanel(
          patientId: patientId,
          patientName: patientName,
          representativeName: representativeName,
          phone: phone,
        ),
      ),
    );
  }

  @override
  State<PatientHistoryPanel> createState() => _PatientHistoryPanelState();
}

class _PatientHistoryPanelState extends State<PatientHistoryPanel> {
  final _ordenesService = di.sl<MedicalOrderService>();
  late final OrderActions _acciones = OrderActions(ordenes: _ordenesService);

  List<AppointmentEntity> _citas = const [];
  Map<String, int> _pendientes = const {};
  AppointmentEntity? _seleccionada;
  bool _cargando = true;
  Object? _error;
  String? _ordenTrabajando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final db = FirebaseFirestore.instance;

      // Se consulta por id y, para las citas creadas antes de que existiera el
      // enlace, tambien por nombre. Los resultados se unen sin duplicar.
      final futuros = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        if (widget.patientId.isNotEmpty)
          db.collection('citas').where('patientId', isEqualTo: widget.patientId).get(),
        if (widget.patientName.trim().isNotEmpty)
          db.collection('citas').where('patientName', isEqualTo: widget.patientName.trim()).get(),
      ];

      final snaps = await Future.wait(futuros);
      final porId = <String, AppointmentEntity>{};
      for (final snap in snaps) {
        for (final doc in snap.docs) {
          porId[doc.id] = AppointmentModel.fromJson(doc.data(), doc.id);
        }
      }

      final lista = porId.values.toList()
        ..sort((a, b) => b.appointmentDateTime.compareTo(a.appointmentDateTime));

      final conteo = await _ordenesService.contarPendientesPorCita(
        lista.map((c) => c.id).toList(),
      );

      if (!mounted) return;
      setState(() {
        _citas = lista;
        _pendientes = conteo;
        _seleccionada = lista.isNotEmpty ? lista.first : null;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1080,
      height: 660,
      child: Column(
        children: [
          _Encabezado(
            paciente: widget.patientName,
            representante: widget.representativeName,
            telefono: widget.phone,
            totalCitas: _citas.length,
            totalPendientes: _pendientes.values.fold(0, (a, b) => a + b),
            onCerrar: () => Navigator.pop(context),
          ),
          Expanded(child: _cuerpo()),
        ],
      ),
    );
  }

  Widget _cuerpo() {
    if (_cargando) return const CargandoCentrado(mensaje: 'Cargando historial...');
    if (_error != null) return EstadoError(error: _error, onReintentar: _cargar);
    if (_citas.isEmpty) {
      return const EstadoVacio(
        icono: Icons.event_note_outlined,
        titulo: 'Este paciente todavia no tiene citas',
        detalle: 'Cuando se agende la primera, aparecera aqui con sus indicaciones.',
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 320, child: _listaCitas()),
        const VerticalDivider(width: 1),
        Expanded(child: _detalleCita()),
      ],
    );
  }

  // ------------------------------------------------------- columna izquierda

  Widget _listaCitas() {
    return Container(
      color: const Color(0xFFFAFBFB),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Text(
              'CITAS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _citas.length,
              itemBuilder: (context, i) {
                final cita = _citas[i];
                final activa = _seleccionada?.id == cita.id;
                final pend = _pendientes[cita.id] ?? 0;

                return InkWell(
                  onTap: () => setState(() => _seleccionada = cita),
                  child: Container(
                    decoration: BoxDecoration(
                      color: activa ? AppColors.surface : Colors.transparent,
                      border: Border(
                        left: BorderSide(
                          color: activa ? AppColors.primary : Colors.transparent,
                          width: 3,
                        ),
                        bottom: const BorderSide(color: Color(0xFFEDF1F0)),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(17, 13, 16, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat("d 'de' MMM 'de' y", 'es').format(cita.appointmentDateTime),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: activa ? FontWeight.bold : FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (pend > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$pend',
                                  style: const TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              DateFormat('h:mm a').format(cita.appointmentDateTime),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(width: 8),
                            StatusPill.cita(cita.status, dense: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------- columna derecha

  Widget _detalleCita() {
    final cita = _seleccionada;
    if (cita == null) {
      return const EstadoVacio(
        icono: Icons.touch_app_outlined,
        titulo: 'Selecciona una cita',
        detalle: 'A la izquierda estan todas las citas de este paciente.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat("EEEE d 'de' MMMM 'de' y", 'es').format(cita.appointmentDateTime),
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              StatusPill.cita(cita.status),
              StatusPill.pago(cita.pagoEstado),
              _dato(Icons.schedule, DateFormat('h:mm a').format(cita.appointmentDateTime)),
              if (cita.phone.isNotEmpty) _dato(Icons.phone_outlined, cita.phone),
            ],
          ),
          const SizedBox(height: 18),
          _bloqueDatos(cita),
          const SizedBox(height: 26),

          Row(
            children: [
              const Text(
                'Indicaciones de la doctora',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => _nuevaIndicacion(cita),
                icon: const Icon(Icons.add, size: 17),
                label: const Text('Agregar indicacion'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Lo que la doctora dejo pendiente para secretaria en esta consulta.',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          _listaOrdenes(cita),
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F6F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(texto,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      );

  Widget _bloqueDatos(AppointmentEntity cita) {
    final filas = <(String, String)>[
      ('Motivo de la consulta', cita.motivo.isEmpty ? 'No se indico' : cita.motivo),
      ('Representante', cita.representativeName.isEmpty ? '-' : cita.representativeName),
      ('Correo', cita.email.isEmpty ? '-' : cita.email),
      if (cita.pagoMonto != null)
        ('Pago', '${cita.pagoMonto!.toStringAsFixed(2)} Bs. · ${cita.pagoBanco ?? 'sin banco'}'),
      if ((cita.pagoMotivoRechazo ?? '').isNotEmpty)
        ('Motivo del rechazo', cita.pagoMotivoRechazo!),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (etiqueta, valor) in filas)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 168,
                    child: Text(etiqueta,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  ),
                  Expanded(
                    child: Text(valor,
                        style: const TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _listaOrdenes(AppointmentEntity cita) {
    return StreamBuilder<List<MedicalOrder>>(
      stream: _ordenesService.observarDeCita(cita.id),
      builder: (context, snap) {
        if (snap.hasError) return EstadoError(error: snap.error);
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: CargandoCentrado(),
          );
        }

        final ordenes = snap.data!;
        if (ordenes.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFBFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, style: BorderStyle.solid),
            ),
            child: const Column(
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 34, color: AppColors.textMuted),
                SizedBox(height: 10),
                Text(
                  'Sin indicaciones para esta cita',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                SizedBox(height: 4),
                Text(
                  'Mientras el panel de la doctora no exista, puedes agregarlas tu\n'
                  'con el boton de arriba y probar el circuito completo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final orden in ordenes)
              OrderTile(
                orden: orden,
                trabajando: _ordenTrabajando == orden.id,
                onAbrirAdjunto: () => abrirArchivo(context, orden.adjuntoUrl),
                onReabrir: () => _acciones.reabrir(context, orden),
                onOmitir: () => _acciones.omitir(context, orden),
                onResolver: () => _resolver(orden, cita),
              ),
          ],
        );
      },
    );
  }

  Future<void> _resolver(MedicalOrder orden, AppointmentEntity cita) async {
    setState(() => _ordenTrabajando = orden.id);
    try {
      final ok = await _acciones.resolver(context, orden: orden, cita: cita);
      if (ok) await _refrescarContadores();
    } finally {
      if (mounted) setState(() => _ordenTrabajando = null);
    }
  }

  Future<void> _nuevaIndicacion(AppointmentEntity cita) async {
    final creada = await NewOrderDialog.mostrar(context, cita: cita);
    if (creada == true) await _refrescarContadores();
  }

  Future<void> _refrescarContadores() async {
    final conteo = await _ordenesService.contarPendientesPorCita(_citas.map((c) => c.id).toList());
    if (mounted) setState(() => _pendientes = conteo);
  }
}

class _Encabezado extends StatelessWidget {
  const _Encabezado({
    required this.paciente,
    required this.representante,
    required this.telefono,
    required this.totalCitas,
    required this.totalPendientes,
    required this.onCerrar,
  });

  final String paciente;
  final String representante;
  final String telefono;
  final int totalCitas;
  final int totalPendientes;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 20, 16, 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primarySoft,
            child: const Icon(Icons.child_care, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  paciente.isEmpty ? 'Paciente' : paciente,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (representante.isNotEmpty) 'Rep.: $representante',
                    if (telefono.isNotEmpty) telefono,
                    '$totalCitas ${totalCitas == 1 ? 'cita' : 'citas'}',
                  ].join('  ·  '),
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (totalPendientes > 0)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.accent),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.pending_actions, size: 16, color: AppColors.accentDark),
                  const SizedBox(width: 7),
                  Text(
                    '$totalPendientes ${totalPendientes == 1 ? 'indicacion pendiente' : 'indicaciones pendientes'}',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.accentDark),
                  ),
                ],
              ),
            ),
          IconButton(
            onPressed: onCerrar,
            icon: const Icon(Icons.close, color: AppColors.textMuted),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }
}
