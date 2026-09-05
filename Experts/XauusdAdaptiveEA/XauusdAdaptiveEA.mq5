//+------------------------------------------------------------------+
//|                                            XauusdAdaptiveEA.mq5 |
//|                 XAUUSD Adaptive Pro EA - v2 main module          |
//|                                                                  |
//| v2 design (user direction):                                      |
//|   - ONLY low volatility means NO TRADE. Every other market state |
//|     is traded with a regime-specific behaviour.                  |
//|   - UPTREND  : buy at fresh Higher-Low, close at Higher-High     |
//|   - DOWNTREND: sell at fresh Lower-High, close at Lower-Low      |
//|   - SIDE     : buy support / sell resistance                     |
//|   - NEWS     : trade the probable direction with a rolling       |
//|     trailing stop; when the trailing stop is hit, reverse into   |
//|     the opposite trade with a new rolling trailing stop.         |
//|                                                                  |
//| Capital protection layers (risk sizing, daily/weekly limits,     |
//| max-DD halt, cooldowns, spread guard) stay active at all times.  |
//|                                                                  |
//| Not a holy grail - losses and drawdowns are part of trading.     |
//+------------------------------------------------------------------+
#property copyright   "XGE Project"
#property link        ""
#property version     "2.00"
#property description "XAUUSD Adaptive Pro EA v2: regime-based structure trading."
#property description "Trades all market states except low volatility."

#include "Include\XGE_Define.mqh"
#include "Include\XGE_Market.mqh"
#include "Include\XGE_Strategy.mqh"
#include "Include\XGE_Risk.mqh"
#include "Include\XGE_Trade.mqh"
#include "Include\XGE_Dashboard.mqh"

//=== General ========================================================
input group "=== General ==="
input long              InpMagic          = 20260905;     // Magic number
input int               InpSlippagePts    = 30;           // Max slippage (points)
input string            InpComment        = "XGE";        // Order comment tag
input bool              InpAllowBuy       = true;         // Allow BUY trades
input bool              InpAllowSell      = true;         // Allow SELL trades

//=== Timeframes =====================================================
input group "=== Timeframes ==="
input ENUM_TIMEFRAMES   InpHTF            = PERIOD_M15;   // Higher TF (regime anchor; keep > entry TF)
input ENUM_TIMEFRAMES   InpEntryTF        = PERIOD_M15;   // Entry TF (signals)
input bool              InpUseHTFRegime   = true;         // Anchor regime/S&R on HTF (best for M5)
input double            InpSwingMinATR    = 0.5;          // Min swing size (xATR) to count (0=off)
input bool              InpAutoM5Preset   = true;         // On M5 charts auto-apply M5-tuned params

//=== Regime trading =================================================
input group "=== Regime Trading ==="
input int               InpSwingFresh     = 3;            // Max age of a fresh swing (bars)
input bool              InpUseNewsMode    = true;         // Enable news stop-and-reverse mode
input double            InpNewsTrailATR   = 1.2;          // News trailing stop (xATR)
input double            InpNewsMomentumATR= 0.4;          // News momentum candle (xATR body)
input int               InpNewsMaxReversals= 3;           // Max stop-and-reverse flips per news window
input double            InpEmergencyATR   = 5.0;          // Emergency exit at adverse xATR

//=== Risk ===========================================================
input group "=== Risk ==="
input double            InpRiskPercent    = 1.0;          // Risk % per trade
input double            InpFixedLot       = 0.0;          // Fixed lot (0 = use risk %)
input double            InpMaxLot         = 10.0;         // Absolute lot cap
input double            InpSLATRmin       = 0.8;          // Min SL distance (xATR)
input double            InpSLATRmax       = 4.0;          // Max SL distance (xATR)

//=== Drawdown Protection ============================================
input group "=== Drawdown Protection ==="
input double            InpMaxDailyLossPct  = 3.0;        // Daily loss limit %
input double            InpMaxWeeklyLossPct = 6.0;        // Weekly loss limit %
input double            InpMaxDrawdownPct   = 15.0;       // Max drawdown % (equity peak)
input int               InpDDHaltDays       = 5;          // DD breaker pause days (then resume)
input int               InpMaxConsecLoss    = 4;          // Consecutive losses -> cooldown
input int               InpCooldownMin      = 180;        // Cooldown minutes

//=== Overtrading Protection =========================================
input group "=== Overtrading Protection ==="
input int               InpMaxTradesPerDay  = 12;         // Max new entries per day
input int               InpMinTradeGapMin   = 5;          // Min minutes between normal entries
input int               InpMaxPositions     = 1;          // Max simultaneous positions
input int               InpSameSetupBars    = 24;         // Block same setup within N bars

//=== Filters ========================================================
input group "=== Filters ==="
input double            InpMaxSpreadPts   = 60.0;         // Max spread (points @0.01)
input int               InpFridayStopHour = 21;           // No new entries Friday after (0=off)
input int               InpFridayCloseHour= 22;           // Close all Friday at (0=off)
input bool              InpUseNewsTimes   = true;         // Use news windows (trading mode)
input int               InpNewsBeforeMin  = 30;           // Window opens N min before
input int               InpNewsAfterMin   = 30;           // Window closes N min after
input string            InpNewsHours      = "13:30,15:00,19:00"; // News times HH:MM (server)

//=== Volatility Model ===============================================
input group "=== Volatility Model ==="
input int               InpATRPeriod      = 14;           // ATR period
input int               InpATRAvgBars     = 200;          // ATR baseline bars
input double            InpVolLowRatio    = 0.55;         // Low vol ratio = NO TRADE threshold
input double            InpVolHighRatio   = 1.60;         // High vol ratio
input double            InpVolExtremeRatio= 2.50;         // Extreme vol ratio
input double            InpAbnormalBarATR = 6.0;          // Abnormal single bar (xATR)

//=== Trend / Structure ==============================================
input group "=== Trend Structure ==="
input int               InpADXPeriod      = 14;           // ADX period
input int               InpEmaFastH       = 50;           // HTF fast EMA
input int               InpEmaSlowH       = 200;          // HTF slow EMA
input int               InpEmaZoneF       = 20;           // Entry fast EMA
input int               InpEmaZoneM       = 50;           // Entry medium EMA
input int               InpEmaZoneS       = 200;          // Entry slow EMA
input double            InpStrengthStrong = 60.0;         // Strong trend threshold
input double            InpStrengthWeak   = 35.0;         // Weak trend threshold
input int               InpSwingStrength  = 3;            // Swing strength (bars/side)
input int               InpSwingLookback  = 120;          // Swing scan lookback bars
input int               InpRSIPeriod      = 14;           // RSI period
input int               InpRangeLookback  = 90;           // Range window bars
input double            InpRangeMinATR    = 2.5;          // Min range width (xATR)
input double            InpRangeMaxATR    = 12.0;         // Max range width (xATR)
input double            InpADXRangeMax    = 20.0;         // Max ADX for range
input double            InpBOMinATR       = 0.15;         // Breakout margin (xATR)
input int               InpBOMinTouches   = 2;            // Min boundary touches

//=== Dashboard & Logging ============================================
input group "=== Dashboard and Logging ==="
input bool              InpShowDashboard  = true;         // Show dashboard
input int               InpDashX          = 12;           // Dashboard X
input int               InpDashY          = 22;           // Dashboard Y
input int               InpDashFont       = 9;            // Dashboard font size
input bool              InpFileLog        = true;         // Write CSV decision log

//--- modules
CMarketAnalyzer  g_mkt;
CStrategyEngine  g_strat;
CRiskManager     g_risk;
CTradeManager    g_tm;
CDashboard       g_dash;

//--- global state
int      g_log = INVALID_HANDLE;
bool     g_ready = false;
datetime g_lastBarTime = 0;
datetime g_lastManageTime = 0;
datetime g_execPauseUntil = 0;
string   g_lastSkipReason = "";
datetime g_lastSkipLogTime = 0;
string   g_lastSignalLine = "no signal";
string   g_lastActionLine = "initialized";
string   g_statusExtra = "";
ENUM_MODE g_mode = MODE_SIDE;
// effective (possibly M5-preset) parameters
double   g_effNewsTrail     = 1.2;
double   g_effNewsMomentum  = 0.4;
int      g_effNewsMaxRev    = 3;
int      g_effSwingFresh    = 3;
bool     g_statsDirty = true;
// news stop-and-reverse state
datetime g_newsKey = 0;
int      g_newsReversals = 0;
// anti overtrading
ENUM_STRATEGY g_lastEntryStrat = STRAT_NONE;
ENUM_SIGNAL_DIR g_lastEntryDir = SIG_NONE;
datetime g_lastEntryBarTime = 0;
int      g_fridayClosedDay = -1;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(PeriodSeconds(InpHTF) <= PeriodSeconds(InpEntryTF))
     {
      Print("XGE: HTF must be higher than Entry TF.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpRiskPercent <= 0.0 && InpFixedLot <= 0.0)
     {
      Print("XGE: Risk percent or fixed lot must be positive.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0 &&
      StringFind(_Symbol, "Gold") < 0)
      Print("XGE warning: designed for XAUUSD/GOLD. Symbol: ", _Symbol);

   g_mkt.m_atrPeriod = InpATRPeriod;
   g_mkt.m_adxPeriod = InpADXPeriod;
   g_mkt.m_rsiPeriod = InpRSIPeriod;
   g_mkt.m_emaFastH = InpEmaFastH;   g_mkt.m_emaSlowH = InpEmaSlowH;
   g_mkt.m_emaZoneF = InpEmaZoneF;   g_mkt.m_emaZoneM = InpEmaZoneM;
   g_mkt.m_emaZoneS = InpEmaZoneS;
   g_mkt.m_swingStrength = InpSwingStrength;
   g_mkt.m_swingLookback = InpSwingLookback;
   g_mkt.m_atrAvgBars = InpATRAvgBars;
   g_mkt.m_volLowRatio = InpVolLowRatio;
   g_mkt.m_volHighRatio = InpVolHighRatio;
   g_mkt.m_volExtremeRatio = InpVolExtremeRatio;
   g_mkt.m_abnormalBarATR = InpAbnormalBarATR;
   g_mkt.m_adxRangeMax = InpADXRangeMax;
   g_mkt.m_strengthStrong = InpStrengthStrong;
   g_mkt.m_strengthWeak = InpStrengthWeak;
   g_mkt.m_rangeLookback = InpRangeLookback;
   g_mkt.m_rangeMinATR = InpRangeMinATR;
   g_mkt.m_rangeMaxATR = InpRangeMaxATR;
   g_mkt.m_boMinATR = InpBOMinATR;
   g_mkt.m_boMinTouches = InpBOMinTouches;
   g_mkt.m_swingMinATR = InpSwingMinATR;
   g_mkt.m_useHTFRegime = (InpUseHTFRegime &&
                           PeriodSeconds(InpHTF) > PeriodSeconds(InpEntryTF));

   //--- v2.1: M5 auto preset (validated on the 1-year M5 backtest)
   g_effNewsTrail    = InpNewsTrailATR;
   g_effNewsMomentum = InpNewsMomentumATR;
   g_effNewsMaxRev   = InpNewsMaxReversals;
   g_effSwingFresh   = InpSwingFresh;
   if(InpEntryTF == PERIOD_M5 && InpAutoM5Preset)
     {
      if(InpNewsMomentumATR == 0.4)  g_effNewsMomentum = 1.0;
      if(InpNewsTrailATR == 1.2)     g_effNewsTrail = 2.0;
      if(InpNewsMaxReversals == 3)   g_effNewsMaxRev = 2;
      if(InpSwingFresh == 3)         g_effSwingFresh = 5;
      Print("XGE: M5 entry TF - auto preset applied (news momentum ",
            DoubleToString(g_effNewsMomentum, 1), "xATR, trail ",
            DoubleToString(g_effNewsTrail, 1), "xATR, max reversals ",
            g_effNewsMaxRev, ", swing fresh ", g_effSwingFresh,
            " bars). NOTE: M5 results are sensitive to the news trail",
            " distance - validate in the Strategy Tester.");
     }

   g_strat.m_slATRmin = InpSLATRmin;
   g_strat.m_slATRmax = InpSLATRmax;
   g_strat.m_swingFresh = g_effSwingFresh;

   g_risk.m_riskPct = InpRiskPercent;
   g_risk.m_fixedLot = InpFixedLot;
   g_risk.m_maxLot = InpMaxLot;
   g_risk.m_maxDailyLossPct = InpMaxDailyLossPct;
   g_risk.m_maxWeeklyLossPct = InpMaxWeeklyLossPct;
   g_risk.m_maxDDPct = InpMaxDrawdownPct;
   g_risk.m_ddHaltDays = InpDDHaltDays;
   g_risk.m_maxConsecLoss = InpMaxConsecLoss;
   g_risk.m_cooldownMin = InpCooldownMin;
   g_risk.m_maxTradesDay = InpMaxTradesPerDay;
   g_risk.m_minTradeGapMin = InpMinTradeGapMin;
   g_risk.m_maxPositions = InpMaxPositions;
   g_risk.Init(InpMagic);

   g_tm.Init(InpMagic, InpSlippagePts);
   if(!g_mkt.Init(InpHTF, InpEntryTF))
      return(INIT_FAILED);

   bool visual = (MQLInfoInteger(MQL_VISUAL_MODE) != 0);
   bool tester = (MQLInfoInteger(MQL_TESTER) != 0);
   g_dash.Init(InpShowDashboard && (!tester || visual), InpDashX, InpDashY, InpDashFont);

   if(InpFileLog)
      OpenLog();
   EventSetTimer(1);
   Print("XGE v2 initialized on ", _Symbol, " EntryTF=", EnumToString(InpEntryTF),
         " magic=", InpMagic, " | regime trading: UP=HL/HH DOWN=LH/LL SIDE=S/R NEWS=trail+reverse");
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   g_mkt.Deinit();
   g_dash.Deinit();
   if(g_log != INVALID_HANDLE)
     {
      FileClose(g_log);
      g_log = INVALID_HANDLE;
     }
   Comment("");
  }

void OnTick()
  {
   datetime now = TimeCurrent();
   if(now != g_lastManageTime)
     {
      g_lastManageTime = now;
      if(g_ready)
        {
         ManagePass(now);
         WeekendAndFridayControl();
        }
     }
   datetime bt = iTime(_Symbol, InpEntryTF, 0);
   if(bt != 0 && bt != g_lastBarTime)
     {
      g_lastBarTime = bt;
      OnNewBar();
     }
  }

void OnTimer()
  {
   if(g_statsDirty)
     {
      g_risk.RefreshStats();
      g_statsDirty = false;
     }
   if(g_dash.m_enabled)
      UpdateDashboard();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      g_statsDirty = true;
  }

//+------------------------------------------------------------------+
//| Regime selection: only LOW VOL stays out                          |
//+------------------------------------------------------------------+
ENUM_MODE CurrentMode(const SMarketState &st, const datetime now)
  {
   if(st.vol == VOL_LOW)
      return(MODE_NOVOL);
   if(InpUseNewsTimes && InpUseNewsMode && NewsWindowKey(now) != 0)
      return(MODE_NEWS);
   // v2.1: prefer HTF-anchored structure/trend when available (M5 charts)
   ENUM_STRUCTURE s = st.htfRegimeValid ? st.htfStructure : st.structure;
   ENUM_TREND_DIR t = st.htfRegimeValid ? st.htfTrend : st.ltfTrend;
   if(s == STRUCT_BULL || (t == TREND_UP && s != STRUCT_BEAR))
      return(MODE_UP);
   if(s == STRUCT_BEAR || (t == TREND_DOWN && s != STRUCT_BULL))
      return(MODE_DOWN);
   return(MODE_SIDE);
  }

//+------------------------------------------------------------------+
//| Full decision cycle on each closed entry-TF bar                  |
//+------------------------------------------------------------------+
void OnNewBar()
  {
   if(!g_mkt.Update())
     {
      g_statusExtra = "waiting for history data";
      return;
     }
   if(!g_ready)
     {
      g_ready = true;
      Print("XGE: market data ready, EA active");
     }
   g_statusExtra = "";
   g_risk.RefreshStats();
   const SMarketState st = g_mkt.st;
   datetime now = TimeCurrent();

   // 1) regime
   g_mode = CurrentMode(st, now);

   // 2) structure-driven exits for open positions
   StructureExits(st, now);
   if(g_mode == MODE_NOVOL)
     {
      g_lastSignalLine = "LOW VOLATILITY - standing aside (only no-trade state)";
      LogSkip("Low volatility - no trade");
      UpdateDashboard();
      return;
     }
   if(g_mode == MODE_NEWS)
     {
      g_lastSignalLine = "NEWS WINDOW - momentum + trailing stop-and-reverse active";
      UpdateDashboard();
      return;   // news entries are handled in ManagePass
     }

   // 3) regime entries
   if(g_risk.OpenPositions() > 0)
     {
      UpdateDashboard();
      return;
     }
   SSignal sigs[];
   ArrayResize(sigs, XGE_MAX_SIGNALS);
   int sigCount = g_strat.BuildSignals(st, g_mode, sigs);
   if(sigCount == 0)
     {
      g_lastSignalLine = StringFormat("%s - waiting for setup", ModeText(g_mode));
      UpdateDashboard();
      return;
     }
   SSignal best = sigs[0];
   for(int i = 1; i < sigCount; i++)
      if(sigs[i].conf > best.conf)
         best = sigs[i];
   if(best.dir == SIG_BUY && !InpAllowBuy)
     {
      LogSkip("Buy disabled");
      UpdateDashboard();
      return;
     }
   if(best.dir == SIG_SELL && !InpAllowSell)
     {
      LogSkip("Sell disabled");
      UpdateDashboard();
      return;
     }

   // 4) protective gates (risk/spread/overtrading only - regimes always tradable)
   string reason = "";
   if(!PassGates(best, reason))
     {
      g_lastSignalLine = StringFormat("%s BLOCKED: %s", DirText(best.dir), reason);
      LogSkip(reason);
      UpdateDashboard();
      return;
     }
   // same-setup guard
   if(best.strat == g_lastEntryStrat && best.dir == g_lastEntryDir && g_lastEntryBarTime > 0)
     {
      int barsSince = iBarShift(_Symbol, InpEntryTF, g_lastEntryBarTime, false);
      if(barsSince >= 0 && barsSince < InpSameSetupBars)
        {
         LogSkip("Same setup repeated");
         UpdateDashboard();
         return;
        }
     }

   // 5) execute
   TryOpen(best.dir, best.sl, best.tp, (int)g_mode, best.reason, false);
   UpdateDashboard();
  }

//+------------------------------------------------------------------+
//| Close open positions when their structure target/failure arrives |
//+------------------------------------------------------------------+
void StructureExits(const SMarketState &st, const datetime now)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      int pmode = g_tm.GetMode(tk);
      long ptype = PositionGetInteger(POSITION_TYPE);
      bool closeNow = false;
      string why = "";
      if(pmode == MODE_UP)
        {
         if(st.bullBOS && st.bullBOSBar <= 2)
           {
            closeNow = true; why = "HIGHER-HIGH target";
           }
         else if(g_mode == MODE_DOWN)
           {
            closeNow = true; why = "trend reversed down";
           }
        }
      else if(pmode == MODE_DOWN)
        {
         if(st.bearBOS && st.bearBOSBar <= 2)
           {
            closeNow = true; why = "LOWER-LOW target";
           }
         else if(g_mode == MODE_UP)
           {
            closeNow = true; why = "trend reversed up";
           }
        }
      else if(pmode == MODE_SIDE)
        {
         if(g_mode == MODE_NEWS || (g_mode == MODE_UP && ptype == POSITION_TYPE_SELL) ||
            (g_mode == MODE_DOWN && ptype == POSITION_TYPE_BUY))
           {
            closeNow = true; why = "regime changed";
           }
        }
      if(closeNow)
        {
         if(g_tm.ClosePosition(tk))
           {
            g_lastActionLine = "CLOSE #" + IntegerToString((long)tk) + " " + why;
            LogRow("CLOSE", ptype == POSITION_TYPE_BUY ? "BUY" : "SELL", "Structure",
                   ModeText(g_mode), why, "");
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Per-second management: emergency, news trailing & stop-reverse    |
//+------------------------------------------------------------------+
void ManagePass(const datetime now)
  {
   const SMarketState st = g_mkt.st;
   g_tm.ManageEmergency(st.atrL, InpEmergencyATR);

   if(!InpUseNewsTimes || !InpUseNewsMode)
      return;
   double atr = st.atrL;
   if(atr <= 0.0)
      return;
   datetime wkey = NewsWindowKey(now);
   if(wkey != g_newsKey)
     {
      g_newsKey = wkey;
      g_newsReversals = 0;
     }
   double trail = g_effNewsTrail * atr;

   // manage open news positions: rolling trailing + stop-and-reverse
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(g_tm.GetMode(tk) != MODE_NEWS)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      double curSL = PositionGetDouble(POSITION_SL);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(wkey == 0)   // window ended -> flatten news position
        {
         if(g_tm.ClosePosition(tk))
            LogRow("CLOSE", ptype == POSITION_TYPE_BUY ? "BUY" : "SELL", "News",
                   "NEWS", "news window ended", "");
         continue;
        }
      if(ptype == POSITION_TYPE_BUY)
        {
         double tgt = bid - trail;
         if(tgt > curSL)
            g_tm.ModifySL(tk, tgt);
         if(bid <= curSL)   // trailing stop hit -> reverse
           {
            g_tm.ClosePosition(tk);
            LogRow("REVERSE", "BUY", "News", "NEWS", "trailing stop hit, reversing", "");
            g_newsReversals++;
            if(g_newsReversals <= g_effNewsMaxRev)
               TryOpen(SIG_SELL, curSL + trail, 0.0, MODE_NEWS,
                       "News stop-and-reverse (sell)", true);
           }
        }
      else
        {
         double tgt = ask + trail;
         if(curSL == 0.0 || tgt < curSL)
            g_tm.ModifySL(tk, tgt);
         if(ask >= curSL)
           {
            g_tm.ClosePosition(tk);
            LogRow("REVERSE", "SELL", "News", "NEWS", "trailing stop hit, reversing", "");
            g_newsReversals++;
            if(g_newsReversals <= g_effNewsMaxRev)
               TryOpen(SIG_BUY, curSL - trail, 0.0, MODE_NEWS,
                       "News stop-and-reverse (buy)", true);
           }
        }
     }

   // fresh momentum entry inside a news window (risk gates still apply)
   if(wkey != 0 && g_risk.OpenPositions() == 0 && g_newsReversals <= g_effNewsMaxRev)
     {
      string riskBlock = g_risk.EntryAllowed();
      double body = st.c1 - st.o1;
      if(riskBlock == "" && MathAbs(body) >= g_effNewsMomentum * atr)
        {
         ENUM_SIGNAL_DIR dir = (body > 0.0) ? SIG_BUY : SIG_SELL;
         double sl = (dir == SIG_BUY) ? (st.c1 - trail) : (st.c1 + trail);
         string why = StringFormat("News momentum %s (body %.2f)", DirText(dir), body);
         TryOpen(dir, sl, 0.0, MODE_NEWS, why, true);
        }
     }
  }

//+------------------------------------------------------------------+
//| Risk / execution gates only (no market-condition filtering)      |
//+------------------------------------------------------------------+
bool PassGates(const SSignal &sig, string &reason)
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     {
      reason = "Trading disabled in terminal";
      return(false);
     }
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
     {
      reason = "Account trading not allowed";
      return(false);
     }
   long tradeMode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode != SYMBOL_TRADE_MODE_FULL)
     {
      reason = "Symbol trade mode restricted";
      return(false);
     }
   if(TimeCurrent() < g_execPauseUntil)
     {
      reason = "Execution paused (slippage protection)";
      return(false);
     }
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spreadPts = (point > 0.0) ?
      (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point : 0.0;
   if(spreadPts > InpMaxSpreadPts)
     {
      reason = StringFormat("High spread %.0f pts", spreadPts);
      return(false);
     }
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(InpFridayStopHour > 0 && dt.day_of_week == 5 && dt.hour >= InpFridayStopHour)
     {
      reason = "Friday pre-weekend stop";
      return(false);
     }
   string riskBlock = g_risk.EntryAllowed();
   if(riskBlock != "")
     {
      reason = riskBlock;
      return(false);
     }
   if(HasOppositePosition(sig.dir))
     {
      reason = "Opposite position already open";
      return(false);
     }
   reason = "";
   return(true);
  }

//+------------------------------------------------------------------+
//| Size and send an order                                           |
//+------------------------------------------------------------------+
void TryOpen(const ENUM_SIGNAL_DIR dir, const double slIn, const double tpIn,
             const int mode, const string reason, const bool bypassGap)
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double refPx = (dir == SIG_BUY) ? ask : bid;
   double slDist = (dir == SIG_BUY) ? (refPx - slIn) : (slIn - refPx);
   if(slDist <= 0.0)
     {
      LogSkip("Invalid SL distance");
      return;
     }
   if(!bypassGap && g_risk.m_lastEntryTime > 0 &&
      (long)(TimeCurrent() - g_risk.m_lastEntryTime) < (long)InpMinTradeGapMin * 60)
     {
      LogSkip("Min interval between trades");
      return;
     }
   string sizeErr = "";
   double lot = g_risk.CalcLots(slDist, sizeErr);
   if(lot <= 0.0)
     {
      LogSkip("Sizing failed: " + sizeErr);
      return;
     }
   if(!g_risk.MarginSafe(lot, dir == SIG_BUY))
     {
      LogSkip("Insufficient free margin");
      return;
     }
   string cmt = InpComment + "|" + IntegerToString(mode);
   if(StringLen(cmt) > 31)
      cmt = StringSubstr(cmt, 0, 31);
   uint retcode = 0;
   double openPx = 0.0;
   bool ok = g_tm.OpenPosition(dir, lot, slIn, tpIn, cmt, mode, retcode, openPx);
   if(ok)
     {
      g_risk.m_lastEntryTime = TimeCurrent();
      g_lastEntryStrat = (mode == MODE_NEWS) ? STRAT_TREND : STRAT_PULLBACK;
      g_lastEntryDir = dir;
      g_lastEntryBarTime = g_mkt.st.barTime;
      g_lastActionLine = StringFormat("OPEN %s mode=%s lots=%.2f",
                                      DirText(dir), ModeText((ENUM_MODE)mode), lot);
      g_lastSignalLine = StringFormat("%s -> EXECUTED lots=%.2f", DirText(dir), lot);
      LogRow("OPEN", DirText(dir), ModeText((ENUM_MODE)mode),
             ConditionText(g_mkt.st.condition), reason,
             StringFormat("sl=%.2f tp=%.2f lots=%.2f", slIn, tpIn, lot));
      Print("XGE TRADE: ", g_lastActionLine, " | ", reason);
     }
   else
     {
      ExecutionGuard(retcode);
      LogSkip(StringFormat("Order failed retcode=%d", retcode));
     }
   g_statsDirty = true;
  }

void ExecutionGuard(const uint retcode)
  {
   if(retcode == TRADE_RETCODE_REQUOTE || retcode == TRADE_RETCODE_PRICE_CHANGED ||
      retcode == TRADE_RETCODE_OFF_QUOTES || retcode == TRADE_RETCODE_TIMEOUT ||
      retcode == TRADE_RETCODE_CONNECTION)
     {
      g_execPauseUntil = TimeCurrent() + 120;
      Print("XGE: execution problem retcode=", retcode, " - paused 2 min");
     }
  }

bool HasOppositePosition(const ENUM_SIGNAL_DIR dir)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong tk = PositionGetTicket(i);
      if(tk == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      long ptype = PositionGetInteger(POSITION_TYPE);
      if(dir == SIG_BUY && ptype == POSITION_TYPE_SELL)
         return(true);
      if(dir == SIG_SELL && ptype == POSITION_TYPE_BUY)
         return(true);
     }
   return(false);
  }

//=== News window detection ==========================================
string TrimSpaces(const string s)
  {
   int b = 0, e = StringLen(s);
   while(b < e && StringGetCharacter(s, b) == ' ')
      b++;
   while(e > b && StringGetCharacter(s, e - 1) == ' ')
      e--;
   if(e <= b)
      return("");
   return(StringSubstr(s, b, e - b));
  }

//--- key of the active news window (event time), 0 = no window
datetime NewsWindowKey(const datetime now)
  {
   if(!InpUseNewsTimes)
      return(0);
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime day0 = StructToTime(dt);
   string parts[];
   int n = StringSplit(InpNewsHours, ',', parts);
   for(int i = 0; i < n; i++)
     {
      string hm = TrimSpaces(parts[i]);
      if(StringLen(hm) < 4)
         continue;
      string hp[];
      if(StringSplit(hm, ':', hp) < 2)
         continue;
      int hh = (int)StringToInteger(hp[0]);
      int mm = (int)StringToInteger(hp[1]);
      if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
         continue;
      datetime evT = day0 + (long)hh * 3600 + (long)mm * 60;
      long diffSec = (long)(now - evT);
      if(diffSec >= -(long)InpNewsBeforeMin * 60 && diffSec <= (long)InpNewsAfterMin * 60)
         return(evT);
     }
   if(MQLInfoInteger(MQL_TESTER) == 0)
     {
      datetime from = now - (long)InpNewsBeforeMin * 60;
      datetime to = now + (long)InpNewsAfterMin * 60;
      CalendarValue values[];
      int cnt = CalendarValueHistory(values, from, to, NULL, "USD");
      for(int i = 0; i < cnt; i++)
        {
         MqlCalendarEvent ev;
         if(CalendarEventById(values[i].event_id, ev) <= 0)
            continue;
         if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
            return((datetime)values[i].time);
        }
     }
   return(0);
  }

void WeekendAndFridayControl(void)
  {
   if(InpFridayCloseHour <= 0)
      return;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= InpFridayCloseHour &&
      g_fridayClosedDay != dt.day_of_year)
     {
      if(g_risk.OpenPositions() > 0)
        {
         string msg = "";
         if(g_tm.CloseAll(msg))
           {
            g_fridayClosedDay = dt.day_of_year;
            Print("XGE: closed all positions before weekend");
            LogRow("CLOSE_ALL", "weekend-protection", "", "", "", msg);
           }
        }
      else
         g_fridayClosedDay = dt.day_of_year;
     }
   if(g_risk.m_ddHalt && g_risk.m_closeAllOnMaxDD && !g_risk.m_ddFlattened)
     {
      if(g_risk.OpenPositions() > 0)
        {
         string msg = "";
         if(g_tm.CloseAll(msg))
           {
            g_risk.m_ddFlattened = true;
            Print("XGE: EMERGENCY FLATTEN at max drawdown");
           }
        }
      else
         g_risk.m_ddFlattened = true;
     }
  }

//=== Logging ========================================================
void OpenLog(void)
  {
   string fn = StringFormat("XGE_Logs\\XGE_%s.csv",
                            TimeToString(TimeCurrent(), TIME_DATE));
   StringReplace(fn, ".", "-");
   g_log = FileOpen(fn, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(g_log == INVALID_HANDLE)
     {
      Print("XGE: cannot open log file ", fn);
      return;
     }
   if(FileSize(g_log) == 0)
      FileWrite(g_log, "time", "action", "direction", "strategy", "condition", "details");
   FileSeek(g_log, 0, SEEK_END);
  }

void LogRow(const string action, const string dir, const string strat,
            const string cond, const string details, const string extra)
  {
   if(g_log == INVALID_HANDLE)
      return;
   FileWrite(g_log,
             TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
             Sanitize(action), Sanitize(dir), Sanitize(strat), Sanitize(cond),
             Sanitize(details) + (extra != "" ? " | " + Sanitize(extra) : ""));
  }

void LogSkip(const string reason)
  {
   if(reason == g_lastSkipReason && TimeCurrent() - g_lastSkipLogTime < 600)
      return;
   g_lastSkipReason = reason;
   g_lastSkipLogTime = TimeCurrent();
   string cond = g_ready ? ConditionText(g_mkt.st.condition) : "N/A";
   LogRow("SKIP", "-", "-", cond, reason, "");
  }

//=== Dashboard ======================================================
void UpdateDashboard(void)
  {
   if(!g_dash.m_enabled)
      return;
   const SMarketState st = g_mkt.st;
   string lines[];
   color  clrs[];
   ArrayResize(lines, 24);
   ArrayResize(clrs, 24);
   int n = 0;

   string statusTxt = "ACTIVE";
   color  statusClr = clrLime;
   if(g_risk.m_ddHalt)        { statusTxt = "HALTED: MAX DRAWDOWN"; statusClr = clrRed; }
   else if(g_risk.m_dailyHalt){ statusTxt = "HALTED: DAILY LOSS"; statusClr = clrRed; }
   else if(g_risk.m_weeklyHalt){ statusTxt = "HALTED: WEEKLY LOSS"; statusClr = clrRed; }
   else if(g_risk.m_ddReduced){ statusTxt = "REDUCED RISK: RECOVERING"; statusClr = clrGold; }
   else if(TimeCurrent() < g_risk.m_cooldownUntil) { statusTxt = "COOLDOWN"; statusClr = clrOrange; }
   else if(!g_ready)          { statusTxt = "WAITING FOR DATA"; statusClr = clrYellow; }
   else if(g_mode == MODE_NOVOL) { statusTxt = "NO TRADE: LOW VOL"; statusClr = clrYellow; }

   lines[n] = XGE_NAME + "  v" + XGE_VERSION;                 clrs[n] = clrWhite; n++;
   lines[n] = "EA Status     : " + statusTxt;                 clrs[n] = statusClr; n++;
   lines[n] = "Mode          : " + ModeText(g_mode);          clrs[n] = clrDeepSkyBlue; n++;
   lines[n] = StringFormat("Trend         : HTF %s | Entry %s", TrendText(st.htfTrend), TrendText(st.ltfTrend));
   clrs[n] = clrWhiteSmoke; n++;
   string hhll = "";
   if(st.flagHH) hhll += "HH ";
   if(st.flagHL) hhll += "HL ";
   if(st.flagLH) hhll += "LH ";
   if(st.flagLL) hhll += "LL ";
   lines[n] = "Structure     : " + StructureText(st.structure) + " " + hhll;
   clrs[n] = clrWhiteSmoke; n++;
   lines[n] = StringFormat("Volatility    : %s (ATR %.2f, ratio %.2f)", VolText(st.vol),
                           st.atrL, st.volRatio);
   clrs[n] = (st.vol == VOL_LOW ? clrYellow : clrLime); n++;
   if(st.rangeValid)
     {
      lines[n] = StringFormat("Range         : %.2f - %.2f (pos %.2f)", st.rangeLow, st.rangeHigh, st.rangePos);
      clrs[n] = clrWhiteSmoke; n++;
     }
   datetime wkey = NewsWindowKey(TimeCurrent());
   lines[n] = "News          : " + (wkey != 0 ?
              "WINDOW ACTIVE since " + TimeToString(wkey, TIME_MINUTES) +
              StringFormat(" (reversals %d/%d)", g_newsReversals, g_effNewsMaxRev) : "no window");
   clrs[n] = (wkey != 0 ? clrOrange : clrWhiteSmoke); n++;
   lines[n] = "Signal        : " + g_lastSignalLine;          clrs[n] = clrGold; n++;
   string bias = "NEUTRAL";
   color biasClr = clrDimGray;
   if(st.htfTrend == TREND_UP && st.ltfTrend != TREND_DOWN) { bias = "BULLISH"; biasClr = clrLime; }
   else if(st.htfTrend == TREND_DOWN && st.ltfTrend != TREND_UP) { bias = "BEARISH"; biasClr = clrTomato; }
   lines[n] = "Buy/Sell Bias : " + bias;                      clrs[n] = biasClr; n++;
   int posCnt = g_risk.OpenPositions();
   lines[n] = StringFormat("Trade Status  : %d position(s), floating %+.2f", posCnt, g_risk.FloatingPL());
   clrs[n] = (g_risk.FloatingPL() >= 0.0) ? clrLime : clrTomato; n++;
   lines[n] = StringFormat("Risk/Trade    : %.2f%%", InpRiskPercent);
   clrs[n] = clrWhiteSmoke; n++;
   lines[n] = StringFormat("Daily P/L     : %+.2f", g_risk.DailyPL());
   clrs[n] = (g_risk.DailyPL() >= 0.0) ? clrLime : clrTomato; n++;
   lines[n] = StringFormat("Drawdown      : %.2f%% (limit %.1f%%)", g_risk.DrawdownPct(), InpMaxDrawdownPct);
   clrs[n] = (g_risk.DrawdownPct() > InpMaxDrawdownPct * 0.6) ? clrOrange : clrWhiteSmoke; n++;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spreadPts = (point > 0.0) ?
      (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point : 0.0;
   lines[n] = StringFormat("Spread        : %.0f pts (max %.0f)", spreadPts, InpMaxSpreadPts);
   clrs[n] = (spreadPts > InpMaxSpreadPts) ? clrTomato : clrWhiteSmoke; n++;
   lines[n] = "Last Action   : " + g_lastActionLine;          clrs[n] = clrAqua; n++;

   g_dash.Update(lines, clrs, n);
  }
//+------------------------------------------------------------------+
