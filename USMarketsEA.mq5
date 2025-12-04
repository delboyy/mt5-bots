//+------------------------------------------------------------------+
//|                                              USMarketsEA.mq5      |
//|                           US Markets Asia-London Range EA        |
//|                                   For SPY and US Indexes          |
//+------------------------------------------------------------------+
#property copyright "MT5 Trading Bot"
#property link      ""
#property version   "2.00"
#property description "Asia-London Range Breakout Reversal Strategy for US Markets"
#property description "Fades breakouts from Asia session range during US market hours"
#property description "Closes positions 1 minute before US market close"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+

input group "=== SYMBOL MODE ==="
input bool EnableMultiSymbol = false;     // Enable Multi-Symbol Trading
input string SymbolOverride = "";         // Symbol Override (single mode only)

input group "=== MULTI-SYMBOL SETTINGS (if enabled) ==="
input string Symbol1 = "SPY";             // Symbol 1 (S&P 500 ETF)
input string Symbol2 = "QQQ";             // Symbol 2 (Nasdaq ETF)
input string Symbol3 = "DIA";             // Symbol 3 (Dow Jones ETF)
input string Symbol4 = "IWM";             // Symbol 4 (Russell 2000 ETF)

input group "=== SESSION TIMES (Eastern Time) ==="
input int AsiaStartHour = 5;              // Asia Session Start Hour (Dubai)
input int AsiaEndHour = 9;                // Asia Session End Hour (Dubai)
input int USMarketOpenHour = 9;           // US Market Open Hour (ET) - 9:30am
input int USMarketOpenMinute = 30;        // US Market Open Minute
input int USMarketCloseHour = 15;         // US Market Close Hour (ET) - 4:00pm
input int USMarketCloseMinute = 59;       // Close positions at 3:59pm (1 min before close)

input group "=== RISK MANAGEMENT ==="
input double RiskPercent = 1.0;           // Risk % Per Trade
input double MaxLots = 5.0;               // Maximum Lot Size (safety limit)
input double StopLossPct = 1.5;           // Stop Loss (% of Asia Range)

input group "=== EA SETTINGS ==="
input int MagicNumber = 234001;           // Magic Number (different from European EA)
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
   SESSION_PRE_US,
   SESSION_US_MARKET,
   SESSION_CLOSED
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   PrintFormat("========================================");
   PrintFormat("US Markets Asia-London Range EA v2.0");
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
   PrintFormat("US Market Hours: %d:%02d - %d:%02d ET (Close positions at %d:%02d)", 
               USMarketOpenHour, USMarketOpenMinute, 
               USMarketCloseHour + 1, 0,
               USMarketCloseHour, USMarketCloseMinute);
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
         
      case SESSION_PRE_US:
         ProcessPreUSSession();
         break;
         
      case SESSION_US_MARKET:
         ProcessUSMarketSession();
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
   
   // Convert broker time (GMT+2) to Dubai time (GMT+4)
   int dubaiHour = dt.hour + 2;
   if(dubaiHour >= 24) dubaiHour -= 24;
   
   // Convert broker time to ET (GMT+2 to ET is -7 hours in DST, -6 in standard)
   // For simplicity, using -6 hours (standard time)
   int etHour = dt.hour - 6;
   if(etHour < 0) etHour += 24;
   
   int etMinute = dt.min;
   
   // Check if in Asia session (Dubai time)
   if(dubaiHour >= AsiaStartHour && dubaiHour < AsiaEndHour) {
      return SESSION_ASIA;
   }
   // Check if in US market hours (ET)
   else if((etHour > USMarketOpenHour || (etHour == USMarketOpenHour && etMinute >= USMarketOpenMinute)) &&
           (etHour < USMarketCloseHour || (etHour == USMarketCloseHour && etMinute <= USMarketCloseMinute))) {
      return SESSION_US_MARKET;
   }
   // Pre-US session (after Asia, before US market)
   else if(dubaiHour >= AsiaEndHour && etHour < USMarketOpenHour) {
      return SESSION_PRE_US;
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
//| Process Pre-US session - finalize ranges                         |
//+------------------------------------------------------------------+
void ProcessPreUSSession() {
   static datetime lastCheck = 0;
   
   // Only check every 5 minutes
   if(TimeCurrent() - lastCheck < 300) return;
   lastCheck = TimeCurrent();
   
   if(EnableLogging) PrintFormat("=== PRE-US MARKET - Finalizing ranges ===");
   
   for(int i = 0; i < symbolCount; i++) {
      if(!asiaRanges[i].identified) {
         CalculateAsiaRange(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Process US Market session - trade breakouts                      |
//+------------------------------------------------------------------+
void ProcessUSMarketSession() {
   static datetime lastCheck = 0;
   
   // Check every minute
   if(TimeCurrent() - lastCheck < 60) return;
   lastCheck = TimeCurrent();
   
   // Check if we're approaching market close (close positions at 3:59pm ET)
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int etHour = dt.hour - 6;
   if(etHour < 0) etHour += 24;
   
   if(etHour == USMarketCloseHour && dt.min >= USMarketCloseMinute) {
      // Close all positions 1 minute before market close
      if(EnableLogging) PrintFormat("=== APPROACHING MARKET CLOSE - Closing positions ===");
      
      for(int i = 0; i < symbolCount; i++) {
         CloseAllPositionsForSymbol(tradingSymbols[i], "MARKET_CLOSE");
      }
      return;
   }
   
   // Normal trading logic
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
//| Process closed session                                           |
//+------------------------------------------------------------------+
void ProcessClosedSession() {
   static bool closedToday = false;
   
   // Close all positions once when session closes
   if(!closedToday) {
      if(EnableLogging) PrintFormat("=== US MARKET CLOSED - Closing positions ===");
      
      for(int i = 0; i < symbolCount; i++) {
         CloseAllPositionsForSymbol(tradingSymbols[i], "TIME_EXIT");
      }
      
      closedToday = true;
   }
   
   // Reset flag at start of new day
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int dubaiHour = dt.hour + 2;  // Broker GMT+2 to Dubai GMT+4
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
   
   // Calculate Asia session start/end times (convert Dubai to broker time GMT+2)
   datetime asiaStart = StringToTime(StringFormat("%04d.%02d.%02d %02d:00", 
                                      dt.year, dt.mon, dt.day, AsiaStartHour - 2));
   datetime asiaEnd = StringToTime(StringFormat("%04d.%02d.%02d %02d:00", 
                                    dt.year, dt.mon, dt.day, AsiaEndHour - 2));
   
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
      result = trade.Buy(lots, symbol, entryPrice, stopLoss, takeProfit, "US Market Range");
   }
   else {
      result = trade.Sell(lots, symbol, entryPrice, stopLoss, takeProfit, "US Market Range");
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
