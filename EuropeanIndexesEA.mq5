//+------------------------------------------------------------------+
//|                                          EuropeanIndexesEA.mq5   |
//|                        European Indexes Asia-London Range EA     |
//|                                   Refactored for Production Use  |
//+------------------------------------------------------------------+
#property copyright "MT5 Trading Bot"
#property link      ""
#property version   "2.00"
#property description "Asia-London Range Breakout Reversal Strategy"
#property description "Fades breakouts from Asia session range during London session"
#property description "Supports single-symbol (default) and multi-symbol modes"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

input group "=== SYMBOL MODE ==="
input bool EnableMultiSymbol = false;     // Enable Multi-Symbol Trading
input string SymbolOverride = "";         // Symbol Override (single mode only)

input group "=== MULTI-SYMBOL SETTINGS (if enabled) ==="
input string Symbol1 = "GER40";           // Symbol 1 (DAX)
input string Symbol2 = "FRA40";           // Symbol 2 (CAC40)
input string Symbol3 = "UK100";           // Symbol 3 (FTSE)
input string Symbol4 = "EUSTX50";         // Symbol 4 (Euro STOXX)

input group "=== SESSION TIMES (Dubai GMT+4) ==="
input int AsiaStartHour = 5;              // Asia Session Start Hour (Dubai)
input int AsiaEndHour = 9;                // Asia Session End Hour (Dubai)
input int LondonStartHour = 9;            // London Session Start Hour (Dubai) - Starts immediately after Asia
input int LondonEndHour = 25;             // London Session End Hour (Dubai) - Extended to 1am (US Close)

input group "=== RISK MANAGEMENT ==="
input double RiskPercent = 1.0;           // Risk % Per Trade
input double MaxLots = 5.0;               // Maximum Lot Size (safety limit)
input double StopLossPct = 1.5;           // Stop Loss (% of Asia Range)

input group "=== EA SETTINGS ==="
input int MagicNumber = 234000;           // Magic Number
input int Slippage = 10;                  // Slippage (points)
input bool EnableLogging = true;          // Enable Detailed Logging

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+

CTrade trade;
string tradingSymbols[];
int symbolCount = 0;

// Asia range data structure
struct AsiaRange {
   datetime date;
   double high;
   double low;
   double size;
   bool identified;
};

// Trade tracking structure
struct TradeInfo {
   bool tradedToday;
   datetime lastTradeDate;
};

// Symbol-specific data
AsiaRange asiaRanges[];
TradeInfo tradeTracking[];

datetime lastResetDate = 0;

// Session enum
enum SESSION_TYPE {
   SESSION_ASIA,
   SESSION_PRE_LONDON,
   SESSION_LONDON,
   SESSION_CLOSED
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   PrintFormat("========================================");
   PrintFormat("European Indexes Asia-London Range EA v2.0");
   PrintFormat("========================================");
   
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetAsyncMode(false);
   
   // Build symbols array based on mode
   if(!BuildSymbolsList()) {
      return INIT_FAILED;
   }
   
   // Initialize arrays
   ArrayResize(asiaRanges, symbolCount);
   ArrayResize(tradeTracking, symbolCount);
   
   for(int i = 0; i < symbolCount; i++) {
      asiaRanges[i].identified = false;
      tradeTracking[i].tradedToday = false;
      tradeTracking[i].lastTradeDate = 0;
   }
   
   PrintFormat("Risk Management: %.1f%% per trade (Max: %.2f lots)", RiskPercent, MaxLots);
   PrintFormat("Stop Loss: %.0f%% of Asia range", StopLossPct * 100);
   PrintFormat("Session Times: Asia %d-%d, London %d-%d (Dubai GMT+4)", 
               AsiaStartHour, AsiaEndHour, LondonStartHour, LondonEndHour);
   PrintFormat("========================================");
   
   lastResetDate = TimeCurrent();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   PrintFormat("========================================");
   PrintFormat("EA Shutdown - Reason: %d", reason);
   PrintFormat("========================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
   // Check for daily reset
   CheckDailyReset();
   
   // Get current session
   SESSION_TYPE session = GetCurrentSession();
   
   // Process based on session
   switch(session) {
      case SESSION_ASIA:
         ProcessAsiaSession();
         break;
         
      case SESSION_PRE_LONDON:
         ProcessPreLondonSession();
         break;
         
      case SESSION_LONDON:
         ProcessLondonSession();
         break;
         
      case SESSION_CLOSED:
         ProcessClosedSession();
         break;
   }
}

//+------------------------------------------------------------------+
//| Build list of symbols to trade                                   |
//+------------------------------------------------------------------+
bool BuildSymbolsList() {
   ArrayFree(tradingSymbols);
   symbolCount = 0;
   
   if(EnableMultiSymbol) {
      // Multi-symbol mode
      PrintFormat("Mode: MULTI-SYMBOL");
      
      string symbols[] = {Symbol1, Symbol2, Symbol3, Symbol4};
      
      for(int i = 0; i < ArraySize(symbols); i++) {
         if(symbols[i] == "") continue;
         
         // Try to select symbol
         if(!SymbolSelect(symbols[i], true)) {
            PrintFormat("WARNING: Symbol %s not found - skipping", symbols[i]);
            continue;
         }
         
         // Verify symbol is tradeable
         if(!SymbolInfoInteger(symbols[i], SYMBOL_TRADE_MODE)) {
            PrintFormat("WARNING: Symbol %s not tradeable - skipping", symbols[i]);
            continue;
         }
         
         // Add to trading list
         ArrayResize(tradingSymbols, symbolCount + 1);
         tradingSymbols[symbolCount] = symbols[i];
         symbolCount++;
         PrintFormat("  ✓ %s added", symbols[i]);
      }
      
      if(symbolCount == 0) {
         PrintFormat("ERROR: No valid symbols found in multi-symbol mode!");
         return false;
      }
   }
   else {
      // Single-symbol mode
      PrintFormat("Mode: SINGLE-SYMBOL");
      
      string symbol = (SymbolOverride != "") ? SymbolOverride : _Symbol;
      
      if(!SymbolSelect(symbol, true)) {
         PrintFormat("ERROR: Symbol %s not found!", symbol);
         return false;
      }
      
      ArrayResize(tradingSymbols, 1);
      tradingSymbols[0] = symbol;
      symbolCount = 1;
      PrintFormat("  ✓ Trading: %s", symbol);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if new day and reset daily variables                       |
//+------------------------------------------------------------------+
void CheckDailyReset() {
   MqlDateTime currentTime, lastTime;
   TimeToStruct(TimeCurrent(), currentTime);
   TimeToStruct(lastResetDate, lastTime);
   
   if(currentTime.day != lastTime.day) {
      if(EnableLogging) PrintFormat("=== DAILY RESET ===");
      
      // Clear Asia ranges and trade tracking
      for(int i = 0; i < symbolCount; i++) {
         asiaRanges[i].identified = false;
         tradeTracking[i].tradedToday = false;
      }
      
      lastResetDate = TimeCurrent();
      
      if(EnableLogging) PrintFormat("Daily state reset complete");
   }
}

//+------------------------------------------------------------------+
//| Get current trading session                                      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get current trading session                                      |
//+------------------------------------------------------------------+
SESSION_TYPE GetCurrentSession() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Convert broker time (GMT+2) to Dubai time (GMT+4)
   // Broker is 2 hours behind Dubai, so add 2 hours
   int dubaiHour = dt.hour + 2;
   if(dubaiHour >= 24) dubaiHour -= 24;
   
   // Handle extended session logic (LondonEndHour > 24)
   int checkHour = dubaiHour;
   if(checkHour < AsiaStartHour) checkHour += 24; // Handle midnight wrap for end check
   
   if(dubaiHour >= AsiaStartHour && dubaiHour < AsiaEndHour) {
      return SESSION_ASIA;
   }
   // Combined trading session (Asia End -> US Close)
   else if(checkHour >= LondonStartHour && checkHour < LondonEndHour) {
      return SESSION_LONDON;
   }
   // If strictly between AsiaEnd and LondonStart (only if gap exists)
   else if(dubaiHour >= AsiaEndHour && dubaiHour < LondonStartHour) {
      return SESSION_PRE_LONDON;
   }
   else {
      return SESSION_CLOSED;
   }
}

// ... existing code ...

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSizeBasedOnRisk(string symbol, double entryPrice, double stopLoss) {
   // Calculate Price Distance
   double distance = MathAbs(entryPrice - stopLoss);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(distance <= 0 || tickSize <= 0) {
      PrintFormat("ERROR: Invalid properties for %s (Dist: %.5f, TickSize: %.5f)", symbol, distance, tickSize);
      return 0;
   }
   
   // Calculate steps (ticks)
   double steps = distance / tickSize;
   
   // Get tick value
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue <= 0) {
      PrintFormat("ERROR: Invalid tick value for %s", symbol);
      return 0;
   }
   
   // Calculate monetary risk
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (RiskPercent / 100.0);
   
   // Calculate lot size: Risk = Lots * Steps * TickValue
   // Thus: Lots = Risk / (Steps * TickValue)
   double lots = riskMoney / (steps * tickValue);

   
   // Get volume step and limits
   double volumeStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   double minVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   
   // Normalize to volume step
   lots = MathFloor(lots / volumeStep) * volumeStep;
   
   // Apply limits
   if(lots < minVolume) lots = minVolume;
   if(lots > maxVolume) lots = maxVolume;
   if(lots > MaxLots) lots = MaxLots;
   
   // Final normalization
   lots = NormalizeDouble(lots, 2);
   
   if(EnableLogging) {
      PrintFormat("%s: Risk=%.2f%% (%.2f), SL=%.1f pts, Lot=%.2f", 
                  symbol, RiskPercent, riskMoney, slPoints, lots);
   }
   
   return lots;
}

//+------------------------------------------------------------------+
//| Place order with SL and TP                                       |
//+------------------------------------------------------------------+
void PlaceOrder(int symbolIndex, string direction, double entryPrice) {
   string symbol = tradingSymbols[symbolIndex];
   AsiaRange range = asiaRanges[symbolIndex];
   
   // Calculate SL and TP
   double stopLoss, takeProfit;
   CalculateSLTP(symbol, direction, entryPrice, range, stopLoss, takeProfit);
   
   // Calculate lot size based on risk
   double lots = CalculateLotSizeBasedOnRisk(symbol, entryPrice, stopLoss);
   
   if(lots <= 0) {
      PrintFormat("ERROR: Invalid lot size for %s", symbol);
      return;
   }
   
   // Normalize entry price
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   entryPrice = NormalizeDouble(entryPrice, digits);
   
   // Place order
   bool result = false;
   
   if(direction == "LONG") {
      result = trade.Buy(lots, symbol, entryPrice, stopLoss, takeProfit, "Asia-London Range");
   }
   else {
      result = trade.Sell(lots, symbol, entryPrice, stopLoss, takeProfit, "Asia-London Range");
   }
   
   if(result) {
      if(EnableLogging) {
         PrintFormat("✅ %s order placed: %s %.2f lots @ %.5f", 
                     symbol, direction, lots, entryPrice);
         PrintFormat("   Target: %.5f | Stop: %.5f", takeProfit, stopLoss);
      }
      
      // Mark as traded today
      tradeTracking[symbolIndex].tradedToday = true;
      tradeTracking[symbolIndex].lastTradeDate = TimeCurrent();
   }
   else {
      PrintFormat("❌ %s order failed: %s", symbol, trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Count open positions for a symbol                                |
//+------------------------------------------------------------------+
int CountOpenPositionsForSymbol(string symbol) {
   int count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++) {
      if(PositionGetSymbol(i) == symbol) {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Close all positions for a symbol                                 |
//+------------------------------------------------------------------+
void CloseAllPositionsForSymbol(string symbol, string reason) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      if(PositionGetSymbol(i) == symbol) {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber) {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            
            if(trade.PositionClose(ticket)) {
               if(EnableLogging) {
                  PrintFormat("📊 CLOSED: %s | Reason: %s | P&L: %.2f", 
                              symbol, reason, PositionGetDouble(POSITION_PROFIT));
               }
            }
            else {
               PrintFormat("❌ Failed to close %s: %s", symbol, trade.ResultRetcodeDescription());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
