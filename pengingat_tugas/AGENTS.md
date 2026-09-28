# Catatan Developer & Lingkungan Kerja (AGENTS.md)

## Informasi Lingkungan Kerja (Environment)
- **Folder Project Baru**: `D:\apkpta\pengingat_tugas` (Dibuat tanpa spasi untuk menghindari bug Kotlin compiler daemon di drive eksternal).
- **Flutter SDK (Puro)**: `C:\Users\Lenovo\.puro\envs\stable\flutter` (Channel Stable, ~3.24/3.47).
- **Android SDK**: `C:\Users\Lenovo\AppData\Local\Android\Sdk`
- **JDK (Java Home)**: `C:\Users\Lenovo\AppData\Local\Programs\Eclipse Adoptium\jdk-25.0.2.10-hotspot`

## Perintah Penting (Build & Run)
Gunakan Environment Variables lengkap berikut saat menjalankan command di terminal:
```powershell
$env:JAVA_HOME = "C:\Users\Lenovo\AppData\Local\Programs\Eclipse Adoptium\jdk-25.0.2.10-hotspot"
$env:PATH = "C:\Users\Lenovo\AppData\Local\Programs\Eclipse Adoptium\jdk-25.0.2.10-hotspot\bin;" + $env:PATH
$env:ANDROID_HOME = "C:\Users\Lenovo\AppData\Local\Android\Sdk"
$env:PATH += ";C:\Users\Lenovo\AppData\Local\Android\Sdk\cmdline-tools\latest\bin;C:\Users\Lenovo\AppData\Local\Android\Sdk\platform-tools;C:\Users\Lenovo\.puro\envs\stable\flutter\bin"
```

Command build:
```powershell
flutter build apk --release
```

## Struktur Data
- **Hive Database**: Model `TaskModel` (Type ID: 0) menyimpan daftar tugas.
- **Alarm**: Menggunakan `flutter_local_notifications` dengan notifikasi full-screen-intent.

## Status Bug & Perbaikan
1. **DatePicker & TimePicker**: Error saat dibuka karena locale `id_ID` belum didaftarkan di `MaterialApp` (sedang difix menggunakan `flutter_localizations`).
2. **Suara Alarm Custom**: Ingin ditambahkan fitur memilih file audio custom `.mp3` dari HP lalu disalin ke internal app data, lalu diputar saat alarm berbunyi.
