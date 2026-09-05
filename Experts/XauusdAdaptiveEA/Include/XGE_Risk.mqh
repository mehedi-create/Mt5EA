//+------------------------------------------------------------------+
//|                                                    XGE_Risk.mqh |
//|        XAUUSD Adaptive Pro EA - risk and capital protection      |
//|                                                                  |
//| Responsibilities:                                                |
//|  - position sizing from risk percent and SL distance             |
//|  - daily / weekly realized PnL from trade history                |
//|  - daily loss limit, weekly loss limit, max drawdown halt        |
//|  - consecutive loss protection with cooldown                     |
//|  - overtrading limits (trades per day, min gap, positions)       |
//+------------------------------------------------------------------+
#ifndef XGE_RISK_MQH
#define XGE_RISK_MQH

#include "XGE_Define.mqh"

class CRiskManager
  {
public:
   // parameters
   double   m_riskPct;            // risk percent of balance per trade
   double   m_fixedLot;           // >0 overrides risk percent sizing
   double   m_maxLot;             // absolute lot cap
   double   m_maxDailyLossPct;    // halt new trades beyond this daily loss
   double   m_maxWeeklyLossPct;   // halt new trades beyond this weekly loss
   double   m_maxDDPct;           // max drawdown from equity peak
   int      m_maxConsecLoss;      // consecutive losses triggering cooldown
   int      m_cooldownMin;        // cooldown minutes after loss streak
   int      m_maxTradesDay;       // max new entries per day
   int      m_minTradeGapMin;     // minimum minutes between entries
   int      m_maxPositions;       // max simultaneous positions of this EA
   long     m_magic;
   bool     m_closeAllOnMaxDD;    // emergency flatten at DD limit
   // state
   double   m_peakEquity;
   double   m_realizedToday, m_realizedWeek;
   double   m_dayStartBalance, m_weekStartBalance;
   int      m_tradesToday;
   int      m_consecLoss;
   datetime m_lastLossTime;
   datetime m_lastEntryTime;
   datetime m_cooldownUntil;
   bool     m_dailyHalt, m_weeklyHalt, m_ddHalt;
   bool     m_ddFlattened;
   datetime m_statStamp;

   CRiskManager(void)
     {
      m_riskPct = 1.0; m_fixedLot = 0.0; m_maxLot = 10.0;
      m_maxDailyLossPct = 3.0; m_maxWeeklyLossPct = 6.0; m_maxDDPct = 15.0;
      m_maxConsecLoss = 4; m_cooldownMin = 180;
      m_maxTradesDay = 6; m_minTradeGapMin = 20; m_maxPositions = 1;
      m_magic = 0; m_closeAllOnMaxDD = false;
      m_peakEquity = 0.0;
      m_realizedToday = 0.0; m_realizedWeek = 0.0;
      m_dayStartBalance = 0.0; m_weekStartBalance = 0.0;
      m_tradesToday = 0; m_consecLoss = 0;
      m_lastLossTime = 0; m_lastEntryTime = 0; m_cooldownUntil = 0;
      m_dailyHalt = false; m_weeklyHalt = false; m_ddHalt = false;
      m_ddFlattened = false; m_statStamp = 0;
     }

   void Init(const long magic)
     {
      m_magic = magic;
      m_peakEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      RefreshStats();
     }

   //--- account floating PnL of this EA only
   double FloatingPL(void)
     {
      double fl = 0.0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         fl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
        }
      return(fl);
     }

   int OpenPositions(void)
     {
      int c = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;
         c++;
        }
      return(c);
     }

   //--- recompute statistics from history (cheap; done per bar / on demand)
   void RefreshStats(void)
     {
      datetime now = TimeCurrent();
      MqlDateTime dt;
      TimeToStruct(now, dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      datetime day0 = StructToTime(dt);
      int daysBack = (dt.day_of_week == 0) ? 6 : dt.day_of_week - 1;
      datetime week0 = day0 - (long)daysBack * 86400;
      datetime hist0 = day0 - (long)30 * 86400;

      if(!HistorySelect(hist0, now + 60))
         return;

      double realD = 0.0, realW = 0.0;
      int trades = 0, streak = 0;
      datetime lastLoss = 0;
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
        {
         ulong t = HistoryDealGetTicket(i);
         if(t == 0)
            continue;
         if(HistoryDealGetString(t, DEAL_SYMBOL) != _Symbol)
            continue;
         if(HistoryDealGetInteger(t, DEAL_MAGIC) != m_magic)
            continue;
         long entryType = HistoryDealGetInteger(t, DEAL_ENTRY);
         datetime tme = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
         double pnl = HistoryDealGetDouble(t, DEAL_PROFIT) +
                      HistoryDealGetDouble(t, DEAL_SWAP) +
                      HistoryDealGetDouble(t, DEAL_COMMISSION);
         if(entryType == DEAL_ENTRY_IN)
           {
            if(tme >= day0)
               trades++;
           }
         else if(entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_INOUT ||
                 entryType == DEAL_ENTRY_OUT_BY)
           {
            if(tme >= day0)
               realD += pnl;
            if(tme >= week0)
               realW += pnl;
            if(pnl < 0.0)
              {
               streak++;
               if(tme > lastLoss)
                  lastLoss = tme;
              }
            else if(pnl > 0.0)
               streak = 0;
           }
        }
      m_realizedToday = realD;
      m_realizedWeek = realW;
      m_tradesToday = trades;
      m_consecLoss = streak;
      m_lastLossTime = lastLoss;
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      m_dayStartBalance = bal - realD;
      m_weekStartBalance = bal - realW;

      // equity peak and halts
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(eq > m_peakEquity)
         m_peakEquity = eq;
      double ddPct = (m_peakEquity > 0.0) ? (m_peakEquity - eq) / m_peakEquity * 100.0 : 0.0;
      m_ddHalt = (ddPct >= m_maxDDPct);
      m_dailyHalt = (m_dayStartBalance > 0.0 &&
                     DailyPL() <= -m_maxDailyLossPct / 100.0 * m_dayStartBalance);
      m_weeklyHalt = (m_weekStartBalance > 0.0 &&
                      WeeklyPL() <= -m_maxWeeklyLossPct / 100.0 * m_weekStartBalance);
      // consecutive loss cooldown
      if(m_consecLoss >= m_maxConsecLoss && m_lastLossTime > 0)
         m_cooldownUntil = m_lastLossTime + (long)m_cooldownMin * 60;
      else if(m_consecLoss == 0)
         m_cooldownUntil = 0;
      m_statStamp = now;
     }

   double DailyPL(void)  { return(m_realizedToday + FloatingPL()); }
   double WeeklyPL(void) { return(m_realizedWeek + FloatingPL()); }

   double DrawdownPct(void)
     {
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(m_peakEquity <= 0.0)
         return(0.0);
      double dd = (m_peakEquity - eq) / m_peakEquity * 100.0;
      return(dd > 0.0 ? dd : 0.0);
     }

   //--- risk gate checks for a NEW entry; returns "" when allowed
   string EntryAllowed(void)
     {
      datetime now = TimeCurrent();
      if(m_dailyHalt)
         return("Daily loss limit reached");
      if(m_weeklyHalt)
         return("Weekly loss limit reached");
      if(m_ddHalt)
         return("Max drawdown protection active");
      if(now < m_cooldownUntil)
         return(StringFormat("Consecutive-loss cooldown until %s",
                             TimeToString(m_cooldownUntil, TIME_MINUTES)));
      if(m_tradesToday >= m_maxTradesDay)
         return("Max trades per day reached");
      if(m_lastEntryTime > 0 &&
         (long)(now - m_lastEntryTime) < (long)m_minTradeGapMin * 60)
         return("Min interval between trades not elapsed");
      if(OpenPositions() >= m_maxPositions)
         return("Max open positions reached");
      return("");
     }

   //--- position sizing based on SL distance
   double CalcLots(const double slDist, string &err)
     {
      err = "";
      double lot = m_fixedLot;
      if(lot <= 0.0)
        {
         double bal = AccountInfoDouble(ACCOUNT_BALANCE);
         double eq = AccountInfoDouble(ACCOUNT_EQUITY);
         double base = MathMin(bal, eq);        // never size off inflated equity
         double riskMoney = base * m_riskPct / 100.0;
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tickValue <= 0.0 || tickSize <= 0.0)
           {
            err = "Invalid tick data";
            return(0.0);
           }
         if(slDist <= 0.0)
           {
            err = "Invalid SL distance";
            return(0.0);
           }
         double lossPerLot = slDist / tickSize * tickValue;
         if(lossPerLot <= 0.0)
           {
            err = "Invalid SL distance";
            return(0.0);
           }
         lot = riskMoney / lossPerLot;
        }
      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double cap = MathMin(maxL, m_maxLot);
      if(step > 0.0)
         lot = MathFloor(lot / step + 1e-9) * step;
      if(lot > cap)
        {
         lot = cap;
         if(step > 0.0)
            lot = MathFloor(lot / step + 1e-9) * step;
        }
      if(lot < minL)
        {
         err = "Computed lot below broker minimum";
         return(0.0);
        }
      lot = NormalizeDouble(lot, 8);
      return(lot);
     }

   //--- reduce lot if required margin is excessive
   bool MarginSafe(double &lot, const bool isBuy)
     {
      double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                           : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double margin = 0.0;
      if(!OrderCalcMargin(isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lot, price, margin))
         return(true);   // cannot check -> allow, broker validates
      double freeM = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
      if(margin <= freeM * 0.8)
         return(true);
      double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double scale = (margin > 0.0) ? (freeM * 0.8) / margin : 1.0;
      lot = lot * scale;
      if(step > 0.0)
         lot = MathFloor(lot / step + 1e-9) * step;
      if(lot < minL)
         return(false);
      return(true);
     }
  };

#endif // XGE_RISK_MQH
