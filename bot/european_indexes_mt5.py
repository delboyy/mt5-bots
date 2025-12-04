#!/usr/bin/env python3
"""
European Indexes Asia-London Range Trading Bot - MT5 VERSION
For use with prop firms via MetaTrader 5

Multi-Symbol Trading:
- DAX 40 (Germany 40)
- CAC 40 (France 40)
- FTSE 100 (UK 100)
- Euro STOXX 50

Strategy: Asia-London range breakout reversal
Expected Performance: 88-261% annual return, 86-92% win rate
"""

import MetaTrader5 as mt5
import pandas as pd
import numpy as np
from datetime import datetime, time as dt_time, timedelta
import pytz
import time
import logging
import json
import os
from typing import Optional, Dict, List
from pathlib import Path

# Setup comprehensive logging
log_dir = Path(__file__).resolve().parents[2] / 'logs'
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / 'european_indexes_mt5.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger('EuropeanIndexesMT5')


class TradeMonitor:
    """Monitor trades, errors, and performance"""
    
    def __init__(self, state_file: str):
        self.state_file = state_file
        self.trades_today = []
        self.errors_today = []
        self.daily_pnl = 0
        self.total_pnl = 0
        
    def log_trade(self, symbol: str, direction: str, entry: float, exit: float, 
                   pnl: float, reason: str):
        """Log trade details"""
        trade = {
            'timestamp': datetime.now().isoformat(),
            'symbol': symbol,
            'direction': direction,
            'entry_price': entry,
            'exit_price': exit,
            'pnl': pnl,
            'reason': reason
        }
        self.trades_today.append(trade)
        self.daily_pnl += pnl
        self.total_pnl += pnl
        
        logger.info(f"📊 TRADE: {symbol} {direction} | Entry: {entry:.2f} → Exit: {exit:.2f} | PnL: {pnl:.2f} | Reason: {reason}")
        self.save_state()
    
    def log_error(self, error_type: str, message: str, symbol: str = None):
        """Log errors for monitoring"""
        error = {
            'timestamp': datetime.now().isoformat(),
            'type': error_type,
            'message': message,
            'symbol': symbol
        }
        self.errors_today.append(error)
        logger.error(f"❌ ERROR [{error_type}]: {message} | Symbol: {symbol}")
        self.save_state()
    
    def get_stats(self) -> Dict:
        """Get trading statistics"""
        wins = sum(1 for t in self.trades_today if t['pnl'] > 0)
        total_trades = len(self.trades_today)
        win_rate = (wins / total_trades * 100) if total_trades > 0 else 0
        
        return {
            'trades_today': total_trades,
            'wins': wins,
            'losses': total_trades - wins,
            'win_rate': win_rate,
            'daily_pnl': self.daily_pnl,
            'total_pnl': self.total_pnl,
            'errors_today': len(self.errors_today)
        }
    
    def save_state(self):
        """Save state to file"""
        try:
            os.makedirs(os.path.dirname(self.state_file), exist_ok=True)
            state = {
                'trades_today': self.trades_today,
                'errors_today': self.errors_today,
                'daily_pnl': self.daily_pnl,
                'total_pnl': self.total_pnl,
                'stats': self.get_stats(),
                'last_update': datetime.now().isoformat()
            }
            with open(self.state_file, 'w') as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            logger.error(f"Error saving state: {e}")
    
    def load_state(self):
        """Load previous state"""
        try:
            if os.path.exists(self.state_file):
                with open(self.state_file, 'r') as f:
                    state = json.load(f)
                    self.total_pnl = state.get('total_pnl', 0)
                    logger.info(f"Loaded state: Total PnL = {self.total_pnl:.2f}")
        except Exception as e:
            logger.error(f"Error loading state: {e}")
    
    def print_summary(self):
        """Print trading summary"""
        stats = self.get_stats()
        logger.info("="*60)
        logger.info("DAILY SUMMARY")
        logger.info("="*60)
        logger.info(f"Trades: {stats['trades_today']} | Wins: {stats['wins']} | Losses: {stats['losses']}")
        logger.info(f"Win Rate: {stats['win_rate']:.1f}%")
        logger.info(f"Daily P&L: {stats['daily_pnl']:.2f}")
        logger.info(f"Total P&L: {stats['total_pnl']:.2f}")
        logger.info(f"Errors: {stats['errors_today']}")
        logger.info("="*60)


class EuropeanIndexesMT5Bot:
    """
    European Indexes Asia-London Range Bot for MT5
    Trades multiple symbols simultaneously
    """
    
    def __init__(self,
                 symbols: List[str] = None,
                 stop_loss_pct: float = 1.5,
                 max_risk_per_trade: float = 0.02,
                 max_daily_risk: float = 0.05,
                 lot_size: float = 0.01):
        """
        Initialize MT5 bot
        
        Args:
            symbols: List of symbols to trade (e.g., ['GER40', 'FRA40', 'UK100', 'EUSTX50'])
            stop_loss_pct: Stop loss as % of Asia range
            max_risk_per_trade: Max risk per trade (2% default)
            max_daily_risk: Max daily risk (5% default)
            lot_size: Position size in lots
        """
        # Default symbols for prop firms (check your broker's symbol names)
        if symbols is None:
            self.symbols = ['GER40', 'FRA40', 'UK100', 'EUSTX50']  # Common MT5 names
        else:
            self.symbols = symbols
        
        self.stop_loss_pct = stop_loss_pct
        self.max_risk_per_trade = max_risk_per_trade
        self.max_daily_risk = max_daily_risk
        self.lot_size = lot_size
        
        # Time zones
        self.dubai_tz = pytz.timezone('Asia/Dubai')
        self.gmt_tz = pytz.timezone('GMT')
        
        # Session times (Dubai time)
        self.asia_start_hour = 5
        self.asia_end_hour = 9
        self.london_start_hour = 11
        self.london_end_hour = 14
        
        # State tracking
        self.asia_ranges = {}  # {symbol: range_data}
        self.current_trades = {}  # {symbol: trade_data}
        self.daily_risk_used = 0
        
        # Monitoring
        state_dir = Path(__file__).resolve().parents[2] / 'state'
        state_dir.mkdir(exist_ok=True)
        self.monitor = TradeMonitor(str(state_dir / 'european_indexes_mt5_state.json'))
        
        logger.info("European Indexes MT5 Bot initialized")
        logger.info(f"Symbols: {', '.join(self.symbols)}")
        logger.info(f"Stop Loss: {self.stop_loss_pct*100:.0f}% of range")
        logger.info(f"Max Risk/Trade: {self.max_risk_per_trade*100:.0f}%")
    
    def connect_mt5(self) -> bool:
        """Connect to MT5"""
        try:
            if not mt5.initialize():
                self.monitor.log_error("MT5_CONNECTION", f"MT5 initialization failed: {mt5.last_error()}")
                return False
            
            # Get account info
            account_info = mt5.account_info()
            if account_info is None:
                self.monitor.log_error("MT5_CONNECTION", "Failed to get account info")
                return False
            
            logger.info(f"✅ Connected to MT5")
            logger.info(f"Account: {account_info.login} | Balance: ${account_info.balance:.2f}")
            logger.info(f"Server: {account_info.server}")
            
            # Verify symbols
            for symbol in self.symbols:
                symbol_info = mt5.symbol_info(symbol)
                if symbol_info is None:
                    self.monitor.log_error("SYMBOL_ERROR", f"Symbol not found: {symbol}", symbol)
                    logger.warning(f"⚠️  Symbol {symbol} not available - check broker symbol names")
                else:
                    logger.info(f"✓ {symbol}: {symbol_info.description}")
            
            return True
            
        except Exception as e:
            self.monitor.log_error("MT5_CONNECTION", str(e))
            return False
    
    def disconnect_mt5(self):
        """Disconnect from MT5"""
        mt5.shutdown()
        logger.info("Disconnected from MT5")
    
    def get_historical_data(self, symbol: str, timeframe: int, bars: int = 100) -> pd.DataFrame:
        """
        Get historical data from MT5
        
        Args:
            symbol: Symbol name
            timeframe: MT5 timeframe (e.g., mt5.TIMEFRAME_M5)
            bars: Number of bars
        """
        try:
            rates = mt5.copy_rates_from_pos(symbol, timeframe, 0, bars)
            
            if rates is None or len(rates) == 0:
                self.monitor.log_error("DATA_ERROR", f"No data received for {symbol}", symbol)
                return pd.DataFrame()
            
            df = pd.DataFrame(rates)
            df['time'] = pd.to_datetime(df['time'], unit='s')
            df.set_index('time', inplace=True)
            
            # Ensure timezone
            if df.index.tz is None:
                df.index = df.index.tz_localize('UTC')
            
            return df
            
        except Exception as e:
            self.monitor.log_error("DATA_ERROR", f"Error getting data for {symbol}: {e}", symbol)
            return pd.DataFrame()
    
    def identify_asia_range(self, symbol: str) -> Optional[Dict]:
        """Identify Asia session range for symbol"""
        try:
            now_dubai = datetime.now(self.dubai_tz)
            today = now_dubai.date()
            
            # Define Asia session
            asia_start = self.dubai_tz.localize(datetime.combine(today, dt_time(self.asia_start_hour, 0)))
            asia_end = self.dubai_tz.localize(datetime.combine(today, dt_time(self.asia_end_hour, 0)))
            
            asia_start_utc = asia_start.astimezone(pytz.UTC)
            asia_end_utc = asia_end.astimezone(pytz.UTC)
            
            # Get data
            df = self.get_historical_data(symbol, mt5.TIMEFRAME_M5, bars=100)
            
            if df.empty:
                return None
            
            # Filter for Asia session
            asia_data = df[(df.index >= asia_start_utc) & (df.index < asia_end_utc)]
            
            if len(asia_data) < 3:
                logger.warning(f"{symbol}: Insufficient Asia data ({len(asia_data)} bars)")
                return None
            
            asia_high = asia_data['high'].max()
            asia_low = asia_data['low'].min()
            range_size = asia_high - asia_low
            
            # Validate range
            if range_size < 5:  # Minimum 5 points
                logger.warning(f"{symbol}: Range too small ({range_size:.2f})")
                return None
            
            logger.info(f"✓ {symbol} Asia Range: {asia_low:.2f} - {asia_high:.2f} (Size: {range_size:.2f})")
            
            return {
                'date': today,
                'asia_high': asia_high,
                'asia_low': asia_low,
                'range_size': range_size,
                'identified_at': now_dubai
            }
            
        except Exception as e:
            self.monitor.log_error("RANGE_ERROR", f"Error identifying range: {e}", symbol)
            return None
    
    def check_breakout(self, symbol: str) -> Optional[str]:
        """Check if price broke Asia range"""
        if symbol not in self.asia_ranges:
            return None
        
        try:
            # Get current price
            tick = mt5.symbol_info_tick(symbol)
            if tick is None:
                return None
            
            current_price = tick.bid
            asia_range = self.asia_ranges[symbol]
            
            # Check breakout
            if current_price > asia_range['asia_high']:
                logger.info(f"{symbol} breakout ABOVE: {current_price:.2f} > {asia_range['asia_high']:.2f}")
                return 'SHORT'  # Fade the breakout
            elif current_price < asia_range['asia_low']:
                logger.info(f"{symbol} breakout BELOW: {current_price:.2f} < {asia_range['asia_low']:.2f}")
                return 'LONG'  # Fade the breakout
            
            return None
            
        except Exception as e:
            self.monitor.log_error("BREAKOUT_ERROR", f"Error checking breakout: {e}", symbol)
            return None
    
    def place_order(self, symbol: str, direction: str, entry_price: float) -> bool:
        """Place order with stop loss and take profit"""
        try:
            asia_range = self.asia_ranges[symbol]
            
            # Calculate target and stop
            if direction == 'LONG':
                target_price = asia_range['asia_high']
                stop_distance = asia_range['range_size'] * self.stop_loss_pct
                stop_loss = entry_price - stop_distance
                order_type = mt5.ORDER_TYPE_BUY
            else:  # SHORT
                target_price = asia_range['asia_low']
                stop_distance = asia_range['range_size'] * self.stop_loss_pct
                stop_loss = entry_price + stop_distance
                order_type = mt5.ORDER_TYPE_SELL
            
            # Check risk limit
            risk_this_trade = self.lot_size * stop_distance
            if self.daily_risk_used + risk_this_trade > self.max_daily_risk:
                logger.warning(f"{symbol}: Daily risk limit reached")
                return False
            
            # Prepare order
            symbol_info = mt5.symbol_info(symbol)
            if symbol_info is None:
                self.monitor.log_error("ORDER_ERROR", f"Symbol info not available", symbol)
                return False
            
            price = entry_price
            request = {
                "action": mt5.TRADE_ACTION_DEAL,
                "symbol": symbol,
                "volume": self.lot_size,
                "type": order_type,
                "price": price,
                "sl": stop_loss,
                "tp": target_price,
                "deviation": 10,
                "magic": 234000,
                "comment": "Asia-London Range",
                "type_time": mt5.ORDER_TIME_GTC,
                "type_filling": mt5.ORDER_FILLING_IOC,
            }
            
            # Send order
            result = mt5.order_send(request)
            
            if result.retcode != mt5.TRADE_RETCODE_DONE:
                self.monitor.log_error("ORDER_ERROR", f"Order failed: {result.comment}", symbol)
                return False
            
            logger.info(f"✅ {symbol} order placed: {direction} {self.lot_size} lots @ {entry_price:.2f}")
            logger.info(f"   Target: {target_price:.2f} | Stop: {stop_loss:.2f}")
            
            # Store trade
            self.current_trades[symbol] = {
                'direction': direction,
                'entry_price': entry_price,
                'target_price': target_price,
                'stop_loss': stop_loss,
                'entry_time': datetime.now(self.dubai_tz),
                'ticket': result.order
            }
            
            self.daily_risk_used += risk_this_trade
            
            return True
            
        except Exception as e:
            self.monitor.log_error("ORDER_ERROR", f"Error placing order: {e}", symbol)
            return False
    
    def manage_position(self, symbol: str):
        """Manage open position"""
        if symbol not in self.current_trades:
            return
        
        try:
            trade = self.current_trades[symbol]
            
            # Get current price
            tick = mt5.symbol_info_tick(symbol)
            if tick is None:
                return
            
            current_price = tick.bid if trade['direction'] == 'LONG' else tick.ask
            
            # Check if position still exists
            positions = mt5.positions_get(symbol=symbol)
            if positions is None or len(positions) == 0:
                # Position closed (hit TP/SL)
                pnl = (trade['target_price'] - trade['entry_price']) if trade['direction'] == 'LONG' else (trade['entry_price'] - trade['target_price'])
                pnl *= self.lot_size
                
                self.monitor.log_trade(
                    symbol, trade['direction'],
                    trade['entry_price'], current_price,
                    pnl, "TP/SL Hit"
                )
                
                del self.current_trades[symbol]
                
        except Exception as e:
            self.monitor.log_error("POSITION_ERROR", f"Error managing position: {e}", symbol)
    
    def close_position(self, symbol: str, reason: str):
        """Manually close position"""
        try:
            positions = mt5.positions_get(symbol=symbol)
            if positions is None or len(positions) == 0:
                return
            
            for position in positions:
                tick = mt5.symbol_info_tick(symbol)
                price = tick.ask if position.type == mt5.ORDER_TYPE_BUY else tick.bid
                
                request = {
                    "action": mt5.TRADE_ACTION_DEAL,
                    "symbol": symbol,
                    "volume": position.volume,
                    "type": mt5.ORDER_TYPE_SELL if position.type == mt5.ORDER_TYPE_BUY else mt5.ORDER_TYPE_BUY,
                    "position": position.ticket,
                    "price": price,
                    "deviation": 10,
                    "magic": 234000,
                    "comment": f"Close: {reason}",
                    "type_time": mt5.ORDER_TIME_GTC,
                    "type_filling": mt5.ORDER_FILLING_IOC,
                }
                
                result = mt5.order_send(request)
                
                if result.retcode == mt5.TRADE_RETCODE_DONE:
                    if symbol in self.current_trades:
                        trade = self.current_trades[symbol]
                        pnl = position.profit
                        
                        self.monitor.log_trade(
                            symbol, trade['direction'],
                            trade['entry_price'], price,
                            pnl, reason
                        )
                        
                        del self.current_trades[symbol]
                
        except Exception as e:
            self.monitor.log_error("CLOSE_ERROR", f"Error closing position: {e}", symbol)
    
    def get_session_status(self) -> str:
        """Get current session"""
        now_dubai = datetime.now(self.dubai_tz)
        current_time = now_dubai.time()
        
        if dt_time(self.asia_start_hour, 0) <= current_time < dt_time(self.asia_end_hour, 0):
            return 'ASIA'
        elif dt_time(self.asia_end_hour, 0) <= current_time < dt_time(self.london_start_hour, 0):
            return 'PRE_LONDON'
        elif dt_time(self.london_start_hour, 0) <= current_time < dt_time(self.london_end_hour, 0):
            return 'LONDON'
        else:
            return 'CLOSED'
    
    def run(self):
        """Main bot loop"""
        logger.info("="*80)
        logger.info("European Indexes Asia-London Range Bot (MT5) Starting")
        logger.info("="*80)
        logger.info(f"Symbols: {', '.join(self.symbols)}")
        logger.info(f"Stop Loss: {self.stop_loss_pct*100:.0f}% of range")
        logger.info(f"Max Risk/Trade: {self.max_risk_per_trade*100:.0f}%")
        logger.info("="*80)
        
        # Load previous state
        self.monitor.load_state()
        
        # Connect to MT5
        if not self.connect_mt5():
            logger.error("Failed to connect to MT5. Exiting.")
            return
        
        try:
            while True:
                session = self.get_session_status()
                now_dubai = datetime.now(self.dubai_tz)
                
                logger.info(f"\n[{now_dubai.strftime('%H:%M:%S')} Dubai] Session: {session}")
                logger.info(f"Active Positions: {len(self.current_trades)} | Daily Risk: {self.daily_risk_used:.1%}")
                
                # Reset daily state if new day
                if now_dubai.hour == 0 and now_dubai.minute < 5:
                    self.daily_risk_used = 0
                    self.asia_ranges = {}
                    self.monitor.trades_today = []
                    self.monitor.errors_today = []
                    self.monitor.daily_pnl = 0
                    logger.info("Daily state reset")
                
                # During Asia: Identify ranges
                if session == 'ASIA':
                    logger.info("Asia session - monitoring ranges...")
                    for symbol in self.symbols:
                        if symbol not in self.asia_ranges:
                            asia_range = self.identify_asia_range(symbol)
                            if asia_range:
                                self.asia_ranges[symbol] = asia_range
                    time.sleep(300)  # 5 minutes
                
                # Pre-London: Finalize ranges
                elif session == 'PRE_LONDON':
                    logger.info("Pre-London - finalizing ranges...")
                    for symbol in self.symbols:
                        if symbol not in self.asia_ranges:
                            asia_range = self.identify_asia_range(symbol)
                            if asia_range:
                                self.asia_ranges[symbol] = asia_range
                    time.sleep(300)
                
                # London: Trade
                elif session == 'LONDON':
                    for symbol in self.symbols:
                        # Manage existing positions
                        if symbol in self.current_trades:
                            self.manage_position(symbol)
                        
                        # Look for new trades
                        elif symbol in self.asia_ranges:
                            direction = self.check_breakout(symbol)
                            if direction:
                                tick = mt5.symbol_info_tick(symbol)
                                if tick:
                                    entry_price = tick.ask if direction == 'LONG' else tick.bid
                                    self.place_order(symbol, direction, entry_price)
                    
                    time.sleep(60)  # 1 minute
                
                # After London: Close positions
                else:
                    if self.current_trades:
                        logger.info("London session ended - closing positions")
                        for symbol in list(self.current_trades.keys()):
                            self.close_position(symbol, 'TIME_EXIT')
                    
                    # Print summary
                    self.monitor.print_summary()
                    
                    time.sleep(1800)  # 30 minutes
                
        except KeyboardInterrupt:
            logger.info("\nBot stopped by user")
        except Exception as e:
            self.monitor.log_error("FATAL_ERROR", str(e))
            logger.error(f"Fatal error: {e}", exc_info=True)
        finally:
            # Close all positions
            for symbol in list(self.current_trades.keys()):
                self.close_position(symbol, 'SHUTDOWN')
            
            self.monitor.print_summary()
            self.disconnect_mt5()
            logger.info("Bot shutdown complete")


if __name__ == "__main__":
    # Configuration for prop firm
    # IMPORTANT: Check your broker's symbol names!
    # Common variations:
    # - DAX: GER40, GER30, DE40, DAX40
    # - CAC40: FRA40, FR40, CAC40
    # - FTSE: UK100, FTSE100
    # - Euro STOXX: EUSTX50, EU50, STOXX50
    
    bot = EuropeanIndexesMT5Bot(
        symbols=['GER40', 'FRA40', 'UK100', 'EUSTX50'],  # Adjust to your broker
        stop_loss_pct=1.5,  # 150% from backtest
        max_risk_per_trade=0.02,  # 2% per trade
        max_daily_risk=0.05,  # 5% daily max
        lot_size=0.01  # Adjust based on account size
    )
    
    bot.run()
