# ZenithTrader EA 🏦🐳

**ZenithTrader v8.0 (Whale Hunter Edition)** is a professional-grade quantitative trading system for MetaTrader 5, specifically engineered to stabilize and grow small accounts (starting from $20) using institutional-grade methodologies.

## 🚀 Performance Highlights (EURUSD v8.0 - 1 Year)
- **Net Profit**: +71.0% ($14.20 profit from $20 initial)
- **Profit Factor**: 1.49
- **Max Drawdown**: 33.04% (Relative) / 11.96% (Absolute)
- **Total Trades**: 33 Trades (Selective & High Quality)
- **Win Rate**: 36.36% (12 Wins / 21 Losses)
- **Average Profit Trade**: $3.58
- **Average Loss Trade**: -$1.29
- **Reward/Risk Ratio**: ~2.77:1
- **Recovery Factor**: 0.84

## 🏛️ Trading Strategy: Candle Range Theory (CRT)
The EA utilizes **Candle Range Theory** to identify institutional expansion phases:
1. **Accumulation Detection**: Monitors price volatility using ATR.
2. **Whale Expansion**: Identifies monster candles (Range > 2.0x ATR, Body > 85%) indicating big bank entries.
3. **Institutional Discount (50% Retrace)**: Uses Limit Orders at the midpoint of expansion candles to ensure "Discount" entry prices.
4. **Double EMA Filter**: Only trades when 50 EMA and 200 EMA are aligned, filtering out 80% of whipsaws.

## 🛡️ Risk Management Features
- **Whale Protection**: Strict 2.0x ATR filter to avoid "noise".
- **Risk-Reward 1:4**: Designed to recover losses quickly with big single wins.
- **Daily Loss Limit**: Stops trading for the day after 2 consecutive losses.
- **Equity Lock**: Hard protection to prevent giving back profits after a successful run.

## ⚙️ Configuration
- **Timeframe**: M15 (Recommended)
- **Pairs**: EURUSD (Primary), GBPUSD (Secondary)
- **Min Balance**: $20 (Cent account recommended for safety)

## ⚖️ Disclaimer
Trading involves risk. This EA is a tool designed to assist in systematic trading. Always test on a demo account before going live.
