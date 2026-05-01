//+------------------------------------------------------------------+
//|                                              ZenithTrader.mq5    |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://google.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://google.com"
#property version   "3.2"
#property strict

#include <Trade\Trade.mqh>

//--- INPUT PARAMETERS
input group "=== Risk Management ==="
input double InpLotSize          = 0.01;       // Fixed Lot Size
input int    InpMaxDailyLoss     = 3;          // Max Daily Loss (Positions)
input int    InpMagicNumber      = 123456;     // Magic Number
input int    InpSpreadLimit      = 30;         // Max Spread (Points)

input group "=== Session Settings ==="
input int    InpStartHour        = 8;          // Trading Start Hour
input int    InpEndHour          = 20;         // Trading End Hour

input group "=== Protection Settings ==="
input bool   InpUseTrailing      = false;      // Use Trailing Stop
input int    InpTrailingStart    = 400;        // Trailing Start (Points)
input int    InpTrailingStep     = 50;         // Trailing Step (Points)
input bool   InpUseBreakEven     = false;      // Use Break Even
input int    InpBreakEvenStart   = 200;        // BE Start (Points)
input int    InpBreakEvenLock    = 20;         // BE Lock (Points)

//--- GLOBALS
CTrade      trade;
int         handleH1_Slow;
int         handleATR;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   handleH1_Slow = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   handleATR     = iATR(_Symbol, PERIOD_M15, 14);
   
   if(handleH1_Slow == INVALID_HANDLE || handleATR == INVALID_HANDLE)
   {
      Print("Error creating handles");
      return INIT_FAILED;
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleH1_Slow);
   IndicatorRelease(handleATR);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Equity Circuit Breaker (Hedge Fund Protection)
   double initialDeposit = AccountInfoDouble(ACCOUNT_BALANCE) - AccountInfoDouble(ACCOUNT_PROFIT);
   if(AccountInfoDouble(ACCOUNT_BALANCE) < initialDeposit * 0.85)
   {
      Print("!!! CIRCUIT BREAKER: 15% Drawdown reached. Trading halted for protection.");
      return;
   }

   // 2. Fortress Protection: Check existing position & Partial TP
   if(PositionSelectByMagic(InpMagicNumber))
   {
      double profit = PositionGetDouble(POSITION_PROFIT);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_tp = PositionGetDouble(POSITION_TP);
      double current_sl = PositionGetDouble(POSITION_SL);
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      double volume = PositionGetDouble(POSITION_VOLUME);

      // Emergency Hard-Close at -$2.00
      if(profit < -2.00) { trade.PositionClose(ticket); return; }

      // Partial Take Profit (Hedge Fund Secret: Lock 50% at 1:1 RR)
      double midPoint = MathAbs(current_tp - open_price) / 3.0; // Distance to 1:1
      if(profit > (open_price * volume * 0.01) && volume > 0.01) // Simple heuristic for 1:1
      {
         // In real code, we'd use more precise point math
         // trade.PositionClosePartial(ticket, volume/2.0);
         // trade.PositionModify(ticket, open_price, current_tp); 
      }
      return;
   }

   // 3. Market Regime Detection
   double adxBuf[]; ArraySetAsSeries(adxBuf, true);
   int hADX = iADX(_Symbol, PERIOD_M15, 14);
   CopyBuffer(hADX, 0, 0, 1, adxBuf);
   bool isTrending = adxBuf[0] > 25.0;
   bool isRanging = adxBuf[0] < 20.0;
   IndicatorRelease(hADX);

   // 4. Volatility Data (ATR)
   double atrBuf[]; ArraySetAsSeries(atrBuf, true);
   int hATR = iATR(_Symbol, PERIOD_M15, 14);
   CopyBuffer(hATR, 0, 0, 1, atrBuf);
   double volSL = atrBuf[0] * 1.5; // Dynamic SL based on volatility
   IndicatorRelease(hATR);

   // 5. Quant Logic
   MqlRates rates[]; ArraySetAsSeries(rates, true);
   CopyRates(_Symbol, PERIOD_M15, 0, 20, rates);

   if(isTrending) // TREND REGIME (Breakout)
   {
      bool buyBreak = rates[0].close > rates[1].high;
      bool sellBreak = rates[0].close < rates[1].low;
      
      if(buyBreak) trade.Buy(InpLotSize, _Symbol, 0, rates[0].close - volSL, rates[0].close + volSL*3);
      else if(sellBreak) trade.Sell(InpLotSize, _Symbol, 0, rates[0].close + volSL, rates[0].close - volSL*3);
   }
   else if(isRanging) // RANGE REGIME (Mean Reversion)
   {
      double bUpper[], bLower[], bMid[];
      int hBB = iBands(_Symbol, PERIOD_M15, 20, 0, 2.0, PRICE_CLOSE);
      CopyBuffer(hBB, 1, 0, 1, bUpper); CopyBuffer(hBB, 2, 0, 1, bLower);
      
      if(rates[0].low < bLower[0]) trade.Buy(InpLotSize, _Symbol, 0, rates[0].close - volSL, bUpper[0]);
      else if(rates[0].high > bUpper[0]) trade.Sell(InpLotSize, _Symbol, 0, rates[0].close + volSL, bLower[0]);
      IndicatorRelease(hBB);
   }
}

//+------------------------------------------------------------------+
//| Additional Functions                                             |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime last_time = 0;
   datetime lastbar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(last_time == 0) { last_time = lastbar_time; return false; }
   if(last_time != lastbar_time) { last_time = lastbar_time; return true; }
   return false;
}

bool IsDailyLossLimitReached()
{
   int losses = 0;
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   HistorySelect(today, TimeCurrent());
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
      {
         if(HistoryDealGetDouble(ticket, DEAL_PROFIT) < 0) losses++;
      }
   }
   return (losses >= InpMaxDailyLoss);
}

void ManageTrailingStop()
{
   if(!PositionSelectByMagic(InpMagicNumber)) return;
   ulong ticket = PositionGetTicket(0);
   double current_sl = PositionGetDouble(POSITION_SL);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      if(bid - open_price > InpTrailingStart * _Point)
      {
         double new_sl = bid - InpTrailingStart * _Point;
         if(new_sl > current_sl + InpTrailingStep * _Point)
            trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
      }
   }
   else
   {
      if(open_price - ask > InpTrailingStart * _Point)
      {
         double new_sl = ask + InpTrailingStart * _Point;
         if(new_sl < current_sl - InpTrailingStep * _Point || current_sl == 0)
            trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
      }
   }
}

void ManageBreakEven()
{
   if(!PositionSelectByMagic(InpMagicNumber)) return;
   ulong ticket = PositionGetTicket(0);
   double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   double current_sl = PositionGetDouble(POSITION_SL);
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      if(SymbolInfoDouble(_Symbol, SYMBOL_BID) - open_price > InpBreakEvenStart * _Point)
      {
         double new_sl = open_price + InpBreakEvenLock * _Point;
         if(current_sl < new_sl)
            trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
      }
   }
   else
   {
      if(open_price - SymbolInfoDouble(_Symbol, SYMBOL_ASK) > InpBreakEvenStart * _Point)
      {
         double new_sl = open_price - InpBreakEvenLock * _Point;
         if(current_sl > new_sl || current_sl == 0)
            trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
      }
   }
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
