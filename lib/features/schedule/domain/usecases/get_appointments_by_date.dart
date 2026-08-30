// lib/features/schedule/domain/usecases/get_appointments_by_date.dart
import '../../../../core/constants/app_status.dart';
import '../entities/appointment_entity.dart';
import '../repositories/appointment_repository.dart';

class GetAppointmentsByDate {
  const GetAppointmentsByDate(this.repository);
  final AppointmentRepository repository;

  /// Devuelve lo que el usuario tiene derecho a ver de ese dia.
  ///
  /// El personal recibe la agenda completa. El representante recibe dos cosas
  /// mezcladas: sus propias citas con todos los datos, y las de los demas
  /// convertidas en un bloque anonimo que solo dice "ocupado". Antes se le
  /// entregaba la agenda entera -con nombres, telefonos y motivos de consulta
  /// de las demas familias- y bastaba con abrir las herramientas del navegador.
  ///
  /// Las propias se piden aparte a proposito. Se escriben en el mismo momento
  /// de reservar, mientras que el bloque anonimo lo publica una funcion del
  /// servidor un segundo despues: sin esta mezcla, el horario que acabas de
  /// tomar seguia figurando libre hasta recargar la pagina.
  Future<List<AppointmentEntity>> call(
    DateTime date, {
    bool esPersonal = false,
  }) async {
    if (esPersonal) {
      final citas = await repository.getAppointmentsByDate(date);
      citas.sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
      return citas;
    }

    final resultados = await Future.wait(<Future<Object>>[
      repository.getOcupadosByDate(date),
      repository.getMisCitasDelDia(date),
    ]);

    final ocupados = resultados[0] as List<DateTime>;
    final mias = resultados[1] as List<AppointmentEntity>;

    // Se indexa por hora para que la cita propia sustituya al marcador anonimo
    // del mismo bloque en vez de duplicarlo.
    final porHora = <String, AppointmentEntity>{};
    for (final cuando in ocupados) {
      porHora[_clave(cuando)] = marcadorDeOcupado(cuando);
    }
    for (final cita in mias) {
      if (cita.status == CitaStatus.cancelada) {
        // Una cita cancelada no ocupa el horario ni debe aparecer en la lista.
        porHora.remove(_clave(cita.appointmentDateTime));
        continue;
      }
      porHora[_clave(cita.appointmentDateTime)] = cita;
    }

    final lista = porHora.values.toList()
      ..sort((a, b) => a.appointmentDateTime.compareTo(b.appointmentDateTime));
    return lista;
  }

  static String _clave(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dos(d.month)}-${dos(d.day)}_${dos(d.hour)}${dos(d.minute)}';
  }

  /// Cita sin identidad: solo dice "este bloque esta tomado".
  static AppointmentEntity marcadorDeOcupado(DateTime cuando) {
    return AppointmentEntity(
      id: '',
      patientName: '',
      patientBirthDate: DateTime(2000),
      address: '',
      representativeName: '',
      email: '',
      phone: '',
      appointmentDateTime: cuando,
      status: CitaStatus.confirmada,
    );
  }
}
