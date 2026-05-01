# ZenithTrader Live Execution Plan 🏦🛡️

## 1. Preparation Phase
- **Broker Choice**: Use an ECN broker with the tightest spreads possible (Raw Spreads).
- **Account Type**: **Cent Account** is highly recommended for $20 - $100 capital.
- **Symbol**: EURUSD.m (or equivalent low spread symbol).
- **Timeframe**: M15.

## 2. Risk Management Protocol (v8.0)
- **Lot Size**: Strictly 0.01 for every $20 of capital.
- **Daily Kill Switch**: If 2 losses occur in 24 hours, the EA must be turned off or left to its "Power of 2" logic.
- **Withdrawal Strategy**: Withdraw 50% of profits every time the account grows by 50%. (e.g., at $30, withdraw $5).

## 3. Monitoring Checklist
- [ ] Check Spread during London Open (If > 25, do not trade).
- [ ] Verify EMA 50 is above/below EMA 200.
- [ ] Monitor "Whale Expansion" candles on M15.
- [ ] Ensure VPS is running with < 50ms latency to broker server.

## 4. Emergency Procedures
- **Hard Close**: If balance drops below $14 (30% Drawdown), stop all trading and re-evaluate strategy.
- **News Event**: Turn off the EA 30 minutes before High Impact News (NFP, CPI, FOMC).
