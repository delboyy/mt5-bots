# Setup Guide

## Prerequisites

1. **Python 3.8 or higher**
   ```bash
   python3 --version
   ```

2. **MetaTrader 5**
   - Download from your prop firm
   - Install and login to your account

3. **Prop Firm Account**
   - Funded account with European indexes access

---

## Installation

### 1. Clone/Download Repository

```bash
cd /Users/a1/Projects/Trading
# Repository is at: european-indexes-mt5-bot/
```

### 2. Create Virtual Environment (Recommended)

```bash
cd european-indexes-mt5-bot
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

---

## Configuration

### 1. Verify Symbol Names

**CRITICAL:** Different brokers use different symbol names!

```bash
python scripts/run_bot.py --test
```

This will show:
- MT5 connection status
- Available symbols
- Your account info

### 2. Update config.json

Edit `config.json` with your broker's symbol names:

```json
{
  "symbols": {
    "default": ["GER40", "FRA40", "UK100", "EUSTX50"]
  }
}
```

**Common variations:**
- **FTMO:** GER40, FRA40, UK100, EUSTX50
- **MyForexFunds:** GER30, FRA40, UK100, EU50
- **The5%ers:** DE40, FR40, UK100, STOXX50

### 3. Adjust Risk Parameters (Optional)

In `config.json`:

```json
{
  "trading_parameters": {
    "lot_size": 0.01,           # Position size
    "max_risk_per_trade": 0.02, # 2% per trade
    "max_daily_risk": 0.05      # 5% daily max
  }
}
```

---

## MT5 Configuration

### Enable Automated Trading

1. Open MT5
2. Tools → Options → Expert Advisors
3. Check:
   - ✅ Allow automated trading
   - ✅ Allow DLL imports
   - ✅ Allow WebRequest for listed URL

### Verify Connection

```bash
python scripts/run_bot.py --test
```

Should show:
```
✅ Connected to MT5
Account: 12345678
Server: YourBroker-Live
Balance: $10,000.00

Testing symbols:
✅ GER40: Germany 40
✅ FRA40: France 40
✅ UK100: UK 100
✅ EUSTX50: Euro Stoxx 50
```

---

## First Run

### 1. Test Mode

```bash
python scripts/run_bot.py --test
```

### 2. Start Bot

```bash
python scripts/run_bot.py
```

### 3. Monitor (Separate Terminal)

```bash
python scripts/monitor.py
```

---

## Troubleshooting

### "MT5 initialization failed"

**Fix:**
1. Ensure MT5 is running
2. Check "Allow automated trading" is enabled
3. Restart MT5

### "Symbol not found"

**Fix:**
1. Run `--test` to see available symbols
2. Update `config.json` with correct names
3. Check you have market data subscription

### "No trades executing"

**Check:**
1. Are you in London session? (11am-2pm Dubai time)
2. Was Asia range identified? (Check logs)
3. Is price breaking the range?

---

## Next Steps

1. ✅ Installation complete
2. ✅ MT5 configured
3. ✅ Symbols verified
4. ✅ Bot tested

**You're ready to trade!**

See [DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md) for code details.
