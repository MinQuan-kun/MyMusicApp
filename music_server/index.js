const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const cloudinary = require('cloudinary').v2;

require('dotenv').config(); 

// --- LẤY THÔNG TIN TỪ FILE .ENV RA ---
const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI;

const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID;
const R2_ACCESS_KEY = process.env.R2_ACCESS_KEY;
const R2_SECRET_KEY = process.env.R2_SECRET_KEY;
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME;
const R2_PUBLIC_DOMAIN = process.env.R2_PUBLIC_DOMAIN;

cloudinary.config({ 
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME, 
  api_key: process.env.CLOUDINARY_API_KEY, 
  api_secret: process.env.CLOUDINARY_API_SECRET 
});

// --------------------------------------------------

const app = express();
app.use(cors());
app.use(express.json());

// Kết nối DB
mongoose.connect(MONGO_URI).then(() => console.log('✅ DB Connected'));

const SongSchema = new mongoose.Schema({
  title: String,
  artist: String,
  imageUrl: String,
  audioUrl: String,
});
const Song = mongoose.model('Song', SongSchema);

// Setup R2 Client
const s3Client = new S3Client({
  region: "auto",
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId: R2_ACCESS_KEY, secretAccessKey: R2_SECRET_KEY },
});

// Setup Multer (Nhận file vào bộ nhớ tạm)
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// --- API ---

// 1. Lấy danh sách bài hát
app.get('/songs', async (req, res) => {
  const songs = await Song.find().sort({_id: -1});
  res.json(songs);
});

// 2. Upload Nhạc + Ảnh (Logic xử lý kép)
app.post('/upload', upload.fields([{ name: 'songFile' }, { name: 'imageFile' }]), async (req, res) => {
  try {
    const files = req.files;
    const body = req.body;

    if (!files.songFile || !files.imageFile) {
      return res.status(400).send("❌ Phải chọn đủ cả File Nhạc và File Ảnh!");
    }

    const songFile = files.songFile[0];
    const imageFile = files.imageFile[0];

    // BƯỚC A: Upload Nhạc lên Cloudflare R2
    const songName = `${Date.now()}_${songFile.originalname}`;
    await s3Client.send(new PutObjectCommand({
      Bucket: R2_BUCKET_NAME,
      Key: songName,
      Body: songFile.buffer,
      ContentType: songFile.mimetype,
    }));
    const finalAudioUrl = `${R2_PUBLIC_DOMAIN}/${songName}`;

    // BƯỚC B: Upload Ảnh lên Cloudinary
    // Chuyển buffer sang base64 để gửi lên Cloudinary
    const b64 = Buffer.from(imageFile.buffer).toString('base64');
    let dataURI = "data:" + imageFile.mimetype + ";base64," + b64;
    
    const imageResult = await cloudinary.uploader.upload(dataURI, {
      folder: "my_music_app_covers", // Tạo thư mục riêng cho gọn
      resource_type: "image"
    });
    const finalImageUrl = imageResult.secure_url;

    // BƯỚC C: Lưu vào MongoDB
    const newSong = new Song({
      title: body.title || songFile.originalname,
      artist: body.artist || "Unknown",
      imageUrl: finalImageUrl, // Link ảnh từ Cloudinary
      audioUrl: finalAudioUrl, // Link nhạc từ R2
    });
    
    await newSong.save();
    console.log("✅ Đã thêm bài hát:", newSong.title);
    res.json({ message: "Upload thành công!", song: newSong });

  } catch (error) {
    console.error(error);
    res.status(500).send("Lỗi: " + error.message);
  }
});

app.listen(PORT, () => {
  console.log(`🚀 Server running at http://localhost:${PORT}`);
});