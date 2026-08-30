// functions/configurar-correo.js
//
// Asistente para dejar listo el envio de correos de PediActual.
//
//   node functions/configurar-correo.js
//
// Pregunta los datos por separado, arma la cadena de conexion, comprueba que el
// servidor la acepte y la guarda como secreto en Firebase.
//
// Por que existe: armar la cadena a mano es la parte que mas falla. Lleva dos
// arrobas con significados distintos y la del correo hay que escribirla como
// %40; si se escribe tal cual, el usuario queda partido y el servidor rechaza
// la conexion con un mensaje que no explica nada. Aqui la cadena la arma el
// programa, se comprueba antes de guardarla, y nunca se dibuja en pantalla ni
// queda en el historial de la terminal.

const readline = require('readline');
const dns = require('dns').promises;
const {spawn} = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');
const nodemailer = require('nodemailer');

const PROYECTO = 'pediactual-ee23b';
const SECRETO = 'SMTP_URI';

// ------------------------------------------------------------------ consola

// Una sola interfaz para toda la sesion. Con una por pregunta, al cerrar la
// primera se perdia lo que quedaba en el buffer de entrada.
const rl = readline.createInterface({input: process.stdin, output: process.stdout});

function preguntar(texto) {
  return new Promise((resolve) => {
    rl.question(texto, (valor) => resolve(valor.trim()));
  });
}

/// Igual que preguntar, pero dibujando asteriscos: la clave no queda a la vista
/// de quien mire la pantalla ni en el historial de la terminal.
function preguntarOculto(texto) {
  return new Promise((resolve) => {
    const normal = rl._writeToOutput;
    process.stdout.write(texto);
    rl._writeToOutput = (s) => {
      if (s.includes('\n') || s.includes('\r')) {
        return rl.output.write('\n');
      }
      rl.output.write('*');
    };
    rl.question('', (valor) => {
      rl._writeToOutput = normal;
      resolve(valor.trim());
    });
  });
}

const log = (t = '') => console.log(t);

// ------------------------------------------------------------------ firebase

/// El CLI puede estar en el PATH o en la carpeta del usuario.
function rutaFirebase() {
  const candidata = path.join(os.homedir(), '.npm-global', 'bin', 'firebase');
  return fs.existsSync(candidata) ? candidata : 'firebase';
}

/// Guarda el secreto pasandolo por la entrada estandar del CLI, para que la
/// cadena no aparezca como argumento del comando (donde quedaria visible en el
/// listado de procesos y en el historial).
function guardarSecreto(uri) {
  return new Promise((resolve) => {
    const hijo = spawn(
        rutaFirebase(),
        ['functions:secrets:set', SECRETO, '--data-file', '-', '--project', PROYECTO],
        {stdio: ['pipe', 'inherit', 'inherit']});

    hijo.on('error', (e) => {
      log(`\n  No se pudo ejecutar firebase: ${e.message}`);
      resolve(false);
    });
    hijo.on('close', (codigo) => resolve(codigo === 0));

    hijo.stdin.write(uri);
    hijo.stdin.end();
  });
}

// --------------------------------------------------------------------- flujo

async function pedirDatos() {
  log('  Donde esta la cuenta de correo de la consulta?');
  log('    1) Gmail  (lo mas comun)');
  log('    2) Otro servidor SMTP\n');

  const opcion = await preguntar('  Elige 1 o 2: ');

  if (opcion === '2') {
    const servidor = await preguntar('\n  Servidor SMTP (ej. smtp.brevo.com): ');
    const puerto = await preguntar('  Puerto (465 para seguro, 587 para TLS): ');
    const usuario = await preguntar('  Usuario: ');
    const clave = await preguntarOculto('  Clave (no se vera): ');
    return {
      servidor,
      puerto: puerto || '465',
      usuario,
      clave,
      seguro: (puerto || '465') === '465',
    };
  }

  log('\n  Necesitas una "contrasena de aplicacion" de Google, no la clave');
  log('  normal de la cuenta. Se genera en:');
  log('    https://myaccount.google.com/apppasswords');
  log('  (la cuenta debe tener la verificacion en dos pasos activada)\n');

  const usuario = await preguntar('  Correo de Gmail de la consulta: ');
  const clave = await preguntarOculto('  Contrasena de aplicacion, 16 letras (no se vera): ');

  // Google la muestra en cuatro grupos de cuatro letras minusculas.
  const limpia = clave.replace(/\s+/g, '');
  if (!/^[a-z]{16}$/.test(limpia)) {
    log('');
    log('  Aviso: una contrasena de aplicacion de Google son exactamente');
    log(`  16 letras minusculas, y la que escribiste tiene ${limpia.length} caracteres`);
    log('  con otro formato. Puede que sea la clave normal de la cuenta.');
    log('  Se intenta igual, pero si falla revisa esto primero.');
  }

  return {
    servidor: 'smtp.gmail.com',
    puerto: '465',
    usuario,
    clave: limpia,
    seguro: true,
  };
}

/// Comprueba que la direccion pueda existir de verdad antes de intentar
/// conectarse. Se agrego despues de perder un rato con una direccion de un
/// dominio que no estaba registrado: Gmail respondia "usuario o clave
/// incorrectos", que apunta al lugar equivocado.
async function revisarDominio(usuario) {
  const dominio = (usuario.split('@')[1] || '').toLowerCase();
  if (!dominio) {
    return {ok: false, motivo: 'La direccion no tiene dominio despues de la arroba.'};
  }
  if (dominio === 'gmail.com' || dominio === 'googlemail.com') {
    return {ok: true};
  }

  let registros;
  try {
    registros = await dns.resolveMx(dominio);
  } catch (e) {
    if (e.code === 'ENOTFOUND' || e.code === 'ENODATA') {
      return {
        ok: false,
        motivo: `El dominio "${dominio}" no existe o no tiene correo configurado.\n` +
          '  No hay ningun buzon en esa direccion, asi que ningun servidor la va\n' +
          '  a aceptar. Usa una direccion que ya funcione.',
      };
    }
    return {ok: true}; // Fallo la consulta DNS: no se bloquea por eso.
  }

  const enGoogle = registros.some((r) => /google(mail)?\.com\.?$/i.test(r.exchange));
  if (!enGoogle) {
    const cual = registros.map((r) => r.exchange).slice(0, 2).join(', ');
    return {
      ok: false,
      motivo: `El correo de "${dominio}" no lo maneja Google sino: ${cual}\n` +
        '  Elige la opcion 2 y usa los datos SMTP de ese proveedor.',
    };
  }
  return {ok: true};
}

function armarUri({servidor, puerto, usuario, clave, seguro}) {
  // La codificacion es justamente lo que se hacia mal a mano: la arroba del
  // correo tiene que viajar como %40 para no partir la direccion.
  const u = encodeURIComponent(usuario);
  const c = encodeURIComponent(clave);
  return `${seguro ? 'smtps' : 'smtp'}://${u}:${c}@${servidor}:${puerto}`;
}

function explicarError(error, datos) {
  const mensaje = error.message || '';

  // La respuesta cruda del servidor suele ser mas concreta que el mensaje de
  // la libreria, asi que se muestra tal cual antes de interpretarla.
  if (error.response) {
    log(`  Respuesta del servidor: ${String(error.response).trim()}`);
    log('');
  }

  if (/invalid login|username and password not accepted|535|BadCredentials/i.test(mensaje + (error.response || ''))) {
    log('  Gmail rechazo el usuario o la clave. Por orden de frecuencia:');
    log('');
    log('   1. La contrasena de aplicacion se genero en OTRA cuenta de Google');
    log(`      distinta de ${datos.usuario}. Es el motivo mas comun: hay que`);
    log('      generarla estando dentro de esa misma cuenta.');
    log('');
    log('   2. Se pego la clave normal de Gmail en vez de la de aplicacion.');
    log('      La de aplicacion son 16 letras minusculas, sin numeros ni signos.');
    log('');
    log('   3. Se copio de mas: solo van las 16 letras, no el nombre que le');
    log('      pusiste ni ningun texto alrededor.');
    log('');
    log('   4. La cuenta es de Google Workspace y el administrador tiene');
    log('      bloqueado el acceso por SMTP.');
    log('');
    log('  Nota: esto NO depende de Firebase ni de tus permisos en el proyecto.');
    log('  La conexion va de tu computadora a Gmail, sin pasar por Firebase.');
  } else if (/ENOTFOUND|EAI_AGAIN/i.test(mensaje)) {
    log('  No se encontro el servidor. Revisa que el nombre este bien escrito.');
  } else if (/ETIMEDOUT|ECONNREFUSED/i.test(mensaje)) {
    log('  El servidor no respondio. Puede ser el puerto: prueba 465 o 587.');
  }
}

async function principal() {
  log('\n  Configuracion del correo de PediActual');
  log('  ======================================\n');

  const datos = await pedirDatos();

  if (!datos.usuario || !datos.clave || !datos.servidor) {
    log('\n  Faltan datos. Vuelve a ejecutarlo cuando los tengas a mano.\n');
    process.exit(1);
  }

  // Solo tiene sentido revisar el dominio cuando se dijo que era Gmail.
  if (datos.servidor === 'smtp.gmail.com') {
    const revision = await revisarDominio(datos.usuario);
    if (!revision.ok) {
      log(`\n  ${revision.motivo}\n`);
      process.exit(1);
    }
  }

  const uri = armarUri(datos);

  log(`\n  Probando ${datos.usuario} contra ${datos.servidor}:${datos.puerto}...\n`);

  try {
    await nodemailer.createTransport(uri).verify();
    log('  El servidor acepta las credenciales.\n');
  } catch (e) {
    log(`  El servidor las rechazo: ${e.message}\n`);
    explicarError(e, datos);
    log('');
    process.exit(1);
  }

  const destino = await preguntar('  Correo donde recibir una prueba (Enter para saltar): ');
  if (destino) {
    try {
      await nodemailer.createTransport(uri).sendMail({
        from: `"PediActual" <${datos.usuario}>`,
        to: destino,
        subject: 'Prueba de correo de PediActual',
        html: '<p>Si estas leyendo esto, el correo de PediActual quedo configurado.</p>',
      });
      log(`\n  Enviado a ${destino}. Revisa la bandeja y tambien el spam.\n`);
    } catch (e) {
      log(`\n  Conecto pero no pudo enviar: ${e.message}\n`);
      process.exit(1);
    }
  }

  const guardar = await preguntar(`\n  Guardar como secreto ${SECRETO} en Firebase? (s/n): `);
  if (guardar.toLowerCase() !== 's') {
    log('\n  No se guardo nada. Cuando quieras, vuelve a ejecutar este asistente.\n');
    return;
  }

  log('');
  const ok = await guardarSecreto(uri);
  if (!ok) {
    log('\n  No se pudo guardar el secreto. Revisa el mensaje de arriba.\n');
    process.exit(1);
  }

  log('\n  Listo. El correo queda configurado en el servidor.');
  log('  El ultimo paso es desplegar las funciones:');
  log('    firebase deploy --only functions\n');
}

// Solo arranca el asistente si se ejecuta directamente. Al importarlo desde
// una prueba se exponen las piezas puras sin lanzar el dialogo.
if (require.main === module) {
  principal()
      .then(() => rl.close())
      .catch((e) => {
        rl.close();
        log(`\n  Error inesperado: ${e.message}\n`);
        process.exit(1);
      });
} else {
  rl.close();
}

module.exports = {armarUri, explicarError, revisarDominio};
