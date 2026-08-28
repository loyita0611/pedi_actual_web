// lib/core/services/storage_service.dart
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Resultado de una subida: lo que hay que guardar en Firestore.
@immutable
class ArchivoSubido {
  const ArchivoSubido({
    required this.url,
    required this.nombre,
    required this.ruta,
    required this.bytes,
    required this.contentType,
  });

  final String url;
  final String nombre;
  final String ruta;
  final int bytes;
  final String contentType;

  bool get esPdf => contentType == 'application/pdf';
}

class ArchivoDemasiadoGrande implements Exception {
  const ArchivoDemasiadoGrande(this.limiteMb);
  final int limiteMb;
  @override
  String toString() => 'El archivo supera el limite de $limiteMb MB.';
}

/// El archivo llego sin contenido. Pasa en web cuando el navegador no logra
/// leer el blob (pestana en segundo plano, archivo movido, permiso revocado):
/// `PlatformFile.length()` devuelve 0 en vez de fallar, asi que sin esta
/// comprobacion se subiria un comprobante vacio y nadie se enteraria.
class ArchivoVacio implements Exception {
  const ArchivoVacio(this.nombre);
  final String nombre;
  @override
  String toString() =>
      'No se pudo leer "$nombre" (llego vacio). Vuelve a adjuntarlo, por favor.';
}

/// Falla de Firebase Storage ya traducida a algo que un representante entienda.
///
/// `toString()` devuelve solo el mensaje: los `catch (e)` que interpolan la
/// excepcion no ensucian la pantalla con el volcado tecnico.
class SubidaFallida implements Exception {
  const SubidaFallida(this.mensaje, {this.codigo, this.causa});

  final String mensaje;

  /// Codigo original de Firebase (`unauthorized`, `retry-limit-exceeded`...)
  /// o uno propio (`timeout`, `timeout-url`, `lectura`).
  final String? codigo;
  final Object? causa;

  @override
  String toString() => mensaje;
}

/// Centraliza todo lo que toca Firebase Storage.
///
/// Regla de oro de esta clase: **ninguna operacion puede quedarse esperando
/// para siempre**. El SDK de Storage reintenta por su cuenta hasta 10 minutos
/// (`maxUploadRetryTime` por defecto) y en web un fallo de CORS o de red no
/// lanza nada durante todo ese rato, asi que la UI se queda con el spinner
/// girando. Aqui se acortan esos reintentos y ademas cada `await` lleva su
/// propio `timeout`, para que el error llegue siempre a quien lo tiene que
/// mostrar.
class StorageService {
  StorageService({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance {
    _afinarReintentos(_storage);
  }

  final FirebaseStorage _storage;

  static const int limiteRecetaMb = 10;
  static const int limiteComprobanteMb = 5;

  /// Lo que la clinica acepta como comprobante de pago.
  /// Debe coincidir con `storage.rules`: alli el comprobante solo pasa si el
  /// `contentType` es una imagen o `application/pdf`.
  static const List<String> extensionesComprobante = <String>[
    'jpg',
    'jpeg',
    'png',
    'webp',
    'pdf',
  ];

  // ------------------------------------------------------------- tiempos
  static const Duration _timeoutLectura = Duration(seconds: 20);
  static const Duration _timeoutUrl = Duration(seconds: 20);

  /// Presupuesto de subida: una base fija mas un margen por MB, con tope.
  static const Duration _subidaBase = Duration(seconds: 30);
  static const Duration _subidaPorMb = Duration(seconds: 20);
  static const Duration _subidaMaxima = Duration(minutes: 3);

  static Duration _limiteDeSubida(int bytes) {
    final mb = (bytes / (1024 * 1024)).ceil();
    final calculado = _subidaBase + (_subidaPorMb * mb);
    return calculado > _subidaMaxima ? _subidaMaxima : calculado;
  }

  /// Instancias ya configuradas (`FirebaseStorage` compara por app y bucket).
  static final Set<FirebaseStorage> _afinadas = <FirebaseStorage>{};

  static void _afinarReintentos(FirebaseStorage storage) {
    if (!_afinadas.add(storage)) {
      return;
    }
    try {
      storage.setMaxUploadRetryTime(const Duration(seconds: 90));
      storage.setMaxOperationRetryTime(const Duration(seconds: 25));
      storage.setMaxDownloadRetryTime(const Duration(seconds: 45));
    } catch (e) {
      // Un mock en tests puede no implementarlos; no es motivo para tumbar nada.
      debugPrint('StorageService: no se pudieron ajustar los reintentos ($e)');
    }
  }

  /// Extrae la extension del nombre del archivo de forma segura.
  static String _extension(String nombre) {
    if (!nombre.contains('.')) {
      return '';
    }
    return nombre.split('.').last.toLowerCase().trim();
  }

  // ---------------------------------------------------------------- recetas

  /// Abre el selector restringido a PDF. Devuelve null si el usuario cancela.
  static Future<PlatformFile?> elegirPdf() async {
    final archivos = await FilePicker.pickFiles(
      dialogTitle: 'Seleccione la receta en PDF',
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
    );

    if (archivos.isEmpty) {
      return null;
    }
    final archivo = archivos.first;

    if (_extension(archivo.name) != 'pdf') {
      throw const FormatException('Solo se aceptan archivos PDF.');
    }
    return archivo;
  }

  /// Sube la receta a `recetas/{patientId}/{archivo}.pdf`.
  Future<ArchivoSubido> subirReceta({
    required String patientId,
    required PlatformFile archivo,
    void Function(double progreso)? onProgreso,
  }) async {
    final datos = await _leerBytes(archivo, limiteMb: limiteRecetaMb);

    final nombreLimpio =
        _nombreSeguro(archivo.name, extensionPorDefecto: 'pdf');
    final marca = DateTime.now().millisecondsSinceEpoch;

    return _subir(
      ruta: 'recetas/$patientId/${marca}_$nombreLimpio',
      datos: datos,
      contentType: 'application/pdf',
      nombreOriginal: archivo.name,
      contentDisposition: 'attachment; filename="$nombreLimpio"',
      onProgreso: onProgreso,
    );
  }

  // ----------------------------------------------------------- comprobantes

  /// Abre el selector del comprobante: imagen o PDF.
  ///
  /// El filtro del navegador es solo una sugerencia (en web siempre se puede
  /// elegir "todos los archivos"), asi que la extension se vuelve a verificar
  /// aqui y el tipo real se confirma por la firma del archivo antes de subirlo.
  static Future<PlatformFile?> elegirComprobante() async {
    final archivos = await FilePicker.pickFiles(
      dialogTitle: 'Seleccione el comprobante del pago',
      type: FileType.custom,
      allowedExtensions: extensionesComprobante,
    );

    if (archivos.isEmpty) {
      return null;
    }
    final archivo = archivos.first;

    if (!extensionesComprobante.contains(_extension(archivo.name))) {
      throw const FormatException(
        'Solo se aceptan imagenes JPG, PNG, WEBP o archivos PDF.',
      );
    }
    return archivo;
  }

  /// Sube el comprobante a `comprobantes/{id}.{ext}`.
  ///
  /// El nombre del archivo es el id del pago porque las reglas de Storage
  /// resuelven el permiso de lectura a partir de el.
  Future<ArchivoSubido> subirComprobante({
    required String id,
    required PlatformFile archivo,
    void Function(double progreso)? onProgreso,
  }) async {
    final datos = await _leerBytes(archivo, limiteMb: limiteComprobanteMb);

    final contentType = _tipoDeComprobante(archivo.name, datos);
    if (contentType == null) {
      throw const FormatException(
        'Ese archivo no parece una imagen ni un PDF. Adjunta la captura en '
        'JPG, PNG, WEBP o el recibo en PDF.',
      );
    }

    return _subir(
      ruta: 'comprobantes/$id.${_extensionDe(contentType)}',
      datos: datos,
      contentType: contentType,
      nombreOriginal: archivo.name,
      onProgreso: onProgreso,
    );
  }

  // -------------------------------------------------------------- interno

  /// Lee el archivo a memoria con tope de tiempo y valida su tamano real.
  static Future<Uint8List> _leerBytes(
    PlatformFile archivo, {
    required int limiteMb,
  }) async {
    // El limite es el mismo de `storage.rules`, que compara con `<`: si se
    // dejara pasar el valor exacto, el bucket rechazaria el archivo despues de
    // haberlo subido entero.
    final limiteBytes = limiteMb * 1024 * 1024;

    // El tamano declarado solo sirve para cortar temprano: en web `length()`
    // devuelve 0 cuando el navegador no logra medir el blob.
    final declarado = await archivo
        .length()
        .timeout(_timeoutLectura, onTimeout: () => 0)
        .catchError((Object _) => 0);
    if (declarado >= limiteBytes) {
      throw ArchivoDemasiadoGrande(limiteMb);
    }

    Uint8List datos;
    try {
      datos = await archivo.readAsBytes().timeout(_timeoutLectura);
    } on TimeoutException {
      throw SubidaFallida(
        'El navegador tardo demasiado en leer "${archivo.name}". '
        'Vuelve a adjuntarlo, por favor.',
        codigo: 'lectura',
      );
    } catch (e) {
      throw SubidaFallida(
        'No se pudo leer "${archivo.name}". Vuelve a adjuntarlo, por favor.',
        codigo: 'lectura',
        causa: e,
      );
    }

    if (datos.isEmpty) {
      throw ArchivoVacio(archivo.name);
    }
    if (datos.length >= limiteBytes) {
      throw ArchivoDemasiadoGrande(limiteMb);
    }
    return datos;
  }

  /// Sube los bytes y devuelve la URL. Nunca se queda esperando.
  Future<ArchivoSubido> _subir({
    required String ruta,
    required Uint8List datos,
    required String contentType,
    required String nombreOriginal,
    String? contentDisposition,
    void Function(double progreso)? onProgreso,
  }) async {
    final ref = _storage.ref().child(ruta);

    final UploadTask tarea;
    try {
      tarea = ref.putData(
        datos,
        SettableMetadata(
          contentType: contentType,
          contentDisposition: contentDisposition,
          customMetadata: <String, String>{'nombreOriginal': nombreOriginal},
        ),
      );
    } on FirebaseException catch (e) {
      throw _traducir(e, nombreOriginal);
    } catch (e) {
      throw SubidaFallida(
        'No se pudo iniciar la subida de "$nombreOriginal": $e',
        causa: e,
      );
    }

    // Si el timeout gana la carrera, la tarea seguira viva un rato y terminara
    // lanzando su error sin nadie que lo escuche. Este oyente vacio evita el
    // "Unhandled Exception" en la consola del navegador.
    unawaited(tarea.then<void>((_) {}, onError: (Object _, StackTrace __) {}));

    StreamSubscription<TaskSnapshot>? progreso;
    if (onProgreso != null) {
      progreso = tarea.snapshotEvents.listen(
        (s) {
          if (s.totalBytes > 0) {
            onProgreso(s.bytesTransferred / s.totalBytes);
          }
        },
        onError: (Object _) {
          // El error real se maneja en el `await` de abajo.
        },
      );
    }

    try {
      await tarea.timeout(_limiteDeSubida(datos.length));
    } on TimeoutException {
      unawaited(tarea.cancel().catchError((Object _) => false));
      throw SubidaFallida(
        'La subida de "$nombreOriginal" tardo demasiado. Revisa tu conexion e '
        'intenta de nuevo.',
        codigo: 'timeout',
      );
    } on FirebaseException catch (e) {
      throw _traducir(e, nombreOriginal);
    } catch (e) {
      throw SubidaFallida(
        'No se pudo subir "$nombreOriginal": $e',
        causa: e,
      );
    } finally {
      await progreso?.cancel();
    }

    // Sin URL el archivo no le sirve a nadie: si falla, se borra lo subido para
    // no dejar basura huerfana en el bucket.
    try {
      final url = await ref.getDownloadURL().timeout(_timeoutUrl);
      return ArchivoSubido(
        url: url,
        nombre: nombreOriginal,
        ruta: ruta,
        bytes: datos.length,
        contentType: contentType,
      );
    } on TimeoutException {
      await borrar(ruta: ruta);
      throw const SubidaFallida(
        'El archivo se subio pero el servidor no devolvio su enlace. '
        'Intenta de nuevo.',
        codigo: 'timeout-url',
      );
    } on FirebaseException catch (e) {
      await borrar(ruta: ruta);
      throw _traducir(e, nombreOriginal);
    }
  }

  /// Traduce el codigo de Firebase a una frase accionable.
  static SubidaFallida _traducir(FirebaseException e, String nombre) {
    final mensaje = switch (e.code) {
      'unauthorized' =>
        'Firebase Storage rechazo "$nombre". Revisa que el tipo y el tamano '
            'esten permitidos en las reglas del bucket.',
      'unauthenticated' =>
        'Tu sesion expiro. Vuelve a iniciar sesion e intenta de nuevo.',
      'canceled' => 'La subida de "$nombre" se cancelo.',
      'retry-limit-exceeded' =>
        'La conexion no aguanto la subida de "$nombre". Intenta de nuevo con '
            'mejor senal.',
      'quota-exceeded' =>
        'El almacenamiento de la clinica llego a su limite. Avisa a la '
            'administracion.',
      'object-not-found' => 'El archivo ya no esta disponible en el servidor.',
      'invalid-checksum' =>
        'El archivo se dano durante la subida. Vuelve a intentarlo.',
      'unknown' =>
        'No se pudo contactar a Firebase Storage. Suele ser un bloqueo de CORS '
            'o de red desde el navegador.',
      _ => 'Firebase Storage devolvio "${e.code}": ${e.message ?? 'sin detalle'}',
    };
    return SubidaFallida(mensaje, codigo: e.code, causa: e);
  }

  /// Tipo MIME del comprobante: primero por extension y, si no alcanza, por la
  /// firma de los primeros bytes (en web el nombre puede llegar sin extension).
  static String? _tipoDeComprobante(String nombre, Uint8List datos) {
    final porNombre = switch (_extension(nombre)) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'jpg' || 'jpeg' => 'image/jpeg',
      'pdf' => 'application/pdf',
      _ => null,
    };
    return porNombre ?? _tipoPorFirma(datos);
  }

  static String? _tipoPorFirma(Uint8List d) {
    if (d.length < 12) {
      return null;
    }
    if (d[0] == 0x25 && d[1] == 0x50 && d[2] == 0x44 && d[3] == 0x46) {
      return 'application/pdf'; // %PDF
    }
    if (d[0] == 0x89 && d[1] == 0x50 && d[2] == 0x4E && d[3] == 0x47) {
      return 'image/png';
    }
    if (d[0] == 0xFF && d[1] == 0xD8 && d[2] == 0xFF) {
      return 'image/jpeg';
    }
    final esRiff = d[0] == 0x52 && d[1] == 0x49 && d[2] == 0x46 && d[3] == 0x46;
    final esWebp =
        d[8] == 0x57 && d[9] == 0x45 && d[10] == 0x42 && d[11] == 0x50;
    if (esRiff && esWebp) {
      return 'image/webp';
    }
    return null;
  }

  static String _extensionDe(String contentType) => switch (contentType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'application/pdf' => 'pdf',
        _ => 'jpg',
      };

  // ----------------------------------------------------------------- borrar

  /// Borra por ruta si la conocemos, y si no cae de vuelta a la URL.
  ///
  /// Se usa tambien para limpiar despues de un fallo, asi que no propaga el
  /// error: no tendria sentido tapar la causa real con el fallo de la limpieza.
  Future<void> borrar({String? ruta, String? url}) async {
    try {
      if (ruta != null && ruta.isNotEmpty) {
        await _storage.ref().child(ruta).delete().timeout(_timeoutUrl);
      } else if (url != null && url.isNotEmpty) {
        await _storage.refFromURL(url).delete().timeout(_timeoutUrl);
      }
    } on FirebaseException catch (e) {
      if (e.code != 'object-not-found') {
        debugPrint('StorageService: no se pudo borrar ($ruta / $url): ${e.code}');
      }
    } catch (e) {
      debugPrint('StorageService: no se pudo borrar ($ruta / $url): $e');
    }
  }

  static String _nombreSeguro(String nombre,
      {required String extensionPorDefecto}) {
    var limpio = nombre.trim().replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (limpio.isEmpty) {
      limpio = 'archivo.$extensionPorDefecto';
    }
    if (!limpio.toLowerCase().endsWith('.$extensionPorDefecto')) {
      limpio = '$limpio.$extensionPorDefecto';
    }
    return limpio.length <= 120
        ? limpio
        : limpio.substring(limpio.length - 120);
  }

  static String tamanoLegible(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
