// lib/features/auth/presentation/pages/login_page.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/async_states.dart';
import 'register_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _cargando = false;
  bool _oculta = true;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _cargando = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _correo.text.trim(),
        password: _clave.text,
      );
      // No hace falta navegar: el StreamBuilder de main.dart detecta la sesion
      // y resuelve el rol en un solo lugar. Antes esta pantalla duplicaba esa
      // logica y las dos podian quedar desalineadas.
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _cargando = false);
      mostrarAviso(context, _mensaje(e.code), esError: true);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _cargando = false);
      mostrarAviso(context, 'No pudimos iniciar sesion. Intenta de nuevo.',
          esError: true);
    }
  }

  Future<void> _recuperar() async {
    final correo = _correo.text.trim();
    if (correo.isEmpty) {
      mostrarAviso(context, 'Escribe tu correo y vuelve a pulsar aqui.',
          esError: true);
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: correo);
      if (mounted) {
        mostrarAviso(context, 'Te enviamos un enlace a $correo', esExito: true);
      }
    } catch (_) {
      if (mounted) {
        mostrarAviso(context, 'No pudimos enviar el enlace.', esError: true);
      }
    }
  }

  static String _mensaje(String codigo) => switch (codigo) {
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'Correo o contraseña incorrectos.',
        'invalid-email' => 'Ese correo no tiene un formato valido.',
        'user-disabled' =>
          'Esta cuenta fue deshabilitada. Comunicate con la clinica.',
        'too-many-requests' => 'Demasiados intentos. Espera unos minutos.',
        'network-request-failed' => 'Sin conexion. Revisa tu internet.',
        _ => 'No pudimos iniciar sesion. Intenta de nuevo.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Pedi',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 32,
                                fontWeight: FontWeight.w300)),
                        Text('Actual',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 32,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text('Inicio de sesion',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13.5)),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Correo electronico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa tu correo'
                          : null,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: _clave,
                      obscureText: _oculta,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _cargando ? null : _entrar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _oculta ? Icons.visibility_off : Icons.visibility,
                              size: 20),
                          onPressed: () => setState(() => _oculta = !_oculta),
                        ),
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? 'Ingresa tu contrasena'
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _recuperar,
                        child: const Text('Olvidé mi contraseña',
                            style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _entrar,
                        child: _cargando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.4))
                            : const Text('Iniciar sesion',
                                style: TextStyle(fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RegisterPage()),
                      ),
                      child: const Text(
                        'Eres nuevo? Registrate como representante',
                        style: TextStyle(
                            color: AppColors.accentDark,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
