// lib/features/secretary/presentation/widgets/pending_orders_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/file_opener.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../../orders/data/medical_order_service.dart';
import '../../../orders/domain/medical_order.dart';
import '../../../orders/presentation/widgets/order_actions.dart';
import '../../../orders/presentation/widgets/order_tile.dart';
import '../../../schedule/data/models/appointment_model.dart';
import '../../../schedule/domain/entities/appointment_entity.dart';

/// Bandeja de trabajo del dia.
///
/// Si las indicaciones solo vivieran dentro del historial de cada paciente, la
/// secretaria tendria que entrar uno por uno para saber que le falta. Esta
/// pestana junta todo lo pendiente de toda la clinica, con lo vencido primero.
class PendingOrdersWidget extends StatefulWidget {
  const PendingOrdersWidget({super.key});

  @override
  State<PendingOrdersWidget> createState() => _PendingOrdersWidgetState();
}

class _PendingOrdersWidgetState extends State<PendingOrdersWidget> {
  final _service = di.sl<MedicalOrderService>();
  late final OrderActions _acciones = OrderActions(ordenes: _service);
  String? _trabajando;
  TipoOrden? _filtro;

  Future<AppointmentEntity?> _cargarCita(String citaId) async {
    final doc = await FirebaseFirestore.instance.collection('citas').doc(citaId).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppointmentModel.fromJson(doc.data()!, doc.id);
  }

  Future<void> _resolver(MedicalOrder orden) async {
    setState(() => _trabajando = orden.id);
    try {
      final cita = await _cargarCita(orden.citaId);
      if (!mounted) return;
      if (cita == null) {
        mostrarAviso(context, 'No se encontro la cita de esta indicacion.', esError: true);
        return;
      }
      await _acciones.resolver(context, orden: orden, cita: cita);
    } finally {
      if (mounted) setState(() => _trabajando = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<List<MedicalOrder>>(
        stream: _service.observarPendientes(),
        builder: (context, snap) {
          if (snap.hasError) return EstadoError(error: snap.error);
          if (!snap.hasData) return const CargandoCentrado(mensaje: 'Buscando indicaciones...');

          final todas = snap.data!;
          final visibles = _filtro == null ? todas : todas.where((o) => o.tipo == _filtro).toList();
          final vencidas = todas.where((o) => o.vencida).length;
          final hoy = todas.where((o) => o.esParaHoy).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Indicaciones pendientes',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          todas.isEmpty
                              ? 'No queda nada por resolver.'
                              : 'Lo que la doctora dejo pedido y todavia no se ha hecho.',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  if (vencidas > 0) _contador('$vencidas vencidas', AppColors.danger),
                  if (hoy > 0) ...[
                    const SizedBox(width: 8),
                    _contador('$hoy para hoy', AppColors.accentDark),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              if (todas.isNotEmpty)
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Todas (${todas.length})'),
                      selected: _filtro == null,
                      onSelected: (_) => setState(() => _filtro = null),
                      selectedColor: AppColors.primarySoft,
                    ),
                    for (final t in TipoOrden.values)
                      if (todas.any((o) => o.tipo == t))
                        ChoiceChip(
                          avatar: Icon(t.icono, size: 15, color: t.color),
                          label: Text('${t.label} (${todas.where((o) => o.tipo == t).length})'),
                          selected: _filtro == t,
                          onSelected: (_) => setState(() => _filtro = t),
                          selectedColor: t.color.withValues(alpha: 0.14),
                        ),
                  ],
                ),
              const SizedBox(height: 16),
              Expanded(
                child: visibles.isEmpty
                    ? const EstadoVacio(
                        icono: Icons.task_alt,
                        titulo: 'Todo al dia',
                        detalle: 'No hay indicaciones pendientes en este momento.',
                      )
                    : ListView.builder(
                        itemCount: visibles.length,
                        itemBuilder: (context, i) {
                          final orden = visibles[i];
                          return OrderTile(
                            orden: orden,
                            mostrarPaciente: true,
                            trabajando: _trabajando == orden.id,
                            onAbrirAdjunto: () => abrirArchivo(context, orden.adjuntoUrl),
                            onOmitir: () => _acciones.omitir(context, orden),
                            onResolver: () => _resolver(orden),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _contador(String texto, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(texto,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
      );
}
