// functions/index.js
//
// Correos transaccionales de PediActual.
//
// Por que vive aqui y no en la aplicacion: antes el envio se hacia desde el
// navegador con EmailJS, y eso obligaba a llevar las credenciales dentro del
// paquete web. Cualquiera podia leerlas con las herramientas del navegador y
// mandar correos a nombre de la clinica. Aqui las credenciales viven en el
// servidor y nunca salen de el.
//
// Ademas los correos ya no se disparan desde un boton sino desde el cambio en
// la base de datos. Eso cierra un fallo viejo de raiz: era posible que saliera
// la confirmacion de una cita que no habia llegado a guardarse.

const {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentWritten,
} = require('firebase-functions/v2/firestore');
const {onSchedule} = require('firebase-functions/v2/scheduler');
const {onCall, onRequest, HttpsError} = require('firebase-functions/v2/https');
const {defineSecret} = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const {initializeApp} = require('firebase-admin/app');
const {getFirestore} = require('firebase-admin/firestore');
const nodemailer = require('nodemailer');
const crypto = require('crypto');
const {ZONA, partesEnZona, claveFecha, claveHora, rangoDelDia} = require('./zona');

initializeApp();
const db = getFirestore();

/// Cadena de conexion completa al servidor de correo, por ejemplo:
///   smtps://consulta%40gmail.com:clave-de-aplicacion@smtp.gmail.com:465
/// Se guarda con:  firebase functions:secrets:set SMTP_URI
const SMTP_URI = defineSecret('SMTP_URI');

// Se reutiliza entre invocaciones para no renegociar la conexion cada vez.
let transporte;

function obtenerTransporte() {
  if (!transporte) {
    transporte = nodemailer.createTransport(SMTP_URI.value());
  }
  return transporte;
}

// ---------------------------------------------------------------- utilidades

/// Datos de la clinica. Salen de Firestore para que se cambien sin volver a
/// desplegar, igual que en la aplicacion.
async function datosClinica() {
  const porDefecto = {
    nombre: 'PediActual',
    telefonoClinica: '',
    direccion: '',
  };
  try {
    const doc = await db.collection('configuracion').doc('clinica').get();
    return doc.exists ? {...porDefecto, ...doc.data()} : porDefecto;
  } catch (e) {
    logger.warn('No se pudo leer la configuracion de la clinica', e);
    return porDefecto;
  }
}

/// Respeta el interruptor de Ajustes. Si el representante apago los avisos, no
/// se le escribe. Ante la duda se envia: es peor perder una confirmacion.
async function quiereRecibirCorreos(representativeId) {
  if (!representativeId) {
    return true;
  }
  try {
    const doc = await db.collection('users').doc(representativeId).get();
    if (!doc.exists) {
      return true;
    }
    return doc.data().notificationsEnabled !== false;
  } catch (e) {
    logger.warn('No se pudo leer la preferencia de avisos', e);
    return true;
  }
}

function formatearFecha(valor) {
  if (!valor) {
    return '';
  }
  const fecha = typeof valor.toDate === 'function' ? valor.toDate() : new Date(valor);
  if (Number.isNaN(fecha.getTime())) {
    return '';
  }
  return new Intl.DateTimeFormat('es-VE', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
    timeZone: 'America/Caracas',
  }).format(fecha);
}

function formatearHora(valor) {
  if (!valor) {
    return '';
  }
  const fecha = typeof valor.toDate === 'function' ? valor.toDate() : new Date(valor);
  if (Number.isNaN(fecha.getTime())) {
    return '';
  }
  return new Intl.DateTimeFormat('es-VE', {
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone: 'America/Caracas',
  }).format(fecha);
}

function escapar(texto) {
  return String(texto ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
}

/// Plantilla comun. El color y la tipografia siguen la identidad de la app.
function armarHtml({titulo, saludo, mensaje, filas, aviso, clinica, acciones}) {
  const lineas = (filas || [])
      .filter((f) => f && f.valor)
      .map((f) => `
        <tr>
          <td style="padding:7px 0;color:#5B6B6E;font-size:14px;width:150px;">${escapar(f.etiqueta)}</td>
          <td style="padding:7px 0;color:#17262A;font-size:15px;font-weight:600;">${escapar(f.valor)}</td>
        </tr>`)
      .join('');

  const bloqueAviso = aviso ? `
      <div style="margin-top:22px;padding:14px 16px;background:#FBF1DC;border-radius:8px;
                  border:1px solid rgba(176,122,30,.35);color:#17262A;font-size:14px;line-height:1.5;">
        ${escapar(aviso)}
      </div>` : '';

  const botones = (acciones || []).length === 0 ? '' : `
      <div style="margin-top:24px;">
        ${acciones.map((a) => `
          <a href="${a.url}" style="display:inline-block;margin:0 8px 10px 0;padding:12px 22px;
             border-radius:8px;text-decoration:none;font-weight:600;font-size:15px;
             ${a.principal ?
               'background:#4594A4;color:#FFFFFF;' :
               'background:#FFFFFF;color:#4A5C60;border:1px solid #DCE6E4;'}">
            ${escapar(a.texto)}
          </a>`).join('')}
      </div>`;

  const pie = [clinica.telefonoClinica, clinica.direccion]
      .filter(Boolean)
      .map((t) => escapar(t))
      .join(' &middot; ');

  return `<!doctype html>
<html lang="es">
<body style="margin:0;padding:24px;background:#F4F7F6;
             font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">
  <div style="max-width:560px;margin:0 auto;background:#FFFFFF;border-radius:12px;
              border:1px solid #E1E8E7;overflow:hidden;">
    <div style="background:#4594A4;padding:20px 26px;">
      <span style="color:#FFFFFF;font-size:22px;font-weight:300;">pedi</span><span
            style="color:#EAA171;font-size:22px;font-weight:700;">actual</span>
    </div>
    <div style="padding:26px;">
      <h1 style="margin:0 0 6px;font-size:20px;color:#17262A;">${escapar(titulo)}</h1>
      <p style="margin:0 0 18px;font-size:15px;color:#4A5C60;line-height:1.55;">
        ${escapar(saludo)} ${escapar(mensaje)}
      </p>
      <table style="width:100%;border-collapse:collapse;border-top:1px solid #E1E8E7;
                    padding-top:8px;">${lineas}</table>
      ${botones}
      ${bloqueAviso}
    </div>
    <div style="padding:16px 26px;background:#F4F7F6;border-top:1px solid #E1E8E7;
                color:#7B8D90;font-size:12.5px;line-height:1.5;">
      ${pie || escapar(clinica.nombre || 'PediActual')}
      <br>Este es un mensaje automatico, no hace falta responderlo.
    </div>
  </div>
</body>
</html>`;
}

/// Direccion del remitente, sacada del usuario de la cadena SMTP.
/// La mayoria de los proveedores rechazan un "from" que no sea la cuenta
/// autenticada, asi que se toma de ahi en vez de dejarla escrita a mano.
function correoRemitente() {
  try {
    const url = new URL(SMTP_URI.value());
    return decodeURIComponent(url.username);
  } catch (e) {
    logger.error('La cadena SMTP_URI no es una URL valida', e);
    return '';
  }
}

async function enviar({para, asunto, html, clinica}) {
  if (!para) {
    logger.info('Sin destinatario, no se envia.');
    return;
  }

  const cuenta = correoRemitente();
  if (!cuenta) {
    logger.error('Sin remitente utilizable: revisa el secreto SMTP_URI.');
    return;
  }

  const nombre = (clinica && clinica.nombre) || 'PediActual';
  await obtenerTransporte().sendMail({
    from: `"${nombre}" <${cuenta}>`,
    to: para,
    subject: asunto,
    html,
  });
  logger.info('Correo enviado', {para, asunto});
}

// ------------------------------------------------------------------- citas

/// Cita nueva: sale la confirmacion.
exports.citaCreada = onDocumentCreated(
    {document: 'citas/{citaId}', secrets: [SMTP_URI]},
    async (event) => {
      const cita = event.data?.data();
      if (!cita || !cita.email) {
        return;
      }
      if (!await quiereRecibirCorreos(cita.representativeId)) {
        return;
      }

      const clinica = await datosClinica();
      const html = armarHtml({
        clinica,
        titulo: 'Tu cita quedo agendada',
        saludo: `Hola ${cita.representativeName || ''},`.trim(),
        mensaje: 'confirmamos la cita pediatrica con los siguientes datos.',
        filas: [
          {etiqueta: 'Paciente', valor: cita.patientName},
          {etiqueta: 'Fecha', valor: formatearFecha(cita.appointmentDateTime)},
          {etiqueta: 'Hora', valor: formatearHora(cita.appointmentDateTime)},
          {etiqueta: 'Motivo', valor: cita.motivo},
        ],
        aviso: cita.pagoEstado === 'verified' ? null :
          'Tu pago esta por verificar. Te avisamos por este medio en cuanto quede confirmado.',
      });

      await enviar({
        clinica,
        para: cita.email,
        asunto: `Cita confirmada - ${cita.patientName || 'PediActual'}`,
        html,
      });
    });

/// Cambios en una cita ya existente: cancelacion o cambio de horario.
exports.citaActualizada = onDocumentUpdated(
    {document: 'citas/{citaId}', secrets: [SMTP_URI]},
    async (event) => {
      const antes = event.data?.before?.data();
      const ahora = event.data?.after?.data();
      if (!antes || !ahora || !ahora.email) {
        return;
      }
      if (!await quiereRecibirCorreos(ahora.representativeId)) {
        return;
      }

      const clinica = await datosClinica();
      const seCancelo = antes.status !== 'cancelled' && ahora.status === 'cancelled';

      const antesMs = antes.appointmentDateTime?.toMillis?.() ?? 0;
      const ahoraMs = ahora.appointmentDateTime?.toMillis?.() ?? 0;
      const seMovio = antesMs !== 0 && ahoraMs !== 0 && antesMs !== ahoraMs;

      if (seCancelo) {
        await enviar({
          clinica,
          para: ahora.email,
          asunto: `Cita cancelada - ${ahora.patientName || 'PediActual'}`,
          html: armarHtml({
            clinica,
            titulo: 'Tu cita fue cancelada',
            saludo: `Hola ${ahora.representativeName || ''},`.trim(),
            mensaje: 'la siguiente cita quedo cancelada.',
            filas: [
              {etiqueta: 'Paciente', valor: ahora.patientName},
              {etiqueta: 'Fecha', valor: formatearFecha(ahora.appointmentDateTime)},
              {etiqueta: 'Hora', valor: formatearHora(ahora.appointmentDateTime)},
            ],
            aviso: 'Si ya habias pagado, comunicate con el consultorio para gestionar el reembolso.',
          }),
        });
        return;
      }

      if (seMovio) {
        await enviar({
          clinica,
          para: ahora.email,
          asunto: `Cita reprogramada - ${ahora.patientName || 'PediActual'}`,
          html: armarHtml({
            clinica,
            titulo: 'Tu cita cambio de horario',
            saludo: `Hola ${ahora.representativeName || ''},`.trim(),
            mensaje: 'estos son los datos nuevos de tu cita.',
            filas: [
              {etiqueta: 'Paciente', valor: ahora.patientName},
              {etiqueta: 'Fecha nueva', valor: formatearFecha(ahora.appointmentDateTime)},
              {etiqueta: 'Hora nueva', valor: formatearHora(ahora.appointmentDateTime)},
              {etiqueta: 'Horario anterior', valor: formatearFecha(antes.appointmentDateTime)},
            ],
          }),
        });
      }
    });

// ------------------------------------------------------------------- pagos

/// Verificacion o rechazo del pago.
exports.pagoActualizado = onDocumentUpdated(
    {document: 'pagos/{pagoId}', secrets: [SMTP_URI]},
    async (event) => {
      const antes = event.data?.before?.data();
      const ahora = event.data?.after?.data();
      if (!antes || !ahora || !ahora.email) {
        return;
      }
      if (antes.status === ahora.status) {
        return;
      }
      if (!await quiereRecibirCorreos(ahora.representativeId)) {
        return;
      }

      const clinica = await datosClinica();
      const monto = typeof ahora.pagoMonto === 'number' ?
        `${ahora.pagoMonto.toFixed(2)} Bs.` : '';

      if (ahora.status === 'verified') {
        await enviar({
          clinica,
          para: ahora.email,
          asunto: `Pago verificado - ${ahora.patientName || 'PediActual'}`,
          html: armarHtml({
            clinica,
            titulo: 'Recibimos tu pago',
            saludo: `Hola ${ahora.representativeName || ''},`.trim(),
            mensaje: 'tu pago quedo verificado y la cita esta confirmada.',
            filas: [
              {etiqueta: 'Paciente', valor: ahora.patientName},
              {etiqueta: 'Referencia', valor: ahora.pagoReferencia},
              {etiqueta: 'Monto', valor: monto},
            ],
          }),
        });
        return;
      }

      if (ahora.status === 'rejected') {
        await enviar({
          clinica,
          para: ahora.email,
          asunto: `Problema con tu pago - ${ahora.patientName || 'PediActual'}`,
          html: armarHtml({
            clinica,
            titulo: 'No pudimos verificar tu pago',
            saludo: `Hola ${ahora.representativeName || ''},`.trim(),
            mensaje: 'revisamos el comprobante y encontramos lo siguiente.',
            filas: [
              {etiqueta: 'Paciente', valor: ahora.patientName},
              {etiqueta: 'Referencia', valor: ahora.pagoReferencia},
              {etiqueta: 'Motivo', valor: ahora.motivoRechazo || ahora.pagoMotivoRechazo},
            ],
            aviso: 'Comunicate con el consultorio para resolverlo y conservar tu horario.',
          }),
        });
      }
    });

// ---------------------------------------------------------- disponibilidad

/// Publica que horarios estan tomados en `disponibilidad/{fecha}`.
///
/// Existe por un problema de permisos con forma de problema de producto: la
/// grilla necesita saber que bloques estan ocupados, pero para averiguarlo
/// pedia todas las citas del dia, y eso obliga a dejar la coleccion `citas`
/// legible por cualquier usuario con sesion. Es decir, un representante podia
/// leer las citas de las demas familias.
///
/// Aqui el servidor publica solo las horas ocupadas, sin nombre, sin telefono
/// y sin motivo. Con eso la grilla se pinta igual y `citas` puede quedar
/// cerrada a su dueno.
async function recalcularDisponibilidad(anio, mes, dia) {
  const {inicio, fin} = rangoDelDia(anio, mes, dia);

  const snap = await db.collection('citas')
      .where('appointmentDateTime', '>=', inicio)
      .where('appointmentDateTime', '<=', fin)
      .get();

  const ocupados = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    // Una cita cancelada libera el horario.
    if (d.status === 'cancelled') {
      continue;
    }
    const cuando = d.appointmentDateTime?.toDate?.();
    if (cuando) {
      ocupados.push(claveHora(cuando));
    }
  }

  const dos = (n) => String(n).padStart(2, '0');
  const clave = `${anio}-${dos(mes)}-${dos(dia)}`;

  await db.collection('disponibilidad').doc(clave).set({
    ocupados: [...new Set(ocupados)].sort(),
    actualizadoEn: new Date(),
  });

  logger.info('Disponibilidad actualizada', {fecha: clave, ocupados: ocupados.length});
}

/// Se recalcula ante cualquier cambio en una cita: alta, cambio de estado,
/// reprogramacion o borrado. Cuando la cita se mueve de dia hay que rehacer
/// los dos, el de origen y el de destino.
exports.sincronizarDisponibilidad = onDocumentWritten(
    'citas/{citaId}',
    async (event) => {
      const antes = event.data?.before?.data();
      const ahora = event.data?.after?.data();

      const claves = new Set();
      for (const datos of [antes, ahora]) {
        const cuando = datos?.appointmentDateTime?.toDate?.();
        if (cuando) {
          claves.add(claveFecha(cuando));
        }
      }

      for (const clave of claves) {
        const [a, m, d] = clave.split('-').map(Number);
        await recalcularDisponibilidad(a, m, d);
      }
    });

/// Rehace la disponibilidad de los proximos meses, todos los dias de madrugada.
///
/// Cumple dos funciones. La primera es poblar los documentos que aun no
/// existen: el disparador de arriba solo reacciona a cambios, asi que las
/// citas ya cargadas antes de todo esto no tenian su dia publicado. La segunda
/// es de mantenimiento, por si algun cambio se perdiera.
///
/// Mientras un dia no tenga su documento, la grilla lo muestra libre y quien
/// intente tomar un bloque ocupado choca contra la transaccion, que devuelve
/// "ese horario acaba de ser reservado". Se degrada, no se rompe.
exports.reconstruirDisponibilidad = onSchedule(
    {
      schedule: '0 3 * * *',
      timeZone: ZONA,
      // Son 120 dias, cada uno con una consulta y una escritura. Con el minuto
      // que trae por defecto la tarea se cortaba por la mitad y dejaba la
      // segunda tanda de dias sin publicar.
      timeoutSeconds: 540,
      memory: '512MiB',
    },
    async () => {
      const hoy = partesEnZona(new Date());
      const ancla = Date.UTC(+hoy.year, +hoy.month - 1, +hoy.day, 12);

      // Un mes hacia atras para el historial y tres meses hacia adelante, que
      // es lo mas lejos que se puede agendar.
      const dias = [];
      for (let i = -30; i < 90; i++) {
        const d = new Date(ancla + i * 86400000);
        dias.push([d.getUTCFullYear(), d.getUTCMonth() + 1, d.getUTCDate()]);
      }

      // De a diez en paralelo: en fila son 240 idas y vueltas a Firestore y
      // no entra en el tiempo disponible.
      const TANDA = 10;
      for (let i = 0; i < dias.length; i += TANDA) {
        await Promise.all(
            dias.slice(i, i + TANDA).map(([a, m, d]) => recalcularDisponibilidad(a, m, d)));
      }

      logger.info('Disponibilidad reconstruida', {dias: dias.length});
    });

// ------------------------------------------------------ codigos por correo

/// Cuanto vive un codigo y cuantos intentos admite.
const CODIGO_MINUTOS = 10;
const CODIGO_INTENTOS = 5;
const CODIGO_ESPERA_SEGUNDOS = 60;

const PROPOSITOS = {
  registro: {
    titulo: 'Confirma tu correo',
    mensaje: 'usa este codigo para terminar de crear tu cuenta en PediActual.',
  },
  recetas: {
    titulo: 'Codigo para ver tus recetas',
    mensaje: 'usa este codigo para abrir las recetas de tus hijos.',
  },
};

/// El codigo nunca se guarda tal cual: si alguien llegara a leer la coleccion
/// solo encontraria el resumen, que no se puede volver atras.
function resumen(codigo, uid) {
  return crypto.createHash('sha256').update(`${uid}:${codigo}`).digest('hex');
}

function nuevoCodigo() {
  // De 100000 a 999999, siempre seis digitos, con generador criptografico.
  return String(100000 + crypto.randomInt(900000));
}

/// Envia un codigo de seis digitos al correo de quien lo pide.
exports.enviarCodigo = onCall({secrets: [SMTP_URI]}, async (req) => {
  const uid = req.auth?.uid;
  const correo = req.auth?.token?.email;
  if (!uid || !correo) {
    throw new HttpsError('unauthenticated', 'Inicia sesion para continuar.');
  }

  const proposito = String(req.data?.proposito || '');
  const textos = PROPOSITOS[proposito];
  if (!textos) {
    throw new HttpsError('invalid-argument', 'Proposito no valido.');
  }

  const ref = db.collection('codigos').doc(`${uid}_${proposito}`);
  const previo = await ref.get();

  // Un codigo por minuto: evita que se use el envio como forma de molestar a
  // alguien llenandole el buzon.
  if (previo.exists) {
    const creado = previo.data().creadoEn?.toDate?.();
    if (creado && Date.now() - creado.getTime() < CODIGO_ESPERA_SEGUNDOS * 1000) {
      const faltan = Math.ceil(
          (CODIGO_ESPERA_SEGUNDOS * 1000 - (Date.now() - creado.getTime())) / 1000);
      throw new HttpsError(
          'resource-exhausted', `Espera ${faltan} segundos para pedir otro codigo.`);
    }
  }

  const codigo = nuevoCodigo();
  await ref.set({
    resumen: resumen(codigo, uid),
    proposito,
    creadoEn: new Date(),
    expiraEn: new Date(Date.now() + CODIGO_MINUTOS * 60000),
    intentos: 0,
  });

  const clinica = await datosClinica();
  await enviar({
    clinica,
    para: correo,
    asunto: `${textos.titulo} - codigo ${codigo}`,
    html: armarHtml({
      clinica,
      titulo: textos.titulo,
      saludo: 'Hola,',
      mensaje: textos.mensaje,
      filas: [
        {etiqueta: 'Tu codigo', valor: codigo},
        {etiqueta: 'Vence en', valor: `${CODIGO_MINUTOS} minutos`},
      ],
      aviso: 'Si no fuiste tu quien lo pidio, ignora este mensaje y no lo compartas con nadie.',
    }),
  });

  logger.info('Codigo enviado', {uid, proposito});
  return {enviado: true, minutos: CODIGO_MINUTOS};
});

/// Comprueba el codigo que escribio la persona.
exports.verificarCodigo = onCall(async (req) => {
  const uid = req.auth?.uid;
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Inicia sesion para continuar.');
  }

  const proposito = String(req.data?.proposito || '');
  const codigo = String(req.data?.codigo || '').trim();
  if (!PROPOSITOS[proposito] || !/^\d{6}$/.test(codigo)) {
    throw new HttpsError('invalid-argument', 'El codigo son seis digitos.');
  }

  const ref = db.collection('codigos').doc(`${uid}_${proposito}`);
  const doc = await ref.get();
  if (!doc.exists) {
    throw new HttpsError('not-found', 'No hay ningun codigo pendiente. Pide uno nuevo.');
  }

  const datos = doc.data();

  const expira = datos.expiraEn?.toDate?.();
  if (!expira || expira.getTime() < Date.now()) {
    await ref.delete();
    throw new HttpsError('deadline-exceeded', 'El codigo vencio. Pide uno nuevo.');
  }

  if ((datos.intentos || 0) >= CODIGO_INTENTOS) {
    await ref.delete();
    throw new HttpsError('resource-exhausted', 'Demasiados intentos. Pide un codigo nuevo.');
  }

  // Comparacion de tiempo constante: no revela nada por cuanto tarda.
  const esperado = Buffer.from(datos.resumen || '', 'hex');
  const recibido = Buffer.from(resumen(codigo, uid), 'hex');
  const coincide = esperado.length === recibido.length &&
      crypto.timingSafeEqual(esperado, recibido);

  if (!coincide) {
    await ref.update({intentos: (datos.intentos || 0) + 1});
    const quedan = CODIGO_INTENTOS - (datos.intentos || 0) - 1;
    throw new HttpsError(
        'permission-denied',
        quedan > 0 ?
          `El codigo no coincide. Te quedan ${quedan} intentos.` :
          'El codigo no coincide y se agotaron los intentos.');
  }

  await ref.delete();

  // El registro deja constancia para no volver a pedirlo.
  if (proposito === 'registro') {
    await db.collection('users').doc(uid).set(
        {correoVerificado: true, correoVerificadoEn: new Date()}, {merge: true});
  }

  logger.info('Codigo verificado', {uid, proposito});
  return {verificado: true};
});

// ------------------------------------------------------------ recordatorios

const REGION = 'us-central1';
const PROYECTO = process.env.GCLOUD_PROJECT || 'pediactual-ee23b';
const URL_RESPUESTA = `https://${REGION}-${PROYECTO}.cloudfunctions.net/responderCita`;

/// A donde se le avisa al personal. Sale de la configuracion de la clinica
/// para poder cambiarlo sin desplegar; si no esta, se usa la propia cuenta
/// desde la que salen los correos.
function correoDelPersonal(clinica) {
  const configurado = (clinica.correoNotificaciones || '').toString().trim();
  return configurado || correoRemitente();
}

/// Pagina simple para el navegador. Quien llega aqui viene de su correo, no de
/// la aplicacion, asi que no hay sesion ni menu: solo un mensaje claro.
function paginaHtml({titulo, mensaje, detalle, acciones, tono}) {
  const colores = {
    bien: '#2E7D5B',
    aviso: '#B07A1E',
    mal: '#B3382E',
    neutro: '#35808F',
  };
  const color = colores[tono] || colores.neutro;

  const botones = (acciones || []).map((a) => `
      <form method="POST" action="${a.url}" style="display:inline-block;margin:0 8px 10px 0;">
        ${Object.entries(a.campos || {}).map(([k, v]) =>
    `<input type="hidden" name="${escapar(k)}" value="${escapar(v)}">`).join('')}
        <button type="submit" style="padding:12px 22px;border-radius:8px;cursor:pointer;
          font-size:15px;font-weight:600;font-family:inherit;
          ${a.principal ?
    'background:#4594A4;color:#FFFFFF;border:none;' :
    'background:#FFFFFF;color:#4A5C60;border:1px solid #DCE6E4;'}">
          ${escapar(a.texto)}
        </button>
      </form>`).join('');

  return `<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapar(titulo)} - PediActual</title>
</head>
<body style="margin:0;padding:24px;background:#F4F7F6;min-height:100vh;
             font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;">
  <div style="max-width:520px;margin:40px auto;background:#FFFFFF;border-radius:12px;
              border:1px solid #E1E8E7;overflow:hidden;">
    <div style="background:#4594A4;padding:20px 26px;">
      <span style="color:#FFFFFF;font-size:22px;font-weight:300;">pedi</span><span
            style="color:#EAA171;font-size:22px;font-weight:700;">actual</span>
    </div>
    <div style="padding:28px 26px;">
      <h1 style="margin:0 0 10px;font-size:21px;color:${color};">${escapar(titulo)}</h1>
      <p style="margin:0 0 6px;font-size:15.5px;color:#17262A;line-height:1.55;">
        ${escapar(mensaje)}
      </p>
      ${detalle ? `<p style="margin:10px 0 0;font-size:14px;color:#5B6B6E;line-height:1.55;">
        ${escapar(detalle)}</p>` : ''}
      ${botones ? `<div style="margin-top:22px;">${botones}</div>` : ''}
    </div>
  </div>
</body>
</html>`;
}

/// Avisa al personal de lo que respondio el representante.
async function avisarAlPersonal({cita, clinica, asunto, titulo, mensaje, tono}) {
  await enviar({
    clinica,
    para: correoDelPersonal(clinica),
    asunto,
    html: armarHtml({
      clinica,
      titulo,
      saludo: 'Aviso de la agenda:',
      mensaje,
      filas: [
        {etiqueta: 'Paciente', valor: cita.patientName},
        {etiqueta: 'Representante', valor: cita.representativeName},
        {etiqueta: 'Telefono', valor: cita.phone},
        {etiqueta: 'Fecha', valor: formatearFecha(cita.appointmentDateTime)},
        {etiqueta: 'Hora', valor: formatearHora(cita.appointmentDateTime)},
      ],
      aviso: tono === 'mal' ?
        'Conviene ofrecer ese horario a otra familia.' : null,
    }),
  });
}

/// Manda el recordatorio de las citas de manana, con los dos enlaces.
///
/// Cierra la promesa que la aplicacion ya le hacia al usuario: el interruptor
/// de Ajustes decia "Recordatorios de tus citas programadas" y guardaba la
/// preferencia, pero no habia nada que la leyera ni que enviara nada.
exports.enviarRecordatorios = onSchedule(
    {
      schedule: '0 9 * * *',
      timeZone: ZONA,
      secrets: [SMTP_URI],
      timeoutSeconds: 540,
      memory: '512MiB',
    },
    async () => {
      // Manana en el calendario de la consulta, no del servidor.
      const hoy = partesEnZona(new Date());
      const manana = new Date(
          Date.UTC(+hoy.year, +hoy.month - 1, +hoy.day, 12) + 86400000);
      const {inicio, fin} = rangoDelDia(
          manana.getUTCFullYear(), manana.getUTCMonth() + 1, manana.getUTCDate());

      const snap = await db.collection('citas')
          .where('appointmentDateTime', '>=', inicio)
          .where('appointmentDateTime', '<=', fin)
          .get();

      const clinica = await datosClinica();
      let enviados = 0;
      let omitidos = 0;

      for (const doc of snap.docs) {
        const cita = doc.data();

        if (cita.status === 'cancelled' || !cita.email) {
          omitidos++;
          continue;
        }
        // Si ya se mando, no se repite aunque la tarea corra dos veces.
        if (cita.recordatorioEnviadoEn) {
          omitidos++;
          continue;
        }
        if (!await quiereRecibirCorreos(cita.representativeId)) {
          omitidos++;
          continue;
        }

        // El enlace lleva un testigo que no se puede adivinar: es lo unico que
        // autoriza a responder, porque quien abre el correo no tiene sesion.
        const testigo = crypto.randomBytes(24).toString('hex');
        await db.collection('recordatorios').doc(testigo).set({
          citaId: doc.id,
          creadoEn: new Date(),
          expiraEn: new Date(inicio.getTime() + 2 * 86400000),
        });

        await enviar({
          clinica,
          para: cita.email,
          asunto: `Manana es tu cita - ${cita.patientName || 'PediActual'}`,
          html: armarHtml({
            clinica,
            titulo: 'Te esperamos manana',
            saludo: `Hola ${cita.representativeName || ''},`.trim(),
            mensaje: 'confirmanos si podras asistir a la consulta.',
            filas: [
              {etiqueta: 'Paciente', valor: cita.patientName},
              {etiqueta: 'Fecha', valor: formatearFecha(cita.appointmentDateTime)},
              {etiqueta: 'Hora', valor: formatearHora(cita.appointmentDateTime)},
            ],
            acciones: [
              {
                texto: 'Si, voy a asistir',
                url: `${URL_RESPUESTA}?t=${testigo}&r=confirmar`,
                principal: true,
              },
              {
                texto: 'No puedo asistir',
                url: `${URL_RESPUESTA}?t=${testigo}&r=rechazar`,
              },
            ],
            aviso: 'Si no puedes venir, avisanos hoy mismo: asi le ofrecemos tu ' +
              'horario a otra familia que lo necesite.',
          }),
        });

        await doc.ref.set({recordatorioEnviadoEn: new Date()}, {merge: true});
        enviados++;
      }

      logger.info('Recordatorios enviados', {enviados, omitidos, total: snap.size});
    });

/// Recibe la respuesta del representante desde el correo.
///
/// No hay sesion: quien llega viene de su bandeja de entrada. Autoriza el
/// testigo del enlace, que es aleatorio y de un solo uso por cita.
///
/// Confirmar se resuelve de una; rechazar no cancela nada por si solo, sino
/// que ofrece elegir entre reprogramar y cancelar. Asi un cliente de correo
/// que precargue los enlaces no puede cancelarle la cita a nadie.
exports.responderCita = onRequest({secrets: [SMTP_URI], cors: false}, async (req, res) => {
  const testigo = String(req.query.t || req.body?.t || '');
  const respuesta = String(req.query.r || req.body?.r || '');

  const responder = (codigo, pagina) => {
    res.status(codigo).set('Content-Type', 'text/html; charset=utf-8').send(pagina);
  };

  if (!/^[a-f0-9]{48}$/.test(testigo)) {
    return responder(400, paginaHtml({
      tono: 'mal',
      titulo: 'Enlace no valido',
      mensaje: 'Este enlace no es correcto.',
      detalle: 'Abrelo desde el correo que te enviamos, sin copiarlo a mano.',
    }));
  }

  const refTestigo = db.collection('recordatorios').doc(testigo);
  const docTestigo = await refTestigo.get();

  if (!docTestigo.exists) {
    return responder(404, paginaHtml({
      tono: 'aviso',
      titulo: 'Enlace vencido',
      mensaje: 'Este enlace ya no esta disponible.',
      detalle: 'Comunicate con el consultorio para gestionar tu cita.',
    }));
  }

  const expira = docTestigo.data().expiraEn?.toDate?.();
  if (expira && expira.getTime() < Date.now()) {
    await refTestigo.delete();
    return responder(410, paginaHtml({
      tono: 'aviso',
      titulo: 'Enlace vencido',
      mensaje: 'Este enlace ya paso su fecha.',
      detalle: 'Comunicate con el consultorio para gestionar tu cita.',
    }));
  }

  const refCita = db.collection('citas').doc(docTestigo.data().citaId);
  const docCita = await refCita.get();
  if (!docCita.exists) {
    return responder(404, paginaHtml({
      tono: 'mal',
      titulo: 'Cita no encontrada',
      mensaje: 'Esa cita ya no existe.',
    }));
  }

  const cita = docCita.data();
  const clinica = await datosClinica();
  const cuando = `${formatearFecha(cita.appointmentDateTime)} a las ` +
    `${formatearHora(cita.appointmentDateTime)}`;

  if (cita.status === 'cancelled') {
    return responder(200, paginaHtml({
      tono: 'aviso',
      titulo: 'La cita esta cancelada',
      mensaje: `La cita de ${cita.patientName} ya figura cancelada.`,
      detalle: 'Si necesitas una nueva, agendala desde la aplicacion.',
    }));
  }

  // -------------------------------------------------- confirmar la asistencia
  if (respuesta === 'confirmar') {
    await refCita.set({
      status: 'confirmed',
      respuestaRecordatorio: 'confirmada',
      respondidoEn: new Date(),
    }, {merge: true});

    await avisarAlPersonal({
      cita, clinica, tono: 'bien',
      asunto: `Cita confirmada - ${cita.patientName}`,
      titulo: 'El representante confirmo la asistencia',
      mensaje: 'respondio que si asistira a la consulta de manana.',
    });

    return responder(200, paginaHtml({
      tono: 'bien',
      titulo: 'Gracias, quedo confirmada',
      mensaje: `Te esperamos el ${cuando}.`,
      detalle: 'Ya le avisamos al consultorio. Si algo cambia, escribenos.',
    }));
  }

  // ------------------------------------------------- no puede: que prefiere
  if (respuesta === 'rechazar') {
    return responder(200, paginaHtml({
      tono: 'aviso',
      titulo: 'Que prefieres hacer?',
      mensaje: `Tu cita es el ${cuando}.`,
      detalle: 'Elige una opcion y le avisamos al consultorio.',
      acciones: [
        {
          texto: 'Quiero reprogramarla',
          url: URL_RESPUESTA,
          campos: {t: testigo, r: 'reprogramar'},
          principal: true,
        },
        {
          texto: 'Cancelar la cita',
          url: URL_RESPUESTA,
          campos: {t: testigo, r: 'cancelar'},
        },
      ],
    }));
  }

  // ------------------------------------------------------------- reprogramar
  if (respuesta === 'reprogramar') {
    await refCita.set({
      respuestaRecordatorio: 'reprogramar',
      respondidoEn: new Date(),
    }, {merge: true});

    await avisarAlPersonal({
      cita, clinica, tono: 'aviso',
      asunto: `Pide reprogramar - ${cita.patientName}`,
      titulo: 'El representante quiere reprogramar',
      mensaje: 'no puede asistir manana y pide otro horario. La cita sigue ' +
        'en pie hasta que se acuerde uno nuevo.',
    });

    return responder(200, paginaHtml({
      tono: 'neutro',
      titulo: 'Avisamos al consultorio',
      mensaje: 'Le pedimos al consultorio que te ofrezca otro horario.',
      detalle: 'Tambien puedes elegirlo tu mismo desde "Mis citas" en la ' +
        'aplicacion, con el boton Reprogramar.',
    }));
  }

  // ---------------------------------------------------------------- cancelar
  if (respuesta === 'cancelar') {
    // El disparador de citas se encarga del correo de cancelacion y de liberar
    // el horario en la disponibilidad publicada.
    await refCita.set({
      status: 'cancelled',
      respuestaRecordatorio: 'cancelada',
      respondidoEn: new Date(),
      canceladaEn: new Date(),
      canceladaPor: 'recordatorio',
    }, {merge: true});

    await refTestigo.delete();

    await avisarAlPersonal({
      cita, clinica, tono: 'mal',
      asunto: `Cita cancelada - ${cita.patientName}`,
      titulo: 'El representante cancelo la cita',
      mensaje: 'cancelo desde el recordatorio y el horario quedo libre.',
    });

    return responder(200, paginaHtml({
      tono: 'neutro',
      titulo: 'Cita cancelada',
      mensaje: 'Tu cita quedo cancelada y el horario liberado.',
      detalle: 'Si ya habias pagado, comunicate con el consultorio para ' +
        'gestionar el reembolso. Puedes agendar de nuevo cuando quieras.',
    }));
  }

  return responder(400, paginaHtml({
    tono: 'mal',
    titulo: 'Opcion no reconocida',
    mensaje: 'No entendimos que querias hacer.',
    detalle: 'Vuelve al correo y usa uno de los dos botones.',
  }));
});
