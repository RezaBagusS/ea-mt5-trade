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
input double   InpLotSize      = 0.01;      // Lot Size
input int      InpStopLoss     = 200;       // Stop Loss (Points)
input int      InpTakeProfit   = 400;       // Take Profit (Points)
input int      InpMagicNumber  = 123456;    // Magic Number

input group "=== Strategy Settings (H1 Preferred) ==="
input int      InpEMAFast      = 10;        // Fast EMA Period
input int      InpEMASlow      = 20;        // Slow EMA Period
input int      InpRSIPeriod    = 14;        // RSI Period
input int      InpRSIFilter    = 50;        // RSI Filter Level

//--- global variables
int      handleEMAFast;
int      handleEMASlow;
int      handleRSI;
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
   handleRSI     = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);
   
   if(handleEMAFast == INVALID_HANDLE || handleEMASlow == INVALID_HANDLE || handleRSI == INVALID_HANDLE)
   {
      Print("Error initializing indicators");
      return(INIT_FAILED);
   }

   Print("EA Initialized for ", _Symbol, " on ", EnumToString(_Period));
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
   // We only look for signals on a new bar to avoid multiple entries
   if(!IsNewBar()) return;

   // Check if we already have an open position with this Magic Number
   if(PositionSelectByMagic(InpMagicNumber)) return;

   double emaFast[], emaSlow[], rsi[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(rsi, true);

   // Copy indicator data (index 1 is the last closed candle, index 2 is the one before)
   if(CopyBuffer(handleEMAFast, 0, 1, 2, emaFast) < 2) return;
   if(CopyBuffer(handleEMASlow, 0, 1, 2, emaSlow) < 2) return;
   if(CopyBuffer(handleRSI, 0, 1, 1, rsi) < 1) return;

   // Logic: Crossover detection
   bool isCrossUp = (emaFast[1] <= emaSlow[1]) && (emaFast[0] > emaSlow[0]);
   bool isCrossDown = (emaFast[1] >= emaSlow[1]) && (emaFast[0] < emaSlow[0]);

   // BUY Signal
   if(isCrossUp && rsi[0] > InpRSIFilter)
   {
      double sl = (InpStopLoss > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) - InpStopLoss * _Point : 0;
      double tp = (InpTakeProfit > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) + InpTakeProfit * _Point : 0;
      
      trade.Buy(InpLotSize, _Symbol, 0, sl, tp, "EMA Cross Buy");
   }
   // SELL Signal
   else if(isCrossDown && rsi[0] < InpRSIFilter)
   {
      double sl = (InpStopLoss > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) + InpStopLoss * _Point : 0;
      double tp = (InpTakeProfit > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) - InpTakeProfit * _Point : 0;
      
      trade.Sell(InpLotSize, _Symbol, 0, sl, tp, "EMA Cross Sell");
   }
}

//+------------------------------------------------------------------+
//| Function to check for a new bar                                  |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime last_time = 0;
   datetime lastbar_time = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);

   if(last_time == 0)
   {
      last_time = lastbar_time;
      return false;
   }

   if(last_time != lastbar_time)
   {
      last_time = lastbar_time;
      return true;
   }

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

