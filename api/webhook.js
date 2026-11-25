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

    // Cari kode format 2S-XXXXXX di pesan WA yang masuk
    const match = message.match(/2S-[A-Z0-9]{6}/);
    if (match && sender) {
      const otpCode = match[0];
      const snap = await db
        .collection('otp_sessions')
        .where('code', '==', otpCode)
        .where('status', '==', 'pending')
        .limit(1)
        .get();

      if (!snap.empty) {
        await snap.docs[0].ref.update({
          status: 'verified',
          phone: sender,
          waName: senderName,
          verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Opsional: Balas WA konfirmasi (hapus/kosongkan FONNTE_TOKEN jika ingin hemat 0 kuota)
        if (process.env.FONNTE_TOKEN) {
          const params = new URLSearchParams();
          params.append('target', sender);
          params.append(
            'message',
            '✅ Verifikasi *2S Member* berhasil! Silakan kembali ke aplikasi.'
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

  // Fonnte mewajibkan response HTTP 200
  return res.status(200).json({ status: true });
};
