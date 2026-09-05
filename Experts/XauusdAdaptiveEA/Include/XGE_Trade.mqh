//+------------------------------------------------------------------+
//|                                                   XGE_Trade.mqh |
//|          XAUUSD Adaptive Pro EA - execution and trade manager    |
//|                                                                  |
//| Responsibilities:                                                |
//|  - safe market execution with filling-mode detection             |
//|  - break-even, ATR trailing stop, partial profit taking          |
//|  - smart exits on condition flip / extreme adverse move          |
//|  - flatten-all helper for protection modes                       |
//+------------------------------------------------------------------+
#ifndef XGE_TRADE_MQH
#define XGE_TRADE_MQH

#include "XGE_Define.mqh"
#include <Trade\Trade.mqh>

class CTradeManager
  {
public:
   CTrade   m_trade;
   long     m_magic;
   // per-position bookkeeping (initial SL distance, one-time flags)
   ulong    m_ticket[64];
   double   m_slDist[64];
   bool     m_partialDone[64];
   bool     m_beDone[64];
   int      m_count;

   CTradeManager(void)
     {
      m_magic = 0;
      m_count = 0;
     }

   void Init(const long magic, const int slippagePts)
     {
      m_magic = magic;
      m_trade.SetExpertMagicNumber(magic);
      m_trade.SetDeviationInPoints(slippagePts);
      m_trade.SetTypeFilling(DetectFilling());
      m_trade.SetAsyncMode(false);
      m_count = 0;
     }

   ENUM_ORDER_TYPE_FILLING DetectFilling(void)
     {
      long modes = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
      if((modes & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
         return(ORDER_FILLING_FOK);
      if((modes & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
         return(ORDER_FILLING_IOC);
      return(ORDER_FILLING_RETURN);
     }

   //--- remember initial SL distance of a freshly opened position
   void Register(const ulong ticket, const double slDist)
     {
      CleanupClosed();
      if(m_count >= 64)
         return;
      m_ticket[m_count] = ticket;
      m_slDist[m_count] = slDist;
      m_partialDone[m_count] = false;
      m_beDone[m_count] = false;
      m_count++;
     }

   //--- drop records of positions that no longer exist
   void CleanupClosed(void)
     {
      int w = 0;
      for(int i = 0; i < m_count; i++)
        {
         bool exists = false;
         if(PositionSelectByTicket(m_ticket[i]))
            exists = true;
         if(exists)
           {
            if(w != i)
              {
               m_ticket[w] = m_ticket[i];
               m_slDist[w] = m_slDist[i];
               m_partialDone[w] = m_partialDone[i];
               m_beDone[w] = m_beDone[i];
              }
            w++;
           }
        }
      m_count = w;
     }

   int FindRecord(const ulong ticket)
     {
      for(int i = 0; i < m_count; i++)
         if(m_ticket[i] == ticket)
            return(i);
      return(-1);
     }

   double MinStopDist(void)
     {
      long pts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      return((double)pts * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
     }

   //--- open a market position; returns true on success
   bool OpenPosition(const ENUM_SIGNAL_DIR dir, double lot,
                     double sl, double tp, const string comment,
                     uint &retcode, double &openPrice)
     {
      retcode = 0;
      openPrice = 0.0;
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double minDist = MinStopDist();
      bool isBuy = (dir == SIG_BUY);
      double px = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // enforce broker minimal stop distances
      if(isBuy)
        {
         if(px - sl < minDist) sl = px - minDist - point;
         if(tp - px < minDist) tp = px + minDist + point;
        }
      else
        {
         if(sl - px < minDist) sl = px + minDist + point;
         if(px - tp < minDist) tp = px - minDist - point;
        }
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);

      bool ok;
      if(isBuy)
         ok = m_trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
      else
         ok = m_trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);
      retcode = m_trade.ResultRetcode();
      openPrice = m_trade.ResultPrice();
      if(ok && (retcode == TRADE_RETCODE_DONE || retcode == TRADE_RETCODE_PLACED ||
                retcode == TRADE_RETCODE_DONE_PARTIAL))
        {
         ulong dealTicket = m_trade.ResultDeal();
         // position ticket may differ from deal; find our newest position
         ulong posTicket = 0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
            ulong tk = PositionGetTicket(i);
            if(tk == 0)
               continue;
            if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
               PositionGetInteger(POSITION_MAGIC) == m_magic)
              {
               posTicket = tk;
               break;
              }
           }
         if(posTicket == 0)
            posTicket = dealTicket;
         double d = MathAbs(openPrice - sl);
         Register(posTicket, d);
         return(true);
        }
      return(false);
     }

   bool ModifySL(const ulong ticket, double newSL)
     {
      if(!PositionSelectByTicket(ticket))
         return(false);
      long ptype = PositionGetInteger(POSITION_TYPE);
      double curSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double minDist = MinStopDist();
      double px = PositionGetDouble(POSITION_PRICE_CURRENT);
      newSL = NormalizeDouble(newSL, _Digits);
      if(ptype == POSITION_TYPE_BUY)
        {
         if(newSL <= curSL)
            return(false);                       // only move in favor
         if(px - newSL < minDist)
            return(false);
         return(m_trade.PositionModify(ticket, newSL, tp));
        }
      else
        {
         if(curSL > 0.0 && newSL >= curSL)
            return(false);
         if(newSL - px < minDist)
            return(false);
         return(m_trade.PositionModify(ticket, newSL, tp));
        }
      return(false);
     }

   bool ClosePosition(const ulong ticket)
     {
      return(m_trade.PositionClose(ticket));
     }

   bool CloseAll(string &closedMsg)
     {
      bool allOk = true;
      closedMsg = "";
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(tk == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         if(!m_trade.PositionClose(tk))
            allOk = false;
         else
            closedMsg += IntegerToString((long)tk) + " ";
        }
      CleanupClosed();
      return(allOk);
     }

   //+------------------------------------------------------------------+
   //| Manage all open positions of this EA                           |
   //+------------------------------------------------------------------+
   void ManagePositions(const SMarketState &st,
                        const bool useBE, const double beTriggerATR, const double beOffsetPts,
                        const bool useTrail, const double trailStartATR, const double trailATR,
                        const bool usePartial, const double partialR, const double partialPct,
                        const bool smartExit, const bool tighten)
     {
      CleanupClosed();
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double atr = st.atrL;
      if(atr <= 0.0)
         atr = st.atrH > 0 ? st.atrH : 0.0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong tk = PositionGetTicket(i);
         if(tk == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         long ptype = PositionGetInteger(POSITION_TYPE);
         bool isBuy = (ptype == POSITION_TYPE_BUY);
         double entry = PositionGetDouble(POSITION_PRICE_OPEN);
         double curSL = PositionGetDouble(POSITION_SL);
         double vol = PositionGetDouble(POSITION_VOLUME);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         int rec = FindRecord(tk);
         double initDist = (rec >= 0) ? m_slDist[rec] : MathAbs(entry - curSL);
         if(initDist <= 0.0)
            initDist = atr > 0 ? atr : 0.0;
         double profitDist = isBuy ? (bid - entry) : (entry - ask);

         //--- emergency exit: extreme adverse move (behind max SL width)
         if(atr > 0.0 && profitDist <= -5.0 * atr)
           {
            m_trade.PositionClose(tk);
            Print("XGE: emergency exit ticket ", tk, " (extreme adverse move)");
            continue;
           }

         //--- smart exit: market condition flipped hard against the position
         if(smartExit)
           {
            bool flipSell = (isBuy && (st.condition == COND_STRONG_DOWNTREND ||
                                       (st.bearBOS && st.bearBOSBar <= 2) ||
                                       st.chochBear));
            bool flipBuy = (!isBuy && (st.condition == COND_STRONG_UPTREND ||
                                       (st.bullBOS && st.bullBOSBar <= 2) ||
                                       st.chochBull));
            if((flipSell || flipBuy) && profitDist > -0.5 * atr)
              {
               m_trade.PositionClose(tk);
               Print("XGE: smart exit ticket ", tk, " (condition flipped)");
               continue;
              }
           }

         //--- partial profit taking
         if(usePartial && rec >= 0 && !m_partialDone[rec] && initDist > 0.0 &&
            profitDist >= partialR * initDist)
           {
            double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double closeVol = vol * partialPct / 100.0;
            if(step > 0.0)
               closeVol = MathFloor(closeVol / step + 1e-9) * step;
            if(closeVol >= minV && (vol - closeVol) >= minV)
              {
               if(m_trade.PositionClosePartial(tk, closeVol))
                 {
                  m_partialDone[rec] = true;
                  Print("XGE: partial close ticket ", tk, " vol ", DoubleToString(closeVol, 2));
                 }
              }
           }

         //--- break-even
         if(useBE && atr > 0.0 && profitDist >= beTriggerATR * atr)
           {
            double off = beOffsetPts * point;
            double target = isBuy ? entry + off : entry - off;
            bool better = isBuy ? (curSL < target) : (curSL > target || curSL == 0.0);
            if(better && (rec < 0 || !m_beDone[rec]))
              {
               if(ModifySL(tk, target))
                 {
                  if(rec >= 0)
                     m_beDone[rec] = true;
                 }
              }
           }

         //--- ATR trailing stop
         if(useTrail && atr > 0.0 && profitDist >= trailStartATR * atr)
           {
            double dist = trailATR * atr;
            if(tighten)
               dist *= 0.5;                    // extreme market -> tighten
            double target = isBuy ? bid - dist : ask + dist;
            if(isBuy)
              {
               if(target > curSL + point)
                  ModifySL(tk, target);
              }
            else
              {
               if(curSL == 0.0 || target < curSL - point)
                  ModifySL(tk, target);
              }
           }
        }
     }
  };

#endif // XGE_TRADE_MQH
