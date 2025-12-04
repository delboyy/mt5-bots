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
input int AsiaStartHour = 5;              // Asia Session Start Hour
input int AsiaEndHour = 9;                // Asia Session End Hour
input int LondonStartHour = 11;           // London Session Start Hour
input int LondonEndHour = 14;             // London Session End Hour

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
SESSION_TYPE GetCurrentSession() {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Adjust for Dubai time (GMT+4)
   int dubaiHour = dt.hour + 4;
   if(dubaiHour >= 24) dubaiHour -= 24;
   
   if(dubaiHour >= AsiaStartHour && dubaiHour < AsiaEndHour) {
      return SESSION_ASIA;
   }
   else if(dubaiHour >= AsiaEndHour && dubaiHour < LondonStartHour) {
      return SESSION_PRE_LONDON;
   }
   else if(dubaiHour >= LondonStartHour && dubaiHour < LondonEndHour) {
      return SESSION_LONDON;
   }
   else {
      return SESSION_CLOSED;
   }
}

//+------------------------------------------------------------------+
//| Process Asia session - identify ranges                           |
//+------------------------------------------------------------------+
void ProcessAsiaSession() {
   static datetime lastCheck = 0;
   
   // Only check every 5 minutes
   if(TimeCurrent() - lastCheck < 300) return;
   lastCheck = TimeCurrent();
   
   if(EnableLogging) PrintFormat("=== ASIA SESSION - Monitoring ranges ===");
   
   for(int i = 0; i < symbolCount; i++) {
      if(!asiaRanges[i].identified) {
         CalculateAsiaRange(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Process Pre-London session - finalize ranges                     |
//+------------------------------------------------------------------+
void ProcessPreLondonSession() {
   static datetime lastCheck = 0;
   
   // Only check every 5 minutes
   if(TimeCurrent() - lastCheck < 300) return;
   lastCheck = TimeCurrent();
   
   if(EnableLogging) PrintFormat("=== PRE-LONDON - Finalizing ranges ===");
   
   for(int i = 0; i < symbolCount; i++) {
      if(!asiaRanges[i].identified) {
         CalculateAsiaRange(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Process London session - trade breakouts                         |
//+------------------------------------------------------------------+
void ProcessLondonSession() {
   static datetime lastCheck = 0;
   
   // Check every minute
   if(TimeCurrent() - lastCheck < 60) return;
   lastCheck = TimeCurrent();
   
   for(int i = 0; i < symbolCount; i++) {
      // Skip if already traded today
      if(tradeTracking[i].tradedToday) continue;
      
      // Skip if range not identified
      if(!asiaRanges[i].identified) continue;
      
      // Skip if already have open position
      if(CountOpenPositionsForSymbol(tradingSymbols[i]) > 0) continue;
      
      // Check for entry signal
      CheckForEntrySignal(i);
   }
}

//+------------------------------------------------------------------+
//| Process closed session - close positions                         |
//+------------------------------------------------------------------+
void ProcessClosedSession() {
   static bool closedToday = false;
   
   // Close all positions once when session closes
   if(!closedToday) {
      if(EnableLogging) PrintFormat("=== LONDON SESSION ENDED - Closing positions ===");
      
      for(int i = 0; i < symbolCount; i++) {
         CloseAllPositionsForSymbol(tradingSymbols[i], "TIME_EXIT");
      }
      
      closedToday = true;
   }
   
   // Reset flag at start of new day
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dubaiHour = dt.hour + 4;
   if(dubaiHour >= 24) dubaiHour -= 24;
   
   if(dubaiHour >= AsiaStartHour) {
      closedToday = false;
   }
}

//+------------------------------------------------------------------+
//| Calculate Asia session range for a symbol                        |
//+------------------------------------------------------------------+
void CalculateAsiaRange(int symbolIndex) {
   string symbol = tradingSymbols[symbolIndex];
   
   // Get current time
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Calculate Asia session start/end times (convert Dubai to GMT)
   datetime asiaStart = StringToTime(StringFormat("%04d.%02d.%02d %02d:00", 
                                      dt.year, dt.mon, dt.day, AsiaStartHour - 4));
   datetime asiaEnd = StringToTime(StringFormat("%04d.%02d.%02d %02d:00", 
                                    dt.year, dt.mon, dt.day, AsiaEndHour - 4));
   
   // Get M5 bars for Asia session
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(symbol, PERIOD_M5, asiaStart, asiaEnd, rates);
   
   if(copied < 3) {
      if(EnableLogging) PrintFormat("%s: Insufficient Asia data (%d bars)", symbol, copied);
      return;
   }
   
   // Find high and low
   double high = rates[0].high;
   double low = rates[0].low;
   
   for(int i = 1; i < copied; i++) {
      if(rates[i].high > high) high = rates[i].high;
      if(rates[i].low < low) low = rates[i].low;
   }
   
   double rangeSize = high - low;
   
   // Validate range (minimum 5 points)
   double minRange = 5.0 * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(rangeSize < minRange) {
      if(EnableLogging) PrintFormat("%s: Range too small (%.5f)", symbol, rangeSize);
      return;
   }
   
   // Store range
   asiaRanges[symbolIndex].date = TimeCurrent();
   asiaRanges[symbolIndex].high = high;
   asiaRanges[symbolIndex].low = low;
   asiaRanges[symbolIndex].size = rangeSize;
   asiaRanges[symbolIndex].identified = true;
   
   if(EnableLogging) {
      PrintFormat("✓ %s Asia Range: %.5f - %.5f (Size: %.5f)", 
                  symbol, low, high, rangeSize);
   }
}

//+------------------------------------------------------------------+
//| Check for entry signal and place order                           |
//+------------------------------------------------------------------+
void CheckForEntrySignal(int symbolIndex) {
   string symbol = tradingSymbols[symbolIndex];
   
   // Get current price
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   AsiaRange range = asiaRanges[symbolIndex];
   
   string direction = "";
   double entryPrice = 0;
   
   // Check for breakout ABOVE (fade with SHORT)
   if(bid > range.high) {
      direction = "SHORT";
      entryPrice = bid;
      
      if(EnableLogging) {
         PrintFormat("%s breakout ABOVE: %.5f > %.5f - Going SHORT", 
                     symbol, bid, range.high);
      }
   }
   // Check for breakout BELOW (fade with LONG)
   else if(ask < range.low) {
      direction = "LONG";
      entryPrice = ask;
      
      if(EnableLogging) {
         PrintFormat("%s breakout BELOW: %.5f < %.5f - Going LONG", 
                     symbol, ask, range.low);
      }
   }
   
   // Place order if breakout detected
   if(direction != "") {
      PlaceOrder(symbolIndex, direction, entryPrice);
   }
}

//+------------------------------------------------------------------+
//| Calculate SL and TP levels                                       |
//+------------------------------------------------------------------+
void CalculateSLTP(string symbol, string direction, double entryPrice, 
                   AsiaRange &range, double &stopLoss, double &takeProfit) {
   
   if(direction == "LONG") {
      takeProfit = range.high;
      stopLoss = entryPrice - (range.size * StopLossPct);
   }
   else { // SHORT
      takeProfit = range.low;
      stopLoss = entryPrice + (range.size * StopLossPct);
   }
   
   // Normalize prices
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   stopLoss = NormalizeDouble(stopLoss, digits);
   takeProfit = NormalizeDouble(takeProfit, digits);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSizeBasedOnRisk(string symbol, double entryPrice, double stopLoss) {
   // Calculate SL distance in points
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double slPoints = MathAbs(entryPrice - stopLoss) / point;
   
   if(slPoints <= 0) {
      PrintFormat("ERROR: Invalid SL distance for %s", symbol);
      return 0;
   }
   
   // Get tick value
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickValue <= 0) {
      PrintFormat("ERROR: Invalid tick value for %s", symbol);
      return 0;
   }
   
   // Calculate monetary risk
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskMoney = balance * (RiskPercent / 100.0);
   
   // Calculate lot size
   double lots = riskMoney / (slPoints * tickValue);
   
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
