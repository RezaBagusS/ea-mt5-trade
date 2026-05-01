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

   Print("EA Initialized for ", _Symbol, " - Mode: ", (InpUseAutoLot ? "Auto Lot (" + DoubleToString(InpRiskPercent, 1) + "%)" : "Fixed Lot"));
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

   // Copy indicator data
   if(CopyBuffer(handleEMAFast, 0, 1, 2, emaFast) < 2) return;
   if(CopyBuffer(handleEMASlow, 0, 1, 2, emaSlow) < 2) return;
   if(CopyBuffer(handleRSI, 0, 1, 1, rsi) < 1) return;

   // Logic: Crossover detection
   bool isCrossUp = (emaFast[1] <= emaSlow[1]) && (emaFast[0] > emaSlow[0]);
   bool isCrossDown = (emaFast[1] >= emaSlow[1]) && (emaFast[0] < emaSlow[0]);

   // Calculate Lot
   double lot = InpUseAutoLot ? CalculateLot(InpStopLoss) : InpLotSize;
   if(lot <= 0) return;

   // BUY Signal
   if(isCrossUp && rsi[0] > InpRSIFilter)
   {
      double sl = (InpStopLoss > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) - InpStopLoss * _Point : 0;
      double tp = (InpTakeProfit > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) + InpTakeProfit * _Point : 0;
      
      trade.Buy(lot, _Symbol, 0, sl, tp, "EMA Cross Buy");
   }
   // SELL Signal
   else if(isCrossDown && rsi[0] < InpRSIFilter)
   {
      double sl = (InpStopLoss > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) + InpStopLoss * _Point : 0;
      double tp = (InpTakeProfit > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) - InpTakeProfit * _Point : 0;
      
      trade.Sell(lot, _Symbol, 0, sl, tp, "EMA Cross Sell");
   }
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
   
   // Formula: Lot = Risk / (SL_in_points * Value_of_1_point)
   double point_value = (tick_value / tick_size) * _Point;
   double lot = risk_amount / (sl_points * point_value);
   
   // Normalize Lot to Broker Requirements
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / step_lot) * step_lot;
   
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

