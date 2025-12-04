# Windows Setup & Testing Guide

This guide is for setting up and testing the MT5 bot on a Windows machine.

---

## 🖥️ Prerequisites

- **Windows 10/11** (or Windows Server)
- **Python 3.8+** installed
- **MetaTrader 5** installed
- **Prop firm account** or demo account configured in MT5

---

## 📦 Installation Steps

### 1. Install Python (if not already installed)

Download from: https://www.python.org/downloads/

**Important:** Check "Add Python to PATH" during installation

Verify installation:
```cmd
python --version
```

### 2. Clone/Copy the Project

```cmd
cd C:\Users\YourName\Documents
git clone <repository-url> mt5-bots
cd mt5-bots
```

Or copy the project folder to your Windows machine.

### 3. Install Dependencies

```cmd
pip install -r requirements.txt
```

Expected output:
```
Successfully installed MetaTrader5-5.0.45 pandas-2.0.0 numpy-1.24.0 pytz-2023.3
```

### 4. Configure MetaTrader 5

1. **Open MT5**
2. **Go to:** Tools → Options → Expert Advisors
3. **Enable:**
   - ✅ Allow automated trading
   - ✅ Allow DLL imports
   - ✅ Allow WebRequest for listed URL
4. **Click OK**

### 5. Verify Symbol Names

Different brokers use different symbol names. Run:

```cmd
python scripts\test_connection.py
```

This will show you:
- Your account info
- Available symbols
- Recommended symbol names for config.json

**Example output:**
```
✅ Connected to MT5
Account: 12345678
Server: YourBroker-Demo
Balance: $100000.00

Testing European Index Symbols:
DAX:
  ✅ GER40: Germany 40
     Spread: 2 | Digits: 2

CAC40:
  ✅ FRA40: France 40
     Spread: 1 | Digits: 2
...
```

### 6. Update Configuration (if needed)

If your broker uses different symbol names, edit `config.json`:

```json
{
  "symbols": {
    "default": ["GER40", "FRA40", "UK100", "EUSTX50"]
  }
}
```

Replace with the symbols found in step 5.

---

## 🧪 Testing

### Quick Test (Recommended)

Run the automated test suite:

```cmd
bash run_tests.sh
```

Or run tests manually:

### Manual Tests

**1. Test MT5 Connection:**
```cmd
python scripts\test_connection.py
```

**2. Test Bot (No Trading):**
```cmd
python scripts\run_bot.py --test
```

**3. Syntax Check:**
```cmd
python -m py_compile bot\european_indexes_mt5.py
python -m py_compile scripts\run_bot.py
```

**4. Configuration Check:**
```cmd
python -c "import json; json.load(open('config.json')); print('Config OK')"
```

---

## 🚀 Running the Bot

### Test Mode (Recommended First)

Start with test mode to verify everything works:

```cmd
python scripts\run_bot.py --test
```

### Demo Account (Recommended)

Run on demo account first:

```cmd
python scripts\run_bot.py
```

**Monitor in separate terminal:**
```cmd
python scripts\monitor.py
```

### Custom Parameters

**Conservative settings:**
```cmd
python scripts\run_bot.py --risk-per-trade 0.01 --daily-risk 0.03 --lot-size 0.01
```

**Specific symbols only:**
```cmd
python scripts\run_bot.py --symbols GER40 FRA40
```

**Custom stop loss:**
```cmd
python scripts\run_bot.py --stop-loss 2.0
```

### Live Trading

**⚠️ Only after successful demo testing!**

1. Switch MT5 to live account
2. Start with small lot size
3. Monitor closely for first week

```cmd
python scripts\run_bot.py --lot-size 0.01
```

---

## 📊 Monitoring

### Real-time Monitoring

**Option 1: Monitoring Dashboard**
```cmd
python scripts\monitor.py
```

**Option 2: Command Line Monitor**
```cmd
python scripts\run_bot.py --monitor
```

**Option 3: Log Files**
```cmd
# View logs in real-time
Get-Content logs\european_indexes_mt5.log -Wait -Tail 50

# Or use tail if you have Git Bash
tail -f logs/european_indexes_mt5.log
```

### Check State

```cmd
# View current state
type state\european_indexes_mt5_state.json

# Pretty print (requires Python)
python -m json.tool state\european_indexes_mt5_state.json
```

---

## 🐛 Troubleshooting

### Issue: "MT5 initialization failed"

**Solutions:**
1. Ensure MT5 is running
2. Check "Allow automated trading" is enabled
3. Try restarting MT5
4. Check if MT5 terminal is logged in

### Issue: "Symbol not found"

**Solutions:**
1. Run `python scripts\test_connection.py`
2. Check your broker's symbol names
3. Update `config.json` with correct symbols

### Issue: "No trades executing"

**Possible causes:**
1. Not in London session (11am-2pm Dubai time)
2. Asia range not identified yet
3. No breakouts occurring
4. Daily risk limit reached

**Check logs:**
```cmd
type logs\european_indexes_mt5.log | findstr ERROR
```

### Issue: "Import error"

**Solutions:**
1. Reinstall dependencies: `pip install -r requirements.txt`
2. Check Python version: `python --version` (should be 3.8+)
3. Verify MetaTrader5 installed: `pip show MetaTrader5`

---

## 📁 File Locations

### Logs
```
logs\european_indexes_mt5.log
```

### State
```
state\european_indexes_mt5_state.json
```

### Configuration
```
config.json
```

---

## ⚙️ Configuration Options

Edit `config.json` to customize:

### Symbols
```json
"symbols": {
  "default": ["GER40", "FRA40", "UK100", "EUSTX50"]
}
```

### Risk Parameters
```json
"trading_parameters": {
  "stop_loss_pct": 1.5,        // 150% of Asia range
  "max_risk_per_trade": 0.02,  // 2% per trade
  "max_daily_risk": 0.05,      // 5% daily max
  "lot_size": 0.01             // Position size
}
```

### Session Times (Dubai timezone)
```json
"session_times_dubai": {
  "asia_start_hour": 5,
  "asia_end_hour": 9,
  "london_start_hour": 11,
  "london_end_hour": 14
}
```

---

## 🔄 Running as Windows Service

To run the bot 24/7, you can set it up as a Windows service.

### Option 1: Task Scheduler

1. Open Task Scheduler
2. Create Basic Task
3. Trigger: At startup
4. Action: Start a program
5. Program: `python`
6. Arguments: `C:\path\to\mt5-bots\scripts\run_bot.py`
7. Start in: `C:\path\to\mt5-bots`

### Option 2: NSSM (Non-Sucking Service Manager)

1. Download NSSM: https://nssm.cc/download
2. Install service:
```cmd
nssm install MT5Bot "C:\Python39\python.exe" "C:\path\to\mt5-bots\scripts\run_bot.py"
nssm start MT5Bot
```

---

## 📈 Performance Monitoring

### Daily Checklist

- [ ] Check logs for errors
- [ ] Verify trades executed correctly
- [ ] Review P&L
- [ ] Check position status
- [ ] Verify risk limits not exceeded

### Weekly Review

- [ ] Calculate win rate
- [ ] Review total P&L
- [ ] Analyze losing trades
- [ ] Adjust parameters if needed
- [ ] Check for any pattern changes

### Monthly Analysis

- [ ] Compare to backtested performance
- [ ] Review strategy effectiveness
- [ ] Optimize parameters
- [ ] Plan improvements

---

## 🚨 Emergency Procedures

### Stop the Bot Immediately

**Method 1: Keyboard**
Press `Ctrl+C` in the terminal

**Method 2: Close All Positions**
```cmd
# This will close all positions and stop
python scripts\run_bot.py --close-all
```

**Method 3: Disable in MT5**
Tools → Options → Expert Advisors → Uncheck "Allow automated trading"

### Recover from Crash

1. Check logs: `logs\european_indexes_mt5.log`
2. Check state: `state\european_indexes_mt5_state.json`
3. Verify open positions in MT5
4. Restart bot: `python scripts\run_bot.py`

The bot will automatically recover its state and continue.

---

## ✅ Pre-Live Checklist

Before going live with real money:

- [ ] All tests pass
- [ ] Symbols verified with broker
- [ ] Demo account tested for 1+ week
- [ ] Win rate matches expectations (86-92%)
- [ ] No errors in logs
- [ ] Monitoring system working
- [ ] Risk parameters appropriate
- [ ] Prop firm rules understood
- [ ] Emergency procedures tested
- [ ] Backup plan in place

---

## 📞 Support

### Check Documentation
1. `README.md` - Quick start
2. `SETUP.md` - Installation
3. `DEVELOPER_GUIDE.md` - Development
4. `CODE_REVIEW_SUMMARY.md` - Code review
5. `docs\USAGE.md` - Detailed usage

### Debug Commands
```cmd
# Test connection
python scripts\test_connection.py

# Test mode
python scripts\run_bot.py --test

# Check status
python scripts\run_bot.py --monitor

# View logs
type logs\european_indexes_mt5.log
```

---

## 🎓 Learning Resources

**MT5 Python API:**
- https://www.mql5.com/en/docs/python_metatrader5
- https://www.mql5.com/en/articles/7159

**Strategy Documentation:**
- See `DEVELOPER_GUIDE.md` for strategy details
- Review `bot\european_indexes_mt5.py` for implementation

---

**Good luck with your trading! 🚀**

Remember: Start with demo, monitor closely, and adjust as needed.
