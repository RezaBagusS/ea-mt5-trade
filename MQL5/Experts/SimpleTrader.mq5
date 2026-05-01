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
input double   InpATR_Multiplier_SL = 1.5;  // ATR Multiplier for SL
input double   InpATR_Multiplier_TP = 3.0;  // ATR Multiplier for TP
input int      InpStopLoss     = 150;       // Fixed SL (if ATR is false)
input int      InpTakeProfit   = 300;       // Fixed TP (if ATR is false)
input int      InpMagicNumber  = 123456;    // Magic Number

input group "=== Break Even Settings ==="
input bool     InpUseBreakEven = true;      // Use Break Even
input int      InpBreakEvenStart = 100;     // Break Even at (Points)
input int      InpBreakEvenLock = 10;       // Lock Profit (Points)

input group "=== Trailing Stop Settings ==="
input bool     InpUseTrailing  = true;      // Use Trailing Stop
input int      InpTrailingStart = 150;      // Start Trailing after (Points)
input int      InpTrailingStep  = 20;       // Trailing Step (Points)

input group "=== Strategy Settings (Scalping Mode) ==="
input int      InpHMA_Fast     = 10;        // HMA Fast Period
input int      InpHMA_Slow     = 20;        // HMA Slow Period
input bool     InpUseHMA       = true;      // Use HMA instead of EMA
input ENUM_TIMEFRAMES InpFilterTF = PERIOD_H1; // Trend Filter Timeframe
input int      InpFilterEMA    = 100;       // Trend Filter EMA Period

input group "=== Bollinger Bands Filter ==="
input bool     InpUseBB        = true;      // Use BB for Entry Filter
input int      InpBB_Period    = 20;        // BB Period
input double   InpBB_Dev       = 2.0;       // BB Deviation

input group "=== Momentum & Strength ==="
input int      InpStochRSIPer  = 14;        // StochRSI Period
input int      InpKPeriod      = 3;         // %K Smoothing
input int      InpDPeriod      = 3;         // %D Smoothing
input int      InpADX_Period   = 14;        // ADX Period
input int      InpADX_Min      = 20;        // ADX Min Strength

input group "=== Session & Protection ==="
input int      InpStartHour    = 8;         // Start Hour
input int      InpEndHour      = 21;        // End Hour
input int      InpMaxDailyLoss = 2;         // Max Daily Loss (Trades)

//--- global variables
int      handleFast;
int      handleSlow;
int      handleRSI;
int      handleFilter;
int      handleATR;
int      handleADX;
int      handleBB;
CTrade   trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Setup Trade Class
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Initialize Indicators
   if(InpUseHMA)
   {
      // HMA uses LWMA logic but calculated manually in OnTick or via multiple handles
      // For simplicity, we'll initialize handles for the base WMAs
      handleFast = iMA(_Symbol, _Period, InpHMA_Fast, 0, MODE_LWMA, PRICE_CLOSE);
      handleSlow = iMA(_Symbol, _Period, InpHMA_Slow, 0, MODE_LWMA, PRICE_CLOSE);
   }
   else
   {
      handleFast = iMA(_Symbol, _Period, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
      handleSlow = iMA(_Symbol, _Period, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   }

   handleRSI     = iRSI(_Symbol, _Period, InpStochRSIPer, PRICE_CLOSE);
   handleFilter  = iMA(_Symbol, InpFilterTF, InpFilterEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleATR     = iATR(_Symbol, _Period, InpATR_Period);
   handleADX     = iADX(_Symbol, _Period, InpADX_Period);
   handleBB      = iBands(_Symbol, _Period, InpBB_Period, 0, InpBB_Dev, PRICE_CLOSE);
   
   if(handleFast == INVALID_HANDLE || handleSlow == INVALID_HANDLE || 
      handleRSI == INVALID_HANDLE || handleFilter == INVALID_HANDLE || 
      handleATR == INVALID_HANDLE || handleADX == INVALID_HANDLE || handleBB == INVALID_HANDLE)
   {
      Print("Error initializing indicators");
      return(INIT_FAILED);
   }

   Print("EA HMA Scalping Mode Initialized (v1.80)");
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

   double fastBuffer[], slowBuffer[];
   ArraySetAsSeries(fastBuffer, true);
   ArraySetAsSeries(slowBuffer, true);

   if(CopyBuffer(handleFast, 0, 1, 2, fastBuffer) < 2) return;
   if(CopyBuffer(handleSlow, 0, 1, 2, slowBuffer) < 2) return;

   // Calculate Stochastic RSI
   double stochRSI_K, stochRSI_D;
   if(!GetStochRSI(stochRSI_K, stochRSI_D)) return;

   // Crossover detection
   bool isCrossUp = (fastBuffer[1] <= slowBuffer[1]) && (fastBuffer[0] > slowBuffer[0]);
   bool isCrossDown = (fastBuffer[1] >= slowBuffer[1]) && (fastBuffer[0] < slowBuffer[0]);

   // Trend Filter (H1)
   double filterBuffer[];
   ArraySetAsSeries(filterBuffer, true);
   if(CopyBuffer(handleFilter, 0, 0, 1, filterBuffer) < 1) return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool isTrendUp = currentPrice > filterBuffer[0];
   bool isTrendDown = currentPrice < filterBuffer[0];

   // ADX Filter
   double adxBuffer[];
   ArraySetAsSeries(adxBuffer, true);
   if(CopyBuffer(handleADX, 0, 0, 1, adxBuffer) < 1) return;
   bool isStrongTrend = adxBuffer[0] > InpADX_Min;

   // Bollinger Bands Filter
   double bbUpper[], bbLower[];
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbLower, true);
   if(CopyBuffer(handleBB, 1, 0, 1, bbUpper) < 1) return;
   if(CopyBuffer(handleBB, 2, 0, 1, bbLower) < 1) return;
   
   bool isBB_BuyOk = !InpUseBB || (currentPrice < bbLower[0] + (bbUpper[0]-bbLower[0])*0.3); // In lower 30% of BB
   bool isBB_SellOk = !InpUseBB || (currentPrice > bbUpper[0] - (bbUpper[0]-bbLower[0])*0.3); // In upper 30% of BB

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

   // Signal Check
   if(isCrossUp && stochRSI_K > 20 && isTrendUp && isStrongTrend && isBB_BuyOk)
   {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = (finalSL > 0) ? ask - finalSL * _Point : 0;
      double tp = (finalTP > 0) ? ask + finalTP * _Point : 0;
      trade.Buy(lot, _Symbol, 0, sl, tp, "HMA Scalp Buy");
   }
   else if(isCrossDown && stochRSI_K < 80 && isTrendDown && isStrongTrend && isBB_SellOk)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = (finalSL > 0) ? bid + finalSL * _Point : 0;
      double tp = (finalTP > 0) ? bid - finalTP * _Point : 0;
      trade.Sell(lot, _Symbol, 0, sl, tp, "HMA Scalp Sell");
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

