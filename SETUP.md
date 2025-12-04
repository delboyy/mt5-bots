# Setup Guide - MQL5 Expert Advisor

This bot is now available as a **native MQL5 Expert Advisor** that runs directly inside MetaTrader 5.

---

## 🎯 Quick Start

### Option 1: MQL5 Expert Advisor (Recommended)

**For Ubuntu Server, Mac, or any platform:**

1. Copy `EuropeanIndexesEA.mq5` to MT5 Experts folder
2. Compile in MetaEditor
3. Attach to chart
4. Configure parameters
5. Enable AutoTrading

**Detailed instructions below** ⬇️

### Option 2: Python Bot (Windows Only)

The original Python bot is still available but requires Windows. See [Python Setup](#python-bot-setup-windows-only) below.

---

## 📋 Prerequisites

### For MQL5 EA (All Platforms)

1. **MetaTrader 5** installed and running
   - Download from your broker/prop firm
   - Login to your account

2. **Prop Firm Account** (or Demo)
   - Account with European indexes access
   - Symbols: GER40, FRA40, UK100, EUSTX50 (or broker equivalents)

3. **Basic MT5 Knowledge**
   - How to attach EA to chart
   - How to enable AutoTrading
   - How to view Expert logs

---

## 🚀 MQL5 EA Installation

### Step 1: Locate MT5 Data Folder

In MetaTrader 5:
1. **File** → **Open Data Folder**
2. This opens your MT5 data directory

### Step 2: Copy EA File

Copy `EuropeanIndexesEA.mq5` to:
```
MQL5/Experts/EuropeanIndexesEA.mq5
```

### Step 3: Compile the EA

1. Open **MetaEditor** (F4 in MT5 or Tools → MetaQuotes Language Editor)
2. Navigate to **Experts** folder in Navigator
3. Double-click `EuropeanIndexesEA.mq5`
4. Click **Compile** button (F7) or Compile menu
5. Check for **0 errors, 0 warnings** in Toolbox

**Expected output:**
```
0 error(s), 0 warning(s)
Compilation successful
```

### Step 4: Attach EA to Chart

1. In MT5, open **any chart** (symbol doesn't matter - EA trades multiple symbols)
2. In **Navigator** panel → **Expert Advisors**
3. Drag `EuropeanIndexesEA` onto the chart
4. A settings dialog will appear

### Step 5: Configure EA Parameters

**Trading Symbols:**
- Symbol1: `GER40` (or your broker's DAX symbol)
- Symbol2: `FRA40` (or your broker's CAC40 symbol)
- Symbol3: `UK100` (or your broker's FTSE symbol)
- Symbol4: `EUSTX50` (or your broker's Euro STOXX symbol)

**Session Times (Dubai GMT+4):**
- AsiaStartHour: `5`
- AsiaEndHour: `9`
- LondonStartHour: `11`
- LondonEndHour: `14`

**Risk Management:**
- LotSize: `0.01` (adjust based on account size)
- StopLossPct: `1.5` (150% of Asia range)
- MaxRiskPerTrade: `0.02` (2%)
- MaxDailyRisk: `0.05` (5%)

**EA Settings:**
- MagicNumber: `234000` (unique identifier)
- Slippage: `10` points
- EnableLogging: `true` (detailed logs)

**Important Checkboxes:**
- ✅ **Allow live trading**
- ✅ **Allow DLL imports** (if required)
- ✅ **Confirm DLL function calls**

Click **OK** to start the EA.

### Step 6: Enable AutoTrading

1. Click **AutoTrading** button in MT5 toolbar (or press Ctrl+E)
2. Button should be **green** when enabled
3. Check chart - EA should show a **smiley face** 😊 in top-right corner

---

## ✅ Verification

### Check EA is Running

1. **Chart indicator:** Smiley face 😊 in top-right corner
2. **Experts tab:** Should show EA initialization messages
3. **Journal tab:** Check for any errors

**Expected logs:**
```
========================================
European Indexes Asia-London Range EA
========================================
Trading 4 symbols:
  - GER40
  - FRA40
  - UK100
  - EUSTX50
Stop Loss: 150% of Asia range
Max Risk/Trade: 2%
Max Daily Risk: 5%
========================================
```

### Verify Symbol Names

If you see errors like "Symbol not found", update the EA parameters:

1. **Right-click chart** → **Expert Advisors** → **Properties**
2. Update symbol names to match your broker
3. Click **OK**

**Common symbol variations:**
- **FTMO:** GER40, FRA40, UK100, EUSTX50
- **MyForexFunds:** GER30, FRA40, UK100, EU50
- **The5%ers:** DE40, FR40, UK100, STOXX50

To find your broker's symbols:
1. **View** → **Market Watch** (Ctrl+M)
2. Search for: DAX, CAC, FTSE, STOXX
3. Note exact symbol names

---

## 📊 Monitoring

### View EA Logs

**Experts Tab:**
- Shows all EA activity
- Entry/exit signals
- Trade executions
- Errors and warnings

**Journal Tab:**
- System messages
- Connection status
- Compilation info

### Check Positions

**Trade Tab:**
- Shows open positions
- Current P&L
- SL/TP levels

**History Tab:**
- Closed trades
- Daily/weekly performance

---

## ⚙️ EA Parameters Explained

### Trading Symbols
Configure which European indexes to trade. Leave blank to skip.

### Session Times
All times in **Dubai timezone (GMT+4)**:
- **Asia Session:** 5am-9am (range identification)
- **London Session:** 11am-2pm (trading window)

### Risk Management
- **LotSize:** Position size (start small: 0.01)
- **StopLossPct:** SL as % of Asia range (1.5 = 150%)
- **MaxRiskPerTrade:** Max risk per trade (0.02 = 2%)
- **MaxDailyRisk:** Daily risk limit (0.05 = 5%)

### Strategy Logic
1. **Asia Session:** Identifies high/low range
2. **London Session:** Waits for breakout
3. **Entry:** Fades the breakout (opposite direction)
4. **Exit:** TP at opposite side of range, SL at 150% of range

---

## 🐛 Troubleshooting

### EA Not Starting

**Check:**
1. AutoTrading is enabled (green button)
2. EA shows smiley face on chart
3. No errors in Experts tab

**Fix:**
1. Remove EA from chart
2. Re-attach with correct parameters
3. Enable AutoTrading

### "Symbol not found" Error

**Fix:**
1. Open Market Watch (Ctrl+M)
2. Find correct symbol names
3. Update EA parameters
4. Restart EA

### No Trades Executing

**Check:**
1. Current time is London session (11am-2pm Dubai)
2. Asia range was identified (check logs)
3. Price is breaking the range
4. Daily risk limit not reached

**View logs:**
```
=== ASIA SESSION - Monitoring ranges ===
✓ GER40 Asia Range: 18500.00 - 18550.00 (Size: 50.00)
```

### Compilation Errors

**Common issues:**
1. Wrong MT5 version (need MT5, not MT4)
2. File in wrong folder (must be in MQL5/Experts/)
3. Syntax errors (check error messages)

**Fix:**
1. Ensure using MT5 (not MT4)
2. Copy file to correct location
3. Recompile with F7

---

## 🔒 Important Notes

### Before Live Trading

1. **Test on Demo Account**
   - Run for at least 1 week
   - Verify trades execute correctly
   - Check P&L calculations

2. **Verify Symbol Names**
   - Each broker uses different names
   - Test with small position size first

3. **Understand the Strategy**
   - Fades breakouts (counter-trend)
   - Requires volatile markets
   - Best during London session

4. **Follow Prop Firm Rules**
   - Check max daily loss limits
   - Verify allowed trading hours
   - Confirm index trading is permitted

### Risk Warning

- Start with **minimum lot size** (0.01)
- Monitor **first trades closely**
- Adjust parameters based on **account size**
- Never risk more than you can afford to lose

---

## 📈 Performance Expectations

**Based on backtesting:**
- Win Rate: 86-92%
- Annual Return: 88-261%
- Trades per Symbol: ~180/year
- Max Risk per Trade: 2%
- Max Daily Risk: 5%

**Important:** Past performance doesn't guarantee future results.

---

## Python Bot Setup (Windows Only)

The original Python bot is still available but **only works on Windows**.

### Prerequisites

1. **Windows OS** (Python MT5 library is Windows-only)
2. **Python 3.8+**
3. **MetaTrader 5**

### Installation

```bash
# Create virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Test connection
python scripts/run_bot.py --test

# Run bot
python scripts/run_bot.py
```

### Why MQL5 EA is Better

✅ **Platform independent** (works on Ubuntu, Mac, Windows)  
✅ **Runs inside MT5** (no external process)  
✅ **More reliable** (native integration)  
✅ **Easier deployment** (just attach to chart)  
✅ **Better performance** (compiled code)

---

## 📞 Support

### Check Logs First

**Experts Tab:** All EA activity  
**Journal Tab:** System messages  
**Trade Tab:** Open positions

### Common Questions

**Q: Can I run this on Ubuntu/Mac?**  
A: Yes! Use the MQL5 EA (runs inside MT5)

**Q: Can I trade different symbols?**  
A: Yes, update EA parameters with your symbols

**Q: Can I change session times?**  
A: Yes, adjust session hours in EA parameters

**Q: How do I stop the EA?**  
A: Disable AutoTrading or remove EA from chart

---

## ✅ Quick Checklist

- [ ] MT5 installed and logged in
- [ ] EA file copied to MQL5/Experts/
- [ ] EA compiled successfully (0 errors)
- [ ] EA attached to chart
- [ ] Symbol names verified and configured
- [ ] Risk parameters set appropriately
- [ ] AutoTrading enabled (green button)
- [ ] EA showing smiley face on chart
- [ ] Logs showing initialization messages
- [ ] Tested on demo account first

---

**You're ready to trade!** 🚀

For code details and strategy explanation, see [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md).
