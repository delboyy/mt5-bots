# European Indexes MT5 Trading Bot

Multi-symbol trading bot for European stock indexes (DAX, CAC40, FTSE, Euro STOXX 50) using the Asia-London range strategy on MetaTrader 5.

## 🎯 Quick Start

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Test MT5 connection
python scripts/run_bot.py --test

# 3. Start trading
python scripts/run_bot.py

# 4. Monitor (separate terminal)
python scripts/monitor.py
```

## 📊 Performance

Based on backtesting:
- **Annual Return:** 88-261%
- **Win Rate:** 86-92%
- **Trades/Year:** ~180 per symbol

## 📁 Structure

```
european-indexes-mt5-bot/
├── bot/                    # Main bot code
├── scripts/                # Run and monitor scripts
├── docs/                   # Documentation
├── logs/                   # Trading logs
└── state/                  # Bot state files
```

## 📖 Documentation

- **[SETUP.md](SETUP.md)** - Installation and configuration
- **[DEVELOPER_GUIDE.md](DEVELOPER_GUIDE.md)** - For developers/next agent
- **[docs/USAGE.md](docs/USAGE.md)** - Detailed usage guide

## ⚙️ Configuration

Edit `config.json` to customize:
- Symbols to trade
- Risk parameters
- Session times
- Lot sizes

## 🔧 Requirements

- Python 3.8+
- MetaTrader 5 installed
- Prop firm account with European indexes

## 📞 Support

Check logs: `logs/european_indexes_mt5.log`  
Check state: `state/european_indexes_mt5_state.json`

## ⚠️ Important

- Verify symbol names with your broker (`--test`)
- Start with small lot sizes
- Monitor closely during first trades
- Follow prop firm rules

---

**Ready to trade!** 🚀
