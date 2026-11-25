const admin = require('firebase-admin');

if (!admin.apps.length) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();

module.exports = async (req, res) => {
  // 1. Verifikasi Webhook oleh Meta (GET)
  if (req.method === 'GET') {
    const mode = req.query['hub.mode'];
    const token = req.query['hub.verify_token'];
    const challenge = req.query['hub.challenge'];

    if (mode === 'subscribe' && token === process.env.META_VERIFY_TOKEN) {
      return res.status(200).send(challenge);
    }
    return res.status(403).send('Forbidden');
  }

  // 2. Terima Pesan Masuk dari WhatsApp User (POST)
  if (req.method === 'POST') {
    try {
      const msg = req.body?.entry?.[0]?.changes?.[0]?.value?.messages?.[0];
      if (msg && msg.type === 'text') {
        const fromPhone = msg.from; // Nomor WA asli user (format: 628xxx)
        const textBody = (msg.text?.body || '').toUpperCase();
        const match = textBody.match(/2S-[A-Z0-9]{6}/);

        if (match) {
          const otpCode = match[0];
          const snap = await db
            .collection('otp_sessions')
            .where('code', '==', otpCode)
            .where('status', '==', 'pending')
            .limit(1)
            .get();

          if (!snap.empty) {
            const docRef = snap.docs[0].ref;
            await docRef.update({
              status: 'verified',
              phone: fromPhone,
              verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Opsional: Balas pesan konfirmasi (1.000 balasan service/bln gratis)
            if (process.env.META_WA_TOKEN && process.env.META_PHONE_NUMBER_ID) {
              await fetch(
                `https://graph.facebook.com/v21.0/${process.env.META_PHONE_NUMBER_ID}/messages`,
                {
                  method: 'POST',
                  headers: {
                    Authorization: `Bearer ${process.env.META_WA_TOKEN}`,
                    'Content-Type': 'application/json',
                  },
                  body: JSON.stringify({
                    messaging_product: 'whatsapp',
                    to: fromPhone,
                    text: {
                      body: '✅ Verifikasi 2S Member berhasil! Silakan kembali ke aplikasi.',
                    },
                  }),
                }
              );
            }
          }
        }
      }
    } catch (err) {
      console.error('Webhook Error:', err);
    }
    return res.status(200).send('EVENT_RECEIVED');
  }

  return res.status(405).send('Method Not Allowed');
};
