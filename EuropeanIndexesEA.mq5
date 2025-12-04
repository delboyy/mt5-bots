//+------------------------------------------------------------------+
//|                                          EuropeanIndexesEA.mq5   |
//|                        European Indexes Asia-London Range EA     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "MT5 Trading Bot"
#property link      ""
#property version   "1.00"
#property description "Asia-London Range Breakout Reversal Strategy"
#property description "Fades breakouts from Asia session range during London session"

#include <Trade\Trade.mqh>

//--- Input parameters
input group "=== Trading Symbols ==="
input string Symbol1 = "GER40";     // Symbol 1 (DAX)
input string Symbol2 = "FRA40";     // Symbol 2 (CAC40)
input string Symbol3 = "UK100";     // Symbol 3 (FTSE)
input string Symbol4 = "EUSTX50";   // Symbol 4 (Euro STOXX)

input group "=== Session Times (Dubai GMT+4) ==="
input int AsiaStartHour = 5;        // Asia Session Start Hour
input int AsiaEndHour = 9;          // Asia Session End Hour
input int LondonStartHour = 11;     // London Session Start Hour
input int LondonEndHour = 14;       // London Session End Hour

input group "=== Risk Management ==="
input double LotSize = 0.01;        // Position Size (Lots)
input double StopLossPct = 1.5;     // Stop Loss (% of Asia Range)
input double MaxRiskPerTrade = 0.02; // Max Risk Per Trade (2%)
input double MaxDailyRisk = 0.05;   // Max Daily Risk (5%)

input group "=== EA Settings ==="
input int MagicNumber = 234000;     // Magic Number
input int Slippage = 10;            // Slippage (points)
input bool EnableLogging = true;    // Enable Detailed Logging

//--- Global variables
CTrade trade;
string symbols[4];
int symbolCount = 0;

// Asia range data structure
struct AsiaRange {
   datetime date;
   double high;
   double low;
   double size;
   bool identified;
};

AsiaRange asiaRanges[4];  // One for each symbol

// Trade tracking structure
struct TradeInfo {
   bool active;
   string direction;
   double entryPrice;
   double targetPrice;
   double stopLoss;
   datetime entryTime;
   ulong ticket;
};

TradeInfo currentTrades[4];  // One for each symbol

// Daily tracking
double dailyRiskUsed = 0.0;
int tradesTotal = 0;
int tradesWon = 0;
double dailyPnL = 0.0;
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
   Print("========================================");
   Print("European Indexes Asia-London Range EA");
   Print("========================================");
   
   // Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(Slippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   trade.SetAsyncMode(false);
   
   // Build symbols array
   symbolCount = 0;
   if(Symbol1 != "") symbols[symbolCount++] = Symbol1;
   if(Symbol2 != "") symbols[symbolCount++] = Symbol2;
   if(Symbol3 != "") symbols[symbolCount++] = Symbol3;
   if(Symbol4 != "") symbols[symbolCount++] = Symbol4;
   
   Print("Trading ", symbolCount, " symbols:");
   for(int i = 0; i < symbolCount; i++) {
      Print("  - ", symbols[i]);
      
      // Verify symbol exists
      if(!SymbolSelect(symbols[i], true)) {
         Print("ERROR: Symbol ", symbols[i], " not found!");
         return INIT_FAILED;
      }
      
      // Initialize structures
      asiaRanges[i].identified = false;
      currentTrades[i].active = false;
   }
   
   Print("Stop Loss: ", StopLossPct * 100, "% of Asia range");
   Print("Max Risk/Trade: ", MaxRiskPerTrade * 100, "%");
   Print("Max Daily Risk: ", MaxDailyRisk * 100, "%");
   Print("========================================");
   
   // Initialize daily reset
   lastResetDate = TimeCurrent();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   Print("========================================");
   Print("EA Shutdown - Reason: ", reason);
   Print("Daily Summary:");
   Print("  Trades: ", tradesTotal);
   Print("  Wins: ", tradesWon);
   Print("  Win Rate: ", (tradesTotal > 0 ? (tradesWon * 100.0 / tradesTotal) : 0), "%");
   Print("  Daily P&L: ", dailyPnL);
   Print("========================================");
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
//| Check if new day and reset daily variables                       |
//+------------------------------------------------------------------+
void CheckDailyReset() {
   MqlDateTime currentTime, lastTime;
   TimeToStruct(TimeCurrent(), currentTime);
   TimeToStruct(lastResetDate, lastTime);
   
   // Reset at midnight Dubai time (adjust for GMT+4)
   if(currentTime.day != lastTime.day) {
      if(EnableLogging) Print("=== DAILY RESET ===");
      
      dailyRiskUsed = 0.0;
      tradesTotal = 0;
      tradesWon = 0;
      dailyPnL = 0.0;
      
      // Clear Asia ranges
      for(int i = 0; i < symbolCount; i++) {
         asiaRanges[i].identified = false;
      }
      
      lastResetDate = TimeCurrent();
      
      if(EnableLogging) Print("Daily state reset complete");
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
   
   if(EnableLogging) Print("=== ASIA SESSION - Monitoring ranges ===");
   
   for(int i = 0; i < symbolCount; i++) {
      if(!asiaRanges[i].identified) {
         IdentifyAsiaRange(i);
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
   
   if(EnableLogging) Print("=== PRE-LONDON - Finalizing ranges ===");
   
   for(int i = 0; i < symbolCount; i++) {
      if(!asiaRanges[i].identified) {
         IdentifyAsiaRange(i);
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
      // Manage existing positions
      if(currentTrades[i].active) {
         ManagePosition(i);
      }
      // Look for new trades
      else if(asiaRanges[i].identified) {
         CheckForBreakout(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Process closed session - close positions                         |
//+------------------------------------------------------------------+
void ProcessClosedSession() {
   static bool closedToday = false;
   
   // Close all positions once when session closes
   if(!closedToday) {
      if(EnableLogging) Print("=== LONDON SESSION ENDED - Closing positions ===");
      
      for(int i = 0; i < symbolCount; i++) {
         if(currentTrades[i].active) {
            ClosePosition(i, "TIME_EXIT");
         }
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
//| Identify Asia session range for a symbol                         |
//+------------------------------------------------------------------+
void IdentifyAsiaRange(int symbolIndex) {
   string symbol = symbols[symbolIndex];
   
   // Get current time in Dubai timezone
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Calculate Asia session start/end times
   datetime asiaStart = StringToTime(StringFormat("%04d.%02d.%02d %02d:00", 
                                      dt.year, dt.mon, dt.day, AsiaStartHour - 4)); // Adjust for GMT
   datetime asiaEnd = StringToTime(StringFormat("%04d.%02d.%02d %02d:00", 
                                    dt.year, dt.mon, dt.day, AsiaEndHour - 4));
   
   // Get M5 bars for Asia session
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(symbol, PERIOD_M5, asiaStart, asiaEnd, rates);
   
   if(copied < 3) {
      if(EnableLogging) Print(symbol, ": Insufficient Asia data (", copied, " bars)");
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
   if(rangeSize < 5.0 * SymbolInfoDouble(symbol, SYMBOL_POINT)) {
      if(EnableLogging) Print(symbol, ": Range too small (", rangeSize, ")");
      return;
   }
   
   // Store range
   asiaRanges[symbolIndex].date = TimeCurrent();
   asiaRanges[symbolIndex].high = high;
   asiaRanges[symbolIndex].low = low;
   asiaRanges[symbolIndex].size = rangeSize;
   asiaRanges[symbolIndex].identified = true;
   
   if(EnableLogging) {
      Print("✓ ", symbol, " Asia Range: ", 
            DoubleToString(low, _Digits), " - ", 
            DoubleToString(high, _Digits), 
            " (Size: ", DoubleToString(rangeSize, _Digits), ")");
   }
}

//+------------------------------------------------------------------+
//| Check for breakout and place order                               |
//+------------------------------------------------------------------+
void CheckForBreakout(int symbolIndex) {
   string symbol = symbols[symbolIndex];
   
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
         Print(symbol, " breakout ABOVE: ", bid, " > ", range.high, " - Going SHORT");
      }
   }
   // Check for breakout BELOW (fade with LONG)
   else if(ask < range.low) {
      direction = "LONG";
      entryPrice = ask;
      
      if(EnableLogging) {
         Print(symbol, " breakout BELOW: ", ask, " < ", range.low, " - Going LONG");
      }
   }
   
   // Place order if breakout detected
   if(direction != "") {
      PlaceOrder(symbolIndex, direction, entryPrice);
   }
}

//+------------------------------------------------------------------+
//| Place order with SL and TP                                       |
//+------------------------------------------------------------------+
void PlaceOrder(int symbolIndex, string direction, double entryPrice) {
   string symbol = symbols[symbolIndex];
   AsiaRange range = asiaRanges[symbolIndex];
   
   // Calculate target and stop
   double targetPrice, stopLoss;
   
   if(direction == "LONG") {
      targetPrice = range.high;
      stopLoss = entryPrice - (range.size * StopLossPct);
   }
   else { // SHORT
      targetPrice = range.low;
      stopLoss = entryPrice + (range.size * StopLossPct);
   }
   
   // Check risk limit
   double stopDistance = MathAbs(entryPrice - stopLoss);
   double riskThisTrade = LotSize * stopDistance / SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(dailyRiskUsed + riskThisTrade > MaxDailyRisk) {
      if(EnableLogging) Print(symbol, ": Daily risk limit reached");
      return;
   }
   
   // Normalize prices
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   targetPrice = NormalizeDouble(targetPrice, digits);
   stopLoss = NormalizeDouble(stopLoss, digits);
   entryPrice = NormalizeDouble(entryPrice, digits);
   
   // Place order
   bool result = false;
   
   if(direction == "LONG") {
      result = trade.Buy(LotSize, symbol, entryPrice, stopLoss, targetPrice, "Asia-London Range");
   }
   else {
      result = trade.Sell(LotSize, symbol, entryPrice, stopLoss, targetPrice, "Asia-London Range");
   }
   
   if(result) {
      if(EnableLogging) {
         Print("✅ ", symbol, " order placed: ", direction, " ", LotSize, " lots @ ", entryPrice);
         Print("   Target: ", targetPrice, " | Stop: ", stopLoss);
      }
      
      // Store trade info
      currentTrades[symbolIndex].active = true;
      currentTrades[symbolIndex].direction = direction;
      currentTrades[symbolIndex].entryPrice = entryPrice;
      currentTrades[symbolIndex].targetPrice = targetPrice;
      currentTrades[symbolIndex].stopLoss = stopLoss;
      currentTrades[symbolIndex].entryTime = TimeCurrent();
      currentTrades[symbolIndex].ticket = trade.ResultOrder();
      
      dailyRiskUsed += riskThisTrade;
      tradesTotal++;
   }
   else {
      Print("❌ ", symbol, " order failed: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Manage open position                                             |
//+------------------------------------------------------------------+
void ManagePosition(int symbolIndex) {
   string symbol = symbols[symbolIndex];
   
   // Check if position still exists
   if(!PositionSelect(symbol)) {
      // Position closed (hit TP/SL)
      TradeInfo trade = currentTrades[symbolIndex];
      
      // Calculate P&L (approximate)
      double pnl = 0;
      if(trade.direction == "LONG") {
         pnl = (trade.targetPrice - trade.entryPrice) * LotSize;
      }
      else {
         pnl = (trade.entryPrice - trade.targetPrice) * LotSize;
      }
      
      if(pnl > 0) tradesWon++;
      dailyPnL += pnl;
      
      if(EnableLogging) {
         Print("📊 TRADE CLOSED: ", symbol, " ", trade.direction, 
               " | Entry: ", trade.entryPrice, " | P&L: ", pnl, " | Reason: TP/SL Hit");
      }
      
      currentTrades[symbolIndex].active = false;
   }
}

//+------------------------------------------------------------------+
//| Close position manually                                          |
//+------------------------------------------------------------------+
void ClosePosition(int symbolIndex, string reason) {
   string symbol = symbols[symbolIndex];
   
   if(!PositionSelect(symbol)) {
      currentTrades[symbolIndex].active = false;
      return;
   }
   
   TradeInfo tradeInfo = currentTrades[symbolIndex];
   
   if(trade.PositionClose(symbol)) {
      double closePrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double pnl = PositionGetDouble(POSITION_PROFIT);
      
      if(pnl > 0) tradesWon++;
      dailyPnL += pnl;
      
      if(EnableLogging) {
         Print("📊 TRADE CLOSED: ", symbol, " ", tradeInfo.direction, 
               " | Entry: ", tradeInfo.entryPrice, " | Exit: ", closePrice,
               " | P&L: ", pnl, " | Reason: ", reason);
      }
      
      currentTrades[symbolIndex].active = false;
   }
   else {
      Print("❌ Failed to close ", symbol, ": ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
