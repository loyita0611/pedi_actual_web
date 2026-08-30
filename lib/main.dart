// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/constants/app_colors.dart';
import 'core/widgets/async_states.dart';
import 'features/auth/presentation/pages/login_page.dart';
import 'features/schedule/presentation/pages/main_layout_page.dart';
import 'features/schedule/presentation/widgets/inactivity_wrapper.dart';
import 'firebase_options.dart';
import 'injection_container.dart' as di;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  // Faltaba: sin esto, cualquier DateFormat con locale 'es' lanza
  // LocaleDataException en cuanto se pinta el calendario.
  await initializeDateFormatting('es');

  await di.init();

  runApp(const PediActualApp());
}

class PediActualApp extends StatelessWidget {
  const PediActualApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PediActual',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) =>
          InactivityWrapper(child: child ?? const SizedBox.shrink()),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      locale: const Locale('es'),
      home: const _Puerta(),
    );
  }
}

/// Decide a donde entra cada quien segun su rol.
class _Puerta extends StatelessWidget {
  const _Puerta();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, sesion) {
        if (sesion.connectionState == ConnectionState.waiting) {
          return const _Cargando();
        }
        final usuario = sesion.data;
        if (usuario == null) return const LoginPage();

        return FutureBuilder<CurrentUser>(
          future: resolverUsuario(usuario),
          builder: (context, perfil) {
            if (perfil.connectionState == ConnectionState.waiting) {
              return const _Cargando();
            }
            if (perfil.hasError) {
              return Scaffold(
                backgroundColor: AppColors.background,
                body: EstadoError(
                  error: perfil.error,
                  onReintentar: () => FirebaseAuth.instance.signOut(),
                ),
              );
            }
            return MainLayoutPage(currentUser: perfil.data!);
          },
        );
      },
    );
  }
}

/// Lee el rol del usuario.
///
/// Prioridad: primero el custom claim (que el usuario no puede modificar),
/// despues el documento de `users`. La red de seguridad por correo se conserva
/// para no dejar fuera a la secretaria mientras se configuran los claims.
Future<CurrentUser> resolverUsuario(User usuario) async {
  var nombre = usuario.displayName ?? usuario.email ?? 'Usuario';
  UserRole rol = UserRole.patient;

  try {
    final token = await usuario.getIdTokenResult();
    final claim = token.claims?['role']?.toString();
    if (claim != null) rol = _rolDesde(claim);
  } catch (_) {
    // Sin claims, se sigue con el documento.
  }

  try {
    // Lectura directa por id: el documento se crea con el uid como id, asi que
    // la consulta con where() que habia antes era un rodeo innecesario.
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(usuario.uid)
        .get();
    final datos = doc.data();
    if (datos != null) {
      nombre = (datos['name'] as String?)?.trim().isNotEmpty == true
          ? datos['name']
          : nombre;
      if (rol == UserRole.patient) rol = _rolDesde(datos['role']?.toString());
    }
  } catch (_) {
    // Si Firestore no responde, se entra como representante.
  }

  if (usuario.email == 'secretaria@pediactual.com') rol = UserRole.secretary;

  return CurrentUser(name: nombre, role: rol);
}

UserRole _rolDesde(String? valor) => switch (valor) {
      'doctor' => UserRole.doctor,
      'secretary' => UserRole.secretary,
      _ => UserRole.patient,
    };

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.background,
        body: CargandoCentrado(),
      );
}
