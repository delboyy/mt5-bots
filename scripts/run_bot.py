#!/usr/bin/env python3
"""
Run Script for European Indexes MT5 Bot
Separate from Alpaca bots - runs independently for prop firm trading
"""

import argparse
import sys
import os
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(
        description='European Indexes Asia-London Range Trading Bot (MT5)',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Run with default settings
  python run_european_indexes_mt5.py
  
  # Custom symbols (check your broker's names)
  python run_european_indexes_mt5.py --symbols GER40 FRA40 UK100
  
  # Conservative risk settings
  python run_european_indexes_mt5.py --risk-per-trade 0.01 --daily-risk 0.03
  
  # Smaller lot size
  python run_european_indexes_mt5.py --lot-size 0.01
  
  # Test connection only
  python run_european_indexes_mt5.py --test
        """
    )
    
    parser.add_argument('--symbols', nargs='+', 
                       default=['GER40', 'FRA40', 'UK100', 'EUSTX50'],
                       help='Symbols to trade (default: GER40 FRA40 UK100 EUSTX50)')
    
    parser.add_argument('--stop-loss', type=float, default=1.5,
                       help='Stop loss as multiple of Asia range (default: 1.5 = 150%%)')
    
    parser.add_argument('--risk-per-trade', type=float, default=0.02,
                       help='Max risk per trade as decimal (default: 0.02 = 2%%)')
    
    parser.add_argument('--daily-risk', type=float, default=0.05,
                       help='Max daily risk as decimal (default: 0.05 = 5%%)')
    
    parser.add_argument('--lot-size', type=float, default=0.01,
                       help='Position size in lots (default: 0.01)')
    
    parser.add_argument('--test', action='store_true',
                       help='Test MT5 connection and symbols only')
    
    parser.add_argument('--monitor', action='store_true',
                       help='Show monitoring dashboard')
    
    args = parser.parse_args()
    
    # Test mode
    if args.test:
        print("🧪 Testing MT5 Connection...")
        print("="*60)
        
        try:
            import MetaTrader5 as mt5
            
            if not mt5.initialize():
                print(f"❌ MT5 initialization failed: {mt5.last_error()}")
                return 1
            
            account_info = mt5.account_info()
            if account_info is None:
                print("❌ Failed to get account info")
                return 1
            
            print(f"✅ Connected to MT5")
            print(f"Account: {account_info.login}")
            print(f"Server: {account_info.server}")
            print(f"Balance: ${account_info.balance:.2f}")
            print(f"Equity: ${account_info.equity:.2f}")
            print()
            
            print("Testing symbols:")
            for symbol in args.symbols:
                symbol_info = mt5.symbol_info(symbol)
                if symbol_info is None:
                    print(f"❌ {symbol}: NOT FOUND")
                    print(f"   Check your broker's symbol name for this index")
                else:
                    print(f"✅ {symbol}: {symbol_info.description}")
                    print(f"   Spread: {symbol_info.spread} | Digits: {symbol_info.digits}")
            
            mt5.shutdown()
            print()
            print("="*60)
            print("✅ Connection test complete")
            return 0
            
        except ImportError:
            print("❌ MetaTrader5 library not installed")
            print("Install with: pip install MetaTrader5")
            return 1
        except Exception as e:
            print(f"❌ Error: {e}")
            return 1
    
    # Monitor mode
    if args.monitor:
        print("📊 Launching monitoring dashboard...")
        state_file = Path(__file__).resolve().parents[2] / 'state' / 'european_indexes_mt5_state.json'
        
        try:
            import json
            if state_file.exists():
                with open(state_file, 'r') as f:
                    state = json.load(f)
                
                print("="*60)
                print("EUROPEAN INDEXES BOT - CURRENT STATUS")
                print("="*60)
                
                stats = state.get('stats', {})
                print(f"Trades Today: {stats.get('trades_today', 0)}")
                print(f"Wins: {stats.get('wins', 0)} | Losses: {stats.get('losses', 0)}")
                print(f"Win Rate: {stats.get('win_rate', 0):.1f}%")
                print(f"Daily P&L: ${stats.get('daily_pnl', 0):.2f}")
                print(f"Total P&L: ${stats.get('total_pnl', 0):.2f}")
                print(f"Errors Today: {stats.get('errors_today', 0)}")
                print()
                
                # Show recent trades
                trades = state.get('trades_today', [])
                if trades:
                    print("Recent Trades:")
                    for trade in trades[-5:]:  # Last 5 trades
                        print(f"  {trade['symbol']} {trade['direction']}: "
                              f"{trade['entry_price']:.2f} → {trade['exit_price']:.2f} | "
                              f"P&L: ${trade['pnl']:.2f} | {trade['reason']}")
                
                # Show errors
                errors = state.get('errors_today', [])
                if errors:
                    print()
                    print("Recent Errors:")
                    for error in errors[-5:]:  # Last 5 errors
                        print(f"  [{error['type']}] {error['message']}")
                
                print("="*60)
            else:
                print("No state file found. Bot hasn't run yet.")
            
            return 0
            
        except Exception as e:
            print(f"Error reading state: {e}")
            return 1
    
    # Run bot
    print("🚀 Starting European Indexes Asia-London Range Bot (MT5)")
    print("="*60)
    print(f"Symbols: {', '.join(args.symbols)}")
    print(f"Stop Loss: {args.stop_loss*100:.0f}% of Asia range")
    print(f"Risk per Trade: {args.risk_per_trade*100:.0f}%")
    print(f"Daily Risk Limit: {args.daily_risk*100:.0f}%")
    print(f"Lot Size: {args.lot_size}")
    print("="*60)
    print()
    
    try:
        # Add bot directory to path
        sys.path.insert(0, str(Path(__file__).parent.parent / 'bot'))
        from european_indexes_mt5 import EuropeanIndexesMT5Bot
        
        bot = EuropeanIndexesMT5Bot(
            symbols=args.symbols,
            stop_loss_pct=args.stop_loss,
            max_risk_per_trade=args.risk_per_trade,
            max_daily_risk=args.daily_risk,
            lot_size=args.lot_size
        )
        
        bot.run()
        
    except ImportError as e:
        print(f"❌ Import error: {e}")
        print()
        print("Make sure MetaTrader5 is installed:")
        print("  pip install MetaTrader5")
        return 1
    except KeyboardInterrupt:
        print("\n👋 Bot stopped by user")
        return 0
    except Exception as e:
        print(f"❌ Error: {e}")
        import traceback
        traceback.print_exc()
        return 1

if __name__ == "__main__":
    sys.exit(main())
