#!/bin/bash
# Quick setup script for European Indexes MT5 Bot

echo "=========================================="
echo "European Indexes MT5 Bot - Setup"
echo "=========================================="
echo ""

# Check Python version
echo "Checking Python version..."
python3 --version
if [ $? -ne 0 ]; then
    echo "❌ Python 3 not found. Please install Python 3.8+"
    exit 1
fi
echo "✅ Python 3 found"
echo ""

# Create virtual environment
echo "Creating virtual environment..."
python3 -m venv venv
if [ $? -ne 0 ]; then
    echo "❌ Failed to create virtual environment"
    exit 1
fi
echo "✅ Virtual environment created"
echo ""

# Activate virtual environment
echo "Activating virtual environment..."
source venv/bin/activate
echo "✅ Virtual environment activated"
echo ""

# Install dependencies
echo "Installing dependencies..."
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    echo "❌ Failed to install dependencies"
    exit 1
fi
echo "✅ Dependencies installed"
echo ""

# Create directories
echo "Creating directories..."
mkdir -p logs state
echo "✅ Directories created"
echo ""

# Test connection
echo "Testing MT5 connection..."
python scripts/test_connection.py
echo ""

echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Review config.json and update symbols if needed"
echo "  2. Run: python scripts/run_bot.py --test"
echo "  3. Start trading: python scripts/run_bot.py"
echo ""
echo "To activate venv in future:"
echo "  source venv/bin/activate"
echo ""
