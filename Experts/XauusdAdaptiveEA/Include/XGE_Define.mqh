//+------------------------------------------------------------------+
//|                                                  XGE_Define.mqh |
//|                XAUUSD Adaptive Pro EA - common definitions      |
//|                                                                  |
//| Shared enums, structures and helper text functions.              |
//+------------------------------------------------------------------+
#ifndef XGE_DEFINE_MQH
#define XGE_DEFINE_MQH

#define XGE_PREFIX  "XGE_"
#define XGE_NAME    "XAUUSD Adaptive Pro EA"
#define XGE_VERSION "1.00"

//--- market condition classification
enum ENUM_MARKET_CONDITION
  {
   COND_STRONG_UPTREND = 0,   // Strong Uptrend
   COND_WEAK_UPTREND,         // Weak Uptrend
   COND_STRONG_DOWNTREND,     // Strong Downtrend
   COND_WEAK_DOWNTREND,       // Weak Downtrend
   COND_PULLBACK_BULL,        // Bullish Pullback
   COND_PULLBACK_BEAR,        // Bearish Pullback
   COND_BREAKOUT_BULL,        // Bullish Breakout
   COND_BREAKOUT_BEAR,        // Bearish Breakout
   COND_RANGE,                // Range Market
   COND_REVERSAL_BULL,        // Potential Bullish Reversal
   COND_REVERSAL_BEAR,        // Potential Bearish Reversal
   COND_LOW_VOL,              // Low Volatility
   COND_EXTREME_VOL,          // Extreme Volatility
   COND_ABNORMAL,             // Abnormal Market
   COND_UNCERTAIN             // Uncertain Market
  };

//--- volatility regime (independent axis)
enum ENUM_VOL_STATE
  {
   VOL_ABNORMAL = 0,
   VOL_LOW,
   VOL_NORMAL,
   VOL_HIGH,
   VOL_EXTREME
  };

enum ENUM_TREND_DIR
  {
   TREND_NONE = 0,
   TREND_UP,
   TREND_DOWN
  };

enum ENUM_STRUCTURE
  {
   STRUCT_UNDEF = 0,
   STRUCT_BULL,      // HH + HL
   STRUCT_BEAR,      // LH + LL
   STRUCT_MIXED
  };

enum ENUM_STRATEGY
  {
   STRAT_NONE = 0,
   STRAT_TREND,      // Trend following / continuation
   STRAT_PULLBACK,   // Pullback continuation
   STRAT_BREAKOUT,   // Breakout
   STRAT_RETEST,     // Breakout retest
   STRAT_RANGE,      // Range trading
   STRAT_REVERSAL,   // Reversal
   STRAT_SWEEP       // Liquidity sweep
  };

enum ENUM_SIGNAL_DIR
  {
   SIG_NONE = 0,
   SIG_BUY,
   SIG_SELL
  };

//--- v2 operating modes: only LOW_VOL stays out of the market
enum ENUM_MODE
  {
   MODE_NOVOL = 0,   // low volatility -> the only NO-TRADE state
   MODE_NEWS,        // news time: momentum + trailing + stop-and-reverse
   MODE_UP,          // uptrend: buy higher-low, close at higher-high
   MODE_DOWN,        // downtrend: sell lower-high, close at lower-low
   MODE_SIDE         // sideways: buy support / sell resistance
  };

string ModeText(const ENUM_MODE m)
  {
   switch(m)
     {
      case MODE_NOVOL: return "LOW VOL - NO TRADE";
      case MODE_NEWS:  return "NEWS - momentum+trailing";
      case MODE_UP:    return "UPTREND - buy HL / exit HH";
      case MODE_DOWN:  return "DOWNTREND - sell LH / exit LL";
      case MODE_SIDE:  return "SIDE - S/R trading";
     }
   return "?";
  }

struct SSwing
  {
   int      bar;      // bar index in series (0 = current)
   datetime time;
   double   price;
  };

//--- a candidate trade idea produced by a strategy
struct SSignal
  {
   ENUM_SIGNAL_DIR dir;
   ENUM_STRATEGY   strat;
   double          conf;      // 0..100 confidence
   double          sl;
   double          tp;
   string          reason;    // why this signal exists
   string          key;       // setup identifier (anti overtrading)
  };

//--- full snapshot of the market (POD only, no strings)
struct SMarketState
  {
   datetime barTime;                 // time of the last closed entry-TF bar
   // last closed candle
   double   o1, h1, l1, c1;
   // volatility
   double   atrL, atrLavg, volRatio;
   ENUM_VOL_STATE vol;
   // trend indicators (entry TF)
   double   adxL, adxL3, diPlusL, diMinusL;
   double   ema20L, ema50L, ema200L, ema50L_3;
   double   rsi1;
   // higher TF
   double   adxH, emaF_H, emaS_H, atrH, closeH;
   ENUM_TREND_DIR htfTrend;
   ENUM_TREND_DIR ltfTrend;
   double   trendStrength;           // 0..100
   // market structure
   ENUM_STRUCTURE structure;
   bool     flagHH, flagHL, flagLH, flagLL;
   int      shCount, slCount;
   SSwing   sh[4];                   // swing highs, [0] = most recent
   SSwing   sl[4];                   // swing lows
   int      sh0Age, sl0Age;          // bars since newest swing got confirmed
   bool     bullBOS, bearBOS;        // break of structure events
   int      bullBOSBar, bearBOSBar;  // bars ago
   bool     chochBull, chochBear;    // change of character
   // range model
   bool     rangeValid;
   double   rangeHigh, rangeLow, rangePos;   // pos 0..1 inside range
   // breakout model
   bool     boBull, boBear, boValid, boFail;
   bool     sweepHigh, sweepLow;
   double   boLevel;
   int      boTouches;
   // pullback model
   bool     pbBull, pbBear;
   double   pbZone;
   // reversal model
   double   revBullScore, revBearScore;
   bool     bullDiv, bearDiv;
   // price action
   bool     strongBull, strongBear;
   // final classification
   ENUM_MARKET_CONDITION condition;
   int      condAge;                 // bars spent in current condition
  };

//+------------------------------------------------------------------+
//| Text helpers                                                     |
//+------------------------------------------------------------------+
string ConditionText(const ENUM_MARKET_CONDITION c)
  {
   switch(c)
     {
      case COND_STRONG_UPTREND:  return "STRONG UPTREND";
      case COND_WEAK_UPTREND:    return "WEAK UPTREND";
      case COND_STRONG_DOWNTREND:return "STRONG DOWNTREND";
      case COND_WEAK_DOWNTREND:  return "WEAK DOWNTREND";
      case COND_PULLBACK_BULL:   return "PULLBACK (BULL)";
      case COND_PULLBACK_BEAR:   return "PULLBACK (BEAR)";
      case COND_BREAKOUT_BULL:   return "BREAKOUT (BULL)";
      case COND_BREAKOUT_BEAR:   return "BREAKOUT (BEAR)";
      case COND_RANGE:           return "RANGE";
      case COND_REVERSAL_BULL:   return "REVERSAL (BULL?)";
      case COND_REVERSAL_BEAR:   return "REVERSAL (BEAR?)";
      case COND_LOW_VOL:         return "LOW VOLATILITY";
      case COND_EXTREME_VOL:     return "EXTREME VOLATILITY";
      case COND_ABNORMAL:        return "ABNORMAL";
     }
   return "UNCERTAIN";
  }

string VolText(const ENUM_VOL_STATE v)
  {
   switch(v)
     {
      case VOL_ABNORMAL: return "ABNORMAL";
      case VOL_LOW:      return "LOW";
      case VOL_NORMAL:   return "NORMAL";
      case VOL_HIGH:     return "HIGH";
      case VOL_EXTREME:  return "EXTREME";
     }
   return "?";
  }

string TrendText(const ENUM_TREND_DIR t)
  {
   if(t == TREND_UP)   return "UP";
   if(t == TREND_DOWN) return "DOWN";
   return "FLAT";
  }

string StructureText(const ENUM_STRUCTURE s)
  {
   switch(s)
     {
      case STRUCT_BULL:  return "BULLISH";
      case STRUCT_BEAR:  return "BEARISH";
      case STRUCT_MIXED: return "MIXED";
     }
   return "UNDEFINED";
  }

string StrategyText(const ENUM_STRATEGY s)
  {
   switch(s)
     {
      case STRAT_TREND:    return "Trend-Follow";
      case STRAT_PULLBACK: return "Pullback";
      case STRAT_BREAKOUT: return "Breakout";
      case STRAT_RETEST:   return "Breakout-Retest";
      case STRAT_RANGE:    return "Range";
      case STRAT_REVERSAL: return "Reversal";
      case STRAT_SWEEP:    return "Liquidity-Sweep";
     }
   return "None";
  }

string StrategyCode(const ENUM_STRATEGY s)
  {
   switch(s)
     {
      case STRAT_TREND:    return "TR";
      case STRAT_PULLBACK: return "PB";
      case STRAT_BREAKOUT: return "BO";
      case STRAT_RETEST:   return "RT";
      case STRAT_RANGE:    return "RG";
      case STRAT_REVERSAL: return "RV";
      case STRAT_SWEEP:    return "SW";
     }
   return "--";
  }

string DirText(const ENUM_SIGNAL_DIR d)
  {
   if(d == SIG_BUY)  return "BUY";
   if(d == SIG_SELL) return "SELL";
   return "NONE";
  }

//--- remove characters that would break CSV logging
string Sanitize(const string s)
  {
   string r = s;
   StringReplace(r, ",", ";");
   StringReplace(r, "\"", "'");
   StringReplace(r, "\n", " ");
   return r;
  }

#endif // XGE_DEFINE_MQH
