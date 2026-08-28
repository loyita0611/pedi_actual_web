// lib/features/orders/presentation/widgets/order_actions.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../../prescriptions/data/prescription_service.dart';
import '../../../schedule/domain/entities/appointment_entity.dart';
import '../../../schedule/domain/usecases/book_appointment.dart';
import '../../../schedule/presentation/widgets/slot_picker_dialog.dart';
import '../../data/medical_order_service.dart';
import '../../domain/medical_order.dart';

/// Ejecuta lo que pide cada indicacion.
///
/// Aqui vive el circuito que faltaba: la doctora deja la orden, la secretaria
/// pulsa un boton y el archivo o la cita quedan creados y enlazados a la orden
/// en un solo paso, sin tener que ir a otra pantalla a repetir los datos.
class OrderActions {
  OrderActions({
    MedicalOrderService? ordenes,
    PrescriptionService? recetas,
  })  : _ordenes = ordenes ?? di.sl<MedicalOrderService>(),
        _recetas = recetas ?? di.sl<PrescriptionService>();

  final MedicalOrderService _ordenes;
  final PrescriptionService _recetas;

  /// Devuelve true si la orden quedo resuelta.
  Future<bool> resolver(
    BuildContext context, {
    required MedicalOrder orden,
    required AppointmentEntity cita,
  }) async {
    switch (orden.tipo) {
      case TipoOrden.receta:
      case TipoOrden.examen:
        return _subirArchivo(context, orden: orden, cita: cita);
      case TipoOrden.control:
        return _agendarControl(context, orden: orden, cita: cita);
      case TipoOrden.nota:
        await _ordenes.marcarHecha(orden);
        if (context.mounted) mostrarAviso(context, 'Indicacion marcada como leida.', esExito: true);
        return true;
    }
  }

  // --------------------------------------------------------- receta/examen

  Future<bool> _subirArchivo(
    BuildContext context, {
    required MedicalOrder orden,
    required AppointmentEntity cita,
  }) async {
    try {
      final archivo = await StorageService.elegirPdf();
      if (archivo == null) return false;

      final patientId = orden.patientId.isNotEmpty ? orden.patientId : cita.patientId;
      if (patientId.isEmpty) {
        if (context.mounted) {
          mostrarAviso(context,
              'Esta cita no tiene un paciente enlazado. Abre su ficha en Pacientes y vuelve a intentar.',
              esError: true);
        }
        return false;
      }

      final receta = await _recetas.subir(
        patientId: patientId,
        patientName: orden.patientName.isNotEmpty ? orden.patientName : cita.patientName,
        representativeId:
            orden.representativeId.isNotEmpty ? orden.representativeId : cita.representativeId,
        archivo: archivo,
        citaId: orden.citaId,
        ordenId: orden.id,
        descripcion: orden.descripcion,
      );

      await _ordenes.resolverConArchivo(
        orden: orden,
        url: receta.fileUrl,
        nombre: receta.fileName,
        ruta: receta.filePath,
      );

      if (context.mounted) {
        mostrarAviso(context, 'Receta enviada. El representante ya puede descargarla.', esExito: true);
      }
      return true;
    } on ArchivoDemasiadoGrande catch (e) {
      if (context.mounted) mostrarAviso(context, e.toString(), esError: true);
    } on ArchivoVacio catch (e) {
      if (context.mounted) mostrarAviso(context, e.toString(), esError: true);
    } on SubidaFallida catch (e) {
      // Ya viene traducida a algo legible: no se le antepone nada.
      if (context.mounted) mostrarAviso(context, e.mensaje, esError: true);
    } on FormatException catch (e) {
      if (context.mounted) mostrarAviso(context, e.message, esError: true);
    } catch (e) {
      if (context.mounted) mostrarAviso(context, 'No se pudo subir el archivo: $e', esError: true);
    }
    return false;
  }

  // ---------------------------------------------------------------- control

  Future<bool> _agendarControl(
    BuildContext context, {
    required MedicalOrder orden,
    required AppointmentEntity cita,
  }) async {
    final sugerida = orden.fechaSugerida ?? DateTime.now().add(const Duration(days: 7));

    final elegido = await SlotPickerDialog.mostrar(
      context,
      fechaInicial: sugerida,
      titulo: 'Agendar control de ${orden.patientName.isNotEmpty ? orden.patientName : cita.patientName}',
    );
    if (elegido == null || !context.mounted) return false;

    try {
      // Se reutiliza la ficha del paciente y del representante de la cita
      // original: la secretaria no tiene que volver a escribir nada.
      final nueva = AppointmentEntity(
        id: '',
        patientId: orden.patientId.isNotEmpty ? orden.patientId : cita.patientId,
        representativeId: cita.representativeId,
        patientName: orden.patientName.isNotEmpty ? orden.patientName : cita.patientName,
        patientBirthDate: cita.patientBirthDate,
        address: cita.address,
        representativeName: cita.representativeName,
        email: cita.email,
        phone: cita.phone,
        appointmentDateTime: elegido,
        status: CitaStatus.confirmada,
        motivo: orden.descripcion.isEmpty
            ? 'Control indicado por la doctora'
            : 'Control: ${orden.descripcion}',
      );

      final nuevaId = await di.sl<BookAppointment>()(nueva);
      await _ordenes.resolverConCita(orden: orden, citaGeneradaId: nuevaId);

      if (context.mounted) {
        mostrarAviso(
          context,
          'Control agendado para el ${DateFormat("d 'de' MMMM 'a las' h:mm a", 'es').format(elegido)}.',
          esExito: true,
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        mostrarAviso(context, 'No se pudo agendar el control: $e', esError: true);
      }
      return false;
    }
  }

  // ----------------------------------------------------------------- omitir

  Future<bool> omitir(BuildContext context, MedicalOrder orden) async {
    final control = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Omitir indicacion', style: TextStyle(fontSize: 17)),
        content: SizedBox(
          width: 380,
          child: TextField(
            controller: control,
            autofocus: true,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Por ejemplo: el representante prefiere llamar despues',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, control.text.trim()),
            child: const Text('Omitir'),
          ),
        ],
      ),
    );
    control.dispose();

    if (motivo == null || motivo.isEmpty) return false;
    await _ordenes.omitir(orden, motivo);
    if (context.mounted) mostrarAviso(context, 'Indicacion omitida.');
    return true;
  }

  Future<void> reabrir(BuildContext context, MedicalOrder orden) async {
    await _ordenes.reabrir(orden);
    if (context.mounted) mostrarAviso(context, 'Indicacion reabierta.');
  }
}
