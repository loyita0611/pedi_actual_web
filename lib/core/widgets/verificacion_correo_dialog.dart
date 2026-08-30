// lib/core/widgets/verificacion_correo_dialog.dart
import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants/app_colors.dart';
import 'async_states.dart';

/// Para que se pide el codigo. Debe coincidir con lo que espera el servidor.
enum PropositoCodigo {
  registro('registro', 'Confirma tu correo',
      'Te enviamos un codigo para terminar de crear tu cuenta.'),
  recetas('recetas', 'Verifica que eres tu',
      'Las recetas llevan datos medicos de tus hijos, asi que pedimos un codigo antes de mostrarlas.');

  const PropositoCodigo(this.clave, this.titulo, this.explicacion);
  final String clave;
  final String titulo;
  final String explicacion;
}

/// Pide un codigo de seis digitos enviado al correo de la sesion.
///
/// Comprueba que quien esta del otro lado tiene acceso de verdad a ese buzon.
/// El codigo se genera y se valida en el servidor: aqui solo viaja lo que la
/// persona escribe, y nunca se guarda nada en el dispositivo.
class VerificacionCorreoDialog extends StatefulWidget {
  const VerificacionCorreoDialog({super.key, required this.proposito});

  final PropositoCodigo proposito;

  /// Devuelve true solo si el codigo se verifico.
  ///
  /// [recordar] evita volver a preguntar durante la misma sesion, para lo que
  /// se consulta seguido, como abrir las recetas varias veces seguidas.
  static Future<bool> pedir(
    BuildContext context, {
    required PropositoCodigo proposito,
    bool recordar = false,
  }) async {
    if (recordar && _verificadosEnLaSesion.contains(proposito)) {
      return true;
    }

    final ok = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => VerificacionCorreoDialog(proposito: proposito),
        ) ??
        false;

    if (ok && recordar) {
      _verificadosEnLaSesion.add(proposito);
    }
    return ok;
  }

  /// Se limpia al cerrar sesion para que el siguiente usuario vuelva a pasar
  /// por la verificacion.
  static void olvidar() => _verificadosEnLaSesion.clear();

  static final Set<PropositoCodigo> _verificadosEnLaSesion = <PropositoCodigo>{};

  @override
  State<VerificacionCorreoDialog> createState() =>
      _VerificacionCorreoDialogState();
}

class _VerificacionCorreoDialogState extends State<VerificacionCorreoDialog> {
  final _codigo = TextEditingController();

  bool _enviando = false;
  bool _verificando = false;
  String? _error;
  String? _aviso;

  /// Segundos que faltan para poder pedir otro codigo.
  int _espera = 0;
  Timer? _reloj;

  String get _correo => FirebaseAuth.instance.currentUser?.email ?? '';

  @override
  void initState() {
    super.initState();
    // El primer codigo sale solo: la persona ya decidio entrar aqui.
    WidgetsBinding.instance.addPostFrameCallback((_) => _enviar());
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _codigo.dispose();
    super.dispose();
  }

  void _arrancarEspera(int segundos) {
    _reloj?.cancel();
    setState(() => _espera = segundos);
    _reloj = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _espera--);
      if (_espera <= 0) {
        t.cancel();
      }
    });
  }

  Future<void> _enviar() async {
    if (_enviando || _espera > 0) {
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
      _aviso = null;
    });

    try {
      await FirebaseFunctions.instance
          .httpsCallable('enviarCodigo')
          .call<Map<String, dynamic>>({'proposito': widget.proposito.clave})
          .timeout(const Duration(seconds: 30));

      if (!mounted) {
        return;
      }
      setState(() => _aviso = 'Codigo enviado a $_correo');
      _arrancarEspera(60);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? 'No se pudo enviar el codigo.');
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'El servidor tardo demasiado. Intenta de nuevo.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo enviar el codigo: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  Future<void> _verificar() async {
    final codigo = _codigo.text.trim();
    if (codigo.length != 6) {
      setState(() => _error = 'El codigo son seis digitos.');
      return;
    }

    setState(() {
      _verificando = true;
      _error = null;
    });

    try {
      await FirebaseFunctions.instance
          .httpsCallable('verificarCodigo')
          .call<Map<String, dynamic>>(
              {'proposito': widget.proposito.clave, 'codigo': codigo})
          .timeout(const Duration(seconds: 30));

      if (!mounted) {
        return;
      }
      Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'El codigo no es valido.';
          _codigo.clear();
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() => _error = 'El servidor tardo demasiado. Intenta de nuevo.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'No se pudo verificar: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _verificando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ocupado = _enviando || _verificando;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Row(
        children: [
          const Icon(Icons.mark_email_read_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(widget.proposito.titulo,
                style: const TextStyle(fontSize: 17)),
          ),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.proposito.explicacion,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            if (_correo.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                _correo,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark),
              ),
            ],
            const SizedBox(height: 18),
            TextField(
              controller: _codigo,
              enabled: !ocupado,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.bold),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                hintText: '------',
                counterText: '',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _verificar(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.danger)),
              ),
            ] else if (_aviso != null) ...[
              const SizedBox(height: 12),
              Text(_aviso!,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.success)),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: (_espera > 0 || ocupado) ? null : _enviar,
                child: Text(
                  _espera > 0
                      ? 'Reenviar codigo en $_espera s'
                      : 'No me llego, reenviar',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: ocupado ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: AppColors.textMuted)),
        ),
        ElevatedButton(
          onPressed: ocupado ? null : _verificar,
          child: _verificando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Verificar'),
        ),
      ],
    );
  }
}

/// Envoltorio para las pantallas que exigen el codigo antes de mostrarse.
class ProtegidoPorCodigo extends StatefulWidget {
  const ProtegidoPorCodigo({
    super.key,
    required this.proposito,
    required this.child,
    this.mensajeBloqueado = 'Necesitas verificar tu correo para ver esta seccion.',
  });

  final PropositoCodigo proposito;
  final Widget child;
  final String mensajeBloqueado;

  @override
  State<ProtegidoPorCodigo> createState() => _ProtegidoPorCodigoState();
}

class _ProtegidoPorCodigoState extends State<ProtegidoPorCodigo> {
  bool _verificado = false;
  bool _preguntando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pedir());
  }

  Future<void> _pedir() async {
    if (!mounted) {
      return;
    }
    setState(() => _preguntando = true);

    final ok = await VerificacionCorreoDialog.pedir(
      context,
      proposito: widget.proposito,
      recordar: true,
    );

    if (mounted) {
      setState(() {
        _verificado = ok;
        _preguntando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_verificado) {
      return widget.child;
    }
    if (_preguntando) {
      return const CargandoCentrado(mensaje: 'Verificando tu correo...');
    }
    return EstadoVacio(
      icono: Icons.lock_outline,
      titulo: 'Seccion protegida',
      detalle: widget.mensajeBloqueado,
      accion: ElevatedButton.icon(
        onPressed: _pedir,
        icon: const Icon(Icons.mark_email_read_outlined, size: 18),
        label: const Text('Verificar mi correo'),
      ),
    );
  }
}
