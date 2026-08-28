// lib/core/widgets/async_states.dart
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Estados vacio, de carga y de error con la misma cara en toda la app.
///
/// Existe por un bug concreto: varios StreamBuilder solo preguntaban por
/// `hasData`, asi que cuando Firestore devolvia un error (por ejemplo por falta
/// de un indice compuesto) la pantalla decia "No hay documentos" y parecia que
/// la operacion habia fallado en silencio.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.icono,
    required this.titulo,
    this.detalle,
    this.accion,
  });

  final IconData icono;
  final String titulo;
  final String? detalle;
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 56, color: AppColors.textMuted.withValues(alpha: 0.55)),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            if (detalle != null) ...[
              const SizedBox(height: 6),
              Text(
                detalle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
              ),
            ],
            if (accion != null) ...[const SizedBox(height: 20), accion!],
          ],
        ),
      ),
    );
  }
}

class EstadoError extends StatelessWidget {
  const EstadoError({super.key, required this.error, this.onReintentar});

  final Object? error;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final texto = error?.toString() ?? 'Error desconocido';
    final faltaIndice = texto.contains('failed-precondition') || texto.contains('requires an index');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: AppColors.danger),
            const SizedBox(height: 14),
            const Text(
              'No se pudo cargar la informacion',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger),
            ),
            const SizedBox(height: 8),
            Text(
              faltaIndice
                  ? 'Falta un indice en Firestore para esta consulta. Ejecuta '
                      '"firebase deploy --only firestore:indexes" y vuelve a intentar.'
                  : texto,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (onReintentar != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onReintentar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class CargandoCentrado extends StatelessWidget {
  const CargandoCentrado({super.key, this.mensaje});
  final String? mensaje;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (mensaje != null) ...[
            const SizedBox(height: 14),
            Text(mensaje!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13.5)),
          ],
        ],
      ),
    );
  }
}

/// StreamBuilder que ya trae las tres ramas resueltas.
class ColeccionView<T> extends StatelessWidget {
  const ColeccionView({
    super.key,
    required this.stream,
    required this.builder,
    required this.vacio,
    this.estaVacio,
    this.cargando,
  });

  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget vacio;
  final bool Function(T data)? estaVacio;
  final Widget? cargando;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return EstadoError(error: snapshot.error);
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return cargando ?? const CargandoCentrado();
        }
        if (!snapshot.hasData) return vacio;
        final data = snapshot.data as T;
        if (estaVacio?.call(data) ?? false) return vacio;
        return builder(context, data);
      },
    );
  }
}

/// Aviso corto con color segun el tipo. Reemplaza los SnackBar sueltos.
void mostrarAviso(
  BuildContext context,
  String mensaje, {
  bool esError = false,
  bool esExito = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: esError
            ? AppColors.danger
            : esExito
                ? AppColors.success
                : AppColors.textPrimary,
        duration: Duration(seconds: esError ? 5 : 3),
      ),
    );
}
