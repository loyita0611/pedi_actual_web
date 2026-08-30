// lib/features/schedule/presentation/widgets/booking_dialog.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../../core/config/clinic_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_status.dart';
import '../../../../core/constants/venezuela_banks.dart';
import '../../../../core/services/bcv_service.dart';
import '../../../../core/services/storage_service.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/entities/appointment_entity.dart';

/// Reserva que no llego a guardarse, con el motivo ya listo para mostrar.
///
/// La lanza quien implementa [BookingDialog.onConfirmBooking] cuando sabe por
/// que fallo: asi el dialogo escribe la causa real en pantalla en vez de un
/// "no se pudo" generico.
class ReservaFallida implements Exception {
  const ReservaFallida(this.mensaje);
  final String mensaje;
  @override
  String toString() => mensaje;
}

/// Formulario de reserva del representante, en tres pasos.
class BookingDialog extends StatefulWidget {
  const BookingDialog({
    super.key,
    this.appointment,
    required this.timeString,
    required this.appointmentDateTime,
    required this.onConfirmBooking,
  });

  final AppointmentEntity? appointment;
  final String timeString;
  final DateTime appointmentDateTime;

  /// Debe devolver true si la cita quedo guardada de verdad.
  final Future<bool> Function(AppointmentEntity) onConfirmBooking;

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  final _formPaciente = GlobalKey<FormState>();
  final _formPago = GlobalKey<FormState>();

  final _representante = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _paciente = TextEditingController();
  final _direccion = TextEditingController();
  final _motivo = TextEditingController();

  final _referencia = TextEditingController();
  final _cedulaPago = TextEditingController();
  final _telefonoPago = TextEditingController();
  final _monto = TextEditingController();

  int _paso = 1;
  bool _guardando = false;

  String? _patientId;
  bool _pacienteNuevo = false;
  DateTime? _nacimiento;

  String? _banco;
  MetodoPago _metodo = MetodoPago.pagoMovil;

  TasaBcv? _tasa;
  bool _cargandoTasa = true;
  Object? _errorTasa;

  // Comprobante de pago
  PlatformFile? _comprobante;
  String? _comprobanteUrl;

  /// Nombre visible del adjunto. Sobrevive a la subida: cuando el archivo ya
  /// esta en Storage `_comprobante` se pone en null y sin esto la tarjeta
  /// volvia a decir "Ya cargada anteriormente".
  String? _comprobanteNombre;

  /// Motivo del ultimo intento fallido. Se pinta dentro del dialogo porque el
  /// SnackBar de `mostrarAviso` sale por detras de la barrera modal y el
  /// representante nunca llega a leerlo.
  String? _errorEnvio;

  /// Texto y avance del indicador mientras se guarda.
  String _fase = '';
  double? _progreso;

  /// Tope de la reserva completa. Es el ultimo cinturon de seguridad: si el
  /// callback que guarda en Firestore no responde, el dialogo se destraba
  /// igual. Firestore no lanza error cuando no hay red, se queda esperando.
  static const Duration _limiteGuardado = Duration(seconds: 60);

  /// Se reserva el id del pago desde el principio para que la captura se suba a
  /// `comprobantes/{pagoId}.jpg` y las reglas de Storage puedan comprobar,
  /// por el nombre del archivo, que quien lo lee es su dueno.
  late final String _pagoId =
      FirebaseFirestore.instance.collection('pagos').doc().id;

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;
  ClinicConfig get _config => ClinicConfigService.actual;

  /// En efectivo se paga en el consultorio: no hay referencia que registrar ni
  /// captura que adjuntar, asi que el paso 3 solo confirma.
  bool get _esEfectivo => _metodo == MetodoPago.efectivo;

  @override
  void initState() {
    super.initState();
    _cargarTasa();

    final usuario = FirebaseAuth.instance.currentUser;
    if (usuario != null) {
      if ((usuario.displayName ?? '').isNotEmpty) {
        _representante.text = usuario.displayName!;
      }
      if ((usuario.email ?? '').isNotEmpty) {
        _correo.text = usuario.email!;
      }
    }

    final cita = widget.appointment;
    if (cita != null && cita.id.isNotEmpty) {
      _patientId = cita.patientId.isEmpty ? null : cita.patientId;
      _paciente.text = cita.patientName;
      _direccion.text = cita.address;
      _representante.text = cita.representativeName;
      _correo.text = cita.email;
      _telefono.text = cita.phone;
      _motivo.text = cita.motivo;
      _nacimiento = cita.patientBirthDate;
      _referencia.text = cita.pagoReferencia ?? '';
      _banco = normalizarBanco(cita.pagoBanco);
      _cedulaPago.text = cita.pagoCedula ?? '';
      _telefonoPago.text = cita.pagoTelefono ?? '';
      _comprobanteUrl = cita.pagoComprobanteUrl;
      if (cita.pagoMonto != null) {
        _monto.text = cita.pagoMonto!.toStringAsFixed(2);
      }
      _metodo = MetodoPago.fromRaw(cita.pagoMetodo);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _representante,
      _telefono,
      _correo,
      _paciente,
      _direccion,
      _motivo,
      _referencia,
      _cedulaPago,
      _telefonoPago,
      _monto,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargarTasa() async {
    setState(() {
      _cargandoTasa = true;
      _errorTasa = null;
    });
    try {
      final tasa = await di.sl<BcvService>().obtener();
      if (mounted) {
        setState(() => _tasa = tasa);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorTasa = e);
      }
    } finally {
      // El indicador se apaga pase lo que pase: antes esto vivia dentro del
      // `if (statusCode == 200)` y cualquier otra respuesta dejaba el spinner
      // girando para siempre.
      if (mounted) {
        setState(() => _cargandoTasa = false);
      }
    }
  }

  double get _totalBs => (_tasa?.valor ?? 0) * _config.tarifaUsd;

  // --------------------------------------------------------------- acciones

  Future<void> _elegirComprobante() async {
    try {
      final archivo = await StorageService.elegirComprobante();
      if (archivo == null) {
        return;
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _comprobante = archivo;
        _comprobanteNombre = archivo.name;
        // Se descarta la URL anterior: si el usuario cambia el archivo, la
        // cita no puede quedarse apuntando al comprobante viejo.
        _comprobanteUrl = null;
        _errorEnvio = null;
      });
    } on FormatException catch (e) {
      if (mounted) {
        mostrarAviso(context, e.message, esError: true);
      }
    } catch (e) {
      if (mounted) {
        mostrarAviso(context, 'No se pudo abrir el archivo: $e', esError: true);
      }
    }
  }

  Future<void> _avanzar() async {
    if (_paso == 1) {
      if (!_pacienteNuevo && _patientId == null) {
        mostrarAviso(context, 'Selecciona un hijo o agrega uno nuevo.',
            esError: true);
        return;
      }
      // La fecha de nacimiento ahora se valida siempre, no solo al crear un
      // paciente: antes, si el nino lo habia cargado la secretaria sin fecha,
      // este boton no hacia nada y no aparecia ningun mensaje.
      if (!_formPaciente.currentState!.validate()) {
        return;
      }
      if (_nacimiento == null) {
        mostrarAviso(
          context,
          'Falta la fecha de nacimiento del paciente. Agregala para continuar.',
          esError: true,
        );
        setState(() => _pacienteNuevo = true);
        return;
      }
      setState(() {
        _paso = 2;
        _errorEnvio = null;
      });
      return;
    }

    if (_paso == 2) {
      if (_tasa == null) {
        mostrarAviso(
            context, 'Necesitamos la tasa del dia para calcular el total.',
            esError: true);
        return;
      }
      if (_monto.text.trim().isEmpty) {
        _monto.text = _totalBs.toStringAsFixed(2);
      }
      setState(() {
        _paso = 3;
        _errorEnvio = null;
      });
      return;
    }

    await _confirmar();
  }

  /// Sube el comprobante y guarda la cita.
  ///
  /// Invariante de este metodo: pase lo que pase (red caida, CORS, reglas de
  /// Storage, Firestore que no contesta o cualquier excepcion inesperada) el
  /// indicador de carga se apaga y el motivo queda escrito en pantalla.
  ///
  /// Lo que congelaba el dialogo no eran los errores sino los `await` que no
  /// terminaban nunca: un `catch` solo corre cuando algo falla, y una promesa
  /// de Firebase que se queda esperando no falla jamas. Por eso cada espera
  /// lleva su propio `timeout` y el apagado del spinner vive en un `finally`.
  Future<void> _confirmar() async {
    // Doble clic o Enter repetido: sin esto se subia el comprobante dos veces
    // y podian entrar dos reservas del mismo horario.
    if (_guardando) {
      return;
    }

    final formulario = _formPago.currentState;
    if (formulario == null || !formulario.validate()) {
      return;
    }

    if (!_esEfectivo && _comprobante == null && (_comprobanteUrl ?? '').isEmpty) {
      mostrarAviso(context, 'Adjunta el comprobante del pago para continuar.',
          esError: true);
      return;
    }

    // Se valida aqui y no dentro del `try`: el `_nacimiento!` de mas abajo
    // reventaba con un error tecnico en vez de devolver al paso que falta.
    if (_nacimiento == null) {
      setState(() {
        _paso = 1;
        _pacienteNuevo = true;
      });
      mostrarAviso(
        context,
        'Falta la fecha de nacimiento del paciente. Agregala para continuar.',
        esError: true,
      );
      return;
    }

    setState(() {
      _guardando = true;
      _errorEnvio = null;
      _progreso = null;
      // En efectivo no hay nada que subir: se entra directo a la cita.
      _fase = _comprobante == null
          ? 'Agendando tu cita...'
          : 'Subiendo los datos del comprobante...';
    });

    var cerrado = false;
    try {
      // 1. Primero la captura, para que la cita nazca ya con su comprobante.
      final urlComprobante = await _asegurarComprobante();

      if (!mounted) {
        return;
      }
      setState(() {
        _fase = 'Agendando tu cita...';
        _progreso = null;
      });

      // 2. Se espera la confirmacion real antes de cerrar. Antes el dialogo se
      //    cerraba y el correo salia sin saber si Firestore habia guardado:
      //    el paciente podia recibir la confirmacion de una cita inexistente.
      final guardada = await widget
          .onConfirmBooking(_armarCita(urlComprobante))
          .timeout(_limiteGuardado);

      if (!mounted) {
        return;
      }
      if (guardada) {
        cerrado = true;
        Navigator.pop(context);
      } else {
        _fallo(
          'No se pudo guardar la cita. Revisa los datos e intenta de nuevo.',
        );
      }
    } on TimeoutException {
      _fallo(
        'El servidor no respondio a tiempo. Revisa tu conexion y confirma en '
        '"Mis citas" si la reserva quedo hecha antes de volver a intentarlo.',
      );
    } on ReservaFallida catch (e) {
      _fallo(e.mensaje);
    } on ArchivoDemasiadoGrande catch (e) {
      _fallo(e.toString());
    } on ArchivoVacio catch (e) {
      _fallo(e.toString());
    } on SubidaFallida catch (e) {
      _fallo(e.mensaje);
    } on FormatException catch (e) {
      _fallo(e.message);
    } on FirebaseException catch (e) {
      _fallo('${e.message ?? 'Firebase rechazo la operacion'} (${e.code})');
    } catch (e) {
      _fallo('No se pudo completar la reserva: $e');
    } finally {
      // Red de seguridad: si el dialogo sigue en pie, el spinner se apaga
      // aunque el error haya llegado por un camino que nadie previo.
      if (!cerrado && mounted) {
        setState(() {
          _guardando = false;
          _progreso = null;
          _fase = '';
        });
      }
    }
  }

  /// Sube la captura si hace falta y devuelve la URL que va a la cita.
  ///
  /// La URL se guarda en `_comprobanteUrl` en cuanto se obtiene: si despues
  /// falla Firestore, el reintento reutiliza el archivo ya subido en vez de
  /// dejar una copia huerfana en el bucket por cada intento.
  Future<String?> _asegurarComprobante() async {
    final archivo = _comprobante;
    if (archivo == null) {
      return _comprobanteUrl;
    }

    final subido = await di.sl<StorageService>().subirComprobante(
          id: _pagoId,
          archivo: archivo,
          onProgreso: (avance) {
            if (mounted) {
              setState(() => _progreso = avance);
            }
          },
        );

    _comprobante = null;
    _comprobanteUrl = subido.url;
    _comprobanteNombre = subido.nombre;
    if (mounted) {
      setState(() {});
    }
    return subido.url;
  }

  AppointmentEntity _armarCita(String? urlComprobante) {
    return AppointmentEntity(
      id: widget.appointment?.id ?? '',
      patientId: _patientId ?? '',
      representativeId: _uid ?? '',
      patientName: _paciente.text.trim(),
      patientBirthDate: _nacimiento!,
      address: _direccion.text.trim(),
      representativeName: _representante.text.trim(),
      email: _correo.text.trim(),
      phone: _telefono.text.trim(),
      appointmentDateTime: widget.appointmentDateTime,
      status: CitaStatus.pendiente,
      // El motivo se pedia y se descartaba: nunca llegaba a Firestore.
      motivo: _motivo.text.trim(),
      pagoId: _pagoId,
      pagoReferencia: _referencia.text.trim(),
      pagoMonto: double.tryParse(_monto.text.trim().replaceAll(',', '.')) ?? 0,
      pagoMontoEsperado: _totalBs,
      pagoTasaBcv: _tasa?.valor,
      pagoBanco: _banco,
      pagoMetodo: _metodo.label,
      pagoEstado: PagoStatus.pendiente,
      pagoCedula: _cedulaPago.text.trim(),
      pagoTelefono: _telefonoPago.text.trim(),
      pagoComprobanteUrl: urlComprobante,
    );
  }

  /// Apaga el indicador y deja el motivo a la vista, en el dialogo y en el
  /// SnackBar. El banner es el que de verdad se lee: el SnackBar aparece
  /// detras de la barrera modal.
  void _fallo(String mensaje) {
    if (!mounted) {
      return;
    }
    setState(() {
      _guardando = false;
      _progreso = null;
      _fase = '';
      _errorEnvio = mensaje;
    });
    mostrarAviso(context, mensaje, esError: true);
  }

  // ------------------------------------------------------------------ vista

  @override
  Widget build(BuildContext context) {
    final editando = widget.appointment?.id.isNotEmpty ?? false;
    final titulos = [
      editando ? 'Modificar cita' : 'Agendar cita pediatrica',
      'Datos para el pago',
      'Registrar el pago',
    ];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulos[_paso - 1],
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            '${DateFormat("EEEE d 'de' MMMM", 'es').format(widget.appointmentDateTime)} · ${widget.timeString}',
            style:
                const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          _Pasos(actual: _paso),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: _guardando
            ? SizedBox(height: 220, child: _indicadorDeGuardado())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (_errorEnvio != null) ...<Widget>[
                      _bannerDeError(_errorEnvio!),
                      const SizedBox(height: 14),
                    ],
                    switch (_paso) {
                      1 => _formularioPaciente(),
                      2 => _instruccionesPago(),
                      _ => _formularioPago(),
                    },
                  ],
                ),
              ),
      ),
      actions: _guardando
          ? null
          : [
              TextButton(
                onPressed: () => _paso > 1
                    ? setState(() => _paso--)
                    : Navigator.pop(context),
                child: Text(_paso == 1 ? 'Cancelar' : 'Atras',
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: _avanzar,
                child: Text(switch (_paso) {
                  1 => 'Continuar al pago',
                  2 => 'Ya pagué',
                  _ => 'Confirmar cita',
                }),
              ),
            ],
    );
  }

  /// Indicador de la reserva. Muestra en que va (comprobante o cita) y, si
  /// Storage informa el avance, el porcentaje real de la subida.
  Widget _indicadorDeGuardado() {
    final avance = _progreso;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              value: avance,
              color: AppColors.primary,
              backgroundColor: const Color(0xFFE3EAE9),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _fase.isEmpty ? 'Agendando tu cita...' : _fase,
            style:
                const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          if (avance != null) ...<Widget>[
            const SizedBox(height: 4),
            Text(
              '${(avance * 100).clamp(0, 100).toStringAsFixed(0)} %',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  /// Aviso rojo dentro del dialogo con el motivo del ultimo fallo.
  Widget _bannerDeError(String mensaje) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mensaje,
              style:
                  const TextStyle(fontSize: 12.5, color: AppColors.danger),
            ),
          ),
          IconButton(
            tooltip: 'Ocultar',
            icon: const Icon(Icons.close, size: 16, color: AppColors.danger),
            onPressed: () => setState(() => _errorEnvio = null),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- paso 1

  Widget _formularioPaciente() {
    return Form(
      key: _formPaciente,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          TextFormField(
            controller: _representante,
            decoration: const InputDecoration(
                labelText: 'Nombre del representante',
                prefixIcon: Icon(Icons.assignment_ind_outlined)),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Telefono de contacto',
                prefixIcon: Icon(Icons.phone)),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          if (_uid != null) _selectorDeHijo(), // 🚀 Corregido: sin llaves
          if (_pacienteNuevo) ...[
            const SizedBox(height: 14),
            _datosNuevoPaciente(),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _motivo,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Motivo de la consulta',
              helperText: 'Le ayuda a la doctora a preparar la consulta.',
              prefixIcon: Icon(Icons.medical_services_outlined),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectorDeHijo() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('patients')
          .where('representativeId', isEqualTo: _uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return EstadoError(error: snap.error);
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: LinearProgressIndicator(minHeight: 2),
          );
        }

        final hijos = snap.data!.docs;
        final sinHijos = hijos.isEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: hijos.any((d) => d.id == _patientId)
                        ? _patientId
                        : null,
                    decoration: InputDecoration(
                      labelText: 'Seleccionar niño o niña',
                      prefixIcon: const Icon(Icons.child_care),
                      helperText:
                          sinHijos ? 'Aun no tienes hijos registrados' : null,
                    ),
                    hint: Text(
                        sinHijos ? 'Agrega el primero' : 'Elige un paciente'),
                    items: [
                      for (final d in hijos)
                        DropdownMenuItem(
                          value: d.id,
                          child: Text(d.data()['patientName']?.toString() ??
                              'Sin nombre'),
                        ),
                    ],
                    onChanged: _pacienteNuevo
                        ? null
                        : (valor) => _tomarHijo(hijos, valor),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: _pacienteNuevo
                      ? 'Elegir uno registrado'
                      : 'Agregar otro hijo o hija',
                  icon:
                      Icon(_pacienteNuevo ? Icons.list : Icons.person_add_alt),
                  onPressed: () => setState(() {
                    _pacienteNuevo = !_pacienteNuevo;
                    if (_pacienteNuevo) {
                      _patientId = null;
                      _paciente.clear();
                      _direccion.clear();
                      _nacimiento = null;
                    }
                  }),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _tomarHijo(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> hijos, String? id) {
    if (id == null) {
      return;
    }
    QueryDocumentSnapshot<Map<String, dynamic>>? doc;
    for (final h in hijos) {
      if (h.id == id) {
        doc = h;
        break;
      }
    }
    if (doc == null) {
      return;
    }
    final d = doc.data();

    setState(() {
      _patientId = id;
      _paciente.text = d['patientName']?.toString() ?? '';
      _direccion.text = d['address']?.toString() ?? '';
      final nac = d['patientBirthDate'];
      _nacimiento = nac is Timestamp ? nac.toDate() : null;
      if ((d['representativeName'] ?? '').toString().isNotEmpty) {
        _representante.text = d['representativeName'].toString();
      }
      if ((d['email'] ?? '').toString().isNotEmpty) {
        _correo.text = d['email'].toString();
      }
      // El telefono ahora si viene guardado en la ficha del paciente.
      if ((d['phone'] ?? '').toString().isNotEmpty) {
        _telefono.text = d['phone'].toString();
      }

      // Si la ficha vino de la secretaria sin fecha de nacimiento, se abre el
      // bloque para completarla en vez de dejar el boton muerto.
      if (_nacimiento == null) {
        _pacienteNuevo = true;
      }
    });
  }

  Widget _datosNuevoPaciente() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Datos del paciente',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  fontSize: 13.5)),
          const SizedBox(height: 12),
          TextFormField(
            controller: _paciente,
            decoration: const InputDecoration(
                labelText: 'Nombre del niño o niña',
                prefixIcon: Icon(Icons.person_outline),
                isDense: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          FormField<DateTime>(
            initialValue: _nacimiento,
            // Ahora es un validador del formulario, asi que se marca en rojo
            // como cualquier otro campo en lugar de bloquear en silencio.
            validator: (_) => _nacimiento == null ? 'Requerida' : null,
            builder: (campo) => InkWell(
              onTap: () async {
                final elegida = await showDatePicker(
                  context: context,
                  initialDate: _nacimiento ??
                      DateTime.now().subtract(const Duration(days: 730)),
                  firstDate: DateTime(2005),
                  lastDate: DateTime.now(),
                );
                if (elegida != null) {
                  setState(() => _nacimiento = elegida);
                  campo.didChange(elegida);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Fecha de nacimiento',
                  prefixIcon: const Icon(Icons.cake_outlined),
                  isDense: true,
                  errorText: campo.errorText,
                ),
                child: Text(_nacimiento == null
                    ? 'Toca para elegir'
                    : DateFormat("d 'de' MMMM 'de' y", 'es')
                        .format(_nacimiento!)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _direccion,
            decoration: const InputDecoration(
                labelText: 'Direccion de habitacion',
                prefixIcon: Icon(Icons.home_outlined),
                isDense: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- paso 2

  Widget _instruccionesPago() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        DropdownButtonFormField<MetodoPago>(
          initialValue: _metodo,
          decoration: const InputDecoration(labelText: 'Metodo de pago'),
          items: [
            for (final m in MetodoPago.values)
              DropdownMenuItem(value: m, child: Text(m.label)),
          ],
          onChanged: (v) => setState(() {
            _metodo = v ?? MetodoPago.pagoMovil;
            // Al cambiar de metodo se limpia lo que ya no aplica.
            if (_esEfectivo) {
              _errorEnvio = null;
            }
          }),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                switch (_metodo) {
                  MetodoPago.pagoMovil => 'Datos para el pago movil',
                  MetodoPago.transferencia => 'Datos para la transferencia',
                  MetodoPago.efectivo => 'Pagas al llegar al consultorio',
                },
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: AppColors.primaryDark),
              ),
              const SizedBox(height: 10),
              // Los datos bancarios ya no estan escritos en el codigo: salen de
              // `configuracion/clinica` y se cambian sin volver a desplegar.
              if (_metodo == MetodoPago.pagoMovil) ...[
                _linea('Banco', _config.bancoReceptor),
                _linea('Telefono', _config.telefonoPagoMovil),
                _linea('Cedula/RIF', _config.cedulaReceptor),
              ] else if (_metodo == MetodoPago.transferencia) ...[
                _linea('Banco', _config.bancoReceptor),
                _linea('Cuenta', _config.numeroCuenta),
                _linea('RIF', _config.rif),
              ] else ...[
                const Text(
                  'Cancelas el monto en la consulta el dia de la cita. No hace '
                  'falta que adjuntes ningun comprobante ahora.',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
              const Divider(height: 24),
              _bloqueTotal(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _linea(String etiqueta, String valor) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 92,
              child: Text(etiqueta,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: SelectableText(valor,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _bloqueTotal() {
    if (_cargandoTasa) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Consultando la tasa del dia...',
                style: TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    // Ya no se muestra "TOTAL A PAGAR: 0.00 Bs." cuando la consulta falla:
    // se dice lo que paso y se ofrece reintentar.
    if (_tasa == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline,
                  size: 18, color: AppColors.danger),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _errorTasa is TasaNoDisponible
                      ? 'No pudimos obtener la tasa oficial. Intenta de nuevo en un momento.'
                      : 'Hubo un problema al calcular el total.',
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.danger),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _cargarTasa,
            icon: const Icon(Icons.refresh, size: 17),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            'Consulta: \$${_config.tarifaUsd.toStringAsFixed(2)}  ·  '
            'Tasa ${_tasa!.valor.toStringAsFixed(2)} Bs./\$',
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Text('Total: ${_totalBs.toStringAsFixed(2)} Bs.',
            style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.accentDark)),
        if (_tasa!.esRespaldo)
          Padding(
            // 🚀 Corregido: sin llaves en el if dentro de la lista
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Tasa del ${DateFormat('d/MM', 'es').format(_tasa!.fecha)}: no pudimos consultar la de hoy. '
              'Si el monto cambio, la secretaria lo ajustara al verificar.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.warning),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------- paso 3

  Widget _formularioPago() {
    if (_esEfectivo) {
      return Form(key: _formPago, child: _confirmacionEfectivo());
    }
    return Form(
      key: _formPago,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _banco,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Banco emisor',
                prefixIcon: Icon(Icons.account_balance_outlined)),
            items: [
              for (final b in kBancosVenezuela)
                DropdownMenuItem(value: b, child: Text(b)),
            ],
            onChanged: (v) => setState(() => _banco = v),
            validator: (v) =>
                v == null ? 'Selecciona el banco desde el que pagaste' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _referencia,
            keyboardType: TextInputType.number,
            maxLength: 6,
            // El teclado ya no deja escribir nada que no sean digitos, y a los
            // seis deja de aceptar. Antes entraban letras, espacios y
            // referencias de largo cualquiera, y la secretaria tenia que
            // adivinar cual era el numero al cotejar con el banco.
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: const InputDecoration(
              labelText: 'Referencia bancaria',
              helperText: 'Los ultimos 6 digitos',
              counterText: '',
            ),
            validator: (v) {
              final texto = (v ?? '').trim();
              if (texto.isEmpty) {
                return 'Ingresa la referencia';
              }
              if (texto.length != 6) {
                return 'Deben ser exactamente 6 digitos';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _cedulaPago,
            decoration: const InputDecoration(labelText: 'Cedula del Emisor'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerida' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telefonoPago,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefono del Emisor'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _monto,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Monto transferido (Bs.)',
              helperText: _tasa == null
                  ? null
                  : 'Total solicitado: ${_totalBs.toStringAsFixed(2)} Bs.',
            ),
            validator: (v) {
              final monto =
                  double.tryParse((v ?? '').trim().replaceAll(',', '.'));
              if (monto == null || monto <= 0) {
                return 'Ingresa el monto que transferiste';
              }
              // Antes se guardaba cualquier cifra sin compararla con el total.
              if (_tasa != null && monto + 0.01 < _totalBs) {
                return 'Es menor al total (${_totalBs.toStringAsFixed(2)} Bs.)';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),
          _selectorComprobante(),
        ],
      ),
    );
  }

  /// Paso 3 cuando se paga en efectivo: no hay nada que registrar, solo
  /// confirmar. El pago queda pendiente hasta que la secretaria lo cobre.
  Widget _confirmacionEfectivo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarySoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.payments_outlined,
                      color: AppColors.primaryDark, size: 20),
                  SizedBox(width: 9),
                  Text('Pago en efectivo',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark)),
                ],
              ),
              const SizedBox(height: 12),
              _linea('Paciente', _paciente.text.trim()),
              _linea('Fecha',
                  DateFormat("d 'de' MMMM", 'es').format(widget.appointmentDateTime)),
              _linea('Hora', widget.timeString),
              const Divider(height: 24),
              _bloqueTotal(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningSoft,
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: AppColors.warning.withValues(alpha: 0.45)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: AppColors.warning, size: 20),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Tu cita queda apartada y el pago se registra como pendiente. '
                  'Cancela el monto en el consultorio el dia de la consulta.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _selectorComprobante() {
    final tiene = _comprobante != null || (_comprobanteUrl ?? '').isNotEmpty;
    final nombre = _comprobanteNombre ?? _comprobante?.name;
    final esPdf = (nombre ?? _comprobanteUrl ?? '')
        .toLowerCase()
        .split('?')
        .first
        .endsWith('.pdf');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tiene ? AppColors.successSoft : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: tiene
              ? AppColors.success.withValues(alpha: 0.4)
              : AppColors.warning.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            tiene
                ? (esPdf ? Icons.picture_as_pdf : Icons.check_circle)
                : Icons.add_a_photo_outlined,
            color: tiene ? AppColors.success : AppColors.warning,
            size: 26,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tiene
                      ? 'Comprobante adjunto'
                      : 'Comprobante del pago (obligatorio)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    color: tiene ? AppColors.success : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nombre ??
                      (tiene
                          ? 'Ya cargado anteriormente'
                          : 'Imagen (JPG, PNG, WEBP) o PDF de la transferencia '
                              'o el pago movil'),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: _elegirComprobante,
            child: Text(tiene ? 'Cambiar' : 'Adjuntar'),
          ),
        ],
      ),
    );
  }
}

/// Indicador de los tres pasos del formulario.
class _Pasos extends StatelessWidget {
  const _Pasos({required this.actual});
  final int actual;

  @override
  Widget build(BuildContext context) {
    const etiquetas = ['Paciente', 'Pago', 'Comprobante'];
    return Row(
      children: [
        for (var i = 1; i <= 3; i++) ...[
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: i <= actual ? AppColors.primary : const Color(0xFFE3EAE9),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: i < actual
                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                  : Text('$i',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: i <= actual ? Colors.white : AppColors.textMuted,
                      )),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            etiquetas[i - 1],
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: i == actual ? FontWeight.bold : FontWeight.normal,
              color: i <= actual ? AppColors.primaryDark : AppColors.textMuted,
            ),
          ),
          if (i < 3)
            Expanded(
              // 🚀 Corregido: sin llaves en el if dentro de la fila
              child: Container(
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: i < actual ? AppColors.primary : const Color(0xFFE3EAE9),
              ),
            ),
        ],
      ],
    );
  }
}
