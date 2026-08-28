// lib/injection_container.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';

import 'core/config/clinic_config.dart';
import 'core/services/bcv_service.dart';
import 'core/services/email_service.dart';
import 'core/services/storage_service.dart';
import 'features/orders/data/medical_order_service.dart';
import 'features/prescriptions/data/prescription_service.dart';
import 'features/schedule/data/datasources/appointment_remote_data_source.dart';
import 'features/schedule/data/repositories/appointment_repository_impl.dart';
import 'features/schedule/domain/repositories/appointment_repository.dart';
import 'features/schedule/domain/usecases/book_appointment.dart';
import 'features/schedule/domain/usecases/cancel_appointment.dart';
import 'features/schedule/domain/usecases/get_appointments_by_date.dart';
import 'features/schedule/domain/usecases/reschedule_appointment.dart';
import 'features/schedule/presentation/bloc/schedule_bloc.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ----------------------------------------------------------- externos
  sl.registerLazySingleton<FirebaseFirestore>(() => FirebaseFirestore.instance);
  sl.registerLazySingleton<FirebaseAuth>(() => FirebaseAuth.instance);

  // ----------------------------------------------------------- servicios
  sl.registerLazySingleton<StorageService>(() => StorageService());
  sl.registerLazySingleton<BcvService>(() => BcvService(firestore: sl()));
  sl.registerLazySingleton<EmailService>(() => EmailService());
  sl.registerLazySingleton<ClinicConfigService>(() => ClinicConfigService(firestore: sl()));
  sl.registerLazySingleton<MedicalOrderService>(
      () => MedicalOrderService(firestore: sl(), auth: sl()));
  sl.registerLazySingleton<PrescriptionService>(
      () => PrescriptionService(firestore: sl(), auth: sl(), storage: sl()));

  // ---------------------------------------------------------------- datos
  sl.registerLazySingleton<AppointmentRemoteDataSource>(
    () => AppointmentRemoteDataSourceImpl(firestore: sl(), auth: sl()),
  );
  sl.registerLazySingleton<AppointmentRepository>(
    () => AppointmentRepositoryImpl(remoteDataSource: sl()),
  );

  // -------------------------------------------------------------- dominio
  sl.registerLazySingleton(() => GetAppointmentsByDate(sl()));
  sl.registerLazySingleton(() => BookAppointment(sl()));
  sl.registerLazySingleton(() => CancelAppointment(sl()));
  sl.registerLazySingleton(() => RescheduleAppointment(sl()));

  // --------------------------------------------------------- presentacion
  sl.registerFactory(
    () => ScheduleBloc(
      getAppointmentsByDate: sl(),
      bookAppointment: sl(),
      cancelAppointment: sl(),
      rescheduleAppointment: sl(),
    ),
  );

  // Se precarga la configuracion para que la grilla no tenga que esperarla.
  await sl<ClinicConfigService>().cargar();
}
