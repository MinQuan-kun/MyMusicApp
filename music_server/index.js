const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const multer = require('multer');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const cloudinary = require('cloudinary').v2;

require('dotenv').config();

const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI;

// --- CẤU HÌNH R2 & CLOUDINARY ---
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

const app = express();
app.use(cors());
app.use(express.json());

mongoose.connect(MONGO_URI).then(() => console.log('✅ DB Connected'));

// --- 1. SCHEMAS (CẤU TRÚC DỮ LIỆU) ---

const SongSchema = new mongoose.Schema({
  title: String,
  artist: String,
  imageUrl: String,
  audioUrl: String,
});
const Song = mongoose.model('Song', SongSchema);

// 👇 QUAN TRỌNG: Thêm Schema Playlist
const PlaylistSchema = new mongoose.Schema({
  name: String,
  songs: [SongSchema] // Mảng chứa các bài hát
});
const Playlist = mongoose.model('Playlist', PlaylistSchema);

// --- 2. SETUP UPLOAD ---
const s3Client = new S3Client({
  region: "auto",
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: { accessKeyId: R2_ACCESS_KEY, secretAccessKey: R2_SECRET_KEY },
});
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// --- 3. API BÀI HÁT (SONGS) ---

app.get('/songs', async (req, res) => {
  const songs = await Song.find().sort({ _id: -1 });
  res.json(songs);
});

app.post('/upload', upload.fields([{ name: 'songFile' }, { name: 'imageFile' }]), async (req, res) => {
  try {
    const files = req.files;
    const body = req.body;

    if (!files.songFile || !files.imageFile) return res.status(400).send("Thiếu file!");

    const songFile = files.songFile[0];
    const imageFile = files.imageFile[0];

    // Upload Nhạc R2
    const cleanName = songFile.originalname.replace(/\s+/g, '-').replace(/[^\w.-]/g, '');
    const songName = `${Date.now()}_${cleanName}`;
    await s3Client.send(new PutObjectCommand({
      Bucket: R2_BUCKET_NAME, Key: songName, Body: songFile.buffer, ContentType: songFile.mimetype,
    }));
    const finalAudioUrl = `${R2_PUBLIC_DOMAIN}/${songName}`;

    // Upload Ảnh Cloudinary
    const b64 = Buffer.from(imageFile.buffer).toString('base64');
    let dataURI = "data:" + imageFile.mimetype + ";base64," + b64;
    const imageResult = await cloudinary.uploader.upload(dataURI, { folder: "my_music_app_covers", resource_type: "image" });
    const finalImageUrl = imageResult.secure_url;

    // Lưu MongoDB
    const newSong = new Song({
      title: body.title || songFile.originalname,
      artist: body.artist || "Unknown",
      imageUrl: finalImageUrl,
      audioUrl: finalAudioUrl,
    });

    await newSong.save();
    res.json({ message: "Upload thành công!", song: newSong });

  } catch (error) {
    console.error(error);
    res.status(500).send("Lỗi: " + error.message);
  }
});

// --- 4. API PLAYLIST (PHẦN BẠN ĐANG THIẾU) ---

// Lấy danh sách Playlist
app.get('/playlists', async (req, res) => {
  try {
    const playlists = await Playlist.find().sort({ _id: -1 });
    res.json(playlists);
  } catch (e) { res.status(500).json({ error: e.message }) }
});

// Tạo Playlist mới
app.post('/playlists', async (req, res) => {
  try {
    const { name, songs } = req.body;
    const newPlaylist = new Playlist({ name, songs: songs || [] });
    await newPlaylist.save();
    res.status(201).json(newPlaylist);
  } catch (e) { res.status(500).json({ error: e.message }) }
});

// 👇 API QUAN TRỌNG: Thêm bài hát vào Playlist
app.post('/playlists/:id/add-song', async (req, res) => {
  try {
    console.log("👉 Request ID:", req.params.id);

    // 🛡️ CHẶN LỖI: Kiểm tra xem ID có đúng chuẩn MongoDB không
    if (!mongoose.Types.ObjectId.isValid(req.params.id)) {
      console.log("❌ ID bị lỗi (null hoặc sai định dạng)");
      return res.status(400).json({ error: "ID Playlist không hợp lệ (App đang gửi null)" });
    }

    const song = req.body;

    // Tìm Playlist và thêm nhạc
    const updated = await Playlist.findByIdAndUpdate(
      req.params.id,
      { $push: { songs: song } },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ error: "Không tìm thấy Playlist này trong DB" });
    }

    res.json(updated);
  } catch (e) {
    console.error("❌ Lỗi Server:", e);
    res.status(500).json({ error: e.message });
  }
});

// Xóa bài hát khỏi Playlist
app.put('/playlists/:id', async (req, res) => {
  try {
    const { name, songs } = req.body;
    const updated = await Playlist.findByIdAndUpdate(req.params.id, { name, songs }, { new: true });
    res.json(updated);
  } catch (e) { res.status(500).json({ error: e.message }) }
});

// Xóa Playlist
app.delete('/playlists/:id', async (req, res) => {
  try {
    await Playlist.findByIdAndDelete(req.params.id);
    res.json({ message: "Deleted" });
  } catch (e) { res.status(500).json({ error: e.message }) }
});

app.listen(PORT, () => {
  console.log(`🚀 Server running at http://localhost:${PORT}`);
});