//+------------------------------------------------------------------+
//|                                                   XGE_Trade.mqh |
//|          XAUUSD Adaptive Pro EA v2 - execution and management    |
//|                                                                  |
//| v2: exits are regime driven (structure / S-R / trailing-reverse) |
//| and handled by the main module. This class provides:             |
//|  - safe market execution with filling-mode detection             |
//|  - per-position bookkeeping (initial SL distance + operating mode)|
//|  - emergency exit on extreme adverse moves                       |
//|  - flatten-all helper for protection / weekend                   |
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
   ulong    m_ticket[64];
   double   m_slDist[64];
   int      m_mode[64];
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

   void Register(const ulong ticket, const double slDist, const int mode)
     {
      CleanupClosed();
      if(m_count >= 64)
         return;
      m_ticket[m_count] = ticket;
      m_slDist[m_count] = slDist;
      m_mode[m_count] = mode;
      m_count++;
     }

   void CleanupClosed(void)
     {
      int w = 0;
      for(int i = 0; i < m_count; i++)
        {
         if(PositionSelectByTicket(m_ticket[i]))
           {
            if(w != i)
              {
               m_ticket[w] = m_ticket[i];
               m_slDist[w] = m_slDist[i];
               m_mode[w] = m_mode[i];
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

   //--- operating mode of a position (-1 unknown)
   int GetMode(const ulong ticket)
     {
      int r = FindRecord(ticket);
      return(r >= 0) ? m_mode[r] : -1;
     }

   double MinStopDist(void)
     {
      long pts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      return((double)pts * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
     }

   //--- open a market position; tp==0 means no fixed take profit
   bool OpenPosition(const ENUM_SIGNAL_DIR dir, double lot,
                     double sl, double tp, const string comment,
                     const int mode, uint &retcode, double &openPrice)
     {
      retcode = 0;
      openPrice = 0.0;
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double minDist = MinStopDist();
      bool isBuy = (dir == SIG_BUY);
      double px = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(isBuy)
        {
         if(px - sl < minDist) sl = px - minDist - point;
         if(tp > 0.0 && tp - px < minDist) tp = px + minDist + point;
        }
      else
        {
         if(sl - px < minDist) sl = px + minDist + point;
         if(tp > 0.0 && px - tp < minDist) tp = px - minDist - point;
        }
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
      if(tp <= 0.0)
         tp = 0.0;

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
            posTicket = m_trade.ResultDeal();
         Register(posTicket, MathAbs(openPrice - sl), mode);
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
            return(false);
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

   //--- emergency exit only; regime exits are driven by the main module
   void ManageEmergency(const double atr, const double emergencyATR)
     {
      CleanupClosed();
      if(atr <= 0.0)
         return;
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
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double profitDist = isBuy ? (bid - entry) : (entry - ask);
         if(profitDist <= -emergencyATR * atr)
           {
            m_trade.PositionClose(tk);
            Print("XGE: emergency exit ticket ", tk, " (extreme adverse move)");
           }
        }
     }
  };

#endif // XGE_TRADE_MQH
