# PediActual — puesta en marcha de esta version

## 1. Dependencias

```bash
flutter pub add file_picker:^12.0.0
flutter pub add firebase_storage:^13.4.6
flutter pub add url_launcher:^6.3.1
flutter pub add flutter_typeahead:^6.0.0
flutter pub add intl:^0.20.2
flutter pub get
```

Ya estan declaradas en `pubspec.yaml` con esas versiones, asi que basta con:

```bash
flutter pub get
```

Nota sobre `image_picker`: no hace falta. `file_picker` ya cubre imagenes y PDF
en web y en movil, devuelve los bytes directamente (que es lo que necesita
`putData` de Firebase Storage) y evita una segunda dependencia que en Flutter
Web se comporta distinto. La captura del pago usa
`FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['jpg','jpeg','png','webp'])`.

Se quitaron los `any` de `firebase_storage` y `flutter_typeahead`: un cambio
incompatible en cualquiera de las dos rompia la compilacion sin haber tocado el
codigo.

## 2. Reglas e indices de Firebase

Sin este paso la app queda abierta: cualquier usuario autenticado podria leer
las historias y los pagos de todos los pacientes.

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

Los indices tardan unos minutos en construirse. Mientras tanto la app no falla
en silencio: las pantallas muestran el error real y el mensaje explica que
falta desplegarlos.

## 3. Rol de la secretaria (Custom Claims)

El rol se lee primero del custom claim y solo despues del documento de usuario.
Mientras no configures los claims sigue funcionando por el documento, pero la
forma segura es esta (una sola vez, desde Node con el Admin SDK):

```js
const admin = require('firebase-admin');
admin.initializeApp();
const uid = 'UID_DE_LA_SECRETARIA';
admin.auth().setCustomUserClaims(uid, { role: 'secretary' })
  .then(() => console.log('listo — que cierre y vuelva a iniciar sesion'));
```

Para la doctora, `role: 'doctor'`.

## 4. Configuracion de la clinica (opcional pero recomendado)

Crea el documento `configuracion/clinica` en Firestore. Si no existe se usa el
valor por defecto y nada se rompe.

```json
{
  "horaInicio": 8,
  "horaFin": 17,
  "minutosPorCita": 30,
  "diasHabiles": [1, 2, 3, 4, 5],
  "almuerzoInicio": 12,
  "almuerzoFin": 13,
  "tarifaUsd": 40,
  "bancoReceptor": "Banco Nacional de Credito (BNC)",
  "telefonoPagoMovil": "0412-5555555",
  "cedulaReceptor": "V-12.345.678",
  "numeroCuenta": "0191-0000-0000-0000-0000",
  "rif": "J-55555555-0",
  "telefonoClinica": "+58 412-5555555",
  "direccion": "Av. Los Leones, Centro Profesional PediaActual, Piso 2. Barquisimeto.",
  "feriados": []
}
```

## 5. Compilar y probar

```bash
flutter analyze
flutter test
flutter run -d chrome
```

## 6. Limpieza pendiente

La carpeta `_to_delete/` tiene tres archivos que quedaron sin uso
(`status_chip.dart`, `settings_panel_widget.dart` y el `register_page.dart`
viejo, que vivia por error dentro de `features/schedule/`). Puedes borrarla:

```bash
rm -rf _to_delete
```

Si `git` se queja de `.git/index.lock`, borra ese archivo antes de hacer commit:

```bash
rm -f .git/index.lock
```
