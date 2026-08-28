// lib/features/prescriptions/presentation/pages/my_prescriptions_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/file_opener.dart';
import '../../../../core/widgets/async_states.dart';
import '../../data/prescription_service.dart';

/// Recetas y documentos del representante.
///
/// Esta pantalla no existia: la secretaria subia los archivos a Storage y no
/// habia ningun lugar en la app donde el paciente pudiera verlos.
class MyPrescriptionsPage extends StatefulWidget {
  const MyPrescriptionsPage({super.key});

  @override
  State<MyPrescriptionsPage> createState() => _MyPrescriptionsPageState();
}

class _MyPrescriptionsPageState extends State<MyPrescriptionsPage> {
  final _service = PrescriptionService();
  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  String _filtroPaciente = '';

  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const EstadoVacio(
        icono: Icons.lock_outline,
        titulo: 'Inicia sesion para ver tus recetas',
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mis Recetas y Documentos',
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            const Text(
              'Todo lo que la doctora indica y la secretaria carga aparece aqui, listo para descargar.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ColeccionView<List<Prescription>>(
                // 🚀 SOLUCIÓN: Agregado el "!" porque ya verificamos arriba que no es null
                stream: _service.observarDeRepresentante(_uid!),
                estaVacio: (lista) => lista.isEmpty,
                vacio: const EstadoVacio(
                  icono: Icons.folder_open_outlined,
                  titulo: 'Todavia no tienes documentos',
                  detalle:
                      'Cuando la doctora emita una receta, la veras aqui para descargarla.',
                ),
                builder: (context, recetas) => _buildLista(recetas),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(List<Prescription> recetas) {
    final pacientes = <String>{for (final r in recetas) r.patientName}.toList()
      ..sort();
    final visibles = _filtroPaciente.isEmpty
        ? recetas
        : recetas.where((r) => r.patientName == _filtroPaciente).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pacientes.length > 1) ...[
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chipFiltro('Todos', _filtroPaciente.isEmpty,
                    () => setState(() => _filtroPaciente = '')),
                for (final p in pacientes)
                  _chipFiltro(p, _filtroPaciente == p,
                      () => setState(() => _filtroPaciente = p)),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Expanded(
          child: ListView.separated(
            itemCount: visibles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _TarjetaReceta(
              receta: visibles[i],
              onAbrir: () => abrirArchivo(context, visibles[i].fileUrl),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipFiltro(String texto, bool activo, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(texto),
          selected: activo,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.primarySoft,
          labelStyle: TextStyle(
            color: activo ? AppColors.primaryDark : AppColors.textSecondary,
            fontWeight: activo ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
}

class _TarjetaReceta extends StatelessWidget {
  const _TarjetaReceta({required this.receta, required this.onAbrir});

  final Prescription receta;
  final VoidCallback onAbrir;

  @override
  Widget build(BuildContext context) {
    final fecha = receta.createdAt;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.picture_as_pdf,
                color: AppColors.danger, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  receta.descripcion?.isNotEmpty == true
                      ? receta.descripcion!
                      : receta.fileName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    receta.patientName,
                    if (fecha != null)
                      DateFormat("d 'de' MMMM 'de' y", 'es').format(fecha),
                    if (receta.sizeBytes > 0) receta.tamanoLegible,
                  ].join('  ·  '),
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: onAbrir,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Descargar Receta (PDF)'),
          ),
        ],
      ),
    );
  }
}
