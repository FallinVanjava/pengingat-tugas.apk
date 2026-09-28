# Kebijakan Keamanan (Security Policy)

## 🛡️ Komitmen Keamanan
Proyek **Pengingat Tugas** dirancang dengan prinsip *Privacy by Design* dan arsitektur *Zero Cloud Dependency (100% Offline-First)*. Keamanan dan integritas data pengguna adalah prioritas utama.

---

## 🔒 Arsitektur Keamanan & Standar Kriptografi

### 1. Autentikasi & Penyimpanan Kredensial
- **Password Hashing**: Menggunakan algoritma **SHA-256** standar industri (`crypto` package) untuk memastikan kata sandi pengguna tidak pernah disimpan dalam format teks polos (*plaintext*).
- **Isolasi Basis Data**: Data tugas (`TaskModel`) dipisahkan ke dalam kotak penyimpanan *Hive* independen untuk setiap *User ID* (`tasks_{userId}`), mencegah kebocoran data antar-pengguna pada perangkat yang sama.

### 2. Autentikasi Biometrik
- Menggunakan API autentikasi native sistem operasi melalui plugin `local_auth`.
- **Android**: Didukung oleh `BiometricManager` dan `KeyguardManager` dengan pembatasan `biometricOnly: true`.
- **iOS**: Terintegrasi langsung dengan `LocalAuthentication framework` (`LAContext`) untuk verifikasi aman **Face ID** dan **Touch ID**.

### 3. Izin Aplikasi (*Principle of Least Privilege*)
- **Android**:
  - `POST_NOTIFICATIONS`: Wajib untuk Android 13+ (API 33).
  - `SCHEDULE_EXACT_ALARM` & `USE_EXACT_ALARM`: Dibatasi hanya untuk ketepatan penjadwalan alarm.
  - `USE_FULL_SCREEN_INTENT`: Membuka layar alarm darurat saat layar terkunci.
  - `READ_MEDIA_AUDIO`: Akses hanya baca pada file audio kustom yang dipilih oleh pengguna (*scoped access*).
- **iOS**:
  - `NSFaceIDUsageDescription`: Akses biometrik dengan izin eksplisit dari pengguna.
  - `NSPhotoLibraryUsageDescription` & `NSAppleMusicUsageDescription`: Akses file audio kustom sesuai kebutuhan.

### 4. Perlindungan Data & Privasi
- Aplikasi tidak mengumpulkan telemetri pengguna, tidak mengirim analitik ke server pihak ketiga, dan tidak menggunakan jaringan internet untuk operasional aplikasi inti.
- Semua data tersimpan secara lokal pada memori internal terisolasi perangkat (*App Sandbox*).

---

## 🚨 Pelaporan Kerentanan Keamanan (Vulnerability Reporting)

Jika Anda menemukan potensi kerentanan keamanan (*security vulnerability*) pada proyek ini, mohon untuk **TIDAK** membuka isu publik di GitHub Issues.

Silakan laporkan secara bertanggung jawab (*Responsible Disclosure*) melalui:
- **Email**: `fadhilwae73@gmail.com`
- **Subjek**: `[SECURITY VULNERABILITY] Pengingat Tugas - <Deskripsi Singkat>`

### Informasi yang Dibutuhkan:
1. Deskripsi rinci mengenai kerentanan yang ditemukan.
2. Langkah-langkah untuk mereproduksi celah keamanan (*Proof of Concept*).
3. Versi aplikasi dan perangkat pengujian (misal: Android 14 / iOS 17).
4. Dampak potensial dari eksploitasi celah tersebut.

Tim pengembang akan menanggapi laporan Anda dalam waktu **1 x 24 jam** dan memberikan pembaruan rutin hingga perbaikan dirilis.
