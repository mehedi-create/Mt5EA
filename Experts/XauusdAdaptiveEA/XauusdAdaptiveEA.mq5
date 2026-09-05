//+------------------------------------------------------------------+
//|                                            XauusdAdaptiveEA.mq5 |
//|                 XAUUSD Adaptive Pro EA - main module             |
//|                                                                  |
//| Design principle:                                                |
//|   GOOD MARKET      -> TRADE                                      |
//|   BAD MARKET       -> NO TRADE                                   |
//|   UNCERTAIN MARKET -> WAIT                                       |
//|   DANGEROUS MARKET -> PROTECT CAPITAL                            |
//|                                                                  |
//| "Every market movement is NOT a trading opportunity."            |
//|                                                                  |
//| Not a holy grail: losses and drawdowns are a normal part of      |
//| trading. The EA focuses on selective high-quality setups and     |
//| strict capital protection.                                       |
//+------------------------------------------------------------------+
#property copyright   "XGE Project"
#property link        ""
#property version     "1.00"
#property description "Adaptive multi-strategy EA for XAUUSD (Gold)."
#property description "Classifies market condition, selects matching strategy,"
#property description "trades only high-quality setups, protects capital first."

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
input ENUM_TIMEFRAMES   InpHTF            = PERIOD_H1;    // Higher TF (context)
input ENUM_TIMEFRAMES   InpEntryTF        = PERIOD_M15;   // Entry TF (signals)

//=== Strategies =====================================================
input group "=== Strategies ==="
input bool              InpUseTrend       = true;         // Use Trend-Follow strategy
input bool              InpUsePullback    = true;         // Use Pullback strategy
input bool              InpUseBreakout    = true;         // Use Breakout strategy
input bool              InpUseRetest      = true;         // Use Breakout-Retest strategy
input bool              InpUseRange       = true;         // Use Range strategy
input bool              InpUseReversal    = false;        // Use Reversal strategy (aggressive)
input bool              InpUseSweep       = true;         // Use Liquidity-Sweep strategy
input bool              InpEnforceHTF     = true;         // Block trades against HTF trend
input bool              InpAllowCounter   = false;        // Allow counter-trend setups
input double            InpMinConfidence  = 62.0;         // Minimum confidence 0-100
input double            InpMinRR          = 1.2;          // Minimum risk:reward
input double            InpRRTP           = 1.8;          // Take profit in R multiples
input double            InpRevMinConf     = 70.0;         // Reversal score threshold

//=== Risk ===========================================================
input group "=== Risk ==="
input double            InpRiskPercent    = 1.0;          // Risk % per trade
input double            InpFixedLot       = 0.0;          // Fixed lot (0 = use risk %)
input double            InpMaxLot         = 10.0;         // Absolute lot cap
input double            InpSLATRmin       = 0.8;          // Min SL distance (xATR)
input double            InpSLATRmax       = 4.0;          // Max SL distance (xATR)
input double            InpMaxExtensionATR= 2.0;          // Max chase distance (xATR)

//=== Drawdown Protection ============================================
input group "=== Drawdown Protection ==="
input double            InpMaxDailyLossPct  = 3.0;        // Daily loss limit %
input double            InpMaxWeeklyLossPct = 6.0;        // Weekly loss limit %
input double            InpMaxDrawdownPct   = 15.0;       // Max drawdown % (equity peak)
input int               InpMaxConsecLoss    = 4;          // Consecutive losses -> cooldown
input int               InpCooldownMin      = 180;        // Cooldown minutes
input bool              InpCloseAllOnMaxDD  = false;      // Flatten all at DD limit

//=== Overtrading Protection =========================================
input group "=== Overtrading Protection ==="
input int               InpMaxTradesPerDay  = 6;          // Max new entries per day
input int               InpMinTradeGapMin   = 20;         // Min minutes between entries
input int               InpMaxPositions     = 1;          // Max simultaneous positions
input int               InpSameSetupBars    = 24;         // Block same setup within N bars

//=== Filters: Spread / Session / News ===============================
input group "=== Filters ==="
input double            InpMaxSpreadPts   = 50.0;         // Max spread (points)
input bool              InpUseSessions    = true;         // Use session filter
input bool              InpUseSydney      = false;        // Trade Sydney
input int               InpSydneyStart    = 0;            // Sydney start hour (server)
input int               InpSydneyEnd      = 9;            // Sydney end hour
input bool              InpUseTokyo       = false;        // Trade Tokyo/Asia
input int               InpTokyoStart     = 0;            // Tokyo start hour
input int               InpTokyoEnd       = 9;            // Tokyo end hour
input bool              InpUseLondon      = true;         // Trade London
input int               InpLondonStart    = 8;            // London start hour
input int               InpLondonEnd      = 17;           // London end hour
input bool              InpUseNY          = true;         // Trade New York
input int               InpNYStart        = 13;           // NY start hour
input int               InpNYEnd          = 22;           // NY end hour
input bool              InpUsePause       = false;        // Daily no-trade window
input int               InpPauseStart     = 23;           // Pause start hour
input int               InpPauseEnd       = 1;            // Pause end hour
input int               InpFridayStopHour = 21;           // No new entries Friday after (0=off)
input int               InpFridayCloseHour= 22;           // Close all Friday at (0=off)
input bool              InpUseNews        = true;         // Use news protection
input int               InpNewsBeforeMin  = 30;           // Block N min before news
input int               InpNewsAfterMin   = 30;           // Block N min after news
input string            InpNewsHours      = "13:30,15:00,19:00"; // Fixed news times (HH:MM,...)

//=== Volatility Model ===============================================
input group "=== Volatility Model ==="
input int               InpATRPeriod      = 14;           // ATR period
input int               InpATRAvgBars     = 200;          // ATR baseline bars
input double            InpVolLowRatio    = 0.55;         // Low vol ratio (ATR / baseline)
input double            InpVolHighRatio   = 1.60;         // High vol ratio
input double            InpVolExtremeRatio= 2.50;         // Extreme vol ratio
input double            InpAbnormalBarATR = 6.0;          // Abnormal single bar (xATR)

//=== Trend Model ====================================================
input group "=== Trend Model ==="
input int               InpADXPeriod      = 14;           // ADX period
input int               InpEmaFastH       = 50;           // HTF fast EMA
input int               InpEmaSlowH       = 200;          // HTF slow EMA
input int               InpEmaZoneF       = 20;           // Entry fast EMA
input int               InpEmaZoneM       = 50;           // Entry medium EMA
input int               InpEmaZoneS       = 200;          // Entry slow EMA
input double            InpStrengthStrong = 60.0;         // Strong trend threshold
input double            InpStrengthWeak   = 35.0;         // Weak trend threshold

//=== Structure / Range / Breakout ===================================
input group "=== Structure Range Breakout ==="
input int               InpSwingStrength  = 3;            // Swing strength (bars/side)
input int               InpSwingLookback  = 120;          // Swing scan lookback bars
input int               InpRSIPeriod      = 14;           // RSI period (divergence)
input int               InpRangeLookback  = 90;           // Range window bars
input double            InpRangeMinATR    = 2.5;          // Min range width (xATR)
input double            InpRangeMaxATR    = 12.0;         // Max range width (xATR)
input double            InpADXRangeMax    = 20.0;         // Max ADX for range
input double            InpBOMinATR       = 0.15;         // Breakout close margin (xATR)
input int               InpBOMinTouches   = 2;            // Min boundary touches
input double            InpRangeEdgePct   = 0.25;         // Range edge zone depth

//=== Pullback Model =================================================
input group "=== Pullback Model ==="
input double            InpPBMinATR       = 0.8;          // Min retrace (xATR)
input double            InpPBMaxATR       = 4.0;          // Max retrace (xATR)
input double            InpPBZoneATR      = 1.5;          // EMA zone width (xATR)
input int               InpPBLook         = 24;           // Impulse lookback bars

//=== Trade Management ===============================================
input group "=== Trade Management ==="
input bool              InpUseBE          = true;         // Use break-even
input double            InpBETriggerATR   = 1.0;          // BE trigger (xATR profit)
input double            InpBEOffsetPts    = 20.0;         // BE lock offset (points)
input bool              InpUseTrailing    = true;         // Use ATR trailing stop
input double            InpTrailStartATR  = 1.2;          // Trail start (xATR profit)
input double            InpTrailATR       = 1.5;          // Trail distance (xATR)
input bool              InpUsePartial     = true;         // Use partial profit taking
input double            InpPartialR       = 1.0;          // Partial at R multiple
input double            InpPartialPct     = 50.0;         // Partial close percent
input bool              InpUseSmartExit   = true;         // Smart exit on condition flip

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
bool     g_statsDirty = true;
// anti overtrading: last entry identity
ENUM_STRATEGY g_lastEntryStrat = STRAT_NONE;
ENUM_SIGNAL_DIR g_lastEntryDir = SIG_NONE;
datetime g_lastEntryBarTime = 0;
// friday close-all once flag
int      g_fridayClosedDay = -1;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   // sanity checks
   if(PeriodSeconds(InpHTF) <= PeriodSeconds(InpEntryTF))
     {
      Print("XGE: HTF must be higher than Entry TF. Please fix inputs.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpRiskPercent <= 0.0 && InpFixedLot <= 0.0)
     {
      Print("XGE: Risk percent or fixed lot must be positive.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0 &&
      StringFind(_Symbol, "Gold") < 0)
      Print("XGE warning: this EA is designed for XAUUSD/GOLD. Current symbol: ", _Symbol);

   // configure modules
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
   g_mkt.m_pbMinATR = InpPBMinATR;
   g_mkt.m_pbMaxATR = InpPBMaxATR;
   g_mkt.m_pbZoneATR = InpPBZoneATR;
   g_mkt.m_pbLook = InpPBLook;

   g_strat.m_useTrend = InpUseTrend;
   g_strat.m_usePullback = InpUsePullback;
   g_strat.m_useBreakout = InpUseBreakout;
   g_strat.m_useRetest = InpUseRetest;
   g_strat.m_useRange = InpUseRange;
   g_strat.m_useReversal = InpUseReversal;
   g_strat.m_useSweep = InpUseSweep;
   g_strat.m_minRR = InpMinRR;
   g_strat.m_rrTP = InpRRTP;
   g_strat.m_slATRmin = InpSLATRmin;
   g_strat.m_slATRmax = InpSLATRmax;
   g_strat.m_extMaxATR = InpMaxExtensionATR;
   g_strat.m_revMinConf = InpRevMinConf;
   g_strat.m_rangeEdgePct = InpRangeEdgePct;
   g_strat.m_boMinTouches = InpBOMinTouches;
   g_strat.m_ltf = InpEntryTF;

   g_risk.m_riskPct = InpRiskPercent;
   g_risk.m_fixedLot = InpFixedLot;
   g_risk.m_maxLot = InpMaxLot;
   g_risk.m_maxDailyLossPct = InpMaxDailyLossPct;
   g_risk.m_maxWeeklyLossPct = InpMaxWeeklyLossPct;
   g_risk.m_maxDDPct = InpMaxDrawdownPct;
   g_risk.m_maxConsecLoss = InpMaxConsecLoss;
   g_risk.m_cooldownMin = InpCooldownMin;
   g_risk.m_maxTradesDay = InpMaxTradesPerDay;
   g_risk.m_minTradeGapMin = InpMinTradeGapMin;
   g_risk.m_maxPositions = InpMaxPositions;
   g_risk.m_closeAllOnMaxDD = InpCloseAllOnMaxDD;
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
   Print("XGE: ", XGE_NAME, " v", XGE_VERSION, " initialized on ", _Symbol,
         " HTF=", EnumToString(InpHTF), " EntryTF=", EnumToString(InpEntryTF),
         " magic=", InpMagic);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Tick: new-bar detection + fast management                        |
//+------------------------------------------------------------------+
void OnTick()
  {
   // manage positions at most once per server second
   datetime now = TimeCurrent();
   if(now != g_lastManageTime)
     {
      g_lastManageTime = now;
      if(g_ready)
        {
         ManageOpenTrades();
         WeekendAndFridayControl();
        }
     }
   // new entry-TF bar => full analysis cycle
   datetime bt = iTime(_Symbol, InpEntryTF, 0);
   if(bt != 0 && bt != g_lastBarTime)
     {
      g_lastBarTime = bt;
      OnNewBar();
     }
  }

//+------------------------------------------------------------------+
//| Timer: dashboard + stats                                         |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Trade transactions -> mark stats dirty                           |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      g_statsDirty = true;
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

   // 1) collect strategy candidates
   SSignal sigs[];
   ArrayResize(sigs, XGE_MAX_SIGNALS);
   int sigCount = g_strat.BuildSignals(st, sigs);

   // 2) direction permissions
   int kept = 0;
   for(int i = 0; i < sigCount; i++)
     {
      if(sigs[i].dir == SIG_BUY && !InpAllowBuy)
         continue;
      if(sigs[i].dir == SIG_SELL && !InpAllowSell)
         continue;
      sigs[kept] = sigs[i];
      kept++;
     }
   sigCount = kept;

   // 3) conflict resolution
   SSignal best;
   best.dir = SIG_NONE;
   best.strat = STRAT_NONE;
   best.conf = 0.0;
   best.sl = 0.0; best.tp = 0.0;
   best.reason = ""; best.key = "";
   bool haveBuy = false, haveSell = false;
   for(int i = 0; i < sigCount; i++)
     {
      if(sigs[i].dir == SIG_BUY) haveBuy = true;
      if(sigs[i].dir == SIG_SELL) haveSell = true;
      if(sigs[i].conf > best.conf)
         best = sigs[i];
     }
   bool conflict = (haveBuy && haveSell);
   if(conflict)
     {
      g_lastSignalLine = "CONFLICTING SIGNALS (BUY vs SELL) - standing aside";
      LogSkip("Conflicting strategy signals");
      UpdateDashboard();
      return;
     }

   if(best.dir == SIG_NONE)
     {
      g_lastSignalLine = StringFormat("no setup | condition=%s", ConditionText(st.condition));
      UpdateDashboard();
      return;
     }

   // 4) protective gates
   string reason = "";
   if(!PassGates(best, st, reason))
     {
      g_lastSignalLine = StringFormat("%s %s conf=%.0f BLOCKED: %s",
                                      DirText(best.dir), StrategyText(best.strat),
                                      best.conf, reason);
      LogSkip(reason);
      UpdateDashboard();
      return;
     }

   // 5) same-setup guard (anti repetition)
   if(best.strat == g_lastEntryStrat && best.dir == g_lastEntryDir && g_lastEntryBarTime > 0)
     {
      int barsSince = iBarShift(_Symbol, InpEntryTF, g_lastEntryBarTime, false);
      if(barsSince >= 0 && barsSince < InpSameSetupBars)
        {
         reason = StringFormat("Same setup repeated within %d bars", InpSameSetupBars);
         g_lastSignalLine = StringFormat("%s %s BLOCKED: %s",
                                         DirText(best.dir), StrategyText(best.strat), reason);
         LogSkip(reason);
         UpdateDashboard();
         return;
        }
     }

   // 6) sizing
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double refPx = (best.dir == SIG_BUY) ? ask : bid;
   double slDist = (best.dir == SIG_BUY) ? (refPx - best.sl) : (best.sl - refPx);
   if(slDist <= 0.0)
     {
      LogSkip("Invalid SL distance at entry");
      UpdateDashboard();
      return;
     }
   string sizeErr = "";
   double lot = g_risk.CalcLots(slDist, sizeErr);
   if(lot <= 0.0 || sizeErr != "")
     {
      g_lastSignalLine = "sizing failed: " + sizeErr;
      LogSkip("Sizing failed: " + sizeErr);
      UpdateDashboard();
      return;
     }
   if(!g_risk.MarginSafe(lot, best.dir == SIG_BUY))
     {
      LogSkip("Insufficient free margin");
      UpdateDashboard();
      return;
     }

   // 7) execute
   string cmt = InpComment + "|" + StrategyCode(best.strat) + "|" +
                IntegerToString((int)MathRound(best.conf));
   if(StringLen(cmt) > 31)
      cmt = StringSubstr(cmt, 0, 31);
   uint retcode = 0;
   double openPx = 0.0;
   bool ok = g_tm.OpenPosition(best.dir, lot, best.sl, best.tp, cmt, retcode, openPx);
   if(ok)
     {
      g_risk.m_lastEntryTime = TimeCurrent();
      g_lastEntryStrat = best.strat;
      g_lastEntryDir = best.dir;
      g_lastEntryBarTime = st.barTime;
      g_lastActionLine = StringFormat("OPEN %s %s lots=%.2f conf=%.0f",
                                      DirText(best.dir), StrategyText(best.strat), lot, best.conf);
      g_lastSignalLine = StringFormat("%s %s conf=%.0f -> EXECUTED lots=%.2f",
                                      DirText(best.dir), StrategyText(best.strat), best.conf, lot);
      LogOpen(st, best, lot);
      Print("XGE TRADE: ", g_lastActionLine, " | condition=", ConditionText(st.condition),
            " | ", best.reason);
     }
   else
     {
      ExecutionGuard(retcode);
      g_lastSignalLine = StringFormat("ORDER FAILED retcode=%d", retcode);
      LogSkip(StringFormat("Order failed retcode=%d", retcode));
     }
   g_statsDirty = true;
   UpdateDashboard();
  }

//+------------------------------------------------------------------+
//| All protective gates; returns true when trade is allowed         |
//+------------------------------------------------------------------+
bool PassGates(const SSignal &sig, const SMarketState &st, string &reason)
  {
   // terminal / account / symbol permission
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
      reason = "Symbol trade mode restricted (close-only?)";
      return(false);
     }
   // execution pause after slippage failures
   if(TimeCurrent() < g_execPauseUntil)
     {
      reason = StringFormat("Execution paused (slippage protection) until %s",
                            TimeToString(g_execPauseUntil, TIME_MINUTES));
      return(false);
     }
   // spread
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spreadPts = (point > 0.0) ?
      (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point : 0.0;
   if(spreadPts > InpMaxSpreadPts)
     {
      reason = StringFormat("High spread %.0f pts > max %.0f", spreadPts, InpMaxSpreadPts);
      return(false);
     }
   // sessions
   if(InpUseSessions)
     {
      string sess = "";
      if(!SessionAllowed(sess))
        {
         reason = "Outside trading session" + (sess != "" ? " (" + sess + ")" : "");
         return(false);
        }
     }
   // friday stop
   MqlDateTime dtnow;
   TimeToStruct(TimeCurrent(), dtnow);
   if(InpFridayStopHour > 0 && dtnow.day_of_week == 5 && dtnow.hour >= InpFridayStopHour)
     {
      reason = "Friday pre-weekend trading stop";
      return(false);
     }
   // news
   string newsWhy = "";
   if(NewsBlocked(newsWhy))
     {
      reason = newsWhy;
      return(false);
     }
   // market condition gates: bad/uncertain/dangerous -> no trade
   switch(st.condition)
     {
      case COND_LOW_VOL:
         reason = "Low volatility market - no trade";
         return(false);
      case COND_EXTREME_VOL:
         reason = "Extreme volatility - protection mode";
         return(false);
      case COND_ABNORMAL:
         reason = "Abnormal market - protection mode";
         return(false);
      case COND_UNCERTAIN:
         reason = "Uncertain market - waiting";
         return(false);
      default:
         break;
     }
   // risk limits
   string riskBlock = g_risk.EntryAllowed();
   if(riskBlock != "")
     {
      reason = riskBlock;
      return(false);
     }
   // opposite position lock
   if(HasOppositePosition(sig.dir))
     {
      reason = "Opposite position already open";
      return(false);
     }
   // higher timeframe alignment
   if(InpEnforceHTF)
     {
      if(sig.dir == SIG_BUY && st.htfTrend == TREND_DOWN &&
         !(sig.strat == STRAT_REVERSAL))
        {
         reason = "HTF trend is DOWN - buy blocked";
         return(false);
        }
      if(sig.dir == SIG_SELL && st.htfTrend == TREND_UP &&
         !(sig.strat == STRAT_REVERSAL))
        {
         reason = "HTF trend is UP - sell blocked";
         return(false);
        }
     }
   // counter-trend structure check
   if(!InpAllowCounter && sig.strat != STRAT_REVERSAL && sig.strat != STRAT_RANGE)
     {
      if(sig.dir == SIG_BUY && st.structure == STRUCT_BEAR)
        {
         reason = "Bearish structure - counter-trend buy blocked";
         return(false);
        }
      if(sig.dir == SIG_SELL && st.structure == STRUCT_BULL)
        {
         reason = "Bullish structure - counter-trend sell blocked";
         return(false);
        }
     }
   // confidence
   if(sig.conf < InpMinConfidence)
     {
      reason = StringFormat("Confidence %.0f below minimum %.0f", sig.conf, InpMinConfidence);
      return(false);
     }
   // risk:reward sanity
   double entry = (sig.dir == SIG_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double risk = (sig.dir == SIG_BUY) ? entry - sig.sl : sig.sl - entry;
   double gain = (sig.dir == SIG_BUY) ? sig.tp - entry : entry - sig.tp;
   if(risk <= 0.0 || gain <= 0.0)
     {
      reason = "Invalid SL/TP geometry";
      return(false);
     }
   if(gain / risk < InpMinRR)
     {
      reason = StringFormat("Poor risk/reward %.2f < %.2f", gain / risk, InpMinRR);
      return(false);
     }
   reason = "";
   return(true);
  }

//+------------------------------------------------------------------+
//| Slippage / execution failure protection                          |
//+------------------------------------------------------------------+
void ExecutionGuard(const uint retcode)
  {
   if(retcode == TRADE_RETCODE_REQUOTE || retcode == TRADE_RETCODE_PRICE_CHANGED ||
      retcode == TRADE_RETCODE_OFF_QUOTES || retcode == TRADE_RETCODE_TIMEOUT ||
      retcode == TRADE_RETCODE_CONNECTION)
     {
      g_execPauseUntil = TimeCurrent() + 120;
      Print("XGE: execution problem retcode=", retcode,
            " - new entries paused for 2 minutes");
     }
  }

//+------------------------------------------------------------------+
//| Any EA position in the opposite direction?                       |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Session filter (server time)                                     |
//+------------------------------------------------------------------+
bool InHourWindow(const int h, const int start, const int end)
  {
   if(start == end)
      return(false);
   if(start < end)
      return(h >= start && h < end);
   return(h >= start || h < end);   // wrap-around window
  }

bool SessionAllowed(string &activeName)
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   activeName = "";
   // daily pause window has priority
   if(InpUsePause && InHourWindow(h, InpPauseStart, InpPauseEnd))
     {
      activeName = "daily pause";
      return(false);
     }
   if(InpUseSydney && InHourWindow(h, InpSydneyStart, InpSydneyEnd))
      activeName += (activeName == "" ? "" : "+") + "SYDNEY";
   if(InpUseTokyo && InHourWindow(h, InpTokyoStart, InpTokyoEnd))
      activeName += (activeName == "" ? "" : "+") + "TOKYO";
   if(InpUseLondon && InHourWindow(h, InpLondonStart, InpLondonEnd))
      activeName += (activeName == "" ? "" : "+") + "LONDON";
   if(InpUseNY && InHourWindow(h, InpNYStart, InpNYEnd))
      activeName += (activeName == "" ? "" : "+") + "NEW YORK";
   return(activeName != "");
  }

//+------------------------------------------------------------------+
//| News protection: fixed windows + economic calendar (live)        |
//| Result cached for 30 seconds to keep the hot path light.         |
//+------------------------------------------------------------------+
bool NewsBlocked(string &why)
  {
   if(!InpUseNews)
      return(false);
   static datetime s_lastCheck = 0;
   static bool     s_lastResult = false;
   static string   s_lastWhy = "";
   datetime now = TimeCurrent();
   if(s_lastCheck != 0 && (long)(now - s_lastCheck) < 30)
     {
      why = s_lastWhy;
      return(s_lastResult);
     }
   bool res = ComputeNewsBlock(now, why);
   s_lastCheck = now;
   s_lastResult = res;
   s_lastWhy = why;
   return(res);
  }

//--- trim spaces without relying on StringTrim* return-type quirks
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

bool ComputeNewsBlock(const datetime now, string &why)
  {
   MqlDateTime dt;
   TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime day0 = StructToTime(dt);

   // 1) fixed daily news windows (backtest friendly)
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
        {
         why = StringFormat("News protection: scheduled event %s (window)", hm);
         return(true);
        }
     }
   // 2) live economic calendar (high-impact USD events)
   if(MQLInfoInteger(MQL_TESTER) == 0)
     {
      datetime from = now - (long)InpNewsBeforeMin * 60;
      datetime to = now + (long)InpNewsAfterMin * 60;
      CalendarValue values[];
      int cnt = CalendarValueHistory(values, from, to, NULL, "USD");
      if(cnt > 0)
        {
         for(int i = 0; i < cnt; i++)
           {
            MqlCalendarEvent ev;
            if(CalendarEventById(values[i].event_id, ev) <= 0)
               continue;
            if(ev.importance == CALENDAR_IMPORTANCE_HIGH)
              {
               why = StringFormat("News protection: high-impact USD event at %s",
                                  TimeToString((datetime)values[i].time, TIME_MINUTES));
               return(true);
              }
           }
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Friday close-all + weekend safety                                |
//+------------------------------------------------------------------+
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
   // emergency flatten at max drawdown
   if(g_risk.m_ddHalt && g_risk.m_closeAllOnMaxDD && !g_risk.m_ddFlattened)
     {
      if(g_risk.OpenPositions() > 0)
        {
         string msg = "";
         if(g_tm.CloseAll(msg))
           {
            g_risk.m_ddFlattened = true;
            Print("XGE: EMERGENCY FLATTEN at max drawdown");
            LogRow("CLOSE_ALL", "max-drawdown-protection", "", "", "", msg);
           }
        }
      else
         g_risk.m_ddFlattened = true;
     }
  }

//+------------------------------------------------------------------+
//| Position management pass                                         |
//+------------------------------------------------------------------+
void ManageOpenTrades(void)
  {
   const SMarketState st = g_mkt.st;
   bool tighten = (st.vol == VOL_EXTREME || st.vol == VOL_ABNORMAL);
   g_tm.ManagePositions(st,
                        InpUseBE, InpBETriggerATR, InpBEOffsetPts,
                        InpUseTrailing, InpTrailStartATR, InpTrailATR,
                        InpUsePartial, InpPartialR, InpPartialPct,
                        InpUseSmartExit, tighten);
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

void LogOpen(const SMarketState &st, const SSignal &sig, const double lot)
  {
   string details = StringFormat("conf=%.0f lot=%.2f sl=%.2f tp=%.2f | %s | cond=%s struct=%s vol=%s htf=%s",
                                 sig.conf, lot, sig.sl, sig.tp, sig.reason,
                                 ConditionText(st.condition), StructureText(st.structure),
                                 VolText(st.vol), TrendText(st.htfTrend));
   LogRow("OPEN", DirText(sig.dir), StrategyText(sig.strat), ConditionText(st.condition),
          details, "");
  }

void LogSkip(const string reason)
  {
   // throttle identical skip messages
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
   if(g_risk.m_ddHalt)      { statusTxt = "HALTED: MAX DRAWDOWN"; statusClr = clrRed; }
   else if(g_risk.m_dailyHalt){ statusTxt = "HALTED: DAILY LOSS LIMIT"; statusClr = clrRed; }
   else if(g_risk.m_weeklyHalt){ statusTxt = "HALTED: WEEKLY LOSS LIMIT"; statusClr = clrRed; }
   else if(TimeCurrent() < g_risk.m_cooldownUntil) { statusTxt = "COOLDOWN"; statusClr = clrOrange; }
   else if(!g_ready)        { statusTxt = "WAITING FOR DATA"; statusClr = clrYellow; }
   else if(st.condition == COND_UNCERTAIN || st.condition == COND_LOW_VOL)
     { statusTxt = "STANDING ASIDE"; statusClr = clrYellow; }

   lines[n] = XGE_NAME + "  v" + XGE_VERSION;            clrs[n] = clrWhite; n++;
   lines[n] = "EA Status     : " + statusTxt + (g_statusExtra != "" ? " (" + g_statusExtra + ")" : "");
   clrs[n] = statusClr; n++;
   lines[n] = StringFormat("Condition     : %s (age %d bars)", ConditionText(st.condition), st.condAge);
   clrs[n] = clrDeepSkyBlue; n++;
   if(g_mkt.m_transition != "")
     {
      lines[n] = "Transition    : " + g_mkt.m_transition;
      clrs[n] = clrDimGray; n++;
     }
   lines[n] = StringFormat("Trend         : HTF %s | Entry %s", TrendText(st.htfTrend), TrendText(st.ltfTrend));
   clrs[n] = clrWhiteSmoke; n++;
   lines[n] = StringFormat("Trend Strength: %.0f / 100%s", st.trendStrength,
                           st.trendStrength >= InpStrengthStrong ? " (STRONG)" :
                           (st.trendStrength >= InpStrengthWeak ? " (WEAK)" : ""));
   clrs[n] = clrWhiteSmoke; n++;
   string hhll = "";
   if(st.flagHH) hhll += "HH ";
   if(st.flagHL) hhll += "HL ";
   if(st.flagLH) hhll += "LH ";
   if(st.flagLL) hhll += "LL ";
   string bos = "";
   if(st.bullBOS && st.bullBOSBar <= 5) bos = StringFormat(" | BOS-UP %db", st.bullBOSBar);
   if(st.bearBOS && st.bearBOSBar <= 5) bos = StringFormat(" | BOS-DN %db", st.bearBOSBar);
   lines[n] = "Structure     : " + StructureText(st.structure) + " " + hhll + bos;
   clrs[n] = clrWhiteSmoke; n++;
   lines[n] = StringFormat("Volatility    : %s (ATR %.2f, ratio %.2f)", VolText(st.vol),
                           st.atrL, st.volRatio);
   clrs[n] = (st.vol == VOL_NORMAL ? clrLime : (st.vol == VOL_LOW ? clrYellow : clrOrangeRed));
   n++;
   if(st.rangeValid)
     {
      lines[n] = StringFormat("Range         : %.2f - %.2f (pos %.2f)", st.rangeLow, st.rangeHigh, st.rangePos);
      clrs[n] = clrWhiteSmoke; n++;
     }
   lines[n] = "Signal        : " + g_lastSignalLine;
   clrs[n] = clrGold; n++;
   string bias = "NEUTRAL";
   color biasClr = clrDimGray;
   if(st.htfTrend == TREND_UP && st.ltfTrend != TREND_DOWN) { bias = "BULLISH"; biasClr = clrLime; }
   else if(st.htfTrend == TREND_DOWN && st.ltfTrend != TREND_UP) { bias = "BEARISH"; biasClr = clrTomato; }
   lines[n] = "Buy/Sell Bias : " + bias;                       clrs[n] = biasClr; n++;
   int posCnt = g_risk.OpenPositions();
   lines[n] = StringFormat("Trade Status  : %d position(s), floating %+.2f", posCnt, g_risk.FloatingPL());
   clrs[n] = (g_risk.FloatingPL() >= 0.0) ? clrLime : clrTomato; n++;
   string riskTxt;
   if(InpFixedLot > 0.0)
      riskTxt = StringFormat("Fixed lot %.2f", InpFixedLot);
   else
     {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      riskTxt = StringFormat("%.2f%% (~%.2f %s)", InpRiskPercent,
                             bal * InpRiskPercent / 100.0, AccountInfoString(ACCOUNT_CURRENCY));
     }
   lines[n] = "Risk/Trade    : " + riskTxt;                     clrs[n] = clrWhiteSmoke; n++;
   lines[n] = StringFormat("Daily P/L     : %+.2f (%.2f%%)", g_risk.DailyPL(),
                           g_risk.m_dayStartBalance > 0 ? g_risk.DailyPL() / g_risk.m_dayStartBalance * 100.0 : 0.0);
   clrs[n] = (g_risk.DailyPL() >= 0.0) ? clrLime : clrTomato; n++;
   lines[n] = StringFormat("Drawdown      : %.2f%% (limit %.1f%%)", g_risk.DrawdownPct(), InpMaxDrawdownPct);
   clrs[n] = (g_risk.DrawdownPct() > InpMaxDrawdownPct * 0.6) ? clrOrange : clrWhiteSmoke; n++;
   string sess = "";
   SessionAllowed(sess);
   lines[n] = "Session       : " + (sess == "" ? "CLOSED" : sess);
   clrs[n] = (sess == "" ? clrTomato : clrWhiteSmoke); n++;
   string newsWhy = "";
   bool newsNow = NewsBlocked(newsWhy);
   lines[n] = "News          : " + (newsNow ? "BLOCKED - " + newsWhy : "CLEAR");
   clrs[n] = newsNow ? clrOrange : clrWhiteSmoke; n++;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spreadPts = (point > 0.0) ?
      (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / point : 0.0;
   lines[n] = StringFormat("Spread        : %.0f pts (max %.0f)", spreadPts, InpMaxSpreadPts);
   clrs[n] = (spreadPts > InpMaxSpreadPts) ? clrTomato : clrWhiteSmoke; n++;
   lines[n] = "Last Action   : " + g_lastActionLine;
   clrs[n] = clrAqua; n++;

   g_dash.Update(lines, clrs, n);
  }
//+------------------------------------------------------------------+
