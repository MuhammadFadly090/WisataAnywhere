const express = require('express');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
const cors = require('cors');
require('dotenv').config();

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const app = express();
const PORT = process.env.PORT || 3000;

app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));
app.use(cors());

app.get('/', (req, res) => {
  res.send('Hai, ini adalah REST API untuk aplikasi wisatanyware!');
});

// ========================
// Endpoint: Send to Device
// ========================
app.post('/send-to-device', async (req, res) => {
  const { token, notification } = req.body;

  const message = {
    token: token,
    notification: {
      title: notification.title,
      body: notification.body
    }
  };

  try {
    const response = await admin.messaging().send(message);
    res.status(200).json({ success: true, response });
  } catch (error) {
    res.status(500).json({ success: false, error });
  }
});

// ==========================
// Endpoint: Send to Multiple
// ==========================
app.post('/send-to-multiple', async (req, res) => {
  const { tokens, notification } = req.body;

  const message = {
    tokens: tokens,
    notification: {
      title: notification.title,
      body: notification.body
    }
  };

  try {
    const response = await admin.messaging().sendMulticast(message);
    res.status(200).json({ success: true, response });
  } catch (error) {
    res.status(500).json({ success: false, error });
  }
});

// ======================
// Endpoint: Send to Topic
// ======================
app.post('/send-to-topic', async (req, res) => {
  const { topic, notification } = req.body;

  const message = {
    topic: topic,
    notification: {
      title: notification.title,
      body: notification.body
    }
  };

  try {
    const response = await admin.messaging().send(message);
    res.status(200).json({ success: true, response });
  } catch (error) {
    res.status(500).json({ success: false, error });
  }
});

app.listen(PORT, () => {
  console.log(`Server berjalan di http://localhost:${PORT}`);
});
