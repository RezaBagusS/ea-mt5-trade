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
input bool     InpUseATR_Exit  = true;      // Use ATR for SL/TP
input double   InpATR_Multiplier_SL = 1.5;  // ATR Multiplier for SL
input double   InpATR_Multiplier_TP = 3.0;  // ATR Multiplier for TP
input int      InpStopLoss     = 200;       // Fixed SL (if ATR is false)
input int      InpTakeProfit   = 400;       // Fixed TP (if ATR is false)
input int      InpMagicNumber  = 123456;    // Magic Number

input group "=== Break Even Settings ==="
input bool     InpUseBreakEven = true;      // Use Break Even
input int      InpBreakEvenStart = 200;     // Break Even at (Points)
input int      InpBreakEvenLock = 20;       // Lock Profit (Points)

input group "=== Trailing Stop Settings ==="
input bool     InpUseTrailing  = true;      // Use Trailing Stop
input int      InpTrailingStart = 300;      // Start Trailing after (Points)
input int      InpTrailingStep  = 30;       // Trailing Step (Points)

input group "=== Strategy Settings (H1 Preferred) ==="
input int      InpEMAFast      = 10;        // Fast EMA Period
input int      InpEMASlow      = 20;        // Slow EMA Period
input ENUM_TIMEFRAMES InpFilterTF = PERIOD_H4; // Trend Filter Timeframe
input int      InpFilterEMA    = 200;       // Trend Filter EMA Period
input int      InpStochRSIPer  = 14;        // StochRSI Period
input int      InpKPeriod      = 3;         // %K Smoothing
input int      InpDPeriod      = 3;         // %D Smoothing
input int      InpATR_Period   = 14;        // ATR Period for Exit
input int      InpOSLevel      = 20;        // Oversold Level
input int      InpOBLevel      = 80;        // Overbought Level

//--- global variables
int      handleEMAFast;
int      handleEMASlow;
int      handleRSI;
int      handleFilter;
int      handleATR;
CTrade   trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Setup Trade Class
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Initialize Indicators
   handleEMAFast = iMA(_Symbol, _Period, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   handleEMASlow = iMA(_Symbol, _Period, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   handleRSI     = iRSI(_Symbol, _Period, InpStochRSIPer, PRICE_CLOSE);
   handleFilter  = iMA(_Symbol, InpFilterTF, InpFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleATR     = iATR(_Symbol, _Period, InpATR_Period);
   
   if(handleEMAFast == INVALID_HANDLE || handleEMASlow == INVALID_HANDLE || 
      handleRSI == INVALID_HANDLE || handleFilter == INVALID_HANDLE || handleATR == INVALID_HANDLE)
   {
      Print("Error initializing indicators");
      return(INIT_FAILED);
   }

   Print("EA Initialized with ATR Dynamic Exit (v1.60)");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(handleEMAFast);
   IndicatorRelease(handleEMASlow);
   IndicatorRelease(handleRSI);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Protections run on every tick
   if(InpUseBreakEven) ManageBreakEven();
   if(InpUseTrailing) ManageTrailingStop();

   // Signal logic remains on new bar only
   if(!IsNewBar()) return;
   
   if(PositionSelectByMagic(InpMagicNumber)) return;

   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);

   if(CopyBuffer(handleEMAFast, 0, 1, 2, emaFast) < 2) return;
   if(CopyBuffer(handleEMASlow, 0, 1, 2, emaSlow) < 2) return;

   // Calculate Stochastic RSI
   double stochRSI_K, stochRSI_D;
   if(!GetStochRSI(stochRSI_K, stochRSI_D)) return;

   // Logic: Crossover detection
   bool isCrossUp = (emaFast[1] <= emaSlow[1]) && (emaFast[0] > emaSlow[0]);
   bool isCrossDown = (emaFast[1] >= emaSlow[1]) && (emaFast[0] < emaSlow[0]);

   // Get Trend Filter Value (H4)
   double filterBuffer[];
   ArraySetAsSeries(filterBuffer, true);
   if(CopyBuffer(handleFilter, 0, 0, 1, filterBuffer) < 1) return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool isTrendUp = currentPrice > filterBuffer[0];
   bool isTrendDown = currentPrice < filterBuffer[0];

   // ATR Calculation for SL/TP
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(handleATR, 0, 0, 1, atrBuffer) < 1) return;
   
   int finalSL = InpStopLoss;
   int finalTP = InpTakeProfit;
   
   if(InpUseATR_Exit)
   {
      finalSL = (int)(atrBuffer[0] * InpATR_Multiplier_SL / _Point);
      finalTP = (int)(atrBuffer[0] * InpATR_Multiplier_TP / _Point);
   }

   double lot = InpUseAutoLot ? CalculateLot(finalSL) : InpLotSize;
   if(lot <= 0) return;

   // BUY Signal: EMA Cross Up AND StochRSI OK AND Trend H4 is UP
   if(isCrossUp && stochRSI_K > InpOSLevel && isTrendUp)
   {
      double sl = (finalSL > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) - finalSL * _Point : 0;
      double tp = (finalTP > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) + finalTP * _Point : 0;
      trade.Buy(lot, _Symbol, 0, sl, tp, "ATR Trend Buy");
   }
   // SELL Signal: EMA Cross Down AND StochRSI OK AND Trend H4 is DOWN
   else if(isCrossDown && stochRSI_K < InpOBLevel && isTrendDown)
   {
      double sl = (finalSL > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) + finalSL * _Point : 0;
      double tp = (finalTP > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) - finalTP * _Point : 0;
      trade.Sell(lot, _Symbol, 0, sl, tp, "ATR Trend Sell");
   }
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
//| Calculate Dynamic Lot based on Risk %                            |
//+------------------------------------------------------------------+
double CalculateLot(int sl_points)
{
   if(sl_points <= 0) return InpLotSize;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = balance * (InpRiskPercent / 100.0);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick_value <= 0 || tick_size <= 0) return InpLotSize;
   double point_value = (tick_value / tick_size) * _Point;
   double lot = risk_amount / (sl_points * point_value);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lot = MathFloor(lot / step_lot) * step_lot;
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lot < min_lot) lot = min_lot;
   if(lot > max_lot) lot = max_lot;
   return NormalizeDouble(lot, 2);
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

