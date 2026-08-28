// lib/features/schedule/presentation/widgets/inactivity_wrapper.dart
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_colors.dart';

/// Cierre de sesion por inactividad.
///
/// Antes escuchaba solo el puntero, asi que alguien escribiendo el formulario
/// de reserva durante seis minutos era desconectado y perdia todo lo cargado,
/// sin ningun aviso. Ahora tambien cuenta el teclado, el margen es mayor y hay
/// un aviso previo con opcion de continuar.
class InactivityWrapper extends StatefulWidget {
  const InactivityWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  static const Duration _limite = Duration(minutes: 15);
  static const Duration _avisoAntes = Duration(seconds: 60);

  Timer? _timerAviso;
  Timer? _timerCierre;
  bool _avisoVisible = false;

  @override
  void initState() {
    super.initState();
    _reiniciar();
  }

  @override
  void dispose() {
    _timerAviso?.cancel();
    _timerCierre?.cancel();
    super.dispose();
  }

  void _reiniciar([dynamic _]) {
    if (_avisoVisible) return; // el dialogo se cierra con su propio boton
    _timerAviso?.cancel();
    _timerCierre?.cancel();

    if (FirebaseAuth.instance.currentUser == null) return;

    _timerAviso = Timer(_limite - _avisoAntes, _mostrarAviso);
    _timerCierre = Timer(_limite, _cerrarSesion);
  }

  void _mostrarAviso() {
    if (!mounted) return;
    final navigator = Navigator.maybeOf(context);
    if (navigator == null) return;

    _avisoVisible = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.timer_outlined, color: AppColors.warning),
            SizedBox(width: 10),
            Text('Tu sesion esta por cerrarse', style: TextStyle(fontSize: 17)),
          ],
        ),
        content: const Text(
          'Por seguridad cerraremos la sesion en un minuto por falta de actividad. '
          'Si sigues aqui, pulsa Continuar y no perderas lo que estabas escribiendo.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _avisoVisible = false;
              _reiniciar();
            },
            child: const Text('Continuar conectado'),
          ),
        ],
      ),
    ).then((_) => _avisoVisible = false);
  }

  Future<void> _cerrarSesion() async {
    _timerAviso?.cancel();
    _timerCierre?.cancel();
    if (!mounted) return;

    if (_avisoVisible && Navigator.canPop(context)) {
      Navigator.pop(context);
      _avisoVisible = false;
    }

    // Se limpia tambien la pestana guardada: si no, el siguiente usuario de
    // este navegador aterrizaba en la ultima pantalla del anterior.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_page_index');
      await prefs.remove('selected_page_role');
    } catch (_) {
      // Si falla, el cierre de sesion igual debe ocurrir.
    }
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _reiniciar,
      onPointerMove: _reiniciar,
      onPointerSignal: _reiniciar,
      child: Focus(
        // Escribir tambien cuenta como actividad.
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) _reiniciar();
          return KeyEventResult.ignored;
        },
        canRequestFocus: false,
        skipTraversal: true,
        child: widget.child,
      ),
    );
  }
}
