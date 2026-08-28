// lib/core/utils/file_opener.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/async_states.dart';

/// Abre la receta o el comprobante en una pestana nueva.
/// En web el navegador se encarga de mostrarlo o descargarlo segun el
/// `contentDisposition` con el que se subio el archivo.
Future<void> abrirArchivo(BuildContext context, String? url) async {
  if (url == null || url.trim().isEmpty) {
    mostrarAviso(context, 'Este registro no tiene ningun archivo adjunto.', esError: true);
    return;
  }
  final uri = Uri.tryParse(url);
  if (uri == null) {
    if (context.mounted) mostrarAviso(context, 'El enlace del archivo no es valido.', esError: true);
    return;
  }
  // `launchUrl` no solo devuelve false: en web tambien lanza si el navegador
  // bloquea la ventana emergente, y ese error subia sin dueno desde el onTap.
  try {
    final abierto = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!abierto && context.mounted) {
      mostrarAviso(context, 'No se pudo abrir el archivo. Revisa el bloqueador de ventanas.',
          esError: true);
    }
  } catch (e) {
    if (context.mounted) {
      mostrarAviso(context, 'No se pudo abrir el archivo: $e', esError: true);
    }
  }
}
