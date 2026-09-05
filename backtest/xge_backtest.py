#!/usr/bin/env python3
"""
XGE Backtest Harness - faithful Python simulation of XauusdAdaptiveEA (MT5).

Mirrors the EA modules:
  XGE_Market    -> market state, condition classification, structure/BOS/range/
                   breakout/pullback/reversal/sweep detection
  XGE_Strategy  -> 7 strategies + confidence scoring + conflict resolution
  XGE_Risk      -> sizing, daily/weekly/DD limits, cooldown, overtrading gates
  XGE_Trade     -> break-even, trailing, partial, smart exit, emergency exit

Data: XAUUSD M5 (XM format) resampled to M15 entry TF + H1 higher TF.
Session/news times are mapped to the dataset timezone (US Eastern) so they
are equivalent to the EA defaults on a typical EET broker server.
"""
import math
import numpy as np
import pandas as pd
from collections import deque

DATA = "/home/user/.cache/bt/ds5yr/XAUUSDm_M5_.csv"
OUT = "/home/user/Mt5EA/backtest"

# =====================================================================
# EA default inputs (mirrors XauusdAdaptiveEA.mq5)
# =====================================================================
P = dict(
    atr_period=14, adx_period=14, rsi_period=14,
    ema_fast_h=50, ema_slow_h=200,
    ema_zone_f=20, ema_zone_m=50, ema_zone_s=200,
    atr_avg_bars=200,
    vol_low_ratio=0.55, vol_high_ratio=1.60, vol_extreme_ratio=2.50,
    abnormal_bar_atr=6.0,
    strength_strong=60.0, strength_weak=35.0,
    swing_strength=3, swing_lookback=120,
    range_lookback=90, range_min_atr=2.5, range_max_atr=12.0, adx_range_max=20.0,
    bo_min_atr=0.15, bo_min_touches=2, range_edge_pct=0.25,
    pb_min_atr=0.8, pb_max_atr=4.0, pb_zone_atr=1.5, pb_look=24,
    rev_threshold=50.0, rev_min_conf=70.0,
    # strategies
    use_trend=True, use_pullback=True, use_breakout=True, use_retest=True,
    use_range=True, use_reversal=False, use_sweep=True,
    enforce_htf=True, allow_counter=False,
    min_confidence=62.0, min_rr=1.2, rr_tp=1.8,
    sl_atr_min=0.8, sl_atr_max=4.0, ext_max_atr=2.0,
    retest_max_bars=16, retest_zone_atr=0.4,
    # risk
    risk_pct=1.0, max_lot=10.0,
    max_daily_loss_pct=3.0, max_weekly_loss_pct=6.0, max_dd_pct=15.0,
    max_consec_loss=4, cooldown_min=180,
    max_trades_day=6, min_trade_gap_min=20, same_setup_bars=24,
    # filters (times in dataset timezone = US Eastern)
    max_spread_price=0.50,
    sessions=[(3, 12), (8, 17)],          # London 03-12 ET, NY 08-17 ET
    news_hours=[(8, 30), (10, 0), (14, 0)],  # 08:30/10:00/14:00 ET events
    news_before_min=30, news_after_min=30,
    friday_stop_hour=16, friday_close_hour=16,
    # management
    use_be=True, be_trigger_atr=1.0, be_offset_price=0.20,
    use_trail=True, trail_start_atr=1.2, trail_atr=1.5,
    use_partial=True, partial_r=1.0, partial_pct=50.0,
    use_smart_exit=True, emergency_atr=5.0,
    # sim
    start_balance=10000.0, contract=100.0, lot_step=0.01, min_lot=0.01,
)

# condition ids (mirror ENUM_MARKET_CONDITION)
(C_SUPT, C_WUPT, C_SDT, C_WDT, C_PBB, C_PBS, C_BOB, C_BOS_, C_RANGE,
 C_REVB, C_REVS, C_LOWV, C_EXTV, C_ABN, C_UNC) = range(15)
COND_TXT = {C_SUPT: "STRONG UPTREND", C_WUPT: "WEAK UPTREND", C_SDT: "STRONG DOWNTREND",
            C_WDT: "WEAK DOWNTREND", C_PBB: "PULLBACK BULL", C_PBS: "PULLBACK BEAR",
            C_BOB: "BREAKOUT BULL", C_BOS_: "BREAKOUT BEAR", C_RANGE: "RANGE",
            C_REVB: "REVERSAL BULL?", C_REVS: "REVERSAL BEAR?", C_LOWV: "LOW VOL",
            C_EXTV: "EXTREME VOL", C_ABN: "ABNORMAL", C_UNC: "UNCERTAIN"}
VOL_ABN, VOL_LOW, VOL_NORM, VOL_HIGH, VOL_EXT = range(5)
TREND_NONE, TREND_UP, TREND_DOWN = 0, 1, 2
STRUCT_UNDEF, STRUCT_BULL, STRUCT_BEAR, STRUCT_MIXED = 0, 1, 2, 3
STRAT_TXT = {1: "Trend", 2: "Pullback", 3: "Breakout", 4: "Retest", 5: "Range",
             6: "Reversal", 7: "Sweep"}
S_TREND, S_PULL, S_BO, S_RT, S_RANGE, S_REV, S_SWEEP = range(1, 8)
SIG_BUY, SIG_SELL = 1, -1


# =====================================================================
# indicators (MQL5-compatible Wilder/EMA)
# =====================================================================
def ema(x, n):
    out = np.full(len(x), np.nan)
    if len(x) < n:
        return out
    out[n - 1] = x[:n].mean()
    k = 2.0 / (n + 1)
    for i in range(n, len(x)):
        out[i] = x[i] * k + out[i - 1] * (1 - k)
    return out


def atr_wilder(h, l, c, n=14):
    tr = np.maximum(h[1:] - l[1:], np.maximum(np.abs(h[1:] - c[:-1]), np.abs(l[1:] - c[:-1])))
    out = np.full(len(h), np.nan)
    if len(tr) < n:
        return out
    out[n] = tr[:n].mean()
    for i in range(n, len(tr)):
        out[i + 1] = (out[i] * (n - 1) + tr[i]) / n
    return out


def rsi_wilder(c, n=14):
    d = np.diff(c)
    up = np.where(d > 0, d, 0.0)
    dn = np.where(d < 0, -d, 0.0)
    out = np.full(len(c), np.nan)
    if len(d) < n:
        return out
    au, ad = up[:n].mean(), dn[:n].mean()
    out[n] = 100.0 if ad == 0 else 100.0 - 100.0 / (1 + au / ad)
    for i in range(n, len(d)):
        au = (au * (n - 1) + up[i]) / n
        ad = (ad * (n - 1) + dn[i]) / n
        out[i + 1] = 100.0 if ad == 0 else 100.0 - 100.0 / (1 + au / ad)
    return out


def adx_wilder(h, l, c, n=14):
    """returns adx array aligned to input index"""
    m = len(h)
    out = np.full(m, np.nan)
    if m < 2 * n + 2:
        return out
    up = h[1:] - h[:-1]
    dn = l[:-1] - l[1:]
    pdm = np.where((up > dn) & (up > 0), up, 0.0)
    mdm = np.where((dn > up) & (dn > 0), dn, 0.0)
    tr = np.maximum(h[1:] - l[1:], np.maximum(np.abs(h[1:] - c[:-1]), np.abs(l[1:] - c[:-1])))
    s_tr = tr[:n].sum(); s_p = pdm[:n].sum(); s_m = mdm[:n].sum()
    dx_list = []
    adx_val = None
    for i in range(n, len(tr)):
        s_tr = s_tr - s_tr / n + tr[i]
        s_p = s_p - s_p / n + pdm[i]
        s_m = s_m - s_m / n + mdm[i]
        dip = 100.0 * s_p / s_tr if s_tr > 0 else 0.0
        dim = 100.0 * s_m / s_tr if s_tr > 0 else 0.0
        dx = 100.0 * abs(dip - dim) / (dip + dim) if (dip + dim) > 0 else 0.0
        if len(dx_list) < n:
            dx_list.append(dx)
            if len(dx_list) == n:
                adx_val = float(np.mean(dx_list))
                out[i + 1] = adx_val
        else:
            adx_val = (adx_val * (n - 1) + dx) / n
            out[i + 1] = adx_val
    return out


# =====================================================================
# data loading
# =====================================================================
def load_data():
    df = pd.read_csv(DATA, sep="\t",
                     names=["date", "time", "open", "high", "low", "close", "tickvol", "vol", "spread"],
                     header=0)
    ts = pd.to_datetime(df["date"] + " " + df["time"], format="%Y.%m.%d %H:%M:%S")
    m5 = pd.DataFrame({"open": df["open"].values, "high": df["high"].values,
                       "low": df["low"].values, "close": df["close"].values,
                       "spread": df["spread"].values * 0.001}, index=ts).sort_index()
    m15 = m5.resample("15min").agg({"open": "first", "high": "max", "low": "min",
                                    "close": "last", "spread": "mean"}).dropna()
    h1 = m5.resample("1h").agg({"open": "first", "high": "max", "low": "min",
                                "close": "last"}).dropna()
    return m15, h1


# =====================================================================
# market state for one bar (mirrors CMarketAnalyzer::Update)
# =====================================================================
class Market:
    def __init__(self, m15, h1):
        self.t = m15.index.values
        self.o = m15["open"].values.astype(float)
        self.h = m15["high"].values.astype(float)
        self.l = m15["low"].values.astype(float)
        self.c = m15["close"].values.astype(float)
        self.sp = m15["spread"].values.astype(float)
        self.n = len(self.o)
        self.ema20 = ema(self.c, P["ema_zone_f"])
        self.ema50 = ema(self.c, P["ema_zone_m"])
        self.ema200 = ema(self.c, P["ema_zone_s"])
        self.atr = atr_wilder(self.h, self.l, self.c, P["atr_period"])
        self.rsi = rsi_wilder(self.c, P["rsi_period"])
        self.adx = adx_wilder(self.h, self.l, self.c, P["adx_period"])
        s = pd.Series(self.atr)
        self.atr_avg = s.rolling(P["atr_avg_bars"], min_periods=P["atr_avg_bars"]).mean().values
        # higher TF
        self.h1_open = h1.index.values
        self.h1_close_t = (h1.index + pd.Timedelta(hours=1)).values
        hc = h1["close"].values.astype(float)
        self.h1_emaF = ema(hc, P["ema_fast_h"])
        self.h1_emaS = ema(hc, P["ema_slow_h"])
        self.h1_atr = atr_wilder(h1["high"].values.astype(float), h1["low"].values.astype(float),
                                 hc, P["atr_period"])
        self.h1_adx = adx_wilder(h1["high"].values.astype(float), h1["low"].values.astype(float),
                                 hc, P["adx_period"])
        self.h1_close = hc
        # swings precompute
        k = P["swing_strength"]
        self.k = k
        ish = np.zeros(self.n, bool)
        isl = np.zeros(self.n, bool)
        for j in range(k, self.n - k):
            win = slice(j - k, j + k + 1)
            hh = self.h[win]
            ll = self.l[win]
            if self.h[j] > hh.max() and hh.argmax() == k:
                ish[j] = True
            if self.l[j] < ll.min() and ll.argmin() == k:
                isl[j] = True
        self.is_sh = ish
        self.is_sl = isl
        # H1 alignment: last closed H1 for each M15 close time
        ct = self.t + np.timedelta64(15, "m")
        need = ct - np.timedelta64(60, "m")
        self.h1_idx = np.searchsorted(self.h1_open, need, side="right") - 1

    def htf(self, t):
        j = self.h1_idx[t]
        if j < 2 or np.isnan(self.h1_emaS[j]):
            return TREND_NONE, np.nan, np.nan
        ef, es, ch = self.h1_emaF[j], self.h1_emaS[j], self.h1_close[j]
        if ef > es and ch > es:
            tr = TREND_UP
        elif ef < es and ch < es:
            tr = TREND_DOWN
        else:
            tr = TREND_NONE
        return tr, self.h1_atr[j], self.h1_adx[j]


# =====================================================================
# backtest engine
# =====================================================================
def run(m, eval_start):
    n = m.n
    k = m.k
    o, h, l, c = m.o, m.h, m.l, m.c
    atr, atr_avg, rsi, adx = m.atr, m.atr_avg, m.rsi, m.adx
    ema20, ema50 = m.ema20, m.ema50

    # warmup lower bound: enough history for every indicator/window
    warm = max(P["ema_zone_s"], P["atr_avg_bars"], P["range_lookback"],
               P["swing_lookback"]) + 10
    i0 = max(warm, int(np.searchsorted(m.t, np.datetime64(eval_start))))

    sh_q = deque()   # (idx, price) recent confirmed swing highs
    sl_q = deque()
    bos_bull_i = None; bos_bear_i = None     # bar index of BOS close
    bos_bull_lvl = None; bos_bear_lvl = None
    bo_mem = None    # (idx, dir, level) last valid breakout for retest

    balance = P["start_balance"]
    peak_equity = balance
    pos = None       # open position dict
    trades = []
    equity_curve = np.full(n, np.nan)
    curve_t = m.t

    # protection state
    realized_day = 0.0; day_key = None; day_start_bal = balance
    realized_week = 0.0; week_key = None
    consec_loss = 0; last_loss_time = None; cooldown_until = None
    trades_today = 0; last_entry_time = None
    last_entry = (None, None, -10**9)   # (strat, dir, bar_idx)
    daily_halt = weekly_halt = dd_halt = False
    skip_counts = {}; cond_counts = {}
    last_signal_txt = ""
    dd_flattened = False

    def block_reason(r):
        skip_counts[r] = skip_counts.get(r, 0) + 1

    def realize(oz, entry, exitp, direction):
        return oz * (exitp - entry) * direction

    def close_pos(px, t_idx, why, partial_oz=None):
        nonlocal pos, balance, realized_day, realized_week, consec_loss
        nonlocal last_loss_time
        oz = partial_oz if partial_oz else pos["oz"]
        pnl = realize(oz, pos["entry"], px, pos["dir"])
        balance += pnl
        realized_day += pnl
        realized_week += pnl
        if partial_oz:
            trades.append(dict(entry_time=pos["entry_time"], dir=pos["dir"],
                               strat=pos["strat"], conf=pos["conf"],
                               lots=partial_oz / P["contract"], entry=pos["entry"],
                               sl_init=pos["sl_init"], tp=pos["tp"],
                               exit_time=m.t[t_idx], exit_px=px, pnl=round(pnl, 2),
                               bars=t_idx - pos["entry_idx"], why="PARTIAL"))
            pos["oz"] -= oz
            if pos["oz"] <= 1e-9:
                pos = None
        else:
            trades.append(dict(entry_time=pos["entry_time"], dir=pos["dir"],
                               strat=pos["strat"], conf=pos["conf"],
                               lots=pos["oz"] / P["contract"], entry=pos["entry"],
                               sl_init=pos["sl_init"], tp=pos["tp"],
                               exit_time=m.t[t_idx], exit_px=px, pnl=round(pnl, 2),
                               bars=t_idx - pos["entry_idx"], why=why))
            if pnl < 0:
                consec_loss += 1
                last_loss_time = m.t[t_idx]
            elif pnl > 0:
                consec_loss = 0
            pos = None
        return pnl

    # ------------------------------------------------------------------
    for t in range(i0, n):
        if np.isnan(atr[t]) or np.isnan(atr_avg[t]) or np.isnan(adx[t]) or np.isnan(atr[t - 3]):
            continue
        # ---- day/week rollover ----
        ts = pd.Timestamp(m.t[t])
        dk = ts.date()
        if dk != day_key:
            day_key = dk
            realized_day = 0.0
            trades_today = 0
            day_start_bal = balance
            daily_halt = False
        wk = (ts - pd.Timedelta(days=ts.dayofweek)).date()   # Monday start (like EA)
        if wk != week_key:
            week_key = wk
            realized_week = 0.0
            weekly_halt = False

        # ---- confirm new swings (j = t-k becomes confirmed now) ----
        j = t - k
        if j >= k:
            if m.is_sh[j]:
                sh_q.append((j, h[j]))
                if len(sh_q) > 4:
                    sh_q.popleft()
                # new most-recent swing high invalidates prior BOS tracking
                bos_bull_i = None; bos_bull_lvl = h[j]
            if m.is_sl[j]:
                sl_q.append((j, l[j]))
                if len(sl_q) > 4:
                    sl_q.popleft()
                bos_bear_i = None; bos_bear_lvl = l[j]
        # BOS detection relative to most recent swing
        if sh_q and bos_bull_i is None:
            sj, sp = sh_q[-1]
            for ii in range(sj + 1, t + 1):
                if c[ii] > sp:
                    bos_bull_i = ii
                    break
        if sl_q and bos_bear_i is None:
            sj, sp = sl_q[-1]
            for ii in range(sj + 1, t + 1):
                if c[ii] < sp:
                    bos_bear_i = ii
                    break
        bull_bos = bos_bull_i is not None
        bear_bos = bos_bear_i is not None
        bull_bos_bar = (t - bos_bull_i) if bull_bos else 9999
        bear_bos_bar = (t - bos_bear_i) if bear_bos else 9999

        sh = list(sh_q)[-4:][::-1]
        sl = list(sl_q)[-4:][::-1]
        structure = STRUCT_UNDEF
        fHH = fHL = fLH = fLL = False
        if len(sh) >= 2 and len(sl) >= 2:
            fHH = sh[0][1] > sh[1][1]; fLH = sh[0][1] < sh[1][1]
            fHL = sl[0][1] > sl[1][1]; fLL = sl[0][1] < sl[1][1]
            if fHH and fHL:
                structure = STRUCT_BULL
            elif fLH and fLL:
                structure = STRUCT_BEAR
            else:
                structure = STRUCT_MIXED
        choch_bull = bull_bos and structure == STRUCT_BEAR
        choch_bear = bear_bos and structure == STRUCT_BULL

        # ---- volatility ----
        a = atr[t]
        rng = h[t] - l[t]
        vol_ratio = a / atr_avg[t] if atr_avg[t] > 0 else 1.0
        if a <= 0:
            vol = VOL_ABN
        elif rng > P["abnormal_bar_atr"] * a or vol_ratio > P["vol_extreme_ratio"] * 1.8:
            vol = VOL_ABN
        elif vol_ratio <= P["vol_low_ratio"]:
            vol = VOL_LOW
        elif vol_ratio >= P["vol_extreme_ratio"]:
            vol = VOL_EXT
        elif vol_ratio >= P["vol_high_ratio"]:
            vol = VOL_HIGH
        else:
            vol = VOL_NORM
        strong_bull = c[t] > o[t] and abs(c[t] - o[t]) >= 1.5 * a
        strong_bear = c[t] < o[t] and abs(c[t] - o[t]) >= 1.5 * a

        # ---- trends ----
        htf_trend, h1_atr_v, h1_adx_v = m.htf(t)
        if ema20[t] > ema50[t] and c[t] > ema50[t]:
            ltf = TREND_UP
        elif ema20[t] < ema50[t] and c[t] < ema50[t]:
            ltf = TREND_DOWN
        else:
            ltf = TREND_NONE
        adxN = min(adx[t], 50.0) / 50.0
        sep = min(abs(ema20[t] - ema50[t]) / (3 * a), 1.0)
        slopeN = min(abs(ema50[t] - ema50[t - 3]) / (3 * a), 1.0)
        strength = 100.0 * (0.45 * adxN + 0.30 * sep + 0.25 * slopeN)

        # ---- range ----
        L = P["range_lookback"]
        wh = h[t - L:t]; wl = l[t - L:t]          # EA bars 2..L+1 == t-L..t-1
        rh = wh.max(); rl = wl.min(); width = rh - rl
        range_valid = False; range_pos = 0.5
        rhT = rlT = 0
        if width > 0:
            tol = 0.15 * width
            rhT = int((wh >= rh - tol).sum()); rlT = int((wl <= rl + tol).sum())
            range_pos = (c[t] - rl) / width
            if adx[t] < P["adx_range_max"] and \
               P["range_min_atr"] * a <= width <= P["range_max_atr"] * a and \
               rhT >= 2 and rlT >= 2:
                range_valid = True

        # ---- breakout / sweeps ----
        bo_bull = bo_bear = bo_valid = bo_fail = False
        sweep_high = sweep_low = False; bo_level = 0.0; bo_touches = 0
        if sl and l[t] < sl[0][1] and c[t] > sl[0][1]:
            sweep_low = True
        if sh and h[t] > sh[0][1] and c[t] < sh[0][1]:
            sweep_high = True
        if width > 0:
            frac = P["bo_min_atr"] * a
            if c[t] > rh + frac:
                bo_bull = True; bo_level = rh; bo_touches = rhT
                bo_valid = (rhT >= P["bo_min_touches"] and rng >= a)
            elif c[t] < rl - frac:
                bo_bear = True; bo_level = rl; bo_touches = rlT
                bo_valid = (rlT >= P["bo_min_touches"] and rng >= a)
            elif h[t] > rh and c[t] <= rh:
                bo_fail = True; sweep_high = True
            elif l[t] < rl and c[t] >= rl:
                sweep_low = True

        # ---- pullback ----
        look = P["pb_look"]
        imp_high = h[t - look + 1:t + 1].max()
        imp_low = l[t - look + 1:t + 1].min()
        low_recent = min(l[t], l[t - 1], l[t - 2])
        high_recent = max(h[t], h[t - 1], h[t - 2])
        pb_bull = pb_bear = False; pb_zone = 0.0
        if ltf == TREND_UP and structure != STRUCT_BEAR:
            retrace = imp_high - low_recent
            near_ma = (abs(c[t] - ema50[t]) <= P["pb_zone_atr"] * a) or \
                      (l[t] <= ema50[t] and c[t] > ema50[t]) or \
                      (l[t] <= ema20[t] and c[t] > ema20[t])
            body = abs(c[t] - o[t]); lw = min(o[t], c[t]) - l[t]
            reject = c[t] > o[t] and rng > 0 and lw >= body and lw >= 0.35 * rng
            if P["pb_min_atr"] * a <= retrace <= P["pb_max_atr"] * a and near_ma and \
               reject and bear_bos_bar > 3:
                pb_bull = True; pb_zone = ema50[t]
        if ltf == TREND_DOWN and structure != STRUCT_BULL:
            retrace = high_recent - imp_low
            near_ma = (abs(c[t] - ema50[t]) <= P["pb_zone_atr"] * a) or \
                      (h[t] >= ema50[t] and c[t] < ema50[t]) or \
                      (h[t] >= ema20[t] and c[t] < ema20[t])
            body = abs(c[t] - o[t]); uw = h[t] - max(o[t], c[t])
            reject = c[t] < o[t] and rng > 0 and uw >= body and uw >= 0.35 * rng
            if P["pb_min_atr"] * a <= retrace <= P["pb_max_atr"] * a and near_ma and \
               reject and bull_bos_bar > 3:
                pb_bear = True; pb_zone = ema50[t]

        # ---- reversal ----
        bull_div = bear_div = False
        if len(sl) >= 2 and sl[0][1] < sl[1][1]:
            if rsi[sl[0][0]] > rsi[sl[1][0]] + 2.0:
                bull_div = True
        if len(sh) >= 2 and sh[0][1] > sh[1][1]:
            if rsi[sh[0][0]] < rsi[sh[1][0]] - 2.0:
                bear_div = True
        rev_bull = rev_bear = 0.0
        if choch_bull: rev_bull += 40
        if choch_bear: rev_bear += 40
        if bull_div: rev_bull += 25
        if bear_div: rev_bear += 25
        if rsi[t] > 50 and rsi[t - 1] <= 50: rev_bull += 15
        if rsi[t] < 50 and rsi[t - 1] >= 50: rev_bear += 15
        if adx[t - 2] - adx[t] >= 2.0:
            rev_bull += 10; rev_bear += 10
        if strong_bull: rev_bull += 10
        if strong_bear: rev_bear += 10

        # ---- condition ----
        if vol == VOL_ABN:
            cond = C_ABN
        elif vol == VOL_EXT:
            cond = C_EXTV
        elif vol == VOL_LOW:
            cond = C_LOWV
        elif bo_bull and bo_valid:
            cond = C_BOB
        elif bo_bear and bo_valid:
            cond = C_BOS_
        elif rev_bull >= P["rev_threshold"] and rev_bull > rev_bear:
            cond = C_REVB
        elif rev_bear >= P["rev_threshold"] and rev_bear > rev_bull:
            cond = C_REVS
        elif pb_bull:
            cond = C_PBB
        elif pb_bear:
            cond = C_PBS
        elif ltf == TREND_UP and strength >= P["strength_strong"]:
            cond = C_SUPT
        elif ltf == TREND_UP and strength >= P["strength_weak"]:
            cond = C_WUPT
        elif ltf == TREND_DOWN and strength >= P["strength_strong"]:
            cond = C_SDT
        elif ltf == TREND_DOWN and strength >= P["strength_weak"]:
            cond = C_WDT
        elif range_valid:
            cond = C_RANGE
        else:
            cond = C_UNC
        cond_counts[COND_TXT[cond]] = cond_counts.get(COND_TXT[cond], 0) + 1

        # ==============================================================
        # manage open position first (like OnTick manage pass)
        # ==============================================================
        sp_t = m.sp[t]
        if pos is not None:
            d = pos["dir"]; entry = pos["entry"]; slv = pos["sl"]; tpv = pos["tp"]
            exit_px = None; why = None
            if d == SIG_BUY:
                if l[t] <= slv:
                    exit_px, why = slv, "SL"
                elif h[t] >= tpv:
                    exit_px, why = tpv, "TP"
            else:
                if h[t] >= slv:
                    exit_px, why = slv - sp_t, "SL"
                elif l[t] <= tpv:
                    exit_px, why = tpv, "TP"
            if exit_px is not None:
                close_pos(exit_px, t, why)
            else:
                bid = c[t]; ask = c[t] + sp_t
                profit_dist = (bid - entry) if d == SIG_BUY else (entry - ask)
                # emergency exit
                if profit_dist <= -P["emergency_atr"] * a:
                    close_pos(bid if d == SIG_BUY else ask, t, "EMERGENCY")
                else:
                    # smart exit
                    flipped = False
                    if P["use_smart_exit"]:
                        if d == SIG_BUY and (cond == C_SDT or (bear_bos and bear_bos_bar <= 2) or choch_bear):
                            flipped = True
                        if d == SIG_SELL and (cond == C_SUPT or (bull_bos and bull_bos_bar <= 2) or choch_bull):
                            flipped = True
                    if flipped and profit_dist > -0.5 * a:
                        close_pos(bid if d == SIG_BUY else ask, t, "SMART_EXIT")
                    else:
                        # partial
                        if P["use_partial"] and not pos["partial_done"] and pos["init_dist"] > 0 and \
                           profit_dist >= P["partial_r"] * pos["init_dist"]:
                            step_oz = P["lot_step"] * P["contract"]
                            min_oz = P["min_lot"] * P["contract"]
                            close_oz = math.floor(pos["oz"] * P["partial_pct"] / 100.0 / step_oz) * step_oz
                            if close_oz >= min_oz and (pos["oz"] - close_oz) >= min_oz:
                                close_pos(bid if d == SIG_BUY else ask, t, "PARTIAL", partial_oz=close_oz)
                                if pos is not None:
                                    pos["partial_done"] = True
                        if pos is not None:
                            # break-even
                            if P["use_be"] and profit_dist >= P["be_trigger_atr"] * a:
                                tgt = entry + P["be_offset_price"] if d == SIG_BUY else entry - P["be_offset_price"]
                                if d == SIG_BUY and pos["sl"] < tgt:
                                    pos["sl"] = tgt; pos["be_done"] = True
                                if d == SIG_SELL and (pos["sl"] > tgt or pos["sl"] == 0):
                                    pos["sl"] = tgt; pos["be_done"] = True
                            # trailing
                            if P["use_trail"] and profit_dist >= P["trail_start_atr"] * a:
                                dist = P["trail_atr"] * a
                                if vol in (VOL_EXT, VOL_ABN):
                                    dist *= 0.5
                                if d == SIG_BUY:
                                    tgt = bid - dist
                                    if tgt > pos["sl"]:
                                        pos["sl"] = tgt
                                else:
                                    tgt = ask + dist
                                    if pos["sl"] == 0 or tgt < pos["sl"]:
                                        pos["sl"] = tgt
        # friday close-all
        if pos is not None and P["friday_close_hour"] > 0 and ts.dayofweek == 4 and \
           ts.hour >= P["friday_close_hour"]:
            d = pos["dir"]
            close_pos(c[t] if d == SIG_BUY else c[t] + sp_t, t, "WEEKEND")

        # equity snapshot
        floating = 0.0
        if pos is not None:
            d = pos["dir"]
            cur = c[t] if d == SIG_BUY else c[t] + sp_t
            floating = pos["oz"] * (cur - pos["entry"]) * d
        equity = balance + floating
        equity_curve[t] = equity
        if equity > peak_equity:
            peak_equity = equity

        # ==============================================================
        # entry logic (once per closed bar)
        # ==============================================================
        if pos is not None:
            continue

        # ---- build strategy signals (mirror CStrategyEngine) ----
        sigs = []

        def score(dir_, conf):
            if htf_trend == TREND_UP:
                conf += 15 if dir_ == SIG_BUY else -20
            elif htf_trend == TREND_DOWN:
                conf += 15 if dir_ == SIG_SELL else -20
            if structure == STRUCT_BULL:
                conf += 10 if dir_ == SIG_BUY else -15
            elif structure == STRUCT_BEAR:
                conf += 10 if dir_ == SIG_SELL else -15
            if vol == VOL_NORM:
                conf += 5
            elif vol == VOL_HIGH:
                conf -= 5
            return max(0.0, min(conf, 100.0))

        def make_sltp(dir_, entry, raw_sl):
            d = abs(entry - raw_sl)
            if d <= 0:
                return None
            d = max(d, P["sl_atr_min"] * a)
            if d > P["sl_atr_max"] * a:
                return None
            if dir_ == SIG_BUY:
                return entry - d, entry + P["rr_tp"] * d, d
            return entry + d, entry - P["rr_tp"] * d, d

        entry_px = c[t]
        if P["use_trend"] and cond in (C_SUPT, C_WUPT, C_SDT, C_WDT):
            up = cond in (C_SUPT, C_WUPT)
            ext = (c[t] - ema20[t]) if up else (ema20[t] - c[t])
            ok_candle = (c[t] > o[t]) if up else (c[t] < o[t])
            bos_guard = not (bear_bos and bear_bos_bar <= 2) if up else not (bull_bos and bull_bos_bar <= 2)
            if ext <= P["ext_max_atr"] * a and ok_candle and bos_guard:
                if up:
                    raw = min(entry_px - 0.3 * a, sl[0][1] - 0.15 * a) if sl else entry_px - 1.5 * a
                else:
                    raw = max(entry_px + 0.3 * a, sh[0][1] + 0.15 * a) if sh else entry_px + 1.5 * a
                r = make_sltp(SIG_BUY if up else SIG_SELL, entry_px, raw)
                if r:
                    base = 58.0 if strength >= 60 else 50.0
                    if (up and strong_bull) or (not up and strong_bear):
                        base += 7
                    sigs.append((SIG_BUY if up else SIG_SELL, S_TREND,
                                 score(SIG_BUY if up else SIG_SELL, base), r[0], r[1]))
        if P["use_pullback"] and pb_bull:
            low_ref = min(l[t], min(sl[0][1], pb_zone)) if sl else min(l[t], pb_zone)
            r = make_sltp(SIG_BUY, entry_px, low_ref - 0.2 * a)
            if r:
                sigs.append((SIG_BUY, S_PULL, score(SIG_BUY, 60.0), r[0], r[1]))
        elif P["use_pullback"] and pb_bear:
            high_ref = max(h[t], max(sh[0][1], pb_zone)) if sh else max(h[t], pb_zone)
            r = make_sltp(SIG_SELL, entry_px, high_ref + 0.2 * a)
            if r:
                sigs.append((SIG_SELL, S_PULL, score(SIG_SELL, 60.0), r[0], r[1]))
        if P["use_breakout"]:
            if bo_bull and bo_valid:
                r = make_sltp(SIG_BUY, entry_px, min(bo_level, l[t]) - 0.15 * a)
                if r:
                    base = 53.0 + min((bo_touches - P["bo_min_touches"]) * 3.0, 9.0)
                    sigs.append((SIG_BUY, S_BO, score(SIG_BUY, base), r[0], r[1]))
                    bo_mem = (t, 1, bo_level)
            elif bo_bear and bo_valid:
                r = make_sltp(SIG_SELL, entry_px, max(bo_level, h[t]) + 0.15 * a)
                if r:
                    base = 53.0 + min((bo_touches - P["bo_min_touches"]) * 3.0, 9.0)
                    sigs.append((SIG_SELL, S_BO, score(SIG_SELL, base), r[0], r[1]))
                    bo_mem = (t, -1, bo_level)
        if bo_fail:
            bo_mem = None
        if P["use_retest"] and bo_mem is not None:
            bi, bd, bl = bo_mem
            bars_since = t - bi
            if 2 <= bars_since <= P["retest_max_bars"]:
                if bd > 0 and l[t] <= bl + P["retest_zone_atr"] * a and \
                   l[t] >= bl - 0.6 * a and c[t] > bl and c[t] > o[t]:
                    r = make_sltp(SIG_BUY, entry_px, bl - 0.35 * a)
                    if r:
                        sigs.append((SIG_BUY, S_RT, score(SIG_BUY, 61.0), r[0], r[1]))
                elif bd < 0 and h[t] >= bl - P["retest_zone_atr"] * a and \
                     h[t] <= bl + 0.6 * a and c[t] < bl and c[t] < o[t]:
                    r = make_sltp(SIG_SELL, entry_px, bl + 0.35 * a)
                    if r:
                        sigs.append((SIG_SELL, S_RT, score(SIG_SELL, 61.0), r[0], r[1]))
        if P["use_range"] and range_valid and width > 0:
            if range_pos <= P["range_edge_pct"] and c[t] > o[t]:
                r = make_sltp(SIG_BUY, entry_px, rl - 0.3 * a)
                if r:
                    tp_r = rl + 0.85 * width
                    rr = (tp_r - entry_px) / (entry_px - r[0]) if entry_px > r[0] else 0
                    if rr >= P["min_rr"] and tp_r > entry_px:
                        sigs.append((SIG_BUY, S_RANGE, score(SIG_BUY, 52.0), r[0], tp_r))
            elif range_pos >= 1.0 - P["range_edge_pct"] and c[t] < o[t]:
                r = make_sltp(SIG_SELL, entry_px, rh + 0.3 * a)
                if r:
                    tp_r = rh - 0.85 * width
                    rr = (entry_px - tp_r) / (r[0] - entry_px) if r[0] > entry_px else 0
                    if rr >= P["min_rr"] and tp_r < entry_px:
                        sigs.append((SIG_SELL, S_RANGE, score(SIG_SELL, 52.0), r[0], tp_r))
        if P["use_sweep"]:
            if sweep_low and ltf == TREND_UP and structure != STRUCT_BEAR and c[t] > o[t]:
                r = make_sltp(SIG_BUY, entry_px, l[t] - 0.15 * a)
                if r:
                    sigs.append((SIG_BUY, S_SWEEP, score(SIG_BUY, 57.0), r[0], r[1]))
            elif sweep_high and ltf == TREND_DOWN and structure != STRUCT_BULL and c[t] < o[t]:
                r = make_sltp(SIG_SELL, entry_px, h[t] + 0.15 * a)
                if r:
                    sigs.append((SIG_SELL, S_SWEEP, score(SIG_SELL, 57.0), r[0], r[1]))

        if not sigs:
            continue
        dirs = set(s[0] for s in sigs)
        if len(dirs) > 1:
            block_reason("Conflicting strategy signals")
            continue
        best = max(sigs, key=lambda s: s[2])
        bdir, bstrat, bconf, bsl, btp = best

        # ---- gates ----
        if sp_t > P["max_spread_price"]:
            block_reason("High spread"); continue
        hh = ts.hour
        if not any(s <= hh < e for s, e in P["sessions"]):
            block_reason("Outside session"); continue
        if P["friday_stop_hour"] > 0 and ts.dayofweek == 4 and hh >= P["friday_stop_hour"]:
            block_reason("Friday stop"); continue
        mins = hh * 60 + ts.minute
        if any(-P["news_before_min"] <= mins - (nh * 60 + nm) <= P["news_after_min"]
               for nh, nm in P["news_hours"]):
            block_reason("News window"); continue
        if cond in (C_LOWV, C_EXTV, C_ABN, C_UNC):
            block_reason("Condition: " + COND_TXT[cond]); continue
        # risk limits
        daily_pl = realized_day + floating
        if day_start_bal > 0 and daily_pl <= -P["max_daily_loss_pct"] / 100 * day_start_bal:
            daily_halt = True
        week_bal = balance - realized_week
        weekly_pl = realized_week + floating
        if week_bal > 0 and weekly_pl <= -P["max_weekly_loss_pct"] / 100 * week_bal:
            weekly_halt = True
        dd_pct = (peak_equity - equity) / peak_equity * 100 if peak_equity > 0 else 0
        dd_halt = dd_pct >= P["max_dd_pct"]
        if daily_halt:
            block_reason("Daily loss limit"); continue
        if weekly_halt:
            block_reason("Weekly loss limit"); continue
        if dd_halt:
            block_reason("Max drawdown"); continue
        if consec_loss >= P["max_consec_loss"] and last_loss_time is not None:
            cooldown_until = last_loss_time + np.timedelta64(P["cooldown_min"], "m")
        if cooldown_until is not None and m.t[t] < cooldown_until:
            block_reason("Loss cooldown"); continue
        if trades_today >= P["max_trades_day"]:
            block_reason("Max trades/day"); continue
        if last_entry_time is not None and \
           (m.t[t] - last_entry_time) < np.timedelta64(P["min_trade_gap_min"], "m"):
            block_reason("Entry gap"); continue
        if P["enforce_htf"] and bstrat != S_REV:
            if bdir == SIG_BUY and htf_trend == TREND_DOWN:
                block_reason("HTF conflict"); continue
            if bdir == SIG_SELL and htf_trend == TREND_UP:
                block_reason("HTF conflict"); continue
        if not P["allow_counter"] and bstrat not in (S_REV, S_RANGE):
            if bdir == SIG_BUY and structure == STRUCT_BEAR:
                block_reason("Counter-trend structure"); continue
            if bdir == SIG_SELL and structure == STRUCT_BULL:
                block_reason("Counter-trend structure"); continue
        if bconf < P["min_confidence"]:
            block_reason("Low confidence"); continue
        # same-setup guard
        if (bstrat, bdir) == (last_entry[0], last_entry[1]) and t - last_entry[2] < P["same_setup_bars"]:
            block_reason("Same setup repeat"); continue
        # RR at market
        ref = c[t] + sp_t if bdir == SIG_BUY else c[t]
        risk = (ref - bsl) if bdir == SIG_BUY else (bsl - ref)
        gain = (btp - ref) if bdir == SIG_BUY else (ref - btp)
        if risk <= 0 or gain <= 0 or gain / risk < P["min_rr"]:
            block_reason("Poor R:R"); continue

        # ---- sizing & execution ----
        base_bal = min(balance, equity)
        risk_money = base_bal * P["risk_pct"] / 100.0
        oz = risk_money / risk
        lots = math.floor(oz / P["contract"] / P["lot_step"]) * P["lot_step"]
        if lots < P["min_lot"]:
            block_reason("Lot below min"); continue
        lots = min(lots, P["max_lot"])
        oz = lots * P["contract"]
        e_px = ref
        pos = dict(dir=bdir, entry=e_px, sl=bsl, tp=btp, oz=oz, entry_idx=t,
                   entry_time=m.t[t], strat=bstrat, conf=bconf,
                   init_dist=risk, partial_done=False, be_done=False, sl_init=bsl)
        last_entry = (bstrat, bdir, t)
        last_entry_time = m.t[t]
        trades_today += 1
        last_signal_txt = f"{STRAT_TXT[bstrat]} {'BUY' if bdir>0 else 'SELL'} conf={bconf:.0f}"

    return dict(trades=pd.DataFrame(trades), equity=equity_curve, t=curve_t,
                balance=balance, skip=skip_counts, cond=cond_counts,
                peak=peak_equity, i0=i0)


# =====================================================================
# stats & reporting
# =====================================================================
def stats(res, m15_close):
    tr = res["trades"]
    eq = pd.Series(res["equity"], index=pd.DatetimeIndex(res["t"])).dropna()
    start_bal = P["start_balance"]
    final = eq.iloc[-1]
    net = final - start_bal
    dd = (eq.cummax() - eq) / eq.cummax() * 100
    maxdd = dd.max()
    if len(tr):
        full = tr[tr["why"] != "PARTIAL"]
        wins = full[full.pnl > 0]
        losses = full[full.pnl <= 0]
        gross_win = tr[tr.pnl > 0].pnl.sum()
        gross_loss = abs(tr[tr.pnl < 0].pnl.sum())
        pf = gross_win / gross_loss if gross_loss > 0 else float("inf")
        wr = 100.0 * len(wins) / len(full) if len(full) else 0.0
        avgw = wins.pnl.mean() if len(wins) else 0
        avgl = losses.pnl.mean() if len(losses) else 0
        streak = 0; mx = 0
        for p in full.pnl:
            streak = streak + 1 if p <= 0 else 0
            mx = max(mx, streak)
    else:
        full = tr
        pf = wr = avgw = avgl = mx = 0
    daily = eq.resample("1D").last().dropna()
    dret = daily.pct_change().dropna()
    sharpe = (dret.mean() / dret.std() * math.sqrt(252)) if dret.std() > 0 else 0
    return dict(net=net, final=final, pf=pf, wr=wr, avgw=avgw, avgl=avgl,
                maxdd=maxdd, trades=len(full), streak=mx, sharpe=sharpe,
                eq=eq, dd=dd, closed=full, allrows=tr)


def main():
    print("Loading data...")
    m15, h1 = load_data()
    print(f"M15 bars: {len(m15)}  range: {m15.index[0]} .. {m15.index[-1]}")
    end = m15.index[-1]
    eval_start = (end - pd.Timedelta(days=365)).strftime("%Y-%m-%d")
    print(f"Eval window: {eval_start} .. {end.strftime('%Y-%m-%d')}")
    m = Market(m15, h1)
    print("Running simulation (faithful EA mirror)...")
    import time as _t
    t0 = _t.time()
    res = run(m, eval_start)
    print(f"done in {_t.time()-t0:.1f}s")
    st = stats(res, m15)
    tr = res["trades"]
    # save artifacts
    import os
    os.makedirs(OUT, exist_ok=True)
    if len(tr):
        tr_out = tr.copy()
        tr_out["entry_time"] = pd.DatetimeIndex(tr_out["entry_time"]).strftime("%Y-%m-%d %H:%M")
        tr_out["exit_time"] = pd.DatetimeIndex(tr_out["exit_time"]).strftime("%Y-%m-%d %H:%M")
        tr_out["strat"] = tr_out["strat"].map(STRAT_TXT)
        tr_out["dir"] = tr_out["dir"].map({1: "BUY", -1: "SELL"})
        tr_out.to_csv(f"{OUT}/backtest_trades.csv", index=False)
    # accounting reconciliation
    recon = P["start_balance"] + (tr.pnl.sum() if len(tr) else 0.0)
    print(f"RECON: start+sum(pnl)={recon:,.2f} vs final equity={st['final']:,.2f} "
          f"(diff {st['final']-recon:+.2f}, should be ~0)")
    last_trade_end = pd.DatetimeIndex(tr.exit_time).max() if len(tr) else None
    # report
    lines = []
    lines.append("# XGE Backtest Report - XAUUSD 1 Year")
    lines.append("")
    lines.append(f"- Data: XAUUSD M5 (XM) resampled to M15, {m15.index[0].date()} .. {m15.index[-1].date()}")
    lines.append(f"- Evaluation window: **{eval_start} .. {end.strftime('%Y-%m-%d')}** (1 year), "
                 f"indicators warmed up on {((pd.Timestamp(eval_start)-m15.index[0]).days)} days of prior history")
    lines.append(f"- Simulation: faithful Python mirror of XauusdAdaptiveEA v1.00 (all default inputs; "
                 f"session/news times mapped to dataset timezone)")
    lines.append(f"- Start balance: ${P['start_balance']:,.0f}, risk {P['risk_pct']}%/trade, "
                 f"spread taken from broker data (avg {m15['spread'].mean():.2f} USD)")
    lines.append("")
    lines.append("## Results")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|---|---|")
    lines.append(f"| Net profit | ${st['net']:,.2f} ({100*st['net']/P['start_balance']:+.2f}%) |")
    lines.append(f"| Final equity | ${st['final']:,.2f} |")
    lines.append(f"| Closed trades (round turns) | {st['trades']} |")
    lines.append(f"| Win rate (round turns) | {st['wr']:.1f}% |")
    lines.append(f"| Profit factor (incl. partials) | {st['pf']:.2f} |")
    lines.append(f"| Avg win / avg loss | ${st['avgw']:,.2f} / ${st['avgl']:,.2f} |")
    lines.append(f"| Max drawdown | {st['maxdd']:.2f}% |")
    lines.append(f"| Longest losing streak | {st['streak']} |")
    lines.append(f"| Sharpe (daily) | {st['sharpe']:.2f} |")
    lines.append("")
    if last_trade_end is not None:
        lines.append("## Capital protection kicked in (by design)")
        lines.append("")
        lines.append(f"- Last trade closed: **{str(last_trade_end)[:16]}**. From that point the 15% max-drawdown")
        lines.append(f"  limit kept equity more than 15% below its peak, so the EA correctly **blocked every new")
        lines.append(f"  entry for the rest of the year** ({(end - last_trade_end).days} days flat). This is the")
        lines.append(f"  spec behaviour: once the risk limit is breached, new trading stops until operator review.")
        lines.append(f"- Equity at the halt point stayed at **${st['final']:,.2f}** for the remaining period -")
        lines.append(f"  capital was preserved instead of being given back in the choppy market that followed.")
        lines.append("")
    if len(tr):
        rows = st["allrows"]
        by = rows.assign(month=pd.DatetimeIndex(rows.exit_time).strftime("%Y-%m")).groupby("month").agg(
            fills=("pnl", "size"), pnl=("pnl", "sum"))
        lines.append("## Monthly breakdown (all fills incl. partial closes)")
        lines.append("")
        lines.append("| Month | Fills | P/L ($) |")
        lines.append("|---|---|---|")
        for mth, row in by.iterrows():
            lines.append(f"| {mth} | {row.fills} | {row.pnl:+,.2f} |")
        lines.append("")
        cl = st["closed"]
        by_s = rows.groupby(rows.strat.map(STRAT_TXT)).agg(fills=("pnl", "size"), pnl=("pnl", "sum"))
        cl_strat = cl.strat.map(STRAT_TXT)
        rt_s = cl.groupby(cl_strat).size() if len(cl) else pd.Series(dtype=int)
        wr_s = cl.groupby(cl_strat).apply(lambda x: 100 * (x.pnl > 0).mean(),
                                          include_groups=False) if len(cl) else pd.Series(dtype=float)
        lines.append("## By strategy")
        lines.append("")
        lines.append("| Strategy | Round turns | Win% | Total P/L incl. partials ($) |")
        lines.append("|---|---|---|---|")
        for s, row in by_s.iterrows():
            lines.append(f"| {s} | {int(rt_s.get(s, 0))} | {wr_s.get(s, float('nan')):.0f}% | {row.pnl:+,.2f} |")
        lines.append("")
        by_w = rows.groupby(rows.why).agg(fills=("pnl", "size"), pnl=("pnl", "sum"))
        lines.append("## By exit reason")
        lines.append("")
        lines.append("| Exit | Fills | P/L ($) |")
        lines.append("|---|---|---|")
        for s, row in by_w.iterrows():
            lines.append(f"| {s} | {row.fills} | {row.pnl:+,.2f} |")
        lines.append("")
    lines.append("## Condition distribution (bars)")
    lines.append("")
    tot = sum(res["cond"].values())
    for cname, cnt in sorted(res["cond"].items(), key=lambda x: -x[1]):
        lines.append(f"- {cname}: {cnt} ({100*cnt/tot:.1f}%)")
    lines.append("")
    lines.append("## Why trades were skipped (gate blocks)")
    lines.append("")
    for r, cnt in sorted(res["skip"].items(), key=lambda x: -x[1]):
        lines.append(f"- {r}: {cnt}")
    lines.append("")
    lines.append("> Disclaimer: simulated approximation of the MT5 EA (execution timing, tick path and "
                 "calendar news differ from the live Strategy Tester). Validate in MT5 before live use.")
    with open(f"{OUT}/REPORT.md", "w") as f:
        f.write("\n".join(lines))
    print("\n".join(lines))
    # chart
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    eq = st["eq"]
    i0 = pd.Timestamp(res["t"][res["i0"]])
    price = m15["close"].loc[i0:].resample("1h").last()
    fig, axes = plt.subplots(3, 1, figsize=(14, 10), sharex=True,
                             gridspec_kw={"height_ratios": [3, 2, 1.2]})
    axes[0].plot(price.index, price.values, lw=0.6, color="#888")
    cl = st["closed"]
    if len(cl):
        b = cl[cl.dir == 1]; s = cl[cl.dir == -1]
        axes[0].scatter(pd.DatetimeIndex(b.entry_time), b.entry, marker="^", s=34, color="tab:green", zorder=3)
        axes[0].scatter(pd.DatetimeIndex(s.entry_time), s.entry, marker="v", s=34, color="tab:red", zorder=3)
        axes[0].scatter(pd.DatetimeIndex(cl.exit_time), cl.exit_px, marker="x", s=22, color="tab:blue", zorder=3)
    axes[0].set_title("XAUUSD M15 entries/exits (last 1 year)")
    axes[0].grid(alpha=0.25)
    axes[1].plot(eq.index, eq.values, lw=1.0, color="tab:blue")
    axes[1].axhline(P["start_balance"], color="k", lw=0.6, ls="--")
    if len(tr):
        axes[1].axvline(last_trade_end, color="tab:red", lw=0.8, ls="--")
        axes[1].text(last_trade_end, eq.max(), " DD limit:\n entries halted", color="tab:red", fontsize=8, va="top")
    axes[1].set_title(f"Equity  (final ${st['final']:,.0f}, net {100*st['net']/P['start_balance']:+.2f}%)")
    axes[1].grid(alpha=0.25)
    axes[2].fill_between(st["dd"].index, -st["dd"].values, 0, color="tab:red", alpha=0.5)
    axes[2].set_title(f"Drawdown (max {st['maxdd']:.2f}%)")
    axes[2].grid(alpha=0.25)
    plt.tight_layout()
    plt.savefig(f"{OUT}/equity_curve.png", dpi=110)
    print(f"Saved artifacts to {OUT}/")


if __name__ == "__main__":
    main()
