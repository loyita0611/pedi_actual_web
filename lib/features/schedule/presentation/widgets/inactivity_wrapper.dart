import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class InactivityWrapper extends StatefulWidget {
  final Widget child;

  const InactivityWrapper({super.key, required this.child});

  @override
  State<InactivityWrapper> createState() => _InactivityWrapperState();
}

class _InactivityWrapperState extends State<InactivityWrapper> {
  Timer? _timer;
  // 🔹 Definimos el tiempo máximo de inactividad (6 minutos)
  final Duration _inactivityTimeout = const Duration(minutes: 6); 

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer([dynamic _]) {
    // Si hay un temporizador corriendo, lo cancelamos
    _timer?.cancel();
    
    // Solo iniciamos el reloj de destrucción si hay un usuario logueado
    if (FirebaseAuth.instance.currentUser != null) {
      _timer = Timer(_inactivityTimeout, _logOutUser);
    }
  }

  Future<void> _logOutUser() async {
    _timer?.cancel();
    await FirebaseAuth.instance.signOut();
    // Al hacer signOut, el StreamBuilder de main.dart detectará el cambio
    // y te enviará automáticamente a la pantalla de Login.
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Listener detecta clics, toques en pantalla y movimientos del mouse
    return Listener(
      onPointerDown: _resetTimer,
      onPointerMove: _resetTimer,
      onPointerUp: _resetTimer,
      child: widget.child,
    );
  }
}