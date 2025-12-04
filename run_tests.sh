#!/bin/bash
# Quick Test Script for MT5 Bot
# Run this on Windows after installing dependencies

echo "=================================="
echo "MT5 Bot Quick Test Suite"
echo "=================================="
echo ""

# Test 1: Python Syntax
echo "1. Testing Python Syntax..."
python -m py_compile bot/european_indexes_mt5.py && echo "   ✅ Main bot compiles" || echo "   ❌ Main bot has syntax errors"
python -m py_compile scripts/run_bot.py && echo "   ✅ Run script compiles" || echo "   ❌ Run script has syntax errors"
python -m py_compile scripts/monitor.py && echo "   ✅ Monitor script compiles" || echo "   ❌ Monitor script has syntax errors"
python -m py_compile scripts/test_connection.py && echo "   ✅ Test script compiles" || echo "   ❌ Test script has syntax errors"
echo ""

# Test 2: Configuration
echo "2. Testing Configuration..."
python -c "import json; json.load(open('config.json')); print('   ✅ config.json is valid')" || echo "   ❌ config.json is invalid"
echo ""

# Test 3: Dependencies
echo "3. Checking Dependencies..."
python -c "import MetaTrader5; print('   ✅ MetaTrader5 installed')" || echo "   ❌ MetaTrader5 not installed"
python -c "import pandas; print('   ✅ pandas installed')" || echo "   ❌ pandas not installed"
python -c "import numpy; print('   ✅ numpy installed')" || echo "   ❌ numpy not installed"
python -c "import pytz; print('   ✅ pytz installed')" || echo "   ❌ pytz not installed"
echo ""

# Test 4: MT5 Connection
echo "4. Testing MT5 Connection..."
python scripts/test_connection.py
echo ""

# Test 5: Bot Test Mode
echo "5. Testing Bot (Test Mode)..."
python scripts/run_bot.py --test
echo ""

echo "=================================="
echo "Test Suite Complete!"
echo "=================================="
echo ""
echo "Next Steps:"
echo "1. If all tests pass, run: python scripts/run_bot.py"
echo "2. Monitor logs: tail -f logs/european_indexes_mt5.log"
echo "3. Check state: python scripts/run_bot.py --monitor"
echo ""
