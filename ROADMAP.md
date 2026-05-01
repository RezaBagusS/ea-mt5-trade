# 🗺️ Roadmap Pengembangan: EA MT5 Trade

Proyek ini dibagi menjadi 3 fase utama untuk memastikan transisi yang aman dari strategi di atas kertas hingga menjadi aset yang menghasilkan.

---

## 🏗️ FASE 1: Foundation & Alpha Testing (STATUS: IN PROGRESS)
**Tujuan:** Membangun core logic dan memvalidasi strategi di akun demo.

- [x] **Core Architecture**: Setup struktur MQL5 (OnTick, OnInit, OnDeinit).
- [x] **Strategy Implementation**: EMA Crossover (10/20) + RSI (14) Filter.
- [ ] **Risk Management Upgrade**: Implementasi Auto-Lot berdasarkan % risk.
- [ ] **Local Backtesting**: Uji coba menggunakan Strategy Tester (99% history quality).
- [ ] **Demo Forward Testing**: Menjalankan EA di akun demo broker selama minimal 2-4 minggu.

---

## 🚀 FASE 2: Production & Optimization (STATUS: PLANNED)
**Tujuan:** Migrasi ke akun real dan optimalisasi infrastruktur.

- [ ] **VPS Setup**: Instalasi MT5 di Windows VPS dengan latency rendah (< 5ms ke server broker).
- [ ] **Real Account Pilot**: Trading di akun real dengan modal kecil (Micro/Cent account) untuk cek slippage & eksekusi.
- [ ] **Performance Monitoring**: Integrasi dengan Myfxbook untuk tracking drawdown & profit factor secara publik.
- [ ] **News Filter**: Integrasi fungsi untuk menghindari trading saat High Impact News.
- [ ] **Auto-Alerts**: Notifikasi ke Telegram jika terjadi error atau posisi terbuka/tertutup.

---

## 💰 FASE 3: Scaling & Marketing (STATUS: PLANNED)
**Tujuan:** Monetisasi dan membangun reputasi.

- [ ] **MQL5 Market Listing**: Publikasi EA di marketplace resmi MQL5 (Free/Paid).
- [ ] **Copy Trading / Signal Service**: Membuka layanan sinyal di MQL5 Signals.
- [ ] **Community Building**: Pembuatan grup Telegram/Discord untuk edukasi dan update performa.
- [ ] **White Label / Licensing**: Sistem lisensi per account number untuk penjualan private.

---
*Dokumentasi diperbarui: 01 Mei 2026*
