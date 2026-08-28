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
}
