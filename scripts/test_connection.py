#!/usr/bin/env python3
"""
Test MT5 Connection and Symbol Availability
"""

import sys
from pathlib import Path

# Add bot directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'bot'))

try:
    import MetaTrader5 as mt5
except ImportError:
    print("❌ MetaTrader5 library not installed")
    print("Install with: pip install MetaTrader5")
    sys.exit(1)

def test_connection():
    """Test MT5 connection"""
    print("="*70)
    print("MT5 CONNECTION TEST")
    print("="*70)
    print()
    
    # Initialize MT5
    if not mt5.initialize():
        print(f"❌ MT5 initialization failed: {mt5.last_error()}")
        print()
        print("Possible fixes:")
        print("  1. Ensure MT5 is running")
        print("  2. Enable 'Allow automated trading' in MT5")
        print("  3. Enable 'Allow DLL imports' in MT5")
        return False
    
    # Get account info
    account_info = mt5.account_info()
    if account_info is None:
        print("❌ Failed to get account info")
        mt5.shutdown()
        return False
    
    print(f"✅ Connected to MT5")
    print(f"Account: {account_info.login}")
    print(f"Server: {account_info.server}")
    print(f"Balance: ${account_info.balance:.2f}")
    print(f"Equity: ${account_info.equity:.2f}")
    print()
    
    # Test symbols
    print("Testing European Index Symbols:")
    print("-"*70)
    
    test_symbols = {
        'DAX': ['GER40', 'GER30', 'DE40', 'DAX40'],
        'CAC40': ['FRA40', 'FR40', 'CAC40'],
        'FTSE': ['UK100', 'FTSE100'],
        'Euro STOXX': ['EUSTX50', 'EU50', 'STOXX50']
    }
    
    found_symbols = {}
    
    for index_name, variations in test_symbols.items():
        print(f"\n{index_name}:")
        found = False
        for symbol in variations:
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is not None:
                print(f"  ✅ {symbol}: {symbol_info.description}")
                print(f"     Spread: {symbol_info.spread} | Digits: {symbol_info.digits}")
                found_symbols[index_name] = symbol
                found = True
                break
        
        if not found:
            print(f"  ❌ None of {variations} found")
            print(f"     Check your broker's symbol names")
    
    print()
    print("="*70)
    
    if found_symbols:
        print("✅ RECOMMENDED SYMBOLS FOR config.json:")
        print()
        print('"symbols": {')
        print(f'  "default": {list(found_symbols.values())}')
        print('}')
    else:
        print("⚠️  No symbols found - check your broker's symbol names")
    
    print("="*70)
    
    mt5.shutdown()
    return True

if __name__ == "__main__":
    success = test_connection()
    sys.exit(0 if success else 1)
