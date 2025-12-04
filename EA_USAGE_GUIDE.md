# European Indexes EA v2.0 - Usage Guide

## 🎯 What Changed

### ✅ Fixed Issues:
1. **Risk Management** - Now uses %-based risk (1% default) instead of fixed lots
2. **Symbol Handling** - Works on ANY broker, no more "symbol not found" errors
3. **Flexibility** - Single-symbol mode (default) OR multi-symbol mode (optional)
4. **Code Quality** - Clean, modular functions, 0 warnings

### ✅ Preserved (Unchanged):
- Asia-London range calculation (exact same logic)
- Entry signals (fade breakouts - exact same)
- SL/TP calculations (exact same formulas)
- Session timing (Asia 5-9am, London 11am-2pm Dubai)
- One trade per day per symbol
- One active position per symbol

---

## 📋 Input Parameters Explained

### **SYMBOL MODE**

**`EnableMultiSymbol`** (default: `false`)
- `false` = Single-symbol mode (RECOMMENDED for prop firms)
- `true` = Multi-symbol mode (trades multiple symbols)

**`SymbolOverride`** (default: `""`)
- Only used in single-symbol mode
- Leave blank to trade the chart's symbol
- Or specify a symbol name (e.g., "GER40")

### **MULTI-SYMBOL SETTINGS** (only if EnableMultiSymbol = true)

**`Symbol1, Symbol2, Symbol3, Symbol4`**
- Define which symbols to trade
- EA will skip any symbol not found (no errors!)
- Leave blank to skip that slot

### **SESSION TIMES** (Dubai GMT+4)

**`AsiaStartHour`** (default: `5`) - Asia session start  
**`AsiaEndHour`** (default: `9`) - Asia session end  
**`LondonStartHour`** (default: `11`) - London session start  
**`LondonEndHour`** (default: `14`) - London session end

### **RISK MANAGEMENT**

**`RiskPercent`** (default: `1.0`)
- Risk % of account balance per trade
- Example: 1.0 = 1% risk per trade
- Recommended: 0.5% - 2.0% for prop firms

**`MaxLots`** (default: `5.0`)
- Maximum position size (safety limit)
- Prevents oversized positions on small SL

**`StopLossPct`** (default: `1.5`)
- Stop loss as % of Asia range size
- 1.5 = 150% of range (from backtesting)

### **EA SETTINGS**

**`MagicNumber`** (default: `234000`)
- Unique identifier for this EA's trades

**`Slippage`** (default: `10`)
- Maximum slippage in points

**`EnableLogging`** (default: `true`)
- Detailed logs in Experts tab

---

## 🚀 How to Use

### **OPTION 1: Single-Symbol Mode (Recommended)**

This is the **simplest and safest** way to use the EA.

**Step 1:** Open a chart for the symbol you want to trade
- Example: Open DAX40 chart

**Step 2:** Attach EA to the chart
- Drag `EuropeanIndexesEA` from Navigator

**Step 3:** Configure parameters
```
EnableMultiSymbol = false
SymbolOverride = ""  (leave blank to use chart symbol)
RiskPercent = 1.0
MaxLots = 5.0
```

**Step 4:** Enable AutoTrading
- Click green AutoTrading button

**Done!** EA will trade only that chart's symbol.

**To trade multiple symbols:**
- Open separate charts (DAX, FTSE, CAC, etc.)
- Attach EA to each chart
- Each instance trades independently

---

### **OPTION 2: Multi-Symbol Mode (Advanced)**

Trade multiple symbols from ONE chart.

**Step 1:** Open ANY chart (symbol doesn't matter)

**Step 2:** Attach EA and configure:
```
EnableMultiSymbol = true
Symbol1 = "GER40"    (or your broker's DAX symbol)
Symbol2 = "FRA40"    (or your broker's CAC symbol)
Symbol3 = "UK100"    (or your broker's FTSE symbol)
Symbol4 = "EUSTX50"  (or your broker's Euro STOXX symbol)
RiskPercent = 1.0
```

**Step 3:** Enable AutoTrading

**Done!** EA will trade all configured symbols.

**Note:** If a symbol is not found, EA will skip it and continue (no errors).

---

## 📊 Broker-Specific Symbol Names

Different brokers use different symbol names. Here's how to find yours:

### **Finding Symbol Names:**

1. Open **Market Watch** (Ctrl+M)
2. Search for: DAX, CAC, FTSE, STOXX
3. Note the exact symbol names

### **Common Variations:**

| Index | FTMO | MyForexFunds | The5%ers | IC Markets |
|-------|------|--------------|----------|------------|
| DAX | GER40 | GER30 | DE40 | DAX40 |
| CAC40 | FRA40 | FRA40 | FR40 | CAC40 |
| FTSE | UK100 | UK100 | UK100 | UK100 |
| Euro STOXX | EUSTX50 | EU50 | STOXX50 | STOXX50 |

### **Update EA Parameters:**

If using multi-symbol mode, update the symbol names:
```
Symbol1 = "DAX40"    // Your broker's DAX name
Symbol2 = "CAC40"    // Your broker's CAC name
Symbol3 = "UK100"    // Your broker's FTSE name
Symbol4 = "STOXX50"  // Your broker's Euro STOXX name
```

---

## 🎯 Running on Specific Symbols

### **DAX40 (Germany 40)**

**Single-Symbol Mode:**
1. Open DAX40 chart
2. Attach EA
3. `EnableMultiSymbol = false`
4. `SymbolOverride = ""` (or "DAX40" if chart symbol differs)

**Multi-Symbol Mode:**
```
Symbol1 = "DAX40"  (or GER40, GER30, DE40 - check your broker)
```

### **UK100 (FTSE 100)**

**Single-Symbol Mode:**
1. Open UK100 chart
2. Attach EA
3. `EnableMultiSymbol = false`

**Multi-Symbol Mode:**
```
Symbol2 = "UK100"  (or FTSE100)
```

### **CAC40 (France 40)**

**Single-Symbol Mode:**
1. Open CAC40 chart (or FRA40)
2. Attach EA
3. `EnableMultiSymbol = false`

**Multi-Symbol Mode:**
```
Symbol3 = "FRA40"  (or CAC40, FR40)
```

### **Euro STOXX 50**

**Single-Symbol Mode:**
1. Open Euro STOXX chart
2. Attach EA
3. `EnableMultiSymbol = false`

**Multi-Symbol Mode:**
```
Symbol4 = "EUSTX50"  (or EU50, STOXX50)
```

### **BTCUSD (Optional - Crypto)**

The EA can trade ANY symbol with sufficient volatility.

**Single-Symbol Mode:**
1. Open BTCUSD chart
2. Attach EA
3. Configure:
```
EnableMultiSymbol = false
RiskPercent = 0.5  (crypto is more volatile)
StopLossPct = 2.0  (wider stops for crypto)
```

**Note:** Adjust session times if trading crypto (24/7 markets).

---

## ⚙️ Risk Management Examples

### **Example 1: Conservative (Prop Firm)**
```
RiskPercent = 0.5   // 0.5% per trade
MaxLots = 2.0       // Max 2 lots
```

**$10,000 account:**
- Risk per trade: $50
- If SL = 50 points, lot size ≈ 0.10

### **Example 2: Moderate**
```
RiskPercent = 1.0   // 1% per trade
MaxLots = 5.0       // Max 5 lots
```

**$10,000 account:**
- Risk per trade: $100
- If SL = 50 points, lot size ≈ 0.20

### **Example 3: Aggressive**
```
RiskPercent = 2.0   // 2% per trade
MaxLots = 10.0      // Max 10 lots
```

**$10,000 account:**
- Risk per trade: $200
- If SL = 50 points, lot size ≈ 0.40

**Recommendation:** Start with 0.5-1.0% for prop firms.

---

## 📈 How the EA Works

### **1. Asia Session (5-9am Dubai)**
- EA monitors price action
- Identifies high and low of the range
- Stores range data

### **2. Pre-London (9-11am Dubai)**
- Finalizes Asia range if not yet identified
- Prepares for London session

### **3. London Session (11am-2pm Dubai)**
- Waits for price to break Asia range
- **Breakout ABOVE** → Goes **SHORT** (fades it)
- **Breakout BELOW** → Goes **LONG** (fades it)
- Sets TP at opposite side of range
- Sets SL at 150% of range size
- Calculates lot size based on risk %

### **4. After London (2pm+ Dubai)**
- Closes any remaining positions
- Resets for next day

### **5. Midnight**
- Daily reset
- Clears ranges and trade tracking

---

## 🔍 Monitoring

### **Check EA is Running:**

**Experts Tab:**
```
========================================
European Indexes Asia-London Range EA v2.0
========================================
Mode: SINGLE-SYMBOL
  ✓ Trading: GER40
Risk Management: 1.0% per trade (Max: 5.00 lots)
Stop Loss: 150% of Asia range
========================================
```

### **During Asia Session:**
```
=== ASIA SESSION - Monitoring ranges ===
✓ GER40 Asia Range: 18500.00000 - 18550.00000 (Size: 50.00000)
```

### **During London Session:**
```
GER40 breakout ABOVE: 18555.00000 > 18550.00000 - Going SHORT
GER40: Risk=1.00% (100.00), SL=75.0 pts, Lot=0.13
✅ GER40 order placed: SHORT 0.13 lots @ 18555.00000
   Target: 18500.00000 | Stop: 18630.00000
```

### **Position Closed:**
```
📊 CLOSED: GER40 | Reason: TP/SL Hit | P&L: 71.50
```

---

## 🐛 Troubleshooting

### **"Symbol not found" Error**

**Solution:**
1. Check symbol name in Market Watch
2. Update EA parameter with correct name
3. Or use single-symbol mode (attach to chart)

### **No Trades Executing**

**Check:**
1. Current time is London session (11am-2pm Dubai)
2. Asia range was identified (check logs)
3. Price is breaking the range
4. No existing position open
5. Haven't traded today yet

### **Lot Size Too Small/Large**

**Adjust:**
- Increase/decrease `RiskPercent`
- Check `MaxLots` limit
- Verify account balance

### **EA Not Starting**

**Check:**
1. AutoTrading enabled (green button)
2. EA shows smiley face on chart
3. No errors in Experts tab
4. Symbol is valid and tradeable

---

## ✅ Pre-Live Checklist

- [ ] Tested on demo account (1+ week)
- [ ] Symbol names verified for your broker
- [ ] Risk % set appropriately (0.5-1% recommended)
- [ ] Session times correct for your timezone
- [ ] AutoTrading enabled
- [ ] Logs showing correct initialization
- [ ] First trade executed correctly
- [ ] SL/TP levels verified

---

## 📞 Quick Reference

**Default Settings (Prop Firm Safe):**
```
EnableMultiSymbol = false
SymbolOverride = ""
RiskPercent = 1.0
MaxLots = 5.0
StopLossPct = 1.5
MagicNumber = 234000
EnableLogging = true
```

**Session Times (Dubai GMT+4):**
- Asia: 5am - 9am
- London: 11am - 2pm

**Strategy:**
- Fades breakouts from Asia range
- One trade per day per symbol
- Risk-based position sizing

---

**You're ready to trade!** 🚀

Start with single-symbol mode on demo, then scale to multi-symbol or live trading.
