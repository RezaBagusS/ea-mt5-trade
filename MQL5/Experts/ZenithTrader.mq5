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
input double InpLotSize          = 0.01;       // Fixed Lot (Best for $20)
input double InpMaxRiskUSD       = 1.50;       // Max Loss per Trade ($)
input int    InpMagicNumber      = 888888;     // Professional Magic
input int    InpMaxSpread        = 25;         // Max Spread in Points

input group "=== Strategy Settings ==="
input int    InpEMAPeriod        = 200;        // The Trend Filter
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
   // 1. Safety First: Position Check
   if(PositionSelectByMagic(InpMagicNumber))
   {
      // Trailing to BE after 1:1
      ManageSmartProtection();
      return;
   }

   // 2. Spread & Time Filters
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpread) return;
   
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.hour < InpStartHour || dt.hour > InpEndHour) return;
   
   if(!IsNewBar()) return;

   // 3. Technical Analysis (Clean & Pro)
   double ema[], rsi[];
   ArraySetAsSeries(ema, true);
   ArraySetAsSeries(rsi, true);
   
   if(CopyBuffer(handleEMA, 0, 0, 1, ema) < 1) return;
   if(CopyBuffer(handleRSI, 0, 0, 2, rsi) < 2) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, _Period, 0, 2, rates) < 2) return;

   double close = rates[0].close;
   bool isUptrend = close > ema[0];
   bool isDowntrend = close < ema[0];

   // 4. Execution Logic (Extreme Mean Reversion)
   // BUY: Uptrend + RSI(2) Extreme Oversold
   bool buySignal = isUptrend && rsi[0] < InpRSILower;
   // SELL: Downtrend + RSI(2) Extreme Overbought
   bool sellSignal = isDowntrend && rsi[0] > InpRSIUpper;

   // SL/TP based on ATR-like fixed precision for $20 account
   double slDist = 150 * _Point; // 15 pips
   double tpDist = 250 * _Point; // 25 pips (1:1.6 RR)

   if(buySignal)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      trade.Buy(InpLotSize, _Symbol, ask, ask - slDist, ask + tpDist, "Zenith v5 Buy");
   }
   else if(sellSignal)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      trade.Sell(InpLotSize, _Symbol, bid, bid + slDist, bid - tpDist, "Zenith v5 Sell");
   }
}

//+------------------------------------------------------------------+
void ManageSmartProtection()
{
   if(!PositionSelectByMagic(InpMagicNumber)) return;
   
   double profit = PositionGetDouble(POSITION_PROFIT);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   ulong ticket = PositionGetInteger(POSITION_TICKET);
   
   // Emergency Hard-Stop ($1.50 Loss)
   if(profit < -InpMaxRiskUSD)
   {
      trade.PositionClose(ticket);
      Print("!!! EMERGENCY: Risk Limit Hit. Position Closed.");
      return;
   }
   
   // Move to Break-Even after 15 pips profit
   double cur_sl = PositionGetDouble(POSITION_SL);
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      if(SymbolInfoDouble(_Symbol, SYMBOL_BID) - open > 150 * _Point && cur_sl < open)
         trade.PositionModify(ticket, open + 10 * _Point, PositionGetDouble(POSITION_TP));
   }
   else
   {
      if(open - SymbolInfoDouble(_Symbol, SYMBOL_ASK) > 150 * _Point && (cur_sl > open || cur_sl == 0))
         trade.PositionModify(ticket, open - 10 * _Point, PositionGetDouble(POSITION_TP));
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
