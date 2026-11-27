const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(200).send('Fonnte Reverse OTP Webhook Ready');
  }

  try {
    const raw = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
    const sender = String(raw.sender || '').replace(/\D/g, '');
    const message = String(raw.message || '').toUpperCase();
    const senderName = String(raw.name || '');

    // Baca kode 6 digit setelah "KODE VERIFIKASI:" atau format lama "2S-"
    const matchNew = message.match(/KODE\s+VERIFIKASI\s*[:\-]\s*\*?\s*([A-Z0-9]{6})\s*\*?/);
    const matchOld = message.match(/2S-[A-Z0-9]{6}/);
    const otpCode = matchNew ? matchNew[1] : (matchOld ? matchOld[0] : null);

    if (otpCode && sender) {
      const snap = await db
        .collection('otp_sessions')
        .where('code', '==', otpCode)
        .where('status', '==', 'pending')
        .limit(1)
        .get();

      if (!snap.empty) {
        const doc = snap.docs[0];
        const session = doc.data() || {};
        const expectedPhone = String(session.expectedPhone || '').replace(/\D/g, '');

        if (expectedPhone && sender !== expectedPhone) {
          await doc.ref.update({
            mismatchSender: sender,
            mismatchAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return res.status(200).json({ status: true, verified: false, reason: 'phone_mismatch' });
        }

        await doc.ref.update({
          status: 'verified',
          phone: sender,
          waName: senderName,
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (process.env.FONNTE_TOKEN) {
          const params = new URLSearchParams();
          params.append('target', sender);
          params.append(
            'message',
            '✅ Nomor WhatsApp Anda berhasil dikonfirmasi! Silakan buka kembali aplikasi *2S Member*.'
          );
          await fetch('https://api.fonnte.com/send', {
            method: 'POST',
            headers: { Authorization: process.env.FONNTE_TOKEN },
            body: params,
          });
        }
      }
    }
  } catch (err) {
    console.error('Fonnte Webhook Error:', err);
  }

  return res.status(200).json({ status: true });
};
