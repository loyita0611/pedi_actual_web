// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; 
import 'package:pedia_actual/features/schedule/presentation/pages/schedule_page.dart';
import 'package:pedia_actual/features/schedule/presentation/bloc/schedule_bloc.dart';
import 'package:pedia_actual/firebase_options.dart';
import 'injection_container.dart' as di; // Importamos con alias Dependency Injection

void main() async {
  // Asegura que los bindings de Flutter estén listos antes de inicializar servicios externos
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicializamos las opciones de Firebase apuntando al nuevo proyecto de forma correcta
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Inicializamos el contenedor de Inyección de Dependencias
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
      
      // CONFIGURACIÓN DE IDIOMA (LOCALIZATION)
      // Estos delegados le enseñan a los componentes nativos (como el calendario) a hablar español
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Definimos los idiomas soportados por la aplicación
      supportedLocales: const [
        Locale('es', ''), // Español (Principal)
        Locale('en', ''), // Inglés (Opcional)
      ],
      // Forzamos a que la app inicie por defecto en español
      locale: const Locale('es', ''),

      // Envolvemos el home con el BlocProvider inyectado con GetIt
      home: BlocProvider(
        create: (_) => di.sl<ScheduleBloc>(),
        child: const SchedulePage(),
      ),
    );
  }
}