// lib/injection_container.dart

import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'features/schedule/data/datasources/appointment_remote_data_source.dart';
import 'features/schedule/data/repositories/appointment_repository_impl.dart';
import 'features/schedule/domain/repositories/appointment_repository.dart';
import 'features/schedule/domain/usecases/get_appointments_by_date.dart';
import 'features/schedule/domain/usecases/book_appointment.dart';
import 'features/schedule/presentation/bloc/schedule_bloc.dart';

final sl = GetIt.instance; // sl significa Service Locator

Future<void> init() async {
  // 1. Capa de Presentación (Features - Schedule)
  // Registramos el Bloc como Factory para que se cree una nueva instancia cada vez que se cierre y abra la pantalla
  sl.registerFactory(() => ScheduleBloc(
        getAppointmentsByDate: sl(),
        bookAppointment: sl(),
      ));

  // 2. Capa de Dominio (Casos de Uso)
  sl.registerLazySingleton(() => GetAppointmentsByDate(sl()));
  sl.registerLazySingleton(() => BookAppointment(sl()));

  // 3. Capa de Datos (Repositorios y Data Sources)
  sl.registerLazySingleton<AppointmentRepository>(
    () => AppointmentRepositoryImpl(remoteDataSource: sl()),
  );
  
  sl.registerLazySingleton<AppointmentRemoteDataSource>(
    () => AppointmentRemoteDataSourceImpl(firestore: sl()),
  );

  // 4. Recursos Externos (Core)
  // Inyectamos la instancia nativa de Firebase Firestore
  final firestore = FirebaseFirestore.instance;
  sl.registerLazySingleton(() => firestore);
}