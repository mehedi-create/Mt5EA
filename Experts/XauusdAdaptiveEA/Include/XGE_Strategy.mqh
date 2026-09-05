//+------------------------------------------------------------------+
//|                                                 XGE_Strategy.mqh |
//|        XAUUSD Adaptive Pro EA - multi strategy signal engine     |
//|                                                                  |
//| Each strategy evaluates the shared SMarketState and may emit a   |
//| candidate signal. The main EA resolves conflicts and applies     |
//| protective gates before any order is sent.                       |
//+------------------------------------------------------------------+
#ifndef XGE_STRATEGY_MQH
#define XGE_STRATEGY_MQH

#include "XGE_Define.mqh"

#define XGE_MAX_SIGNALS 10

class CStrategyEngine
  {
public:
   // strategy switches
   bool   m_useTrend, m_usePullback, m_useBreakout, m_useRetest;
   bool   m_useRange, m_useReversal, m_useSweep;
   // sizing / quality parameters
   double m_minRR, m_rrTP;
   double m_slATRmin, m_slATRmax;
   double m_extMaxATR;        // max allowed chase distance from EMA fast
   double m_revMinConf;       // reversal score threshold to trade
   double m_rangeEdgePct;     // range zone depth (0.25 = outer 25%)
   int    m_retestMaxBars;    // max age of breakout for retest entries
   double m_retestZoneATR;    // how close to broken level counts as retest
   int    m_boMinTouches;     // min boundary touches for a valid breakout
   ENUM_TIMEFRAMES m_ltf;     // entry timeframe (set by main EA)
   // memory: last valid breakout (for retest strategy)
   datetime m_boTime;
   int      m_boDir;          // +1 bull / -1 bear / 0 none
   double   m_boLevel;

   CStrategyEngine(void)
     {
      m_useTrend = true; m_usePullback = true; m_useBreakout = true;
      m_useRetest = true; m_useRange = true; m_useReversal = false;
      m_useSweep = true;
      m_minRR = 1.2; m_rrTP = 1.8;
      m_slATRmin = 0.8; m_slATRmax = 4.0;
      m_extMaxATR = 2.0;
      m_revMinConf = 70.0;
      m_rangeEdgePct = 0.25;
      m_retestMaxBars = 16; m_retestZoneATR = 0.4;
      m_boMinTouches = 2;
      m_ltf = PERIOD_M15;
      m_boTime = 0; m_boDir = 0; m_boLevel = 0.0;
     }

   //--- build all candidate signals for the current bar
   int BuildSignals(const SMarketState &st, SSignal &sigs[])
     {
      int n = 0;
      if(m_useTrend)
         n += SigTrend(st, sigs, n);
      if(m_usePullback)
         n += SigPullback(st, sigs, n);
      if(m_useBreakout)
         n += SigBreakout(st, sigs, n);
      if(m_useRetest)
         n += SigRetest(st, sigs, n);
      if(m_useRange)
         n += SigRange(st, sigs, n);
      if(m_useReversal)
         n += SigReversal(st, sigs, n);
      if(m_useSweep)
         n += SigSweep(st, sigs, n);
      // remember fresh valid breakout for future retest entries
      if(st.boBull && st.boValid)
        {
         m_boTime = st.barTime; m_boDir = +1; m_boLevel = st.boLevel;
        }
      else if(st.boBear && st.boValid)
        {
         m_boTime = st.barTime; m_boDir = -1; m_boLevel = st.boLevel;
        }
      // breakout failure invalidates pending retest
      if(st.boFail)
         m_boDir = 0;
      return(n);
     }

private:
   //--- common confidence scoring against HTF / structure / volatility
   double Score(const SMarketState &st, const ENUM_SIGNAL_DIR dir, double conf)
     {
      if(st.htfTrend == TREND_UP)
         conf += (dir == SIG_BUY) ? 15.0 : -20.0;
      else if(st.htfTrend == TREND_DOWN)
         conf += (dir == SIG_SELL) ? 15.0 : -20.0;
      if(st.structure == STRUCT_BULL)
         conf += (dir == SIG_BUY) ? 10.0 : -15.0;
      else if(st.structure == STRUCT_BEAR)
         conf += (dir == SIG_SELL) ? 10.0 : -15.0;
      if(st.vol == VOL_NORMAL)
         conf += 5.0;
      else if(st.vol == VOL_HIGH)
         conf -= 5.0;
      if(conf < 0.0)   conf = 0.0;
      if(conf > 100.0) conf = 100.0;
      return(conf);
     }

   //--- clamp structural SL to ATR bounds; false => setup rejected
   bool MakeSLTP(const SMarketState &st, const ENUM_SIGNAL_DIR dir,
                 const double entry, const double rawSL,
                 double &sl, double &tp)
     {
      double d = MathAbs(entry - rawSL);
      if(d <= 0.0)
         return(false);
      if(d < m_slATRmin * st.atrL)
         d = m_slATRmin * st.atrL;
      if(d > m_slATRmax * st.atrL)
         return(false);            // stop too wide -> risk unacceptable
      if(dir == SIG_BUY)
        {
         sl = entry - d;
         tp = entry + m_rrTP * d;
        }
      else
        {
         sl = entry + d;
         tp = entry - m_rrTP * d;
        }
      return(true);
     }

   void Emit(const ENUM_SIGNAL_DIR dir, const ENUM_STRATEGY strat,
             const double conf, const double sl, const double tp,
             const string reason, SSignal &sigs[], int &n)
     {
      if(n >= XGE_MAX_SIGNALS)
         return;
      sigs[n].dir = dir;
      sigs[n].strat = strat;
      sigs[n].conf = conf;
      sigs[n].sl = sl;
      sigs[n].tp = tp;
      sigs[n].reason = reason;
      sigs[n].key = StrategyCode(strat) + DirText(dir);
      n++;
     }

   //--- 1) trend following / continuation
   int SigTrend(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      bool up = (st.condition == COND_STRONG_UPTREND || st.condition == COND_WEAK_UPTREND);
      bool dn = (st.condition == COND_STRONG_DOWNTREND || st.condition == COND_WEAK_DOWNTREND);
      if(!up && !dn)
         return(0);
      if(st.atrL <= 0.0)
         return(0);
      ENUM_SIGNAL_DIR dir = up ? SIG_BUY : SIG_SELL;
      // do not chase extended price
      double ext = up ? (st.c1 - st.ema20L) : (st.ema20L - st.c1);
      if(ext > m_extMaxATR * st.atrL)
         return(0);
      // momentum candle in trade direction required
      if(up && st.c1 <= st.o1) return(0);
      if(!up && st.c1 >= st.o1) return(0);
      // fresh opposite BOS invalidates
      if(up && st.bearBOS && st.bearBOSBar <= 2) return(0);
      if(!up && st.bullBOS && st.bullBOSBar <= 2) return(0);

      double entry = st.c1;
      double rawSL;
      if(up)
         rawSL = (st.slCount > 0) ? MathMin(entry - 0.3 * st.atrL, st.sl[0].price - 0.15 * st.atrL)
                                  : entry - 1.5 * st.atrL;
      else
         rawSL = (st.shCount > 0) ? MathMax(entry + 0.3 * st.atrL, st.sh[0].price + 0.15 * st.atrL)
                                  : entry + 1.5 * st.atrL;
      double sl, tp;
      if(!MakeSLTP(st, dir, entry, rawSL, sl, tp))
         return(0);
      double base = (st.trendStrength >= 60.0) ? 58.0 : 50.0;
      if(st.strongBull && up) base += 7.0;
      if(st.strongBear && !up) base += 7.0;
      double conf = Score(st, dir, base);
      Emit(dir, STRAT_TREND, conf, sl, tp,
           StringFormat("Trend continuation; strength=%.0f; ADX=%.1f", st.trendStrength, st.adxL),
           sigs, n);
      return(n - n0);
     }

   //--- 2) pullback continuation
   int SigPullback(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      if(st.atrL <= 0.0)
         return(0);
      if(st.pbBull)
        {
         double entry = st.c1;
         double lowRef = MathMin(st.l1, MathMin(st.sl[0].price, st.pbZone));
         if(st.slCount == 0)
            lowRef = MathMin(st.l1, st.pbZone);
         double rawSL = lowRef - 0.2 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_BUY, entry, rawSL, sl, tp))
           {
            double conf = Score(st, SIG_BUY, 60.0);
            Emit(SIG_BUY, STRAT_PULLBACK, conf, sl, tp,
                 StringFormat("Bullish pullback to EMA zone; rejection candle; retrace ok"),
                 sigs, n);
           }
        }
      else if(st.pbBear)
        {
         double entry = st.c1;
         double highRef = MathMax(st.h1, MathMax(st.sh[0].price, st.pbZone));
         if(st.shCount == 0)
            highRef = MathMax(st.h1, st.pbZone);
         double rawSL = highRef + 0.2 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_SELL, entry, rawSL, sl, tp))
           {
            double conf = Score(st, SIG_SELL, 60.0);
            Emit(SIG_SELL, STRAT_PULLBACK, conf, sl, tp,
                 StringFormat("Bearish pullback to EMA zone; rejection candle; retrace ok"),
                 sigs, n);
           }
        }
      return(n - n0);
     }

   //--- 3) fresh valid breakout
   int SigBreakout(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      if(st.atrL <= 0.0)
         return(0);
      if(st.boBull && st.boValid)
        {
         double entry = st.c1;
         double rawSL = MathMin(st.boLevel, st.l1) - 0.15 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_BUY, entry, rawSL, sl, tp))
           {
            double base = 53.0 + MathMin((double)(st.boTouches - m_boMinTouches) * 3.0, 9.0);
            double conf = Score(st, SIG_BUY, base);
            Emit(SIG_BUY, STRAT_BREAKOUT, conf, sl, tp,
                 StringFormat("Bullish breakout of range %.2f with %d touches", st.boLevel, st.boTouches),
                 sigs, n);
           }
        }
      else if(st.boBear && st.boValid)
        {
         double entry = st.c1;
         double rawSL = MathMax(st.boLevel, st.h1) + 0.15 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_SELL, entry, rawSL, sl, tp))
           {
            double base = 53.0 + MathMin((double)(st.boTouches - m_boMinTouches) * 3.0, 9.0);
            double conf = Score(st, SIG_SELL, base);
            Emit(SIG_SELL, STRAT_BREAKOUT, conf, sl, tp,
                 StringFormat("Bearish breakout of range %.2f with %d touches", st.boLevel, st.boTouches),
                 sigs, n);
           }
        }
      return(n - n0);
     }

   //--- 4) breakout retest (delayed entry after breakout)
   int SigRetest(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      if(m_boDir == 0 || st.atrL <= 0.0 || m_boTime == 0)
         return(0);
      int barsSince = BarsBetween(m_boTime, st.barTime);
      if(barsSince < 2 || barsSince > m_retestMaxBars)
         return(0);
      if(m_boDir > 0)
        {
         // level retested from above and price holds
         if(st.l1 <= m_boLevel + m_retestZoneATR * st.atrL &&
            st.l1 >= m_boLevel - 0.6 * st.atrL &&
            st.c1 > m_boLevel && st.c1 > st.o1)
           {
            double entry = st.c1;
            double rawSL = m_boLevel - 0.35 * st.atrL;
            double sl, tp;
            if(MakeSLTP(st, SIG_BUY, entry, rawSL, sl, tp))
              {
               double conf = Score(st, SIG_BUY, 61.0);
               Emit(SIG_BUY, STRAT_RETEST, conf, sl, tp,
                    StringFormat("Bullish breakout retest of %.2f held", m_boLevel),
                    sigs, n);
              }
           }
        }
      else
        {
         if(st.h1 >= m_boLevel - m_retestZoneATR * st.atrL &&
            st.h1 <= m_boLevel + 0.6 * st.atrL &&
            st.c1 < m_boLevel && st.c1 < st.o1)
           {
            double entry = st.c1;
            double rawSL = m_boLevel + 0.35 * st.atrL;
            double sl, tp;
            if(MakeSLTP(st, SIG_SELL, entry, rawSL, sl, tp))
              {
               double conf = Score(st, SIG_SELL, 61.0);
               Emit(SIG_SELL, STRAT_RETEST, conf, sl, tp,
                    StringFormat("Bearish breakout retest of %.2f held", m_boLevel),
                    sigs, n);
              }
           }
        }
      return(n - n0);
     }

   //--- bars between two datetimes on the entry timeframe
   int BarsBetween(const datetime t1, const datetime t2)
     {
      if(t1 <= 0 || t2 <= 0 || t2 <= t1)
         return(9999);
      int b = iBarShift(_Symbol, m_ltf, t1, false);
      int c = iBarShift(_Symbol, m_ltf, t2, false);
      if(b < 0 || c < 0)
         return(9999);
      return(b - c);
     }

   //--- 5) range trading at zone edges
   int SigRange(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      if(!st.rangeValid || st.atrL <= 0.0)
         return(0);
      double width = st.rangeHigh - st.rangeLow;
      if(width <= 0.0)
         return(0);
      // lower zone: buy
      if(st.rangePos <= m_rangeEdgePct && st.c1 > st.o1)
        {
         double entry = st.c1;
         double rawSL = st.rangeLow - 0.3 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_BUY, entry, rawSL, sl, tp))
           {
            tp = st.rangeLow + 0.85 * width;              // aim opposite side
            double rr = (entry > sl) ? (tp - entry) / (entry - sl) : 0.0;
            if(rr >= m_minRR && tp > entry)
              {
               double conf = Score(st, SIG_BUY, 52.0);
               Emit(SIG_BUY, STRAT_RANGE, conf, sl, tp,
                    StringFormat("Range lower zone buy; range %.2f-%.2f pos=%.2f",
                                 st.rangeLow, st.rangeHigh, st.rangePos),
                    sigs, n);
              }
           }
        }
      // upper zone: sell
      if(st.rangePos >= 1.0 - m_rangeEdgePct && st.c1 < st.o1)
        {
         double entry = st.c1;
         double rawSL = st.rangeHigh + 0.3 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_SELL, entry, rawSL, sl, tp))
           {
            tp = st.rangeHigh - 0.85 * width;
            double rr = (sl > entry) ? (entry - tp) / (sl - entry) : 0.0;
            if(rr >= m_minRR && tp < entry)
              {
               double conf = Score(st, SIG_SELL, 52.0);
               Emit(SIG_SELL, STRAT_RANGE, conf, sl, tp,
                    StringFormat("Range upper zone sell; range %.2f-%.2f pos=%.2f",
                                 st.rangeLow, st.rangeHigh, st.rangePos),
                    sigs, n);
              }
           }
        }
      return(n - n0);
     }

   //--- 6) reversal (conservative, confirmation required)
   int SigReversal(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      if(st.atrL <= 0.0)
         return(0);
      if(st.revBullScore >= m_revMinConf && st.c1 > st.o1 &&
         MathAbs(st.c1 - st.o1) >= 0.6 * st.atrL)
        {
         double entry = st.c1;
         double lowRef = st.l1;
         if(st.slCount > 0)
            lowRef = MathMin(lowRef, st.sl[0].price);
         double rawSL = lowRef - 0.25 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_BUY, entry, rawSL, sl, tp))
           {
            double conf = Score(st, SIG_BUY, 40.0 + 0.35 * st.revBullScore);
            Emit(SIG_BUY, STRAT_REVERSAL, conf, sl, tp,
                 StringFormat("Bullish reversal score=%.0f choch=%s div=%s",
                              st.revBullScore, st.chochBull ? "Y" : "N", st.bullDiv ? "Y" : "N"),
                 sigs, n);
           }
        }
      else if(st.revBearScore >= m_revMinConf && st.c1 < st.o1 &&
              MathAbs(st.c1 - st.o1) >= 0.6 * st.atrL)
        {
         double entry = st.c1;
         double highRef = st.h1;
         if(st.shCount > 0)
            highRef = MathMax(highRef, st.sh[0].price);
         double rawSL = highRef + 0.25 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_SELL, entry, rawSL, sl, tp))
           {
            double conf = Score(st, SIG_SELL, 40.0 + 0.35 * st.revBearScore);
            Emit(SIG_SELL, STRAT_REVERSAL, conf, sl, tp,
                 StringFormat("Bearish reversal score=%.0f choch=%s div=%s",
                              st.revBearScore, st.chochBear ? "Y" : "N", st.bearDiv ? "Y" : "N"),
                 sigs, n);
           }
        }
      return(n - n0);
     }

   //--- 7) liquidity sweep fade in trend direction
   int SigSweep(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      if(st.atrL <= 0.0)
         return(0);
      if(st.sweepLow && st.ltfTrend == TREND_UP && st.structure != STRUCT_BEAR && st.c1 > st.o1)
        {
         double entry = st.c1;
         double rawSL = st.l1 - 0.15 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_BUY, entry, rawSL, sl, tp))
           {
            double conf = Score(st, SIG_BUY, 57.0);
            Emit(SIG_BUY, STRAT_SWEEP, conf, sl, tp,
                 "Liquidity sweep of recent low; close back above",
                 sigs, n);
           }
        }
      else if(st.sweepHigh && st.ltfTrend == TREND_DOWN && st.structure != STRUCT_BULL && st.c1 < st.o1)
        {
         double entry = st.c1;
         double rawSL = st.h1 + 0.15 * st.atrL;
         double sl, tp;
         if(MakeSLTP(st, SIG_SELL, entry, rawSL, sl, tp))
           {
            double conf = Score(st, SIG_SELL, 57.0);
            Emit(SIG_SELL, STRAT_SWEEP, conf, sl, tp,
                 "Liquidity sweep of recent high; close back below",
                 sigs, n);
           }
        }
      return(n - n0);
     }
  };

#endif // XGE_STRATEGY_MQH
