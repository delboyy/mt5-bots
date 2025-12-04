#!/usr/bin/env python3
"""
Monitoring Script for European Indexes MT5 Bot
Shows real-time stats, errors, and trade history
"""

import json
import os
from pathlib import Path
from datetime import datetime
import time

def clear_screen():
    """Clear terminal screen"""
    os.system('clear' if os.name == 'posix' else 'cls')

def load_state(state_file):
    """Load bot state"""
    try:
        if state_file.exists():
            with open(state_file, 'r') as f:
                return json.load(f)
        return None
    except Exception as e:
        print(f"Error loading state: {e}")
        return None

def print_dashboard(state):
    """Print monitoring dashboard"""
    clear_screen()
    
    print("="*80)
    print("EUROPEAN INDEXES MT5 BOT - LIVE MONITORING")
    print("="*80)
    print(f"Last Update: {state.get('last_update', 'N/A')}")
    print()
    
    # Statistics
    stats = state.get('stats', {})
    print("📊 STATISTICS")
    print("-"*80)
    print(f"Trades Today:    {stats.get('trades_today', 0)}")
    print(f"Wins:            {stats.get('wins', 0)}")
    print(f"Losses:          {stats.get('losses', 0)}")
    print(f"Win Rate:        {stats.get('win_rate', 0):.1f}%")
    print(f"Daily P&L:       ${stats.get('daily_pnl', 0):.2f}")
    print(f"Total P&L:       ${stats.get('total_pnl', 0):.2f}")
    print(f"Errors Today:    {stats.get('errors_today', 0)}")
    print()
    
    # Recent Trades
    trades = state.get('trades_today', [])
    if trades:
        print("💰 RECENT TRADES (Last 10)")
        print("-"*80)
        for trade in trades[-10:]:
            timestamp = trade.get('timestamp', '')[:19]  # Remove microseconds
            symbol = trade.get('symbol', '')
            direction = trade.get('direction', '')
            entry = trade.get('entry_price', 0)
            exit_price = trade.get('exit_price', 0)
            pnl = trade.get('pnl', 0)
            reason = trade.get('reason', '')
            
            pnl_symbol = "✅" if pnl > 0 else "❌"
            print(f"{timestamp} | {symbol:8} {direction:5} | "
                  f"{entry:8.2f} → {exit_price:8.2f} | "
                  f"{pnl_symbol} ${pnl:7.2f} | {reason}")
        print()
    else:
        print("💰 RECENT TRADES: None yet")
        print()
    
    # Recent Errors
    errors = state.get('errors_today', [])
    if errors:
        print("⚠️  RECENT ERRORS (Last 10)")
        print("-"*80)
        for error in errors[-10:]:
            timestamp = error.get('timestamp', '')[:19]
            error_type = error.get('type', '')
            message = error.get('message', '')
            symbol = error.get('symbol', 'N/A')
            
            print(f"{timestamp} | [{error_type:15}] {symbol:8} | {message}")
        print()
    else:
        print("⚠️  RECENT ERRORS: None")
        print()
    
    print("="*80)
    print("Press Ctrl+C to exit | Refreshes every 10 seconds")
    print("="*80)

def main():
    """Main monitoring loop"""
    state_file = Path(__file__).resolve().parents[2] / 'state' / 'european_indexes_mt5_state.json'
    
    print("Starting European Indexes MT5 Bot Monitor...")
    print(f"State file: {state_file}")
    print()
    
    if not state_file.exists():
        print("⚠️  State file not found. Bot hasn't run yet or no trades executed.")
        print(f"Expected location: {state_file}")
        return
    
    try:
        while True:
            state = load_state(state_file)
            
            if state:
                print_dashboard(state)
            else:
                print("⚠️  Could not load state file")
            
            time.sleep(10)  # Refresh every 10 seconds
            
    except KeyboardInterrupt:
        print("\n\n👋 Monitoring stopped")

if __name__ == "__main__":
    main()
