# 🚀 EA MT5 Live Production & Marketing Plan

Dokumen ini merinci langkah operasional untuk membawa EA dari tahap development ke pasar real dan strategi monetisasi.

---

## 💰 1. Rincian Estimasi Biaya (Monthly OpEx)

### Skala Pilot (1 - 2 Akun Real)
*Fokus pada stabilitas eksekusi.*

| Komponen | Layanan | Biaya (Estimasi) |
| :--- | :--- | :--- |
| **Hosting** | Windows VPS (Standard - 2GB RAM) | Rp 150.000 - 250.000 |
| **Data Feed** | Real-time dari Broker (Demo/Real) | Gratis (Included in Account) |
| **Monitoring** | Myfxbook / MQL5 Signals | Gratis |
| **TOTAL** | | **~Rp 200.000 / bln** |

### Skala Commercial (Public Signal / Sales)
*Fokus pada skalabilitas dan kepercayaan publik.*

| Komponen | Layanan | Biaya (Estimasi) |
| :--- | :--- | :--- |
| **Hosting** | Windows VPS (Optimized - Low Latency) | Rp 400.000 |
| **Marketing** | Social Media Ads / Community Collab | Rp 500.000+ |
| **MQL5 Seller** | Pendaftaran Seller MQL5 (Sekali bayar) | ~$100 (Opsional) |
| **TOTAL** | | **~Rp 900.000++ / bln** |

---

## 🏗️ 2. Langkah Strategis (Deployment Roadmap)

### Phase 1: Infrastructure Readiness
1.  **Pilih Broker**: Gunakan broker ECN/Raw Spread untuk EA scalping (misal: IC Markets, Pepperstone, atau Exness).
2.  **VPS Deployment**: Gunakan VPS yang lokasinya dekat dengan datacenter broker (biasanya London LD4 atau New York NY4).
3.  **Terminal Sync**: Pastikan setting "Allow Automated Trading" dan "Allow WebRequest" (jika perlu) aktif.

### Phase 2: Risk Management (Production Mode)
1.  **Equity Protection**: Implementasi fitur "Emergency Stop" jika drawdown melebihi batas (misal 10%).
2.  **Max Lot Restriction**: Membatasi ukuran lot maksimal untuk mencegah fatal error code.
3.  **Daily Log Backup**: Export log MT5 secara berkala untuk audit jika terjadi anomali harga.

---

## 📈 3. Strategi Marketing & Monetisasi

### A. Proof of Performance (Trust)
- **MQL5 Signals**: Publikasikan performa akun real ke komunitas global MQL5. Ini adalah bukti paling valid (Verified History).
- **Myfxbook Dashboard**: Sediakan link publik ke dashboard Myfxbook dengan setting privasi yang tepat.

### B. Revenue Streams
1.  **Subscription Fee**: Biaya bulanan untuk menyalin sinyal (Copy Trading).
2.  **Product Sales**: Menjual file `.ex5` di marketplace MQL5 (Sekali beli).
3.  **Affiliate/IB**: Mengarahkan user menggunakan broker tertentu melalui link IB untuk mendapatkan rebate per transaksi.

---

## 🛡️ 4. Risk Management & Compliance
- **Disclaimers**: Sertakan pernyataan risiko (Risk Disclosure) di setiap kanal marketing.
- **Support System**: Sediakan bot Telegram untuk bantuan teknis dan update versi EA.
- **Versioning**: Gunakan semantic versioning (misal v1.0, v1.1) untuk memudahkan tracking update strategi.

---
*Dokumen ini diperbarui secara berkala sesuai performa EA di pasar.*
