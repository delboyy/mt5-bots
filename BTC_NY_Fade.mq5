//+------------------------------------------------------------------+
//|                                                   BTC_NY_Fade.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Input parameters
input double   RiskPercent = 1.0;        // Risk per trade (% of Balance)
input int      RangeStartHour = 13;      // Range Start Hour (Data Time)
input int      RangeStartMinute = 30;    // Range Start Minute
input int      RangeEndHour = 15;        // Range End Hour (Data Time)
input int      RangeEndMinute = 0;       // Range End Minute
input int      ExitHour = 19;            // Force Exit Hour (Data Time)
input int      ExitMinute = 0;           // Force Exit Minute
input double   StopLossMultiplier = 1.0; // Stop Loss Multiplier (x Range)
input int      MagicNumber = 123456;     // Magic Number

//--- Global variables
CTrade         trade;
double         rangeHigh = 0;
double         rangeLow = 0;
bool           rangeDefined = false;
bool           tradeTaken = false;
datetime       lastTradeDay = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   datetime time = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(time, dt);

   // 1. Reset Logic at Start of Day
   if(dt.day != lastTradeDay)
     {
      rangeDefined = false;
      tradeTaken = false;
      rangeHigh = 0;
      rangeLow = 0;
      lastTradeDay = dt.day;
     }

   // 2. Define Range (13:30 - 15:00)
   if(!rangeDefined)
     {
      // Check if we are past the range end time
      if(IsTimeAfter(dt, RangeEndHour, RangeEndMinute))
        {
         CalculateRange(time);
         rangeDefined = true;
         Print("Range Defined: High=", rangeHigh, " Low=", rangeLow);
        }
     }

   // 3. Trading Logic (15:00 - 19:00)
   if(rangeDefined && !tradeTaken)
     {
      // Check if we are before exit time
      if(!IsTimeAfter(dt, ExitHour, ExitMinute))
        {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         // Fade Breakout Logic
         // Price breaks ABOVE High -> SELL
         if(bid > rangeHigh)
           {
            double sl = rangeHigh + (rangeHigh - rangeLow) * StopLossMultiplier;
            double tp = rangeLow;
            double lotSize = CalculateLotSize(MathAbs(bid - sl));
            
            if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "BTC NY Fade Sell"))
              {
               tradeTaken = true;
               Print("SELL Executed. Lot:", lotSize, " SL:", sl, " TP:", tp);
              }
           }
         // Price breaks BELOW Low -> BUY
         else if(ask < rangeLow)
           {
            double sl = rangeLow - (rangeHigh - rangeLow) * StopLossMultiplier;
            double tp = rangeHigh;
            double lotSize = CalculateLotSize(MathAbs(ask - sl));

            if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "BTC NY Fade Buy"))
              {
               tradeTaken = true;
               Print("BUY Executed. Lot:", lotSize, " SL:", sl, " TP:", tp);
              }
           }
        }
     }

   // 4. Time Exit (19:00)
   if(IsTimeAfter(dt, ExitHour, ExitMinute))
     {
      if(PositionsTotal() > 0)
        {
         CloseAllPositions();
        }
     }
  }

//+------------------------------------------------------------------+
//| Helper Functions                                                 |
//+------------------------------------------------------------------+
bool IsTimeAfter(MqlDateTime &dt, int hour, int minute)
  {
   if(dt.hour > hour) return true;
   if(dt.hour == hour && dt.min >= minute) return true;
   return false;
  }

void CalculateRange(datetime currentTime)
  {
   // Calculate start time of range for today
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   dt.hour = RangeStartHour;
   dt.min = RangeStartMinute;
   dt.sec = 0;
   datetime startRange = StructToTime(dt);
   
   dt.hour = RangeEndHour;
   dt.min = RangeEndMinute;
   datetime endRange = StructToTime(dt);
   
   // Get High/Low from M1 bars
   double highs[];
   double lows[];
   
   int bars = CopyHigh(_Symbol, PERIOD_M1, endRange, startRange, highs);
   CopyLow(_Symbol, PERIOD_M1, endRange, startRange, lows); // Use same bars count logic
   
   // If CopyHigh uses start/end logic differently (count vs dates), use CopyRates or iHigh
   // Correct way with dates:
   // CopyHigh(symbol, timeframe, start_time, stop_time, array)
   
   // Re-do with CopyRates for safety
   MqlRates rates[];
   int count = CopyRates(_Symbol, PERIOD_M1, startRange, endRange, rates);
   
   if(count > 0)
     {
      rangeHigh = rates[0].high;
      rangeLow = rates[0].low;
      
      for(int i=1; i<count; i++)
        {
         if(rates[i].high > rangeHigh) rangeHigh = rates[i].high;
         if(rates[i].low < rangeLow) rangeLow = rates[i].low;
        }
     }
  }

double CalculateLotSize(double slDistance)
  {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(slDistance == 0 || tickSize == 0 || tickValue == 0) return 0.01;
   
   double slTicks = slDistance / tickSize;
   double lotSize = riskAmount / (slTicks * tickValue);
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / step) * step;
   
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;
   
   return lotSize;
  }

void CloseAllPositions()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
        {
         trade.PositionClose(ticket);
         Print("Time Exit Executed for Ticket: ", ticket);
        }
     }
  }
