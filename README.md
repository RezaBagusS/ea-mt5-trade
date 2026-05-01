# 💹 EA MT5 Trade: Forex Automated Trading System

Proyek ini bertujuan untuk membangun **Expert Advisor (EA)** profesional untuk platform **MetaTrader 5 (MT5)** yang difokuskan pada pasar Forex. Sistem ini menggunakan strategi **EMA Crossover with RSI Filter**.

## 🎯 Visi Proyek
Menciptakan asisten trading otomatis yang stabil, transparan, dan dapat diandalkan untuk jangka panjang menggunakan pendekatan konfirmasi tren ganda.

## 🛠️ Tech Stack
- **Language**: MQL5 (MetaQuotes Language 5)
- **Platform**: MetaTrader 5 Desktop
- **Infrastructure**: Windows VPS (for 24/7 execution)
- **Monitoring**: MQL5 Signals / Myfxbook

## 📊 Strategi & Analisa (v1.10)
- **Core Logic**: EMA Fast (10) & EMA Slow (20) Crossover.
- **Filter**: RSI (14) Level 50 (Momentum confirmation).
- **Timeframe**: H1 (Recommended).
- **Supported Pairs**: EURUSD, GBPUSD, USDJPY, EURJPY, GBPJPY.
- **Risk Management**: Fixed Lot, Stop Loss, and Take Profit (Alpha version).

## 📁 Struktur Folder
- `/MQL5`: Berisi source code `.mq5` dan include files `.mqh`.
- `/Presets`: Set file `.set` untuk optimasi parameter di berbagai pair.
- `/Docs`: Dokumentasi strategi dan jurnal riset.
- `ROADMAP.md`: Rencana pengembangan fitur.
- `plan-live.md`: Rencana produksi, biaya, dan marketing.

---
*Status: Fase 1 - Alpha Development (Demo Testing)*
