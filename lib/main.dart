// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pedia_actual/features/auth/presentation/pages/login_page.dart';
import 'package:pedia_actual/firebase_options.dart';
import 'injection_container.dart' as di; 

// 🔹 Importaciones del Layout y Vigilante
import 'package:pedia_actual/features/schedule/presentation/widgets/inactivity_wrapper.dart'; 
import 'package:pedia_actual/features/schedule/presentation/pages/main_layout_page.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // OBLIGAMOS a Firebase a mantener la sesión guardada localmente
  await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
  
  await di.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PediaActual',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      
      // Vigilante de inactividad
      builder: (context, child) {
        return InactivityWrapper(child: child!);
      },
      
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', ''), 
        Locale('en', ''), 
      ],
      locale: const Locale('es', ''),

      // HOME INTELIGENTE
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          
          // Cargador mientras Firebase revisa la caché
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: Color(0xFFF4F7F6),
              body: Center(child: CircularProgressIndicator(color: Colors.teal)),
            );
          }
          
          // Si hay sesión guardada en Firebase
          if (snapshot.hasData && snapshot.data != null) {
            final firebaseUser = snapshot.data!;
            
            // Construimos el usuario base
            final currentUser = CurrentUser(
              name: firebaseUser.displayName ?? firebaseUser.email ?? 'Paciente',
              role: UserRole.patient, 
            );

            return MainLayoutPage(currentUser: currentUser); 
          }
          
          // Si no hay sesión o pasaron 6 minutos
          return const LoginPage();
        },
      ),
    );
  }
}