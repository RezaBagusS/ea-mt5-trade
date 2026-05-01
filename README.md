# 💹 EA MT5 Trade: Forex Automated Trading System

Proyek ini bertujuan untuk membangun **Expert Advisor (EA)** profesional untuk platform **MetaTrader 5 (MT5)** yang difokuskan pada pasar Forex. Sistem ini menggunakan strategi **EMA Crossover with RSI Filter**.

## 🎯 Visi Proyek
Menciptakan asisten trading otomatis yang stabil, transparan, dan dapat diandalkan untuk jangka panjang menggunakan pendekatan konfirmasi tren ganda.

## 🛠️ Tech Stack & Strategy
- **Platform**: MetaTrader 5 (MQL5)
- **Primary Pair**: Major Forex Pairs (EURUSD, GBPUSD, etc.)
- **Timeframe**: H1 (Signal) & H4 (Trend Filter)
- **Indicators**: 
  - **EMA 10/20 Crossover**: Core signal trigger.
  - **Stochastic RSI**: Momentum filter (OS > 20, OB < 80).
  - **H4 EMA 200**: Trend filter (only take H1 signals in H4 direction).
  - **ATR (14)**: Dynamic SL (1.5x) and TP (3.0x) calculation.
- **Risk Management**: 
  - Auto-Lot (Dynamic based on % Risk).
  - Break Even & Trailing Stop logic.

## 📊 Performance (Alpha Results)
Berdasarkan backtest data kualitas 100%:
- **Profit Factor**: 2.03
- **Win Rate**: 60.00%
- **Max Drawdown**: 4.95%
- **R:R Ratio**: 1:2 (Dynamic)

## 📁 Struktur Folder
- `/MQL5`: Berisi source code `.mq5` dan include files `.mqh`.
- `/Presets`: Set file `.set` untuk optimasi parameter di berbagai pair.
- `/Docs`: Dokumentasi strategi dan jurnal riset.
- `ROADMAP.md`: Rencana pengembangan fitur.
- `plan-live.md`: Rencana produksi, biaya, dan marketing.

---
*Status: Fase 1 - Alpha Development (Demo Testing)*
