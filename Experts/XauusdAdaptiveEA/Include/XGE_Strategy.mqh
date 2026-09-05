//+------------------------------------------------------------------+
//|                                                 XGE_Strategy.mqh |
//|          XAUUSD Adaptive Pro EA - v2 structure strategy engine   |
//|                                                                  |
//| v2 philosophy (user direction):                                  |
//|  - trade in EVERY market state except low volatility             |
//|  - UPTREND  : enter BUY at a fresh Higher-Low, exit at Higher-High|
//|  - DOWNTREND: enter SELL at a fresh Lower-High, exit at Lower-Low |
//|  - SIDE     : buy at support, sell at resistance                  |
//|  - NEWS     : handled by the main module (momentum + trailing     |
//|               stop-and-reverse)                                   |
//+------------------------------------------------------------------+
#ifndef XGE_STRATEGY_MQH
#define XGE_STRATEGY_MQH

#include "XGE_Define.mqh"

#define XGE_MAX_SIGNALS 10

class CStrategyEngine
  {
public:
   double m_slATRmin, m_slATRmax;   // structural stop sanity clamps
   double m_srZoneATR;              // distance to S/R that counts as "at level"
   double m_srMinRR;                // min reward/risk for side trades
   double m_swingFresh;             // max confirmation age (bars) of a fresh swing

   CStrategyEngine(void)
     {
      m_slATRmin = 0.8;
      m_slATRmax = 4.0;
      m_srZoneATR = 0.35;
      m_srMinRR = 1.0;
      m_swingFresh = 3.0;
     }

   //--- build candidate signals for the current operating mode
   int BuildSignals(const SMarketState &st, const ENUM_MODE mode, SSignal &sigs[])
     {
      int n = 0;
      if(st.atrL <= 0.0)
         return(0);
      if(mode == MODE_UP)
         n += SigTrendUp(st, sigs, n);
      else if(mode == MODE_DOWN)
         n += SigTrendDown(st, sigs, n);
      else if(mode == MODE_SIDE)
         n += SigSide(st, sigs, n);
      // MODE_NEWS and MODE_NOVOL are handled by the main module
      return(n);
     }

private:
   //--- structural stop clamp; false => stop unacceptable
   bool MakeSL(const SMarketState &st, const ENUM_SIGNAL_DIR dir,
               const double entry, const double rawSL, double &sl)
     {
      double d = MathAbs(entry - rawSL);
      if(d <= 0.0)
         return(false);
      if(d < m_slATRmin * st.atrL)
         d = m_slATRmin * st.atrL;
      if(d > m_slATRmax * st.atrL)
         return(false);
      sl = (dir == SIG_BUY) ? entry - d : entry + d;
      return(true);
     }

   void Emit(const ENUM_SIGNAL_DIR dir, const ENUM_STRATEGY strat,
             const double sl, const double tp, const string reason,
             SSignal &sigs[], int &n)
     {
      if(n >= XGE_MAX_SIGNALS)
         return;
      sigs[n].dir = dir;
      sigs[n].strat = strat;
      sigs[n].conf = 100.0;          // v2: rule-based, no confidence gate
      sigs[n].sl = sl;
      sigs[n].tp = tp;
      sigs[n].reason = reason;
      sigs[n].key = StrategyCode(strat) + DirText(dir);
      n++;
     }

   //--- UPTREND: buy when a fresh Higher-Low is confirmed and price holds above it
   int SigTrendUp(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      if(st.slCount < 2)
         return(0);
      bool freshHL = (st.sl0Age <= (int)m_swingFresh) &&
                     (st.sl[0].price > st.sl[1].price);
      if(!freshHL)
         return(0);
      // price must respect the higher low
      if(st.c1 < st.sl[0].price)
         return(0);
      // no fresh bearish break of structure against us
      if(st.bearBOS && st.bearBOSBar <= 2)
         return(0);
      double sl;
      if(!MakeSL(st, SIG_BUY, st.c1, st.sl[0].price - 0.2 * st.atrL, sl))
         return(0);
      Emit(SIG_BUY, STRAT_PULLBACK, sl, 0.0,
           StringFormat("Uptrend: fresh Higher-Low %.2f (> prev %.2f); exit at Higher-High",
                        st.sl[0].price, st.sl[1].price),
           sigs, n);
      return(n - n0);
     }

   //--- DOWNTREND: sell when a fresh Lower-High is confirmed and price holds below it
   int SigTrendDown(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      if(st.shCount < 2)
         return(0);
      bool freshLH = (st.sh0Age <= (int)m_swingFresh) &&
                     (st.sh[0].price < st.sh[1].price);
      if(!freshLH)
         return(0);
      if(st.c1 > st.sh[0].price)
         return(0);
      if(st.bullBOS && st.bullBOSBar <= 2)
         return(0);
      double sl;
      if(!MakeSL(st, SIG_SELL, st.c1, st.sh[0].price + 0.2 * st.atrL, sl))
         return(0);
      Emit(SIG_SELL, STRAT_PULLBACK, sl, 0.0,
           StringFormat("Downtrend: fresh Lower-High %.2f (< prev %.2f); exit at Lower-Low",
                        st.sh[0].price, st.sh[1].price),
           sigs, n);
      return(n - n0);
     }

   //--- SIDE: buy at support (last swing low), sell at resistance (last swing high)
   int SigSide(const SMarketState &st, SSignal &sigs[], int n)
     {
      int n0 = n;
      if(st.slCount < 1 || st.shCount < 1)
         return(0);
      double support = st.sl[0].price;
      double resist = st.sh[0].price;
      if(resist <= support)
         return(0);
      // buy near support with a bullish reaction candle
      if(st.l1 <= support + m_srZoneATR * st.atrL && st.c1 > st.o1)
        {
         double sl, tp = resist;
         if(MakeSL(st, SIG_BUY, st.c1, support - 0.3 * st.atrL, sl))
           {
            double rr = (st.c1 > sl) ? (tp - st.c1) / (st.c1 - sl) : 0.0;
            if(rr >= m_srMinRR)
               Emit(SIG_BUY, STRAT_RANGE, sl, tp,
                    StringFormat("Side: buy at support %.2f; target resistance %.2f", support, resist),
                    sigs, n);
           }
        }
      // sell near resistance with a bearish reaction candle
      if(st.h1 >= resist - m_srZoneATR * st.atrL && st.c1 < st.o1)
        {
         double sl, tp = support;
         if(MakeSL(st, SIG_SELL, st.c1, resist + 0.3 * st.atrL, sl))
           {
            double rr = (sl > st.c1) ? (st.c1 - tp) / (sl - st.c1) : 0.0;
            if(rr >= m_srMinRR)
               Emit(SIG_SELL, STRAT_RANGE, sl, tp,
                    StringFormat("Side: sell at resistance %.2f; target support %.2f", resist, support),
                    sigs, n);
           }
        }
      return(n - n0);
     }
  };

#endif // XGE_STRATEGY_MQH
