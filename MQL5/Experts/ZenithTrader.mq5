//+------------------------------------------------------------------+
//|                                              ZenithTrader.mq5    |
//|                                  Copyright 2026, Antigravity AI  |
//|                                      Version 5.0 (Masterclass)   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property version   "5.0"
#property strict

#include <Trade\Trade.mqh>

//--- INPUTS
input group "=== Risk Management ==="
input double InpLotSize      = 0.01;      // Lot Size
input double InpMaxRiskUSD   = 1.5;       // Max Loss per Position ($)
input int    InpMagicNumber  = 888888;    // Magic Number
input int    InpStartHour    = 8;         // Session Start (UTC)
input int    InpEndHour      = 16;        // Session End (UTC)
input int    InpMaxSpread    = 25;        // Max Spread in Points

input group "=== Strategy Settings ==="
input int    InpEMAPeriod        = 200;        // The Trend Filter (M30 Recommended)
input int    InpRSIPeriod        = 2;          // The Sniper (Fast RSI)
input int    InpRSIUpper         = 90;         // Overbought
input int    InpRSILower         = 10;         // Oversold

input group "=== Session Settings (UTC) ==="
input int    InpStartHour        = 12;         // London Open (UTC)
input int    InpEndHour          = 18;         // NY Overlap (UTC)

//--- GLOBALS
CTrade      trade;
int         handleEMA;
int         handleRSI;

//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   handleEMA = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   
   if(handleEMA == INVALID_HANDLE || handleRSI == INVALID_HANDLE) return INIT_FAILED;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   IndicatorRelease(handleEMA);
   IndicatorRelease(handleRSI);
}

//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Session Filter: Only trade during London/NY (UTC)
   MqlDateTime dt;
   TimeTradeServer(dt);
   bool isSession = (dt.hour >= InpStartHour && dt.hour < InpEndHour);

   // 2. Safety First: Position Check
   if(PositionSelectByMagic(InpMagicNumber))
   {
      ManageSmartProtection();
      return;
   }

   if(!isSession) 
   {
      CleanOldOrders(); // Clear pending orders outside session
      return;
   }

   // 3. Volatility Data (ATR for Range Baseline)
   double atrBuf[]; ArraySetAsSeries(atrBuf, true);
   int hATR = iATR(_Symbol, _Period, 14);
   if(CopyBuffer(hATR, 0, 0, 1, atrBuf) < 1) { IndicatorRelease(hATR); return; }
   double avgRange = atrBuf[0];
   IndicatorRelease(hATR);

   if(!IsNewBar()) return;

   // 3. Technical Analysis (Whale Hunter)
   MqlRates rates[]; ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 3, rates) < 3) return;

   double ema200[], ema50[]; 
   ArraySetAsSeries(ema200, true); ArraySetAsSeries(ema50, true);
   int hEMA50 = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   if(CopyBuffer(handleEMA, 0, 0, 1, ema200) < 1) return;
   if(CopyBuffer(hEMA50, 0, 0, 1, ema50) < 1) { IndicatorRelease(hEMA50); return; }
   IndicatorRelease(hEMA50);

   // WHALE FILTER: Monster Expansion (> 2.0x ATR)
   double candleRange = rates[1].high - rates[1].low;
   double candleBody  = MathAbs(rates[1].close - rates[1].open);
   
   bool isWhaleExpansion = (candleRange > avgRange * 2.0) && (candleBody / candleRange > 0.85);
   bool isBullish        = rates[1].close > rates[1].open;
   bool isBearish        = rates[1].close < rates[1].open;
   
   bool isTrendUp   = rates[0].close > ema200[0] && ema50[0] > ema200[0];
   bool isTrendDown = rates[0].close < ema200[0] && ema50[0] < ema200[0];

    // 4. Multi-Adaptive Entry Logic (Whale Hunter)
   double midPoint = rates[1].low + (candleRange / 2.0);
   double buffer = (_Symbol == "GBPUSD") ? 100 * _Point : 30 * _Point; // Wider buffer for GBP
   
   if(isWhaleExpansion && isBullish && isTrendUp)
   {
      double sl = rates[1].low - buffer; 
      double risk = midPoint - sl;
      double tp = midPoint + (risk * 4.0); // 1:4 RR
      
      CleanOldOrders();
      trade.BuyLimit(InpLotSize, midPoint, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Zenith v8.1 Adaptive");
   }
   else if(isWhaleExpansion && isBearish && isTrendDown)
   {
      double sl = rates[1].high + buffer;
      double risk = sl - midPoint;
      double tp = midPoint - (risk * 4.0); // 1:4 RR
      
      CleanOldOrders();
      trade.SellLimit(InpLotSize, midPoint, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "Zenith v8.1 Adaptive");
   }
}

void CleanOldOrders()
{
   for(int i=OrdersTotal()-1; i>=0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(OrderSelect(ticket) && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         trade.OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
void ManageSmartProtection()
{
   if(!PositionSelectByMagic(InpMagicNumber)) return;
   
   double profit = PositionGetDouble(POSITION_PROFIT);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double cur_sl = PositionGetDouble(POSITION_SL);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   ulong ticket = PositionGetInteger(POSITION_TICKET);
   long type = PositionGetInteger(POSITION_TYPE);
   
   if(profit < -InpMaxRiskUSD) { trade.PositionClose(ticket); return; }
   
   // TIME-EXIT: Expansion should be fast. Close after 8 bars (2 hours on M15)
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   if(TimeCurrent() - openTime > 8 * 15 * 60) {
      if(profit > 0) { trade.PositionClose(ticket); return; } // Take small win
   }

   // ADAPTIVE BREAK-EVEN: Move to BE only after 1.5x Risk (to avoid GBP whipsaws)
   double riskSize = MathAbs(open - cur_sl);
   if(type == POSITION_TYPE_BUY) {
      if(bid - open > riskSize * 1.5 && cur_sl < open)
         trade.PositionModify(ticket, open + 20 * _Point, PositionGetDouble(POSITION_TP));
   } else {
      if(open - ask > riskSize * 1.5 && (cur_sl > open || cur_sl == 0))
         trade.PositionModify(ticket, open - 20 * _Point, PositionGetDouble(POSITION_TP));
   }
}

bool IsNewBar()
{
   static datetime last_time = 0;
   datetime lastbar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(last_time != lastbar_time) { last_time = lastbar_time; return true; }
   return false;
}

bool PositionSelectByMagic(long magic)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == magic && PositionGetString(POSITION_SYMBOL) == _Symbol)
            return true;
      }
   }
   return false;
}
