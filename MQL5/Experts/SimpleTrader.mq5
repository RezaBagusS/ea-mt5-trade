//+------------------------------------------------------------------+
//|                                                 SimpleTrader.mq5 |
//|                                  Copyright 2026, Antigravity AI  |
//|                                             https://github.com/  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity AI"
#property link      "https://github.com/"
#property version   "1.10"
#property strict

//--- include trade class
#include <Trade\Trade.mqh>

//--- input parameters
input group "=== Risk Management ==="
input bool     InpUseAutoLot   = true;      // Use Auto Lot (% Risk)
input double   InpRiskPercent  = 1.0;       // Risk Percent per Trade (%)
input double   InpLotSize      = 0.01;      // Fixed Lot Size (if Auto Lot is false)
input bool     InpForceMinLot  = true;      // Force 0.01 Lot on Small Accounts
input bool     InpUseATR_Exit  = true;      // Use ATR for SL/TP
input double   InpATR_Multiplier_SL = 1.0;  // ATR SL
input double   InpATR_Multiplier_TP = 1.5;  // ATR TP (Sniper R:R 1:1.5)
input int      InpStopLoss     = 100;       // Fixed SL
input int      InpTakeProfit   = 150;       // Fixed TP
input int      InpMagicNumber  = 123456;    // Magic Number

input group "=== Break Even Settings ==="
input bool     InpUseBreakEven = false;     // Disable BE for M15 (Recommended)
input int      InpBreakEvenStart = 500;     // BE Start (Points)
input int      InpBreakEvenLock = 20;       // BE Lock (Points)

input group "=== Trailing Stop Settings ==="
input bool     InpUseTrailing  = true;      // Use Trailing Stop (Safety)
input int      InpTrailingStart = 400;      // Start Trailing
input int      InpTrailingStep  = 20;       // Trailing Step

input group "=== Strategy Settings (M15 Scalp / H1 Trend Master) ==="
input int      InpH1_Fast      = 14;        // H1 Fast HMA
input int      InpH1_Slow      = 28;        // H1 Slow HMA
input int      InpM15_Fast     = 7;         // M15 Fast HMA (Pullback Entry)
input int      InpM15_Slow     = 21;        // M15 Slow HMA

input group "=== Momentum (StochRSI) ==="
input int      InpStochRSIPer  = 14;        // StochRSI Period
input int      InpKPeriod      = 3;         // %K Smoothing
input int      InpDPeriod      = 3;         // %D Smoothing
input int      InpOSLevel      = 20;        // Oversold
input int      InpOBLevel      = 80;        // Overbought

input group "=== Session & Protection ==="
input int      InpStartHour    = 8;         // Start Hour
input int      InpEndHour      = 22;        // End Hour
input int      InpMaxDailyLoss = 3;         // Max Daily Loss

//--- global variables
int      handleM15_Fast;
int      handleM15_Slow;
int      handleH1_Fast;
int      handleH1_Slow;
int      handleRSI;
int      handleATR;
int      handleADX;
CTrade   trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // M15 Handles
   handleM15_Fast = iMA(_Symbol, PERIOD_M15, InpM15_Fast, 0, MODE_LWMA, PRICE_CLOSE);
   handleM15_Slow = iMA(_Symbol, PERIOD_M15, InpM15_Slow, 0, MODE_LWMA, PRICE_CLOSE);
   
   // H1 Handles (Trend Master)
   handleH1_Fast  = iMA(_Symbol, PERIOD_H1, InpH1_Fast, 0, MODE_LWMA, PRICE_CLOSE);
   handleH1_Slow  = iMA(_Symbol, PERIOD_H1, InpH1_Slow, 0, MODE_LWMA, PRICE_CLOSE);

   handleRSI     = iRSI(_Symbol, PERIOD_M15, InpStochRSIPer, PRICE_CLOSE);
   handleATR     = iATR(_Symbol, PERIOD_M15, 14);
   handleADX     = iADX(_Symbol, PERIOD_M15, 14);
   
   if(handleM15_Fast == INVALID_HANDLE || handleM15_Slow == INVALID_HANDLE || 
      handleH1_Fast == INVALID_HANDLE || handleH1_Slow == INVALID_HANDLE ||
      handleRSI == INVALID_HANDLE || handleATR == INVALID_HANDLE || handleADX == INVALID_HANDLE)
   {
      Print("Error initializing indicators");
      return(INIT_FAILED);
   }

   Print("EA H1-M15 Sync Master Initialized (v1.84)");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleM15_Fast);
   IndicatorRelease(handleM15_Slow);
   IndicatorRelease(handleH1_Fast);
   IndicatorRelease(handleH1_Slow);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleADX);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check Daily Loss Limit                                           |
//+------------------------------------------------------------------+
bool IsDailyLossLimitReached()
{
   datetime today = iTime(_Symbol, PERIOD_D1, 0);
   int losses = 0;
   
   HistorySelect(today, TimeCurrent());
   int total = HistoryDealsTotal();
   
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
      {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(profit < 0) losses++;
      }
   }
   
   return (losses >= InpMaxDailyLoss);
}

void OnTick()
{
   // Protections run on every tick
   if(InpUseBreakEven) ManageBreakEven();
   if(InpUseTrailing) ManageTrailingStop();

   // Session Filter
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.hour < InpStartHour || dt.hour > InpEndHour) return;

   // Daily Loss Limit Check
   if(IsDailyLossLimitReached()) return;

   // Signal logic remains on new bar only
   if(!IsNewBar()) return;
   
   if(PositionSelectByMagic(InpMagicNumber)) return;

   // 1. Get H1 Order Flow Bias
   double h1Trend[];
   ArraySetAsSeries(h1Trend, true);
   if(CopyBuffer(handleH1_Slow, 0, 0, 1, h1Trend) < 1) return;
   double closeH1[];
   if(CopyClose(_Symbol, PERIOD_H1, 0, 1, closeH1) < 1) return;
   bool isBullishBias = closeH1[0] > h1Trend[0];
   bool isBearishBias = closeH1[0] < h1Trend[0];

   // 2. Detect M15 Price Leg (Swing High/Low in last 20 bars)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 20, rates) < 20) return;

   double swingHigh = rates[0].high;
   double swingLow = rates[0].low;
   int highIdx = 0, lowIdx = 0;

   for(int i=1; i<20; i++) {
      if(rates[i].high > swingHigh) { swingHigh = rates[i].high; highIdx = i; }
      if(rates[i].low < swingLow) { swingLow = rates[i].low; lowIdx = i; }
   }

   // 3. Fibonacci Levels Calculation
   double diff = swingHigh - swingLow;
   if(diff <= 0) return;

   double fib618_Buy = swingHigh - (diff * 0.618);
   double fib786_Buy = swingHigh - (diff * 0.786);
   double fib618_Sell = swingLow + (diff * 0.618);
   double fib786_Sell = swingLow + (diff * 0.786);

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 4. Entry Logic (Optimal Trade Entry - OTE)
   // BUY: Bullish Bias + Market Shift (High formed after Low) + Price in Golden Zone
   if(isBullishBias && highIdx < lowIdx && currentPrice <= fib618_Buy && currentPrice >= fib786_Buy)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = swingLow - 10 * _Point; // SL below the 100% Fib
      double tp = swingHigh + (diff * 0.27); // TP at -27% expansion
      trade.Buy(InpLotSize, _Symbol, 0, sl, tp, "Fib OTE Buy");
   }
   // SELL: Bearish Bias + Market Shift (Low formed after High) + Price in Golden Zone
   else if(isBearishBias && lowIdx < highIdx && currentPrice >= fib618_Sell && currentPrice <= fib786_Sell)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = swingHigh + 10 * _Point; // SL above the 100% Fib
      double tp = swingLow - (diff * 0.27); // TP at -27% expansion
      trade.Sell(InpLotSize, _Symbol, 0, sl, tp, "Fib OTE Sell");
   }
}

//+------------------------------------------------------------------+
//| Helper to get return code description                            |
//+------------------------------------------------------------------+
string GetRetcodeSelection(uint retcode)
{
   return(IntegerToString(retcode));
}

double CalculateLot(int slPoints)
{
   if(slPoints <= 0) return 0; // Prevent division by zero
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(tickValue <= 0) return InpLotSize;
   
   double lot = (balance * (InpRiskPercent / 100.0)) / (slPoints * tickValue);
   
   // Apply constraints
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   
   if(InpForceMinLot && lot < 0.01) lot = 0.01;
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Trailing Stop Management                                         |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double current_sl = PositionGetDouble(POSITION_SL);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            if(type == POSITION_TYPE_BUY)
            {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(bid - open_price > InpTrailingStart * _Point)
               {
                  double new_sl = bid - InpTrailingStart * _Point;
                  if(new_sl > current_sl + InpTrailingStep * _Point || current_sl == 0)
                  {
                     trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               if(open_price - ask > InpTrailingStart * _Point)
               {
                  double new_sl = ask + InpTrailingStart * _Point;
                  if(new_sl < current_sl - InpTrailingStep * _Point || current_sl == 0)
                  {
                     trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Break Even Management                                            |
//+------------------------------------------------------------------+
void ManageBreakEven()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            double current_sl = PositionGetDouble(POSITION_SL);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            if(type == POSITION_TYPE_BUY)
            {
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               if(bid - open_price > InpBreakEvenStart * _Point)
               {
                  double new_sl = open_price + InpBreakEvenLock * _Point;
                  // Only move if new SL is higher than current SL (to avoid moving back)
                  if(current_sl < new_sl - _Point)
                  {
                     trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               if(open_price - ask > InpBreakEvenStart * _Point)
               {
                  double new_sl = open_price - InpBreakEvenLock * _Point;
                  // Only move if new SL is lower than current SL
                  if(current_sl > new_sl + _Point || current_sl == 0)
                  {
                     trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Stochastic RSI Manual                                  |
//+------------------------------------------------------------------+
bool GetStochRSI(double &k, double &d)
{
   int lookback = InpStochRSIPer + InpKPeriod + InpDPeriod;
   double rsiValues[];
   ArraySetAsSeries(rsiValues, true);
   
   if(CopyBuffer(handleRSI, 0, 1, lookback, rsiValues) < lookback) return false;
   
   double stochValues[];
   ArrayResize(stochValues, InpKPeriod + InpDPeriod);
   
   for(int i = 0; i < InpKPeriod + InpDPeriod; i++)
   {
      double highRSI = rsiValues[i];
      double lowRSI = rsiValues[i];
      
      for(int j = 1; j < InpStochRSIPer; j++)
      {
         if(rsiValues[i+j] > highRSI) highRSI = rsiValues[i+j];
         if(rsiValues[i+j] < lowRSI) lowRSI = rsiValues[i+j];
      }
      
      if(highRSI != lowRSI)
         stochValues[i] = 100.0 * (rsiValues[i] - lowRSI) / (highRSI - lowRSI);
      else
         stochValues[i] = 50.0;
   }
   
   // K Line (Simple Moving Average of StochRSI)
   double sumK = 0;
   for(int i = 0; i < InpKPeriod; i++) sumK += stochValues[i];
   k = sumK / InpKPeriod;
   
   // D Line (Simple Moving Average of K)
   double sumD = 0;
   for(int i = 0; i < InpDPeriod; i++)
   {
      double tempK = 0;
      for(int j = 0; j < InpKPeriod; j++) tempK += stochValues[i+j];
      sumD += (tempK / InpKPeriod);
   }
   d = sumD / InpDPeriod;
   
   return true;
}

//+------------------------------------------------------------------+
//| Function to check for a new bar                                  |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime last_time = 0;
   datetime lastbar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(last_time == 0) { last_time = lastbar_time; return false; }
   if(last_time != lastbar_time) { last_time = lastbar_time; return true; }
   return false;
}

//+------------------------------------------------------------------+
//| Helper to check positions by Magic Number                        |
//+------------------------------------------------------------------+
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

