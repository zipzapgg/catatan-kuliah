# Panduan mengumpulkan proyek di SeptaLabs

Panduan ini dapat dipakai ulang untuk proyek berikutnya. Persyaratan dicatat dari formulir yang diperiksa pada 3 Oktober 2026; cocokkan kembali dengan formulir saat mengirim karya baru.

Formulir: <https://karya.septalabs.com/student/projects/create>

Pedoman: <https://karya.septalabs.com/guidelines>

## 1. Siapkan identitas dan penjelasan karya

| Kolom | Isi yang perlu disiapkan |
| --- | --- |
| Judul Lengkap — wajib | Nama proyek dan fungsi utamanya. |
| Rumpun Ilmu — wajib | Pilih kategori yang sesuai dengan proyek. |
| Tipe Spesifik — wajib | Pilih jenis karya pada daftar formulir. |
| Platform / Output | Platform dan bentuk hasil, dipisahkan koma. Contoh: `Android, APK`. |
| Ringkasan Singkat — wajib | Maksimal **300 karakter**, termasuk spasi. Jelaskan pengguna, fungsi, dan keunggulan yang benar-benar tersedia. |
| Deskripsi Lengkap — wajib | Latar belakang, tujuan, fitur, teknologi, hasil pengujian, manfaat, dan batas penggunaan. |
| Anggota / Undang Teman | Kosongkan untuk karya individu. Untuk kelompok, cantumkan anggota yang benar-benar berkontribusi. |

Gunakan hasil pengujian yang benar-benar dilakukan. Jangan mengisi tautan contoh sebagai tautan karya atau mengklaim fitur yang belum tersedia.

## 2. Siapkan gambar dan demo

| Berkas | Persyaratan formulir | Saran persiapan |
| --- | --- | --- |
| Thumbnail Cover — wajib | Rasio **16:9**, maksimal **2 MB**. | PNG/JPG 1920 × 1080; judul jelas dan tampilan produk nyata. |
| Logo / Icon App — wajib | Rasio **1:1**, maksimal **2 MB**. | PNG 1024 × 1024 dengan ikon yang sesuai proyek. |
| Screenshots — wajib | Maksimal **6 gambar**, masing-masing maksimal **2 MB**. | Pilih layar utama dan alur penting; gunakan contoh data. |
| Link YouTube (Demo) — wajib | Kolom menerima **ID video 11 karakter**. | Unggah MP4 ke YouTube terlebih dahulu. Pastikan video bisa dibuka oleh penilai. |

Untuk aplikasi, rekam cara menjalankan fungsi utamanya, bukan hanya slideshow. Video dapat memakai narasi atau keterangan teks. Hindari menampilkan password, pesan pribadi, informasi pelanggan, dan data pengguna nyata.

Pada URL `https://www.youtube.com/watch?v=XXXXXXXXXXX`, salin hanya nilai sesudah `v=`. Pada tautan `youtu.be/XXXXXXXXXXX`, salin ID sesudah garis miring. `XXXXXXXXXXX` hanya penanda pada panduan ini, bukan ID untuk dikirim.

## 3. Siapkan berkas hasil dan source

- Android: APK release yang berhasil dibangun dan memiliki tanda tangan valid.
- Website: tautan demo yang dapat dibuka; sertakan source bila ingin membagikannya.
- Source: ZIP atau repository berisi kode, konfigurasi contoh, daftar dependensi, dan README untuk menjalankan proyek.
- Dokumentasi: langkah instalasi, versi yang dibutuhkan, fitur, pengujian, dan batas penggunaan.

Sebelum membagikan source, keluarkan kredensial, `.env`, private key, keystore Android, `key.properties`, `local.properties`, data pribadi, cache, dan hasil build yang tidak diperlukan. Konfigurasi contoh harus memakai nilai placeholder.

Simpan kunci signing Android dan password pada cadangan pribadi. Kunci yang sama diperlukan untuk pembaruan APK; kunci tersebut tidak masuk ke paket publik.

## 4. Buat tautan yang dapat diakses

1. Unggah demo ke akun YouTube sendiri. Pilih **Tidak Publik / Unlisted** jika akses cukup melalui tautan; video Private tidak dapat ditonton semua penilai.
2. Unggah hasil aplikasi, source ZIP, dan petunjuk instalasi ke folder Google Drive, atau gunakan layanan pendukung yang sesuai.
3. Jika memakai Drive untuk berkas publik, atur akses **Siapa saja yang memiliki link → Pelihat** pada folder yang berisi berkas tersebut.
4. Salin tautan folder ke **Tautan Eksternal Pendukung**. Kolom ini wajib pada formulir yang diperiksa.
5. **Repository (Source Code)** tidak ditandai wajib pada formulir yang diperiksa. Isi URL repository yang benar jika tersedia; jika source dibagikan melalui Drive, kolom repository dapat dikosongkan.
6. Periksa video dan tautan pendukung dari jendela browser tanpa login untuk memastikan akses penilai.

## 5. Isi dan periksa formulir

1. Buka formulir pembuatan proyek dan isi identitas, ringkasan, serta deskripsi.
2. Pilih cover, logo, dan screenshot. Periksa preview serta batas ukuran tiap gambar.
3. Tempel **ID YouTube**, tautan pendukung, dan repository jika ada.
4. Isi anggota hanya jika karya kelompok.
5. Gunakan **Draft** bila masih ada isi yang belum siap. Gunakan **Kirim Sekarang** setelah berkas, informasi, dan akses tautan sudah diperiksa.

## Checklist sebelum dikirim

- [ ] Judul, kategori, tipe karya, dan platform sesuai proyek.
- [ ] Ringkasan tidak melebihi 300 karakter.
- [ ] Deskripsi menjelaskan masalah, fitur, teknologi, manfaat, pengujian, dan batas penggunaan.
- [ ] Cover 16:9 dan logo 1:1; keduanya tidak melebihi 2 MB.
- [ ] Screenshot berjumlah 1–6, masing-masing tidak melebihi 2 MB.
- [ ] Video menunjukkan fitur yang berjalan dan bisa diakses penilai.
- [ ] ID YouTube terdiri dari 11 karakter, tanpa URL lengkap.
- [ ] Tautan pendukung berisi berkas karya yang benar dan bisa dibuka tanpa akun pemilik.
- [ ] Source dapat dipahami lewat README dan tidak memuat kredensial atau data pribadi.
- [ ] Anggota sesuai status individu/kelompok.
- [ ] Seluruh tautan dan preview diperiksa sebelum menekan Kirim Sekarang.

## Template proyek berikutnya

```text
Judul lengkap:
Rumpun ilmu:
Tipe spesifik:
Platform / output:
Status karya: individu / kelompok
Anggota (jika kelompok):

Ringkasan singkat (maks. 300 karakter):

Deskripsi lengkap:
Latar belakang:
Tujuan:
Fitur utama:
Teknologi:
Hasil pengujian:
Manfaat:
Batas penggunaan:

Cover:
Logo:
Screenshots:
Video MP4:
ID YouTube:
Tautan eksternal pendukung:
Repository (opsional):
```

## Paket Catatan Kuliah

Dalam workspace aplikasi, paket proyek pertama berada di `artifacts/septalabs_upload/`. Jika membuka paket ZIP, gunakan folder hasil ekstraksinya. Buka `MULAI-DI-SINI.md` di dalam paket untuk daftar berkas dan isian yang sudah disiapkan khusus untuk Catatan Kuliah.
