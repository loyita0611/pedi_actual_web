// lib/features/auth/presentation/pages/register_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/search_utils.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../core/widgets/verificacion_correo_dialog.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  final _telefono = TextEditingController();

  bool _cargando = false;
  bool _oculta = true;

  @override
  void dispose() {
    for (final c in [_nombre, _correo, _clave, _telefono]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _cargando = true);

    try {
      final credencial =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _correo.text.trim(),
        password: _clave.text,
      );
      final usuario = credencial.user;
      if (usuario == null) throw Exception('No se pudo crear la cuenta.');

      await usuario.updateDisplayName(_nombre.text.trim());

      await FirebaseFirestore.instance
          .collection('users')
          .doc(usuario.uid)
          .set({
        'uid': usuario.uid,
        'name': _nombre.text.trim(),
        'nombreBusqueda': normalizarTexto(_nombre.text),
        'email': _correo.text.trim().toLowerCase(),
        'phone': _telefono.text.trim(),
        // El rol solo puede ser 'patient' desde aqui, y las reglas de Firestore
        // impiden que el propio usuario lo cambie luego. Esa era la puerta que
        // permitia auto-ascenderse a secretaria.
        'role': 'patient',
        'notificationsEnabled': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Si la secretaria ya habia cargado hijos con este correo, se enlazan
      // ahora para que aparezcan en su desplegable desde el primer momento.
      await _enlazarHijosExistentes(
          usuario.uid, _correo.text.trim().toLowerCase());

      if (!mounted) return;

      // Codigo de seis digitos al correo, antes de dejar entrar. Comprueba que
      // la direccion es suya de verdad: sin esto bastaba con registrarse
      // usando el correo de otra familia para llegar a su historia clinica,
      // porque las reglas de Firestore conceden acceso por coincidencia de
      // correo a los pacientes que la secretaria cargo de antemano.
      final verificado = await VerificacionCorreoDialog.pedir(
        context,
        proposito: PropositoCodigo.registro,
      );

      if (!mounted) return;

      if (!verificado) {
        // La cuenta queda creada pero sin verificar: puede entrar y hacerlo
        // mas tarde, y mientras tanto solo ve lo suyo.
        mostrarAviso(
          context,
          'Cuenta creada, pero no verificaste el correo. Podras hacerlo mas '
          'tarde desde Ajustes.',
        );
      } else {
        mostrarAviso(context, 'Listo. Ya puedes agendar tu primera cita.',
            esExito: true);
      }
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarAviso(context, _mensaje(e.code), esError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarAviso(context, 'No pudimos completar el registro.', esError: true);
    }
  }

  Future<void> _enlazarHijosExistentes(String uid, String correo) async {
    try {
      final huerfanos = await FirebaseFirestore.instance
          .collection('patients')
          .where('email', isEqualTo: correo)
          .limit(20)
          .get();
      if (huerfanos.docs.isEmpty) return;

      final lote = FirebaseFirestore.instance.batch();
      for (final doc in huerfanos.docs) {
        if ((doc.data()['representativeId'] ?? '').toString().isEmpty) {
          lote.update(doc.reference, {'representativeId': uid});
        }
      }
      await lote.commit();
    } catch (_) {
      // Es una comodidad, no puede tumbar el registro.
    }
  }

  static String _mensaje(String codigo) => switch (codigo) {
        'email-already-in-use' =>
          'Ese correo ya esta registrado. Inicia sesion.',
        'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
        'invalid-email' => 'Ese correo no tiene un formato valido.',
        'network-request-failed' => 'Sin conexion. Revisa tu internet.',
        _ => 'No pudimos completar el registro.',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Container(
              width: 420,
              padding: const EdgeInsets.all(32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Registro de representante',
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary)),
                    const SizedBox(height: 6),
                    const Text(
                        'Crea tu cuenta para gestionar las citas de tus ninos',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _nombre,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre y apellido',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Escribe tu nombre completo'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _telefono,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Numero telefonico',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                      validator: (v) => (v == null || v.trim().length < 7)
                          ? 'Ingresa un telefono valido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Correo electronico',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        final texto = (v ?? '').trim();
                        if (texto.isEmpty) return 'Ingresa tu correo';
                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(texto)) {
                          return 'Ese correo no parece valido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _clave,
                      obscureText: _oculta,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        helperText: 'Minimo 6 caracteres',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                              _oculta ? Icons.visibility_off : Icons.visibility,
                              size: 20),
                          onPressed: () => setState(() => _oculta = !_oculta),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Minimo 6 caracteres'
                          : null,
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentDark),
                        onPressed: _cargando ? null : _registrar,
                        child: _cargando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.4))
                            : const Text('Crear mi cuenta',
                                style: TextStyle(fontSize: 15)),
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
