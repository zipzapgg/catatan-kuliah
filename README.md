# Catatan Kuliah

Aplikasi Android berbasis Flutter untuk mengatur mata kuliah, tugas, catatan, kalender, dan e-learning Mentari secara offline.

Dibuat oleh **Ghalbi**. Watermark **© 2026 Ghalbi** tampil kecil di bawah navigasi aplikasi.

## Fitur versi 2

- Beranda monokrom dengan ringkasan tugas, progres, deadline terdekat, dan sesi Mentari.
- Empat halaman utama: Beranda, Tugas, Kalender, dan Mata kuliah; filter semester tersedia di setiap halaman.
- Mentari setiap minggu atau dua minggu, lengkap dengan tanggal/jam dibuka, deadline, akhir perkuliahan, tautan kelas, dan penanda selesai.
- Periode UTS/UAS per semester melewati sesi Mentari yang beririsan, tanpa menggeser pola jadwal setelah ujian.
- Kalender menggabungkan jadwal kelas, tugas, ujian, presentasi, dan Mentari.
- Preset kalender UNPAM Gasal 2026/2027: UTS 19–24 Oktober dan UAS 14–19 Desember 2026; tanggal akademik mahasiswa juga tampil di kalender.
- Bayaran dan cicilan: tanggal bayar, nominal rupiah opsional, pengingat H-3/H-1/hari bayar, penanda dibayar, edit, hapus, dan urungkan. Preset Reg. A/B: angsuran ke-3 & UTS 13 Oktober; pelunasan & UAS 8 Desember 2026.
- Deadline dengan jam, pilihan pengingat H-3/H-1/1 jam/saat deadline, prioritas, serta status Belum mulai → Dikerjakan → Siap dikumpulkan → Terkumpul.
- Tugas berulang harian, mingguan, atau dua mingguan. Menandai tugas terkumpul membuat satu tugas berikutnya dengan langkah yang kembali belum selesai.
- Deskripsi, langkah pengerjaan, foto/PDF (maksimal 10 MB per berkas), serta tautan pada detail tugas.
- Hapus satu tugas tanpa menghapus mata kuliah, dengan konfirmasi dan **Urungkan**. Catatan dan arsip mata kuliah tetap tersedia.
- Tema terang/gelap, formulir bergulir, dukungan teks besar, dan cadangan JSON yang divalidasi sebelum pemulihan.
- Impor PDF/JPG/PNG lokal untuk jadwal kuliah, tagihan, dan kalender akademik; ada pratinjau, pencocokan mata kuliah, koreksi, dan pemilihan baris sebelum diterapkan.

## Impor dokumen

Buka **Kalender → Impor PDF / gambar**, atau pilih menu yang sama pada tombol pengaturan. Pilih dokumen satu per satu, periksa semester tujuan dan hasilnya, lalu tekan **Terapkan data terpilih**. Pemilihan berkas belum mengubah data. Batas setiap dokumen adalah 20 MB dan 20 halaman.

PDF dengan teks dibaca langsung. PDF scan dan gambar memakai OCR Latin di perangkat; tidak memerlukan akun, API key, atau pengiriman dokumen ke server. Berkas sementara OCR dibersihkan setelah pembacaan. Aplikasi menyimpan data yang diterapkan; dokumen asli tidak menjadi lampiran otomatis.

- **Jadwal:** tabel UNPAM dengan kolom nama mata kuliah, hari, waktu, dosen, dan ruang. Posisi kolom dapat berpindah; nama beberapa baris tetap digabungkan. Periksa pilihan **Terapkan ke** untuk memperbarui mata kuliah yang sudah ada sambil mempertahankan tugas, catatan, dan Mentari.
- **Tagihan:** nomor tagihan dipakai untuk mencegah duplikasi. Nominal, status LUNAS/BELUM LUNAS, dan tanggal transaksi dikenali. **TGL BAYAR tidak dijadikan jatuh tempo.** Tagihan tanpa tanggal jatuh tempo dicatat tanpa alarm sampai tanggalnya diisi.
- **Kalender:** tanggal lengkap berbahasa Indonesia dibaca dari keterangan kegiatan. Pekan UTS/UAS mengubah jeda Mentari pada semester yang sama. Kegiatan lain tampil di kalender. Baris dengan tahun yang berbeda, angka OCR ambigu, atau administrasi dosen/PMB tidak dicentang otomatis. Periode ujian yang belum terbaca tidak mengganti periode yang sudah tersimpan.

Perubahan desain dokumen tidak menjamin semua baris tetap dikenali. Tabel sangat rapat, gambar buram, singkatan yang berbeda, atau tanggal tanpa tahun perlu pemeriksaan. Hasil OCR selalu diberi pemberitahuan. Tanggal atau baris tabel yang terdeteksi tetapi tidak lengkap dilaporkan; sebagian teks pada desain yang berbeda bisa tetap terlewat. Koreksi baris yang terdeteksi sebelum penerapan. Jadwal pembukaan/deadline Mentari per mata kuliah tetap diisi sesuai informasi dosen, karena tidak tersedia pada PDF jadwal kuliah.

Kelompok kelas dapat dipilih saat impor dan dikenali dari PDF jadwal. Reguler A adalah kelas pagi dengan Kamis libur; B adalah kelas malam Senin–Jumat; CK hanya Kamis; CS hanya Sabtu. Hari atau kegiatan yang tidak sesuai kelompok tidak dipilih otomatis. Jam tetap mengikuti PDF, tanpa mengarang batas jam pagi/malam. Pilihan kelompok berlaku untuk sesi impor tersebut.

## Mengatur Mentari

1. Buka **Mata kuliah**, lalu tambah atau edit mata kuliah.
2. Isi **Semester** dengan nama yang sama untuk mata kuliah dalam satu semester, lalu aktifkan **E-learning Mentari**.
3. Pilih **Setiap minggu** atau **Setiap 2 minggu**. Tentukan tanggal/jam pertama dibuka, deadline pertama, akhir perkuliahan, dan pengingat.
4. Di **Kalender → Atur UTS / UAS**, pilih semester dan rentang tanggal ujian. Seluruh mata kuliah dalam semester itu mengikuti periode yang sama.
5. Tandai sesi Mentari selesai untuk membatalkan sisa pengingat sesi tersebut. Gunakan tautan kelas untuk membukanya di browser.

Tanggal Mentari diisi manual; aplikasi tidak mengambil tugas atau kalender dari akun Mentari. Pola pengulangan dihitung dari tanggal pertama. Sesi yang deadline-nya melewati akhir perkuliahan tidak dibuat.

## Kalender UNPAM dan bayaran

Buka **Kalender → Kalender UNPAM Gasal 2026/2027 → Terapkan kalender UNPAM**. Mata kuliah aktif yang belum memiliki semester masuk ke semester UNPAM tersebut, periode ujian terisi, dan dua batas bayaran Reguler A/B ditambahkan. Mata kuliah semester lain serta jadwal bayaran yang sudah ada tidak ditimpa. Menjalankan preset lagi tidak membuat bayaran ganda.

Untuk Mentari baru pada semester UNPAM, tanggal awal bawaan adalah 31 Agustus 2026 (awal Reg. A/B). Batas akhir bawaan 13 Desember adalah pilihan praktis agar Mentari berhenti sebelum UAS, **bukan tanggal akhir semester resmi**. Sesuaikan pertemuan pertama, frekuensi, deadline, dan batas akhir dengan kelas/dosen. Kalender sumber mencantumkan akhir semester pada 5 dan 6 Februari 2027; aplikasi menampilkan kedua tanggal tersebut.

Buka **Beranda atau Kalender → Bayaran & cicilan** untuk menambah angsuran lain, mengisi nominal, atau menandai dibayar. Tanggal dan nominal cicilan pertama/kedua tidak diasumsikan karena tidak tercantum pada kalender. Pengingat bawaan berbunyi H-3, H-1, dan hari bayar pukul 09.00; jam ini mengatur notifikasi, bukan batas layanan pembayaran kampus. Pengingat tersisa dibatalkan ketika bayaran ditandai sudah dibayar atau dihapus. Status tidak disinkronkan dengan SIA/bank.

Acuan kalender berasal dari gambar UNPAM Gasal 2026/2027 yang diberikan pengguna. Tanggal susulan, herregistrasi, libur akhir tahun, revisi KRS, dan awal semester genap ditampilkan sebagai informasi; jeda Mentari hanya mengikuti pekan UTS/UAS utama. Baris Natal pada gambar mencantumkan tahun 2025 di bagian Desember 2026, sehingga dua tanggal yang tidak konsisten tersebut tidak dimasukkan otomatis. Jadwal PMB dan administrasi dosen tidak dimasukkan.

## Data dan pengingat

Data versi 1 dibaca tanpa menghapus mata kuliah, tugas, status selesai, atau catatan. Deadline relatif lama seperti "Besok" menjadi tanggal tetap berdasarkan tanggal pembuatan. Keterangan bebas seperti "Sebelum UTS" tetap bisa disimpan tetapi tidak menghasilkan pengingat bertanggal.

Izinkan notifikasi Android agar pengingat tampil. Pengingat memakai alarm lokal; penghematan baterai Android dapat menunda waktu tampil. Jadwal dibatalkan saat tugas dihapus/diselesaikan, mata kuliah diarsipkan, sesi Mentari selesai, atau periode ujian berubah. Maksimal 450 pengingat terdekat dijadwalkan sekaligus; aplikasi memberi pesan jika batas terlampaui.

Cadangan JSON mencakup data tugas dan informasi lampiran/tautan. **Isi foto/PDF tetap tersimpan di perangkat dan belum disertakan dalam cadangan JSON.** Setelah pindah perangkat, lampirkan kembali berkasnya. Simpan keystore dan cadangan pribadi di luar source yang dibagikan.

Bayaran, kegiatan akademik hasil impor, dan data kuliah disimpan bersama dalam satu perubahan, serta ikut cadangan JSON versi 2. Cadangan lama berbentuk daftar masih diterima. Pemulihan mengganti seluruh data: bagian bayaran/kegiatan yang tidak tersedia pada cadangan lama akan dikosongkan.

## Menjalankan dan menguji

Lingkungan pengujian: Flutter 3.41.4, Dart 3.11.1, JDK 17.

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter run
```

Tes mencakup kegagalan penyimpanan, perubahan bersamaan, hapus/urungkan, impor tidak valid, migrasi data, pengulangan tanpa duplikasi, pola Mentari, jeda UTS/UAS, rencana pengingat, parser tanggal/rupiah, tabel dokumen, dan penerapan impor secara atomik. Layout diuji pada empat ukuran layar, kedua tema, dan skala teks 1× serta 2×. Screenshot tes memakai data contoh, bukan data pengguna.

## Build Android

```powershell
.\scripts\build_android.ps1 -Mode debug
.\scripts\build_android.ps1 -Mode release
```

Script menggunakan Java dari PATH hanya untuk proses build. Gunakan parameter `-Jdk` untuk menunjuk JDK 17/21 yang kompatibel jika diperlukan. Hasil APK berada di `build/app/outputs/flutter-apk/`.

Untuk distribusi, salin `android/key.properties.example` menjadi `android/key.properties` dan isi keystore milikmu. File kunci dan kata sandi dikecualikan dari Git. Build release tanpa keystore tidak otomatis ditandatangani dengan kunci debug. Lihat [panduan signing Flutter](https://docs.flutter.dev/deployment/android#sign-the-app).

Folder `artifacts`, `.private`, dan `.test-temp` berisi hasil kerja lokal dan tidak termasuk source publik.
