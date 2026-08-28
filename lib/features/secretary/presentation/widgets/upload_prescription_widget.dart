// lib/features/secretary/presentation/widgets/upload_prescription_widget.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/utils/file_opener.dart';
import '../../../../core/utils/search_utils.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../../prescriptions/data/prescription_service.dart';

/// Recetas y documentos del paciente.
///
/// Se elimino el PIN que protegia esta pantalla: se generaba con Random() en el
/// navegador, se guardaba en una variable y se comparaba ahi mismo, asi que
/// cualquiera con la consola abierta podia leerlo. Ademas viajaba a un correo
/// escrito en el codigo, no al de la secretaria conectada. El acceso ahora lo
/// decide el rol y lo hacen cumplir las reglas de Firestore y de Storage.
class UploadPrescriptionWidget extends StatefulWidget {
  const UploadPrescriptionWidget({super.key});

  @override
  State<UploadPrescriptionWidget> createState() =>
      _UploadPrescriptionWidgetState();
}

class _UploadPrescriptionWidgetState extends State<UploadPrescriptionWidget> {
  final _service = di.sl<PrescriptionService>();

  String? _patientId;
  String? _patientName;
  String? _representativeId;
  String? _representativeName;
  bool _subiendo = false;

  Future<List<Map<String, dynamic>>> _buscar(String consulta) async {
    final q = normalizarTexto(consulta);
    if (q.isEmpty) {
      return const [];
    }

    // Se busca contra `nombreBusqueda`, en minusculas y sin tildes, porque las
    // consultas de rango de Firestore distinguen mayusculas: escribir "juan"
    // no encontraba a "Juan".
    final snap = await FirebaseFirestore.instance
        .collection('patients')
        .where('nombreBusqueda', isGreaterThanOrEqualTo: q)
        .where('nombreBusqueda', isLessThanOrEqualTo: cotaSuperior(q))
        .limit(12)
        .get();

    if (snap.docs.isNotEmpty) {
      return snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
    }

    // Respaldo para las fichas creadas antes de que existiera ese campo.
    final legado = await FirebaseFirestore.instance
        .collection('patients')
        .orderBy('patientName')
        .limit(200)
        .get();
    return legado.docs
        .where((d) =>
            normalizarTexto((d.data()['patientName'] ?? '').toString())
                .contains(q))
        .take(12)
        .map((d) => {'id': d.id, ...d.data()})
        .toList();
  }

  Future<void> _subirPdf() async {
    if (_patientId == null) {
      mostrarAviso(context, 'Primero busca y selecciona un paciente.',
          esError: true);
      return;
    }

    setState(() => _subiendo = true);
    try {
      // Selector restringido a PDF, con doble verificacion de la extension.
      final archivo = await StorageService.elegirPdf();
      if (archivo == null) {
        return;
      }

      await _service.subir(
        patientId: _patientId!,
        patientName: _patientName ?? '',
        representativeId: _representativeId ?? '',
        archivo: archivo,
      );

      if (mounted) {
        mostrarAviso(
            context, 'Receta enviada. El representante ya puede descargarla.',
            esExito: true);
      }
    } on ArchivoDemasiadoGrande catch (e) {
      if (mounted) {
        mostrarAviso(context, e.toString(), esError: true);
      }
    } on ArchivoVacio catch (e) {
      if (mounted) {
        mostrarAviso(context, e.toString(), esError: true);
      }
    } on SubidaFallida catch (e) {
      // Ya viene traducida a algo legible: no se le antepone nada.
      if (mounted) {
        mostrarAviso(context, e.mensaje, esError: true);
      }
    } on FormatException catch (e) {
      if (mounted) {
        mostrarAviso(context, e.message, esError: true);
      }
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo subir el documento: $e',
            esError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _subiendo = false);
      }
    }
  }

  Future<void> _eliminar(Prescription receta) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Eliminar documento', style: TextStyle(fontSize: 17)),
        content: Text('Se borrara "${receta.fileName}" de forma permanente. '
            'El representante dejara de verlo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) {
      return;
    }

    try {
      await _service.eliminar(receta);
      if (mounted) {
        mostrarAviso(context, 'Documento eliminado.');
      }
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo eliminar: $e', esError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recetas y Documentos',
          style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.primary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Busca un paciente y adjunta su receta en PDF. Al subirla, el representante la ve al instante en su panel.',
          style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 22),
        TypeAheadField<Map<String, dynamic>>(
          suggestionsCallback: _buscar,
          emptyBuilder: (_) => const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Ningun paciente coincide.',
                style: TextStyle(color: AppColors.textMuted)),
          ),
          builder: (context, controller, focusNode) => TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Buscar paciente',
              hintText: 'Escribe el nombre del niño o niña',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _patientId == null
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        controller.clear();
                        setState(() {
                          _patientId = null;
                          _patientName = null;
                          _representativeId = null;
                          _representativeName = null;
                        });
                      },
                    ),
            ),
          ),
          itemBuilder: (context, s) => ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.primarySoft,
              child: Icon(Icons.child_care, color: AppColors.primary, size: 20),
            ),
            title: Text(s['patientName']?.toString() ?? ''),
            subtitle: Text(
                'Rep.: ${s['representativeName'] ?? '-'}  ·  ${s['phone'] ?? 'sin telefono'}'),
          ),
          onSelected: (s) => setState(() {
            _patientId = s['id']?.toString();
            _patientName = s['patientName']?.toString();
            _representativeId = s['representativeId']?.toString();
            _representativeName = s['representativeName']?.toString();
          }),
        ),
        const SizedBox(height: 24),
        Expanded(child: _panelPaciente()),
      ],
    );
  }

  Widget _panelPaciente() {
    if (_patientId == null) {
      return const EstadoVacio(
        icono: Icons.folder_shared_outlined,
        titulo: 'Selecciona un paciente',
        detalle: 'Sus recetas y estudios apareceran aqui.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _patientName ?? '',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary),
                  ),
                  if ((_representativeName ?? '').isNotEmpty)
                    Text('Representante: $_representativeName',
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.textMuted)),
                  if ((_representativeId ?? '').isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Esta ficha no tiene representante enlazado: el archivo se subira, '
                        'pero el padre no podra verlo hasta que se le asocie una cuenta.',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.warning),
                      ),
                    ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _subiendo ? null : _subirPdf,
              icon: _subiendo
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.picture_as_pdf, size: 18),
              label: Text(_subiendo ? 'Subiendo...' : 'Adjuntar receta (PDF)'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ColeccionView<List<Prescription>>(
            stream: _service.observarDePaciente(_patientId!),
            estaVacio: (l) => l.isEmpty,
            vacio: const EstadoVacio(
              icono: Icons.description_outlined,
              titulo: 'Sin documentos todavia',
              detalle: 'Adjunta la primera receta con el boton de arriba.',
            ),
            builder: (context, recetas) => ListView.separated(
              itemCount: recetas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final r = recetas[i];
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf,
                        color: AppColors.danger, size: 28),
                    title: Text(r.fileName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(
                      [
                        if (r.createdAt != null)
                          DateFormat("d 'de' MMMM 'de' y, h:mm a", 'es')
                              .format(r.createdAt!),
                        if (r.sizeBytes > 0) r.tamanoLegible,
                      ].join('  ·  '),
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Abrir',
                          icon: const Icon(Icons.open_in_new,
                              size: 19, color: AppColors.primary),
                          onPressed: () => abrirArchivo(context, r.fileUrl),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          icon: const Icon(Icons.delete_outline,
                              size: 19, color: AppColors.danger),
                          onPressed: () => _eliminar(r),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
