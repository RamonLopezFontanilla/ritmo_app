const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * Función Cloud Function para crear un músico
 */
exports.crearMusico = functions.https.onCall(async (data, context) => {
  // ✅ Verificar autenticación
  if (!context.auth) {
    throw new functions.https.HttpsError(
        "unauthenticated",
        "El usuario no está autenticado.",
    );
  }

  const uidAdmin = context.auth.uid;

  // ✅ Verificar rol admin
  const adminDoc = await db.collection("usuarios").doc(uidAdmin).get();
  if (!adminDoc.exists || adminDoc.data().rol !== "admin") {
    throw new functions.https.HttpsError(
        "permission-denied",
        "Solo un admin puede crear músicos.",
    );
  }

  // 📦 Datos del músico
  const {
    email,
    nombre,
    telefono,
    fechaNacimiento,
    bandaId,
    instrumento,
    categoria,
    anioPrimeraSemanaSanta,
  } = data;

  if (!email || !nombre || !bandaId) {
    throw new functions.https.HttpsError(
        "invalid-argument",
        "Faltan campos obligatorios.",
    );
  }

  // 🔍 Buscar si el usuario ya existe por email
  const usuariosSnap = await db
      .collection("usuarios")
      .where("email", "==", email.toLowerCase())
      .limit(1)
      .get();

  let musicoUid;

  if (usuariosSnap.empty) {
    // Crear nuevo usuario en Firestore
    const nuevoUsuarioRef = db.collection("usuarios").doc();
    musicoUid = nuevoUsuarioRef.id;

    await nuevoUsuarioRef.set({
      email: email.toLowerCase(),
      nombre,
      telefono: telefono || "",
      fechaNacimiento: fechaNacimiento ? new Date(fechaNacimiento) : null,
      rol: "musico",
      creadoEn: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    musicoUid = usuariosSnap.docs[0].id;
  }

  // Crear usuario en la colección de la banda
  await db
      .collection("bandas")
      .doc(bandaId)
      .collection("usuarios")
      .doc(musicoUid)
      .set({
        activo: true,
        instrumento: instrumento || null,
        categoria: categoria || null,
        anioPrimeraSemanaSanta: anioPrimeraSemanaSanta || null,
        agregadoEn: admin.firestore.FieldValue.serverTimestamp(),
      });

  return {uid: musicoUid};
});
