//+------------------------------------------------------------------+
//|                                                   XGE_Market.mqh |
//|         XAUUSD Adaptive Pro EA - market condition engine        |
//|                                                                  |
//| Responsibilities:                                                |
//|  - volatility regime (ATR ratio vs long baseline)                |
//|  - trend detection on higher and entry timeframe                 |
//|  - market structure (HH/HL/LH/LL) via swing points               |
//|  - break of structure / change of character                      |
//|  - range model, breakout model, pullback model                   |
//|  - reversal scoring incl. RSI divergence                         |
//|  - final condition classification + transition tracking          |
//+------------------------------------------------------------------+
#ifndef XGE_MARKET_MQH
#define XGE_MARKET_MQH

#include "XGE_Define.mqh"

class CMarketAnalyzer
  {
public:
   // timeframes
   ENUM_TIMEFRAMES  m_htf, m_ltf;
   // indicator handles
   int      m_hEmaF, m_hEmaS, m_hATR, m_hADX;
   int      m_lEmaF, m_lEmaM, m_lEmaS, m_lATR, m_lADX, m_lRSI;
   // parameters
   int      m_atrPeriod, m_adxPeriod, m_rsiPeriod;
   int      m_emaFastH, m_emaSlowH;            // HTF trend EMAs
   int      m_emaZoneF, m_emaZoneM, m_emaZoneS;// entry TF EMAs
   int      m_swingStrength, m_swingLookback;
   int      m_atrAvgBars;
   double   m_volLowRatio, m_volHighRatio, m_volExtremeRatio, m_abnormalBarATR;
   double   m_adxStrong, m_adxWeak, m_adxRangeMax;
   double   m_strengthStrong, m_strengthWeak;
   int      m_rangeLookback;
   double   m_rangeMinATR, m_rangeMaxATR;
   double   m_boMinATR;
   int      m_boMinTouches;
   double   m_pbMinATR, m_pbMaxATR, m_pbZoneATR;
   int      m_pbLook;
   double   m_revThreshold;
   // state
   SMarketState st;
   string   m_transition;
   // raw data buffers (series order, [1] = last closed bar)
   double   m_high[], m_low[], m_open[], m_close[];
   datetime m_time[];
   double   m_ema20Buf[], m_ema50Buf[], m_ema200Buf[];
   double   m_atrBuf[], m_adxBuf[], m_diPlusBuf[], m_diMinusBuf[], m_rsiBuf[];
   int      m_nBars;

   CMarketAnalyzer(void)
     {
      m_htf = PERIOD_H1;  m_ltf = PERIOD_M15;
      m_hEmaF = INVALID_HANDLE; m_hEmaS = INVALID_HANDLE;
      m_hATR  = INVALID_HANDLE; m_hADX  = INVALID_HANDLE;
      m_lEmaF = INVALID_HANDLE; m_lEmaM = INVALID_HANDLE;
      m_lEmaS = INVALID_HANDLE; m_lATR  = INVALID_HANDLE;
      m_lADX  = INVALID_HANDLE; m_lRSI  = INVALID_HANDLE;
      m_atrPeriod = 14; m_adxPeriod = 14; m_rsiPeriod = 14;
      m_emaFastH = 50; m_emaSlowH = 200;
      m_emaZoneF = 20; m_emaZoneM = 50; m_emaZoneS = 200;
      m_swingStrength = 3; m_swingLookback = 120;
      m_atrAvgBars = 200;
      m_volLowRatio = 0.55; m_volHighRatio = 1.60;
      m_volExtremeRatio = 2.50; m_abnormalBarATR = 6.0;
      m_adxStrong = 25.0; m_adxWeak = 18.0; m_adxRangeMax = 20.0;
      m_strengthStrong = 60.0; m_strengthWeak = 35.0;
      m_rangeLookback = 90; m_rangeMinATR = 2.5; m_rangeMaxATR = 12.0;
      m_boMinATR = 0.15; m_boMinTouches = 2;
      m_pbMinATR = 0.8; m_pbMaxATR = 4.0; m_pbZoneATR = 1.5; m_pbLook = 24;
      m_revThreshold = 50.0;
      m_transition = "";
      m_nBars = 0;
      ZeroMemory(st);
      st.condition = COND_UNCERTAIN;
     }

   //--- create all indicator handles
   bool Init(ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES ltf)
     {
      m_htf = htf; m_ltf = ltf;
      m_hEmaF = iMA(_Symbol, m_htf, m_emaFastH, 0, MODE_EMA, PRICE_CLOSE);
      m_hEmaS = iMA(_Symbol, m_htf, m_emaSlowH, 0, MODE_EMA, PRICE_CLOSE);
      m_hATR  = iATR(_Symbol, m_htf, m_atrPeriod);
      m_hADX  = iADX(_Symbol, m_htf, m_adxPeriod);
      m_lEmaF = iMA(_Symbol, m_ltf, m_emaZoneF, 0, MODE_EMA, PRICE_CLOSE);
      m_lEmaM = iMA(_Symbol, m_ltf, m_emaZoneM, 0, MODE_EMA, PRICE_CLOSE);
      m_lEmaS = iMA(_Symbol, m_ltf, m_emaZoneS, 0, MODE_EMA, PRICE_CLOSE);
      m_lATR  = iATR(_Symbol, m_ltf, m_atrPeriod);
      m_lADX  = iADX(_Symbol, m_ltf, m_adxPeriod);
      m_lRSI  = iRSI(_Symbol, m_ltf, m_rsiPeriod, PRICE_CLOSE);
      if(m_hEmaF == INVALID_HANDLE || m_hEmaS == INVALID_HANDLE ||
         m_hATR == INVALID_HANDLE  || m_hADX == INVALID_HANDLE  ||
         m_lEmaF == INVALID_HANDLE || m_lEmaM == INVALID_HANDLE ||
         m_lEmaS == INVALID_HANDLE || m_lATR == INVALID_HANDLE  ||
         m_lADX == INVALID_HANDLE  || m_lRSI == INVALID_HANDLE)
        {
         Print("XGE: failed to create indicator handles");
         return(false);
        }
      return(true);
     }

   void Deinit(void)
     {
      if(m_hEmaF != INVALID_HANDLE) IndicatorRelease(m_hEmaF);
      if(m_hEmaS != INVALID_HANDLE) IndicatorRelease(m_hEmaS);
      if(m_hATR  != INVALID_HANDLE) IndicatorRelease(m_hATR);
      if(m_hADX  != INVALID_HANDLE) IndicatorRelease(m_hADX);
      if(m_lEmaF != INVALID_HANDLE) IndicatorRelease(m_lEmaF);
      if(m_lEmaM != INVALID_HANDLE) IndicatorRelease(m_lEmaM);
      if(m_lEmaS != INVALID_HANDLE) IndicatorRelease(m_lEmaS);
      if(m_lATR  != INVALID_HANDLE) IndicatorRelease(m_lATR);
      if(m_lADX  != INVALID_HANDLE) IndicatorRelease(m_lADX);
      if(m_lRSI  != INVALID_HANDLE) IndicatorRelease(m_lRSI);
     }

   //--- required number of entry-TF bars
   int BarsNeeded(void)
     {
      int n = m_swingLookback + m_swingStrength + 10;
      n = MathMax(n, m_atrAvgBars + 5);
      n = MathMax(n, m_rangeLookback + 5);
      n = MathMax(n, m_emaZoneS + 10);
      return(n);
     }

   //--- true when enough history exists on both timeframes
   bool DataReady(void)
     {
      if(Bars(_Symbol, m_ltf) < BarsNeeded() + 5)
         return(false);
      if(Bars(_Symbol, m_htf) < m_emaSlowH + 30)
         return(false);
      return(true);
     }

   //--- full update; call once per new entry-TF bar
   bool Update(void)
     {
      if(!DataReady())
         return(false);
      if(!ReadRawData())
         return(false);

      ENUM_MARKET_CONDITION prev = st.condition;
      int prevAge = st.condAge;

      st.barTime = m_time[1];
      st.o1 = m_open[1];  st.h1 = m_high[1];  st.l1 = m_low[1];  st.c1 = m_close[1];

      ReadEntryIndicators();
      ReadHTFIndicators();
      ClassifyVolatility();
      DetectSwings();
      DetectStructure();
      DetectBOS();
      ClassifyTrends();
      DetectRange();
      DetectBreakout();
      DetectPullback();
      DetectReversal();
      ClassifyCondition();

      // transition tracking
      if(st.condition != prev)
        {
         m_transition = ConditionText(prev) + " -> " + ConditionText(st.condition);
         st.condAge = 1;
         if(prev != COND_UNCERTAIN || st.condition != COND_UNCERTAIN)
            Print("XGE condition change: ", m_transition);
        }
      else
         st.condAge = prevAge + 1;
      return(true);
     }

private:
   //--- copy indicator buffer into series array
   bool CopyInd(const int handle, const int buffer, const int count, double &out[])
     {
      ArraySetAsSeries(out, true);
      if(handle == INVALID_HANDLE)
         return(false);
      if(CopyBuffer(handle, buffer, 0, count, out) < count)
         return(false);
      return(true);
     }

   bool ReadRawData(void)
     {
      int n = BarsNeeded();
      m_nBars = n;
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, m_ltf, 0, n, rates) < n)
         return(false);
      ArrayResize(m_high, n);  ArrayResize(m_low, n);
      ArrayResize(m_open, n);  ArrayResize(m_close, n);
      ArrayResize(m_time, n);
      for(int i = 0; i < n; i++)
        {
         m_high[i]  = rates[i].high;
         m_low[i]   = rates[i].low;
         m_open[i]  = rates[i].open;
         m_close[i] = rates[i].close;
         m_time[i]  = rates[i].time;
        }
      return(true);
     }

   bool ReadEntryIndicators(void)
     {
      int n = m_nBars;
      if(!CopyInd(m_lEmaF, 0, n, m_ema20Buf))  return(false);
      if(!CopyInd(m_lEmaM, 0, n, m_ema50Buf))  return(false);
      if(!CopyInd(m_lEmaS, 0, n, m_ema200Buf)) return(false);
      if(!CopyInd(m_lATR,  0, n, m_atrBuf))    return(false);
      if(!CopyInd(m_lADX,  MAIN_LINE, n, m_adxBuf))     return(false);
      if(!CopyInd(m_lADX,  PLUSDI_LINE, n, m_diPlusBuf))return(false);
      if(!CopyInd(m_lADX,  MINUSDI_LINE, n, m_diMinusBuf)) return(false);
      if(!CopyInd(m_lRSI,  0, n, m_rsiBuf))    return(false);

      st.ema20L  = m_ema20Buf[1];
      st.ema50L  = m_ema50Buf[1];
      st.ema200L = m_ema200Buf[1];
      st.ema50L_3= m_ema50Buf[4];
      st.atrL    = m_atrBuf[1];
      st.adxL    = m_adxBuf[1];
      st.adxL3   = m_adxBuf[3];
      st.diPlusL = m_diPlusBuf[1];
      st.diMinusL= m_diMinusBuf[1];
      st.rsi1    = m_rsiBuf[1];

      // ATR long-run baseline
      double sum = 0.0;
      int cnt = 0;
      for(int i = 1; i <= m_atrAvgBars && i < m_nBars; i++)
        {
         sum += m_atrBuf[i];
         cnt++;
        }
      st.atrLavg = (cnt > 0) ? sum / cnt : st.atrL;
      return(true);
     }

   bool ReadHTFIndicators(void)
     {
      double f[], s[], a[], adx[], cl[];
      if(!CopyInd(m_hEmaF, 0, 8, f))            return(false);
      if(!CopyInd(m_hEmaS, 0, 8, s))            return(false);
      if(!CopyInd(m_hATR,  0, 4, a))            return(false);
      if(!CopyInd(m_hADX,  MAIN_LINE, 4, adx))  return(false);
      ArraySetAsSeries(cl, true);
      if(CopyClose(_Symbol, m_htf, 0, 4, cl) < 4) return(false);
      st.emaF_H = f[1];
      st.emaS_H = s[1];
      st.atrH   = a[1];
      st.adxH   = adx[1];
      st.closeH = cl[1];
      return(true);
     }

   void ClassifyVolatility(void)
     {
      double rng = st.h1 - st.l1;
      st.volRatio = (st.atrLavg > 0.0) ? st.atrL / st.atrLavg : 1.0;
      ENUM_VOL_STATE v = VOL_NORMAL;
      if(st.atrL <= 0.0)
         v = VOL_ABNORMAL;
      else if(rng > m_abnormalBarATR * st.atrL || st.volRatio > m_volExtremeRatio * 1.8)
         v = VOL_ABNORMAL;
      else if(st.volRatio <= m_volLowRatio)
         v = VOL_LOW;
      else if(st.volRatio >= m_volExtremeRatio)
         v = VOL_EXTREME;
      else if(st.volRatio >= m_volHighRatio)
         v = VOL_HIGH;
      st.vol = v;

      // price action flags (single candle)
      double body = MathAbs(st.c1 - st.o1);
      st.strongBull = (st.c1 > st.o1 && st.atrL > 0 && body >= 1.5 * st.atrL);
      st.strongBear = (st.c1 < st.o1 && st.atrL > 0 && body >= 1.5 * st.atrL);
     }

   //--- detect confirmed swing highs/lows (fractal with k bars each side)
   void DetectSwings(void)
     {
      st.shCount = 0;
      st.slCount = 0;
      int k = m_swingStrength;
      int last = MathMin(m_swingLookback, m_nBars - k - 2);
      for(int i = k; i <= last; i++)
        {
         if(st.shCount >= 4 && st.slCount >= 4)
            break;
         bool isH = true, isL = true;
         for(int j = 1; j <= k; j++)
           {
            if(m_high[i] <= m_high[i - j] || m_high[i] <= m_high[i + j])
               isH = false;
            if(m_low[i] >= m_low[i - j] || m_low[i] >= m_low[i + j])
               isL = false;
            if(!isH && !isL)
               break;
           }
         if(isH && st.shCount < 4)
           {
            st.sh[st.shCount].bar = i;
            st.sh[st.shCount].time = m_time[i];
            st.sh[st.shCount].price = m_high[i];
            st.shCount++;
           }
         if(isL && st.slCount < 4)
           {
            st.sl[st.slCount].bar = i;
            st.sl[st.slCount].time = m_time[i];
            st.sl[st.slCount].price = m_low[i];
            st.slCount++;
           }
        }
     }

   void DetectStructure(void)
     {
      st.flagHH = false; st.flagHL = false;
      st.flagLH = false; st.flagLL = false;
      if(st.shCount >= 2 && st.slCount >= 2)
        {
         st.flagHH = (st.sh[0].price > st.sh[1].price);
         st.flagLH = (st.sh[0].price < st.sh[1].price);
         st.flagHL = (st.sl[0].price > st.sl[1].price);
         st.flagLL = (st.sl[0].price < st.sl[1].price);
         if(st.flagHH && st.flagHL)
            st.structure = STRUCT_BULL;
         else if(st.flagLH && st.flagLL)
            st.structure = STRUCT_BEAR;
         else
            st.structure = STRUCT_MIXED;
        }
      else
         st.structure = STRUCT_UNDEF;
     }

   //--- break of structure: close beyond most recent swing high/low
   void DetectBOS(void)
     {
      st.bullBOS = false; st.bearBOS = false;
      st.bullBOSBar = 9999; st.bearBOSBar = 9999;
      if(st.shCount > 0)
        {
         double lvl = st.sh[0].price;
         int sBar = st.sh[0].bar;
         for(int i = 1; i < sBar; i++)
           {
            if(m_close[i] > lvl)
              {
               st.bullBOS = true;
               st.bullBOSBar = i;
               break;
              }
           }
        }
      if(st.slCount > 0)
        {
         double lvl = st.sl[0].price;
         int sBar = st.sl[0].bar;
         for(int i = 1; i < sBar; i++)
           {
            if(m_close[i] < lvl)
              {
               st.bearBOS = true;
               st.bearBOSBar = i;
               break;
              }
           }
        }
      // change of character = BOS against the current structural bias
      st.chochBull = (st.bullBOS && st.structure == STRUCT_BEAR);
      st.chochBear = (st.bearBOS && st.structure == STRUCT_BULL);
     }

   void DetectRange(void)
     {
      st.rangeValid = false;
      st.rangeHigh = 0.0; st.rangeLow = 0.0; st.rangePos = 0.5;
      int L = MathMin(m_rangeLookback, m_nBars - 4);
      if(L < 20 || st.atrL <= 0.0)
         return;
      double rh = -DBL_MAX, rl = DBL_MAX;
      for(int i = 2; i <= L + 1; i++)
        {
         if(m_high[i] > rh) rh = m_high[i];
         if(m_low[i]  < rl) rl = m_low[i];
        }
      double width = rh - rl;
      if(width <= 0.0)
         return;
      double tol = 0.15 * width;
      int rhTouches = 0, rlTouches = 0;
      for(int i = 2; i <= L + 1; i++)
        {
         if(m_high[i] >= rh - tol) rhTouches++;
         if(m_low[i]  <= rl + tol) rlTouches++;
        }
      st.rangeHigh = rh;
      st.rangeLow  = rl;
      st.rangePos  = (st.c1 - rl) / width;
      if(st.adxL < m_adxRangeMax &&
         width >= m_rangeMinATR * st.atrL &&
         width <= m_rangeMaxATR * st.atrL &&
         rhTouches >= 2 && rlTouches >= 2)
         st.rangeValid = true;
     }

   void DetectBreakout(void)
     {
      st.boBull = false; st.boBear = false; st.boValid = false;
      st.boFail = false; st.sweepHigh = false; st.sweepLow = false;
      st.boLevel = 0.0; st.boTouches = 0;
      // structural sweeps (beyond last swing) - independent of range model
      if(st.slCount > 0 && st.l1 < st.sl[0].price && st.c1 > st.sl[0].price)
         st.sweepLow = true;
      if(st.shCount > 0 && st.h1 > st.sh[0].price && st.c1 < st.sh[0].price)
         st.sweepHigh = true;
      if(st.rangeHigh <= st.rangeLow)
         return;
      double frac = m_boMinATR * st.atrL;
      double rh = st.rangeHigh, rl = st.rangeLow;
      // recompute touches quickly (rangeDetect already validated zone)
      int L = MathMin(m_rangeLookback, m_nBars - 4);
      double tol = 0.15 * (rh - rl);
      int rhT = 0, rlT = 0;
      for(int i = 2; i <= L + 1; i++)
        {
         if(m_high[i] >= rh - tol) rhT++;
         if(m_low[i]  <= rl + tol) rlT++;
        }
      if(st.c1 > rh + frac)
        {
         st.boBull = true;
         st.boLevel = rh;
         st.boTouches = rhT;
         st.boValid = (rhT >= m_boMinTouches && (st.h1 - st.l1) >= st.atrL);
        }
      else if(st.c1 < rl - frac)
        {
         st.boBear = true;
         st.boLevel = rl;
         st.boTouches = rlT;
         st.boValid = (rlT >= m_boMinTouches && (st.h1 - st.l1) >= st.atrL);
        }
      else if(st.h1 > rh && st.c1 <= rh)
        {
         st.boFail = true;
         st.sweepHigh = true;   // liquidity sweep above range high
        }
      else if(st.l1 < rl && st.c1 >= rl)
        {
         st.sweepLow = true;    // liquidity sweep below range low
        }
     }

   void DetectPullback(void)
     {
      st.pbBull = false; st.pbBear = false; st.pbZone = 0.0;
      if(st.atrL <= 0.0)
         return;
      int look = MathMin(m_pbLook, m_nBars - 3);
      double impHigh = -DBL_MAX, impLow = DBL_MAX;
      for(int i = 1; i <= look; i++)
        {
         if(m_high[i] > impHigh) impHigh = m_high[i];
         if(m_low[i]  < impLow)  impLow = m_low[i];
        }
      double lowRecent = MathMin(m_low[1], MathMin(m_low[2], m_low[3]));
      double highRecent = MathMax(m_high[1], MathMax(m_high[2], m_high[3]));

      // bullish pullback: uptrend, retracement into EMA zone, rejection candle
      if(st.ltfTrend == TREND_UP && st.structure != STRUCT_BEAR)
        {
         double retrace = impHigh - lowRecent;
         bool nearMA = (MathAbs(st.c1 - st.ema50L) <= m_pbZoneATR * st.atrL) ||
                       (m_low[1] <= st.ema50L && st.c1 > st.ema50L) ||
                       (m_low[1] <= st.ema20L && st.c1 > st.ema20L);
         double body = MathAbs(st.c1 - st.o1);
         double lw = MathMin(st.o1, st.c1) - st.l1;
         double rng = st.h1 - st.l1;
         bool reject = (st.c1 > st.o1) && (rng > 0) && (lw >= body) && (lw >= 0.35 * rng);
         if(retrace >= m_pbMinATR * st.atrL && retrace <= m_pbMaxATR * st.atrL &&
            nearMA && reject && st.bearBOSBar > 3)
           {
            st.pbBull = true;
            st.pbZone = st.ema50L;
           }
        }
      // bearish pullback
      if(st.ltfTrend == TREND_DOWN && st.structure != STRUCT_BULL)
        {
         double retrace = highRecent - impLow;
         bool nearMA = (MathAbs(st.c1 - st.ema50L) <= m_pbZoneATR * st.atrL) ||
                       (m_high[1] >= st.ema50L && st.c1 < st.ema50L) ||
                       (m_high[1] >= st.ema20L && st.c1 < st.ema20L);
         double body = MathAbs(st.c1 - st.o1);
         double uw = st.h1 - MathMax(st.o1, st.c1);
         double rng = st.h1 - st.l1;
         bool reject = (st.c1 < st.o1) && (rng > 0) && (uw >= body) && (uw >= 0.35 * rng);
         if(retrace >= m_pbMinATR * st.atrL && retrace <= m_pbMaxATR * st.atrL &&
            nearMA && reject && st.bullBOSBar > 3)
           {
            st.pbBear = true;
            st.pbZone = st.ema50L;
           }
        }
     }

   void DetectReversal(void)
     {
      st.bullDiv = false; st.bearDiv = false;
      // RSI divergence at last two swings
      if(st.slCount >= 2)
        {
         int b0 = st.sl[0].bar, b1 = st.sl[1].bar;
         if(b0 < m_nBars && b1 < m_nBars && st.sl[0].price < st.sl[1].price)
           {
            if(m_rsiBuf[b0] > m_rsiBuf[b1] + 2.0)
               st.bullDiv = true;
           }
        }
      if(st.shCount >= 2)
        {
         int b0 = st.sh[0].bar, b1 = st.sh[1].bar;
         if(b0 < m_nBars && b1 < m_nBars && st.sh[0].price > st.sh[1].price)
           {
            if(m_rsiBuf[b0] < m_rsiBuf[b1] - 2.0)
               st.bearDiv = true;
           }
        }
      double bull = 0.0, bear = 0.0;
      if(st.chochBull)  bull += 40.0;
      if(st.chochBear)  bear += 40.0;
      if(st.bullDiv)    bull += 25.0;
      if(st.bearDiv)    bear += 25.0;
      if(st.rsi1 > 50.0 && m_rsiBuf[2] <= 50.0) bull += 15.0;
      if(st.rsi1 < 50.0 && m_rsiBuf[2] >= 50.0) bear += 15.0;
      if(st.adxL3 - st.adxL >= 2.0)             // trend weakening
        {
         bull += 10.0;
         bear += 10.0;
        }
      if(st.strongBull) bull += 10.0;
      if(st.strongBear) bear += 10.0;
      st.revBullScore = MathMin(bull, 100.0);
      st.revBearScore = MathMin(bear, 100.0);
     }

   void ClassifyTrends(void)
     {
      // higher timeframe
      if(st.emaF_H > st.emaS_H && st.closeH > st.emaS_H)
         st.htfTrend = TREND_UP;
      else if(st.emaF_H < st.emaS_H && st.closeH < st.emaS_H)
         st.htfTrend = TREND_DOWN;
      else
         st.htfTrend = TREND_NONE;
      // entry timeframe
      if(st.ema20L > st.ema50L && st.c1 > st.ema50L)
         st.ltfTrend = TREND_UP;
      else if(st.ema20L < st.ema50L && st.c1 < st.ema50L)
         st.ltfTrend = TREND_DOWN;
      else
         st.ltfTrend = TREND_NONE;
      // trend strength 0..100
      double adxN = MathMin(st.adxL, 50.0) / 50.0;
      double sep = 0.0, slopeN = 0.0;
      if(st.atrL > 0)
        {
         sep = MathAbs(st.ema20L - st.ema50L) / (3.0 * st.atrL);
         sep = MathMin(sep, 1.0);
         slopeN = MathAbs(st.ema50L - st.ema50L_3) / (3.0 * st.atrL);
         slopeN = MathMin(slopeN, 1.0);
        }
      st.trendStrength = 100.0 * (0.45 * adxN + 0.30 * sep + 0.25 * slopeN);
     }

   //--- final single-label condition (priority based)
   void ClassifyCondition(void)
     {
      ENUM_MARKET_CONDITION c = COND_UNCERTAIN;
      if(st.vol == VOL_ABNORMAL)
         c = COND_ABNORMAL;
      else if(st.vol == VOL_EXTREME)
         c = COND_EXTREME_VOL;
      else if(st.vol == VOL_LOW)
         c = COND_LOW_VOL;
      else if(st.boBull && st.boValid)
         c = COND_BREAKOUT_BULL;
      else if(st.boBear && st.boValid)
         c = COND_BREAKOUT_BEAR;
      else if(st.revBullScore >= m_revThreshold && st.revBullScore > st.revBearScore)
         c = COND_REVERSAL_BULL;
      else if(st.revBearScore >= m_revThreshold && st.revBearScore > st.revBullScore)
         c = COND_REVERSAL_BEAR;
      else if(st.pbBull)
         c = COND_PULLBACK_BULL;
      else if(st.pbBear)
         c = COND_PULLBACK_BEAR;
      else if(st.ltfTrend == TREND_UP && st.trendStrength >= m_strengthStrong)
         c = COND_STRONG_UPTREND;
      else if(st.ltfTrend == TREND_UP && st.trendStrength >= m_strengthWeak)
         c = COND_WEAK_UPTREND;
      else if(st.ltfTrend == TREND_DOWN && st.trendStrength >= m_strengthStrong)
         c = COND_STRONG_DOWNTREND;
      else if(st.ltfTrend == TREND_DOWN && st.trendStrength >= m_strengthWeak)
         c = COND_WEAK_DOWNTREND;
      else if(st.rangeValid)
         c = COND_RANGE;
      else
         c = COND_UNCERTAIN;
      st.condition = c;
     }
  };

#endif // XGE_MARKET_MQH
