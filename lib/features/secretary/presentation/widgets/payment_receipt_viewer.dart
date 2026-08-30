// lib/features/secretary/presentation/widgets/payment_receipt_viewer.dart
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/file_opener.dart';

/// Visor de la captura del pago, con zoom.
/// Sin esto la secretaria tendria que verificar el pago a ciegas, solo con la
/// referencia que el representante escribio a mano.
class PaymentReceiptViewer extends StatelessWidget {
  const PaymentReceiptViewer({
    super.key,
    required this.url,
    required this.titulo,
    this.referencia,
  });

  final String url;
  final String titulo;
  final String? referencia;

  /// El comprobante puede llegar en PDF (varios bancos lo entregan asi). La
  /// extension viaja en la ruta del enlace de descarga, antes del `?token=`,
  /// porque el archivo se guarda como `comprobantes/{pagoId}.{ext}`.
  bool get _esPdf => url.toLowerCase().split('?').first.endsWith('.pdf');

  static Future<void> mostrar(
    BuildContext context, {
    required String url,
    required String titulo,
    String? referencia,
  }) {
    return showDialog(
      context: context,
      builder: (_) => PaymentReceiptViewer(url: url, titulo: titulo, referencia: referencia),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 640,
        height: 640,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        if ((referencia ?? '').isNotEmpty)
                          Text('Referencia: $referencia',
                              style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Abrir en pestana nueva',
                    icon: const Icon(Icons.open_in_new, size: 20),
                    onPressed: () => abrirArchivo(context, url),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xFF1B2422),
                child: _esPdf ? _avisoPdf(context) : InteractiveViewer(
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      // El bucket no devuelve cabeceras CORS, asi que al
                      // dibujar sobre el lienzo el navegador bloqueaba la
                      // descarga y la captura salia siempre rota. Pintarla como
                      // <img> del navegador la muestra igual, sin depender de
                      // la configuracion CORS del bucket.
                      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : const Center(child: CircularProgressIndicator(color: Colors.white70)),
                      errorBuilder: (context, error, stack) => const Padding(
                        padding: EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_outlined, size: 48, color: Colors.white38),
                            SizedBox(height: 12),
                            Text('No se pudo cargar la imagen.',
                                style: TextStyle(color: Colors.white70)),
                            SizedBox(height: 6),
                            Text('Abrela en una pestana nueva con el boton de arriba.',
                                style: TextStyle(color: Colors.white38, fontSize: 12.5)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// El navegador no pinta un PDF dentro de un `Image`: se ofrece abrirlo.
  Widget _avisoPdf(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.picture_as_pdf, size: 56, color: Colors.white54),
            const SizedBox(height: 14),
            const Text(
              'El representante adjunto el comprobante en PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () => abrirArchivo(context, url),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Abrir el PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
