// lib/features/secretary/presentation/widgets/payments_data_table.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../../../core/services/email_service.dart';
import '../../../../core/config/clinic_config.dart';
import 'payment_receipt_viewer.dart';

/// Verificacion de pagos.
///
/// El bug central del sistema estaba aqui: al aprobar se escribia
/// `status: 'approved'` solo en `pagos` y no se tocaba la cita, mientras el
/// panel del paciente leia `citas.pagoEstado` esperando otro vocabulario. El
/// pago nunca llegaba a mostrarse como confirmado del lado del representante.
/// Ahora ambos documentos se actualizan en el mismo lote y con las mismas claves.
class PaymentsDataTable extends StatefulWidget {
  const PaymentsDataTable({super.key});

  @override
  State<PaymentsDataTable> createState() => _PaymentsDataTableState();
}

class _PaymentsDataTableState extends State<PaymentsDataTable> {
  final _db = FirebaseFirestore.instance;
  PagoStatus _filtro = PagoStatus.pendiente;
  String? _procesando;

  Future<void> _verificar(String pagoId, Map<String, dynamic> pago) async {
    setState(() => _procesando = pagoId);
    try {
      await _actualizar(pagoId, pago, PagoStatus.verificado, null);
      final correo = (pago['email'] ?? '').toString();
      if (correo.isNotEmpty) {
        await di.sl<EmailService>().pagoVerificado(
              correo: correo,
              paciente: (pago['patientName'] ?? '').toString(),
              fecha: DateFormat('d/MM/y').format(DateTime.now()),
              hora: '',
              telefonoClinica: ClinicConfigService.actual.telefonoClinica,
            );
      }
      if (mounted) mostrarAviso(context, 'Pago verificado. El representante ya lo ve confirmado.', esExito: true);
    } catch (e) {
      if (mounted) mostrarAviso(context, 'No se pudo verificar: $e', esError: true);
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  Future<void> _rechazar(String pagoId, Map<String, dynamic> pago) async {
    // Antes no habia forma de escribir por que se rechazaba, y el boton del
    // paciente para "consultar el motivo" solo imprimia en la consola.
    final motivo = await _pedirMotivo();
    if (motivo == null || motivo.isEmpty) return;

    setState(() => _procesando = pagoId);
    try {
      await _actualizar(pagoId, pago, PagoStatus.rechazado, motivo);
      final correo = (pago['email'] ?? '').toString();
      if (correo.isNotEmpty) {
        await di.sl<EmailService>().pagoRechazado(
              correo: correo,
              paciente: (pago['patientName'] ?? '').toString(),
              motivo: motivo,
              telefonoClinica: ClinicConfigService.actual.telefonoClinica,
            );
      }
      if (mounted) mostrarAviso(context, 'Pago rechazado. Se le informo el motivo al representante.');
    } catch (e) {
      if (mounted) mostrarAviso(context, 'No se pudo rechazar: $e', esError: true);
    } finally {
      if (mounted) setState(() => _procesando = null);
    }
  }

  /// Escribe en `pagos` y en `citas` a la vez.
  Future<void> _actualizar(
    String pagoId,
    Map<String, dynamic> pago,
    PagoStatus estado,
    String? motivo,
  ) async {
    final lote = _db.batch();

    lote.update(_db.collection('pagos').doc(pagoId), {
      'status': estado.key,
      'motivoRechazo': motivo,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final citaId = (pago['appointmentId'] ?? '').toString();
    if (citaId.isNotEmpty) {
      lote.set(
        _db.collection('citas').doc(citaId),
        {
          'pagoEstado': estado.key,
          'pagoMotivoRechazo': motivo,
          'pagoVerificadoEn': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await lote.commit();
  }

  Future<String?> _pedirMotivo() async {
    final control = TextEditingController();
    const sugerencias = [
      'La referencia no coincide con el banco',
      'El monto es menor al total',
      'No se encontro el pago reportado',
      'La captura no es legible',
    ];

    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Motivo del rechazo', style: TextStyle(fontSize: 17)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'El representante vera este texto en su panel, asi que se claro.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: control,
                  autofocus: true,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Motivo'),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final s in sugerencias)
                      ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 11.5)),
                        onPressed: () => setLocal(() => control.text = s),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, control.text.trim()),
              child: const Text('Rechazar pago'),
            ),
          ],
        ),
      ),
    );
    control.dispose();
    return motivo;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Verificacion de pagos',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const Spacer(),
              for (final e in PagoStatus.values)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ChoiceChip(
                    label: Text(e.label),
                    selected: _filtro == e,
                    onSelected: (_) => setState(() => _filtro = e),
                    selectedColor: e.background,
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      color: _filtro == e ? e.color : AppColors.textSecondary,
                      fontWeight: _filtro == e ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: _tabla()),
        ],
      ),
    );
  }

  Widget _tabla() {
    return ColeccionView<QuerySnapshot<Map<String, dynamic>>>(
      // Sin orderBy: se evita depender de un indice compuesto y se ordena abajo.
      stream: _db.collection('pagos').where('status', isEqualTo: _filtro.key).snapshots(),
      estaVacio: (s) => s.docs.isEmpty,
      vacio: EstadoVacio(
        icono: _filtro == PagoStatus.pendiente ? Icons.check_circle_outline : Icons.receipt_long_outlined,
        titulo: _filtro == PagoStatus.pendiente
            ? 'No hay pagos por verificar'
            : 'No hay pagos ${_filtro.label.toLowerCase()}',
      ),
      builder: (context, snap) {
        final docs = snap.docs.toList()
          ..sort((a, b) {
            final fa = a.data()['date'];
            final fb = b.data()['date'];
            if (fa is! Timestamp || fb is! Timestamp) return 0;
            return fb.compareTo(fa);
          });

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.primary.withValues(alpha: 0.05)),
              columnSpacing: 22,
              columns: const [
                DataColumn(label: Text('Fecha')),
                DataColumn(label: Text('Paciente')),
                DataColumn(label: Text('Banco / Referencia')),
                DataColumn(label: Text('Monto')),
                DataColumn(label: Text('Comprobante')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: docs.map((doc) => _fila(doc)).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _fila(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    final fecha = d['date'] is Timestamp ? (d['date'] as Timestamp).toDate() : null;
    final monto = (d['pagoMonto'] as num?)?.toDouble() ?? 0;
    final esperado = (d['pagoMontoEsperado'] as num?)?.toDouble();
    final url = (d['comprobanteUrl'] ?? '').toString();
    final ocupado = _procesando == doc.id;

    // Si el paciente reporto menos de lo que se le pidio, se marca en rojo.
    final faltante = esperado != null && monto + 0.01 < esperado;

    return DataRow(cells: [
      DataCell(Text(fecha == null ? '-' : DateFormat('d/MM/y').format(fecha))),
      DataCell(Text(d['patientName']?.toString() ?? '-')),
      DataCell(Text('${d['pagoBanco'] ?? '-'}\nRef: ${d['pagoReferencia'] ?? '-'}',
          style: const TextStyle(fontSize: 12))),
      DataCell(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('${monto.toStringAsFixed(2)} Bs.',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: faltante ? AppColors.danger : AppColors.textPrimary)),
            if (esperado != null)
              Text('Esperado: ${esperado.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 11, color: faltante ? AppColors.danger : AppColors.textMuted)),
          ],
        ),
      ),
      DataCell(
        url.isEmpty
            ? const Text('Sin captura', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
            : TextButton.icon(
                onPressed: () => PaymentReceiptViewer.mostrar(
                  context,
                  url: url,
                  titulo: d['patientName']?.toString() ?? 'Comprobante',
                  referencia: d['pagoReferencia']?.toString(),
                ),
                icon: const Icon(Icons.image_outlined, size: 17),
                label: const Text('Ver captura', style: TextStyle(fontSize: 12.5)),
              ),
      ),
      DataCell(
        ocupado
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_filtro != PagoStatus.verificado)
                    IconButton(
                      tooltip: 'Verificar pago',
                      icon: const Icon(Icons.check_circle_outline, color: AppColors.success),
                      onPressed: () => _verificar(doc.id, d),
                    ),
                  if (_filtro != PagoStatus.rechazado)
                    IconButton(
                      tooltip: 'Rechazar pago',
                      icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                      onPressed: () => _rechazar(doc.id, d),
                    ),
                ],
              ),
      ),
    ]);
  }
}
