// test/widget_test.dart
//
// El archivo anterior era la plantilla del contador de Flutter: buscaba un
// boton "+" y el texto "0", asi que fallaba siempre. Ademas MyApp necesitaba
// Firebase inicializado para arrancar.
//
// Estas pruebas cubren la logica pura, la que de verdad puede romperse sin que
// nadie se de cuenta: la generacion de horarios y el mapeo de estados.

import 'package:flutter_test/flutter_test.dart';
import 'package:pedia_actual/core/config/clinic_config.dart';
import 'package:pedia_actual/core/constants/app_status.dart';
import 'package:pedia_actual/core/constants/venezuela_banks.dart';
import 'package:pedia_actual/core/utils/search_utils.dart';
import 'package:pedia_actual/features/schedule/data/datasources/appointment_remote_data_source.dart';
import 'package:pedia_actual/features/schedule/domain/entities/appointment_entity.dart';
import 'package:pedia_actual/features/schedule/domain/repositories/appointment_repository.dart';
import 'package:pedia_actual/features/schedule/domain/usecases/get_appointments_by_date.dart';
import 'package:pedia_actual/features/schedule/presentation/widgets/time_slot_helper.dart';

AppointmentEntity _cita(DateTime cuando, {CitaStatus estado = CitaStatus.confirmada}) {
  return AppointmentEntity(
    id: 'x',
    patientName: 'Prueba',
    patientBirthDate: DateTime(2020),
    address: '',
    representativeName: '',
    email: '',
    phone: '',
    appointmentDateTime: cuando,
    status: estado,
  );
}

void main() {
  const config = ClinicConfig(
    horaInicio: 8,
    horaFin: 17,
    minutosPorCita: 30,
    diasHabiles: [1, 2, 3, 4, 5],
    almuerzoInicio: 12,
    almuerzoFin: 13,
    tarifaUsd: 40,
    bancoReceptor: 'BNC',
    telefonoPagoMovil: '0412',
    cedulaReceptor: 'V-1',
    numeroCuenta: '0191',
    rif: 'J-1',
    telefonoClinica: '+58',
    direccion: 'x',
    feriados: <String>[],
  );

  // Un lunes lejano, para que nunca sea "hoy" ni quede en el pasado.
  final lunes = DateTime(2027, 3, 8, 0, 0);
  final domingo = DateTime(2027, 3, 14, 0, 0);

  group('Generacion de horarios', () {
    test('no genera bloques en fin de semana', () {
      final slots = TimeSlotHelper.generateSlotsForDate(
        selectedDate: domingo,
        bookedAppointments: const [],
        config: config,
      );
      expect(slots, isEmpty, reason: 'Antes se generaban bloques los siete dias.');
    });

    test('respeta la hora de almuerzo', () {
      final slots = TimeSlotHelper.generateSlotsForDate(
        selectedDate: lunes,
        bookedAppointments: const [],
        config: config,
      );
      final almuerzo = slots.where((s) => s.dateTime.hour == 12);
      expect(almuerzo, isNotEmpty);
      expect(almuerzo.every((s) => s.motivo == MotivoBloqueo.almuerzo), isTrue);
      expect(almuerzo.every((s) => !s.disponible), isTrue);
    });

    test('marca como ocupado el bloque que ya tiene cita', () {
      final slots = TimeSlotHelper.generateSlotsForDate(
        selectedDate: lunes,
        bookedAppointments: [_cita(DateTime(2027, 3, 8, 9, 0))],
        config: config,
      );
      final nueve = slots.firstWhere((s) => s.dateTime.hour == 9 && s.dateTime.minute == 0);
      expect(nueve.isOccupied, isTrue);
    });

    test('una cita cancelada libera el horario', () {
      // La grilla recalculaba la ocupacion solo por hora y minuto, ignorando el
      // estado, asi que una cita cancelada seguia bloqueando el bloque.
      final slots = TimeSlotHelper.generateSlotsForDate(
        selectedDate: lunes,
        bookedAppointments: [
          _cita(DateTime(2027, 3, 8, 9, 0), estado: CitaStatus.cancelada),
        ],
        config: config,
      );
      final nueve = slots.firstWhere((s) => s.dateTime.hour == 9 && s.dateTime.minute == 0);
      expect(nueve.disponible, isTrue);
    });

    test('no expone el paciente salvo que se pida explicitamente', () {
      final citas = [_cita(DateTime(2027, 3, 8, 9, 0))];
      final paraPaciente = TimeSlotHelper.generateSlotsForDate(
        selectedDate: lunes,
        bookedAppointments: citas,
        config: config,
      );
      final paraPersonal = TimeSlotHelper.generateSlotsForDate(
        selectedDate: lunes,
        bookedAppointments: citas,
        config: config,
        exponerDatosDelPaciente: true,
      );
      expect(paraPaciente.firstWhere((s) => s.isOccupied).appointment, isNull);
      expect(paraPersonal.firstWhere((s) => s.isOccupied).appointment, isNotNull);
    });
  });

  group('Estados', () {
    test('acepta los tres dialectos viejos de pago', () {
      expect(PagoStatus.fromRaw('approved'), PagoStatus.verificado);
      expect(PagoStatus.fromRaw('aprobado'), PagoStatus.verificado);
      expect(PagoStatus.fromRaw('pagado'), PagoStatus.verificado);
      expect(PagoStatus.fromRaw('verificado'), PagoStatus.verificado);
      expect(PagoStatus.fromRaw('rejected'), PagoStatus.rechazado);
      expect(PagoStatus.fromRaw('Pendiente'), PagoStatus.pendiente);
      expect(PagoStatus.fromRaw(null), PagoStatus.pendiente);
    });

    test('lee los estados de cita ya guardados', () {
      expect(CitaStatus.fromRaw('in_room'), CitaStatus.enSala);
      expect(CitaStatus.fromRaw('attended'), CitaStatus.atendida);
      expect(CitaStatus.fromRaw('cancelled'), CitaStatus.cancelada);
      expect(CitaStatus.fromRaw('no_show'), CitaStatus.noAsistio);
      expect(CitaStatus.fromRaw('cualquier cosa'), CitaStatus.pendiente);
    });
  });

  group('Identificador de horario', () {
    test('el mismo bloque produce el mismo id', () {
      final a = AppointmentRemoteDataSourceImpl.idDeHorario(DateTime(2026, 9, 12, 8, 30));
      final b = AppointmentRemoteDataSourceImpl.idDeHorario(DateTime(2026, 9, 12, 8, 30));
      expect(a, b);
      expect(a, '2026-09-12_0830');
    });

    test('bloques distintos producen ids distintos', () {
      expect(
        AppointmentRemoteDataSourceImpl.idDeHorario(DateTime(2026, 9, 12, 8, 30)),
        isNot(AppointmentRemoteDataSourceImpl.idDeHorario(DateTime(2026, 9, 12, 9, 0))),
      );
    });
  });

  group('Busqueda', () {
    test('ignora mayusculas y tildes', () {
      expect(normalizarTexto('  JOSÉ  Andrés '), 'jose andres');
      expect(normalizarTexto('Muñoz'), 'munoz');
    });

    test('la cota superior contiene al prefijo', () {
      expect(cotaSuperior('jua').startsWith('jua'), isTrue);
      expect(cotaSuperior('jua').length, greaterThan(3));
    });
  });

  group('Bancos', () {
    test('la lista tiene los 20 bancos sin repetidos', () {
      expect(kBancosVenezuela.length, 20);
      expect(kBancosVenezuela.toSet().length, 20);
    });

    test('recupera los bancos guardados con el nombre viejo', () {
      expect(normalizarBanco('Mercantil'), 'Banco Mercantil');
      expect(normalizarBanco('BNC'), 'Banco Nacional de Credito (BNC)');
      expect(normalizarBanco('Banesco'), 'Banesco');
      expect(normalizarBanco('  banesco '), 'Banesco');
      expect(normalizarBanco(null), isNull);
      expect(normalizarBanco('Banco Inexistente'), isNull);
    });
  });

  group('Configuracion de la clinica', () {
    test('domingo no es dia habil', () {
      expect(config.esDiaHabil(domingo), isFalse);
      expect(config.esDiaHabil(lunes), isTrue);
    });

    // Regresion: los selectores de fecha abrian en "hoy" con un filtro que
    // rechaza los dias no habiles, y Flutter tiene un assert que exige que la
    // fecha inicial sea seleccionable. Abrir la agenda un domingo tumbaba el
    // dialogo y dejaba la pantalla en blanco.
    test('el proximo dia habil salta el fin de semana', () {
      const config = ClinicConfig.fallback;
      // 30 de agosto de 2026 es domingo.
      final domingo = DateTime(2026, 8, 30);
      expect(config.esDiaHabil(domingo), isFalse);

      final siguiente = config.proximoDiaHabil(domingo);
      expect(config.esDiaHabil(siguiente), isTrue);
      expect(siguiente, DateTime(2026, 8, 31));
    });

    test('el proximo dia habil deja igual un dia que ya es habil', () {
      const config = ClinicConfig.fallback;
      final lunes = DateTime(2026, 8, 31);
      expect(config.proximoDiaHabil(lunes), lunes);
    });

    test('un feriado bloquea el dia', () {
      final conFeriado = ClinicConfig(
        horaInicio: config.horaInicio,
        horaFin: config.horaFin,
        minutosPorCita: config.minutosPorCita,
        diasHabiles: config.diasHabiles,
        almuerzoInicio: config.almuerzoInicio,
        almuerzoFin: config.almuerzoFin,
        tarifaUsd: config.tarifaUsd,
        bancoReceptor: config.bancoReceptor,
        telefonoPagoMovil: config.telefonoPagoMovil,
        cedulaReceptor: config.cedulaReceptor,
        numeroCuenta: config.numeroCuenta,
        rif: config.rif,
        telefonoClinica: config.telefonoClinica,
        direccion: config.direccion,
        feriados: const ['2027-03-08'],
      );
      expect(conFeriado.esDiaHabil(lunes), isFalse);
    });
  });

  group('Agenda del representante', () {
    final dia = DateTime(2026, 9, 1);
    AppointmentEntity miCita(int hora, {CitaStatus estado = CitaStatus.pendiente}) {
      return AppointmentEntity(
        id: 'mia',
        representativeId: 'uid-1',
        patientName: 'Sofia',
        patientBirthDate: DateTime(2020),
        address: 'Casa',
        representativeName: 'Jorge',
        email: 'jorge@ejemplo.com',
        phone: '0412',
        appointmentDateTime: DateTime(2026, 9, 1, hora),
        status: estado,
      );
    }

    test('las citas ajenas llegan sin un solo dato', () async {
      final caso = GetAppointmentsByDate(_RepositorioFalso(
        ocupados: [DateTime(2026, 9, 1, 8), DateTime(2026, 9, 1, 9)],
      ));

      final resultado = await caso(dia);

      expect(resultado.length, 2);
      for (final cita in resultado) {
        expect(cita.patientName, isEmpty);
        expect(cita.representativeName, isEmpty);
        expect(cita.email, isEmpty);
        expect(cita.phone, isEmpty);
      }
    });

    test('la cita propia reemplaza al marcador de su horario', () async {
      final caso = GetAppointmentsByDate(_RepositorioFalso(
        ocupados: [DateTime(2026, 9, 1, 8), DateTime(2026, 9, 1, 9)],
        mias: [miCita(9)],
      ));

      final resultado = await caso(dia);

      // Sigue habiendo dos bloques ocupados, no tres: no se duplica.
      expect(resultado.length, 2);
      expect(resultado.first.patientName, isEmpty);
      expect(resultado.last.patientName, 'Sofia');
      expect(resultado.last.representativeId, 'uid-1');
    });

    test('la cita propia aparece aunque el servidor no haya publicado el dia', () async {
      // Es el caso de recien reservar: la cita ya esta escrita pero la funcion
      // que publica la disponibilidad todavia no corrio.
      final caso = GetAppointmentsByDate(_RepositorioFalso(mias: [miCita(10)]));

      final resultado = await caso(dia);

      expect(resultado.length, 1);
      expect(resultado.single.patientName, 'Sofia');
    });

    test('una cita propia cancelada libera el horario', () async {
      final caso = GetAppointmentsByDate(_RepositorioFalso(
        ocupados: [DateTime(2026, 9, 1, 8)],
        mias: [miCita(8, estado: CitaStatus.cancelada)],
      ));

      final resultado = await caso(dia);

      expect(resultado, isEmpty);
    });

    test('el personal recibe la agenda completa', () async {
      final caso = GetAppointmentsByDate(_RepositorioFalso(
        todas: [miCita(8), miCita(9)],
        ocupados: const [],
      ));

      final resultado = await caso(dia, esPersonal: true);

      expect(resultado.length, 2);
      expect(resultado.first.patientName, 'Sofia');
    });
  });
}

/// Repositorio de mentira: devuelve lo que se le ponga, sin tocar Firestore.
class _RepositorioFalso implements AppointmentRepository {
  _RepositorioFalso({this.ocupados = const [], this.mias = const [], this.todas = const []});

  final List<DateTime> ocupados;
  final List<AppointmentEntity> mias;
  final List<AppointmentEntity> todas;

  @override
  Future<List<DateTime>> getOcupadosByDate(DateTime date) async => ocupados;

  @override
  Future<List<AppointmentEntity>> getMisCitasDelDia(DateTime date) async => mias;

  @override
  Future<List<AppointmentEntity>> getAppointmentsByDate(DateTime date) async => todas;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
