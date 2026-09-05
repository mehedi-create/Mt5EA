#!/usr/bin/env python3
"""
XGE Backtest Harness v2 - Python simulation of XauusdAdaptiveEA v2 (MT5).

v2 rules mirrored:
  - ONLY low volatility is a no-trade state; every other regime is traded
  - UPTREND : buy fresh Higher-Low, exit at Higher-High (bullBOS)
  - DOWNTREND: sell fresh Lower-High, exit at Lower-Low (bearBOS)
  - SIDE    : buy support / sell resistance (last swings), TP opposite side
  - NEWS    : momentum entry, rolling ATR trailing stop, stop-and-reverse
              (max N flips per window), flatten when window ends

Capital protection layers stay active (spread, daily/weekly loss, max DD,
cooldown, max trades/day, weekend flatten, emergency exit).

Data: XAUUSD M5 (XM) resampled to M15 + H1. Session-free (24h) by v2 design;
news times mapped to dataset timezone (US Eastern).
"""
import math
import numpy as np
import pandas as pd
from collections import deque

DATA = "/home/user/.cache/bt/ds5yr/XAUUSDm_M5_.csv"
OUT = "/home/user/Mt5EA/backtest"

P = dict(
    atr_period=14, adx_period=14, rsi_period=14,
    ema_fast_h=50, ema_slow_h=200,
    ema_zone_f=20, ema_zone_m=50, ema_zone_s=200,
    atr_avg_bars=200,
    vol_low_ratio=0.55, vol_high_ratio=1.60, vol_extreme_ratio=2.50,
    abnormal_bar_atr=6.0,
    strength_strong=60.0, strength_weak=35.0,
    swing_strength=3, swing_lookback=120,
    range_lookback=90,
    # v2 regime params
    swing_fresh=3, sr_zone_atr=0.35, sr_min_rr=1.0,
    news_trail_atr=1.2, news_momentum_atr=0.4, news_max_reversals=3,
    emergency_atr=5.0,
    # risk
    sl_atr_min=0.8, sl_atr_max=4.0,
    risk_pct=1.0, max_lot=10.0,
    max_daily_loss_pct=3.0, max_weekly_loss_pct=6.0, max_dd_pct=15.0, dd_halt_days=5,
    max_consec_loss=4, cooldown_min=180,
    max_trades_day=12, min_trade_gap_min=5, same_setup_bars=24,
    max_spread_price=0.50,
    news_hours=[(8, 30), (10, 0), (14, 0)],   # ET equivalents of 13:30/15:00/19:00 EET
    news_before_min=30, news_after_min=30,
    friday_stop_hour=16, friday_close_hour=16,
    start_balance=10000.0, contract=100.0, lot_step=0.01, min_lot=0.01,
    dd_risk_mult=0.5,
)

VOL_ABN, VOL_LOW, VOL_NORM, VOL_HIGH, VOL_EXT = range(5)
TREND_NONE, TREND_UP, TREND_DOWN = 0, 1, 2
STRUCT_UNDEF, STRUCT_BULL, STRUCT_BEAR, STRUCT_MIXED = 0, 1, 2, 3
MODE_NOVOL, MODE_NEWS, MODE_UP, MODE_DOWN, MODE_SIDE = range(5)
MODE_TXT = {MODE_NOVOL: "LOW VOL (no trade)", MODE_NEWS: "NEWS", MODE_UP: "UPTREND",
            MODE_DOWN: "DOWNTREND", MODE_SIDE: "SIDE"}
SIG_BUY, SIG_SELL = 1, -1


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


def load_data(tf="m15"):
    df = pd.read_csv(DATA, sep="\t",
                     names=["date", "time", "open", "high", "low", "close", "tickvol", "vol", "spread"],
                     header=0)
    ts = pd.to_datetime(df["date"] + " " + df["time"], format="%Y.%m.%d %H:%M:%S")
    m5 = pd.DataFrame({"open": df["open"].values, "high": df["high"].values,
                       "low": df["low"].values, "close": df["close"].values,
                       "spread": df["spread"].values * 0.001}, index=ts).sort_index()
    if tf == "m5":
        entry = m5
    else:
        entry = m5.resample("15min").agg({"open": "first", "high": "max", "low": "min",
                                          "close": "last", "spread": "mean"}).dropna()
    h1 = m5.resample("1h").agg({"open": "first", "high": "max", "low": "min",
                                "close": "last"}).dropna()
    return entry, h1


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
        self.atr = atr_wilder(self.h, self.l, self.c, P["atr_period"])
        s = pd.Series(self.atr)
        self.atr_avg = s.rolling(P["atr_avg_bars"], min_periods=P["atr_avg_bars"]).mean().values
        k = P["swing_strength"]
        self.k = k
        ish = np.zeros(self.n, bool)
        isl = np.zeros(self.n, bool)
        for j in range(k, self.n - k):
            nh = max(self.h[j - k:j].max(), self.h[j + 1:j + k + 1].max())
            nl = min(self.l[j - k:j].min(), self.l[j + 1:j + k + 1].min())
            if self.h[j] > nh:
                ish[j] = True
            if self.l[j] < nl:
                isl[j] = True
        self.is_sh = ish
        self.is_sl = isl


def news_key(ts):
    mins = ts.hour * 60 + ts.minute
    for nh, nm in P["news_hours"]:
        ev = nh * 60 + nm
        if -P["news_before_min"] <= mins - ev <= P["news_after_min"]:
            return ts.normalize() + pd.Timedelta(hours=nh, minutes=nm)
    return None


def run(m, eval_start):
    n = m.n
    k = m.k
    o, h, l, c = m.o, m.h, m.l, m.c
    atr, atr_avg = m.atr, m.atr_avg
    ema20, ema50 = m.ema20, m.ema50
    warm = max(P["ema_zone_s"], P["atr_avg_bars"], P["range_lookback"], P["swing_lookback"]) + 10
    i0 = max(warm, int(np.searchsorted(m.t, np.datetime64(eval_start))))

    sh_q = deque(); sl_q = deque()
    bos_bull_i = None; bos_bear_i = None

    balance = P["start_balance"]
    peak = balance
    pos = None
    trades = []
    equity_curve = np.full(n, np.nan)

    realized_day = 0.0; day_key = None; day_start_bal = balance; daily_halt = False
    realized_week = 0.0; week_key = None; weekly_halt = False
    consec = 0; last_loss_time = None; cooldown_until = None
    trades_today = 0; last_entry_time = None
    last_entry = (None, None, -10 ** 9)
    news_win = None; reversals = 0
    dd_halt = False; dd_halt_time = None
    dd_reduced = False; dd_trip_peak = None
    skip_counts = {}; mode_counts = {}

    def realize(oz, entry, px, d):
        return oz * (px - entry) * d

    def close_pos(px, t, why, partial=False):
        nonlocal pos, balance, realized_day, realized_week, consec, last_loss_time
        d = pos["dir"]
        pnl = realize(pos["oz"], pos["entry"], px, d)
        balance += pnl
        realized_day += pnl
        realized_week += pnl
        trades.append(dict(entry_time=pos["entry_time"], dir=d, mode=pos["mode"],
                           lots=pos["oz"] / P["contract"], entry=pos["entry"],
                           sl_init=pos["sl_init"], tp=pos["tp"],
                           exit_time=m.t[t], exit_px=px, pnl=round(pnl, 2),
                           bars=t - pos["entry_idx"], why=why))
        if pnl < 0:
            consec += 1
            last_loss_time = m.t[t]
        elif pnl > 0:
            consec = 0
        pos = None
        return pnl

    def risk_ok(t):
        nonlocal dd_halt, dd_halt_time, peak, dd_reduced, dd_trip_peak
        if daily_halt or weekly_halt:
            return False, "loss limit"
        eq_now = balance
        ddp = (peak - eq_now) / peak * 100 if peak > 0 else 0
        if not dd_halt and ddp >= P["max_dd_pct"]:
            dd_halt = True
            dd_halt_time = m.t[t]
            dd_trip_peak = peak      # recovery target for reduced-risk mode
        elif dd_halt and dd_halt_time is not None and \
                (m.t[t] - dd_halt_time) >= np.timedelta64(P["dd_halt_days"], "D"):
            dd_halt = False
            dd_reduced = True        # resume at reduced risk until recovery
            peak = eq_now     # fresh baseline after breaker pause
        if dd_reduced and dd_trip_peak is not None and eq_now >= dd_trip_peak:
            dd_reduced = False       # full recovery -> normal risk
        if dd_halt:
            return False, "max dd"
        if consec >= P["max_consec_loss"] and last_loss_time is not None:
            if m.t[t] < last_loss_time + np.timedelta64(P["cooldown_min"], "m"):
                return False, "cooldown"
        if trades_today >= P["max_trades_day"]:
            return False, "max trades/day"
        return True, ""

    for t in range(i0, n):
        if np.isnan(atr[t]) or np.isnan(atr_avg[t]):
            continue
        ts = pd.Timestamp(m.t[t])
        dk = ts.date()
        if dk != day_key:
            day_key = dk
            realized_day = 0.0
            trades_today = 0
            day_start_bal = balance
            daily_halt = False
        wk = (ts - pd.Timedelta(days=ts.dayofweek)).date()
        if wk != week_key:
            week_key = wk
            realized_week = 0.0
            weekly_halt = False

        # confirm swings
        j = t - k
        if j >= k:
            if m.is_sh[j]:
                sh_q.append((j, h[j]))
                if len(sh_q) > 4: sh_q.popleft()
                bos_bull_i = None
            if m.is_sl[j]:
                sl_q.append((j, l[j]))
                if len(sl_q) > 4: sl_q.popleft()
                bos_bear_i = None
        if sh_q and bos_bull_i is None:
            sj, sp_ = sh_q[-1]
            for ii in range(sj + 1, t + 1):
                if c[ii] > sp_:
                    bos_bull_i = ii
                    break
        if sl_q and bos_bear_i is None:
            sj, sp_ = sl_q[-1]
            for ii in range(sj + 1, t + 1):
                if c[ii] < sp_:
                    bos_bear_i = ii
                    break
        bull_bos = bos_bull_i is not None
        bear_bos = bos_bear_i is not None
        bull_bos_bar = (t - bos_bull_i) if bull_bos else 9999
        bear_bos_bar = (t - bos_bear_i) if bear_bos else 9999
        sh = list(sh_q)[-4:][::-1]
        sl = list(sl_q)[-4:][::-1]
        structure = STRUCT_UNDEF
        if len(sh) >= 2 and len(sl) >= 2:
            fHH = sh[0][1] > sh[1][1]; fLH = sh[0][1] < sh[1][1]
            fHL = sl[0][1] > sl[1][1]; fLL = sl[0][1] < sl[1][1]
            if fHH and fHL:
                structure = STRUCT_BULL
            elif fLH and fLL:
                structure = STRUCT_BEAR
            else:
                structure = STRUCT_MIXED

        a = atr[t]
        vol_ratio = a / atr_avg[t] if atr_avg[t] > 0 else 1.0
        if a <= 0:
            vol = VOL_ABN
        elif (h[t] - l[t]) > P["abnormal_bar_atr"] * a or vol_ratio > P["vol_extreme_ratio"] * 1.8:
            vol = VOL_ABN
        elif vol_ratio <= P["vol_low_ratio"]:
            vol = VOL_LOW
        elif vol_ratio >= P["vol_extreme_ratio"]:
            vol = VOL_EXT
        else:
            vol = VOL_NORM
        if ema20[t] > ema50[t] and c[t] > ema50[t]:
            ltf = TREND_UP
        elif ema20[t] < ema50[t] and c[t] < ema50[t]:
            ltf = TREND_DOWN
        else:
            ltf = TREND_NONE

        # regime
        nk = news_key(ts)
        if nk != news_win:
            news_win = nk
            reversals = 0
        if vol == VOL_LOW:
            mode = MODE_NOVOL
        elif nk is not None:
            mode = MODE_NEWS
        elif structure == STRUCT_BULL or (ltf == TREND_UP and structure != STRUCT_BEAR):
            mode = MODE_UP
        elif structure == STRUCT_BEAR or (ltf == TREND_DOWN and structure != STRUCT_BULL):
            mode = MODE_DOWN
        else:
            mode = MODE_SIDE
        mode_counts[MODE_TXT[mode]] = mode_counts.get(MODE_TXT[mode], 0) + 1

        sp_t = m.sp[t]
        # ---------------- position management ----------------
        if pos is not None:
            d = pos["dir"]; entry = pos["entry"]; slv = pos["sl"]; tpv = pos["tp"]
            exit_px = None; why = None
            if d == SIG_BUY:
                if l[t] <= slv:
                    exit_px, why = slv, "SL"
                elif tpv > 0 and h[t] >= tpv:
                    exit_px, why = tpv, "TP"
            else:
                if h[t] >= slv:
                    exit_px, why = slv - sp_t, "SL"
                elif tpv > 0 and l[t] <= tpv:
                    exit_px, why = tpv, "TP"
            if exit_px is not None:
                pmode = pos["mode"]
                if pmode == MODE_NEWS and why == "SL" and reversals < P["news_max_reversals"]:
                    # stop-and-reverse: close, then flip with a fresh rolling stop
                    close_pos(exit_px, t, "TRAIL_STOP")
                    rd = -d
                    newsl = exit_px + (P["news_trail_atr"] * a if rd == SIG_SELL else -P["news_trail_atr"] * a)
                    riskd = abs(exit_px - newsl)
                    eff_pct = P["risk_pct"] * (P["dd_risk_mult"] if dd_reduced else 1.0)
                    oz = balance * eff_pct / 100.0 / riskd if riskd > 0 else 0.0
                    lots = math.floor(oz / P["contract"] / P["lot_step"]) * P["lot_step"]
                    if lots >= P["min_lot"]:
                        reversals += 1
                        pos = dict(dir=rd, entry=exit_px, sl=newsl, tp=0.0,
                                   oz=lots * P["contract"], entry_idx=t,
                                   entry_time=m.t[t], mode=MODE_NEWS, sl_init=newsl)
                        trades_today += 1
                        last_entry_time = m.t[t]
                    else:
                        pos = None
                else:
                    close_pos(exit_px, t, why if why != "SL" else
                              ("TRAIL_STOP" if pmode == MODE_NEWS else "SL"))
            if pos is not None:
                pmode = pos["mode"]
                bid = c[t]; ask = c[t] + sp_t
                # structure exits
                if pmode == MODE_UP:
                    if (bull_bos and bull_bos_bar <= 2):
                        close_pos(bid, t, "HIGHER_HIGH")
                    elif mode == MODE_DOWN:
                        close_pos(bid, t, "TREND_REV")
                elif pmode == MODE_DOWN:
                    if (bear_bos and bear_bos_bar <= 2):
                        close_pos(ask, t, "LOWER_LOW")
                    elif mode == MODE_UP:
                        close_pos(ask, t, "TREND_REV")
                elif pmode == MODE_SIDE:
                    if mode == MODE_NEWS or (mode == MODE_UP and pos["dir"] == SIG_SELL) or \
                       (mode == MODE_DOWN and pos["dir"] == SIG_BUY):
                        close_pos(bid if pos["dir"] == SIG_BUY else ask, t, "REGIME_CHG")
                elif pmode == MODE_NEWS:
                    # rolling trailing + window end
                    if news_win is None:
                        close_pos(bid if pos["dir"] == SIG_BUY else ask, t, "NEWS_END")
                    else:
                        trail = P["news_trail_atr"] * a
                        if pos["dir"] == SIG_BUY:
                            tgt = bid - trail
                            if tgt > pos["sl"]:
                                pos["sl"] = tgt
                        else:
                            tgt = ask + trail
                            if pos["sl"] == 0 or tgt < pos["sl"]:
                                pos["sl"] = tgt
                # emergency
                if pos is not None:
                    pdist = (bid - pos["entry"]) if pos["dir"] == SIG_BUY else (pos["entry"] - ask)
                    if pdist <= -P["emergency_atr"] * a:
                        close_pos(bid if pos["dir"] == SIG_BUY else ask, t, "EMERGENCY")
        # friday close
        if pos is not None and P["friday_close_hour"] > 0 and ts.dayofweek == 4 and \
           ts.hour >= P["friday_close_hour"]:
            close_pos(c[t] if pos["dir"] == SIG_BUY else c[t] + sp_t, t, "WEEKEND")

        floating = 0.0
        if pos is not None:
            cur = c[t] if pos["dir"] == SIG_BUY else c[t] + sp_t
            floating = pos["oz"] * (cur - pos["entry"]) * pos["dir"]
        equity_curve[t] = balance + floating
        if balance + floating > peak:
            peak = balance + floating
        # daily/weekly halt flags
        if day_start_bal > 0 and realized_day + floating <= -P["max_daily_loss_pct"] / 100 * day_start_bal:
            daily_halt = True
        week_bal = balance - realized_week
        if week_bal > 0 and realized_week + floating <= -P["max_weekly_loss_pct"] / 100 * week_bal:
            weekly_halt = True

        # ---------------- entries ----------------
        if pos is not None or mode == MODE_NOVOL:
            continue
        sig = None  # (dir, mode, sl, tp, why, stratKey)
        if mode == MODE_UP and len(sl) >= 2:
            freshHL = ((t - sl[0][0] - k) <= P["swing_fresh"]) and (sl[0][1] > sl[1][1])
            if freshHL and c[t] > sl[0][1] and not (bear_bos and bear_bos_bar <= 2):
                raw = sl[0][1] - 0.2 * a
                dd = max(abs(c[t] - raw), P["sl_atr_min"] * a)
                if dd <= P["sl_atr_max"] * a:
                    sig = (SIG_BUY, MODE_UP, c[t] - dd, 0.0,
                           f"HL buy sl0={sl[0][1]:.2f}>sl1={sl[1][1]:.2f}", "TR")
        elif mode == MODE_DOWN and len(sh) >= 2:
            freshLH = ((t - sh[0][0] - k) <= P["swing_fresh"]) and (sh[0][1] < sh[1][1])
            if freshLH and c[t] < sh[0][1] and not (bull_bos and bull_bos_bar <= 2):
                raw = sh[0][1] + 0.2 * a
                dd = max(abs(raw - c[t]), P["sl_atr_min"] * a)
                if dd <= P["sl_atr_max"] * a:
                    sig = (SIG_SELL, MODE_DOWN, c[t] + dd, 0.0,
                           f"LH sell sh0={sh[0][1]:.2f}<sh1={sh[1][1]:.2f}", "TR")
        elif mode == MODE_SIDE and len(sh) >= 1 and len(sl) >= 1:
            support, resist = sl[0][1], sh[0][1]
            if resist > support:
                if l[t] <= support + P["sr_zone_atr"] * a and c[t] > o[t]:
                    dd = max(c[t] - (support - 0.3 * a), P["sl_atr_min"] * a)
                    if dd <= P["sl_atr_max"] * a:
                        slv = c[t] - dd
                        rr = (resist - c[t]) / (c[t] - slv) if c[t] > slv else 0
                        if rr >= P["sr_min_rr"]:
                            sig = (SIG_BUY, MODE_SIDE, slv, resist,
                                   f"side buy support={support:.2f} resist={resist:.2f}", "SR")
                elif h[t] >= resist - P["sr_zone_atr"] * a and c[t] < o[t]:
                    dd = max((resist + 0.3 * a) - c[t], P["sl_atr_min"] * a)
                    if dd <= P["sl_atr_max"] * a:
                        slv = c[t] + dd
                        rr = (c[t] - support) / (slv - c[t]) if slv > c[t] else 0
                        if rr >= P["sr_min_rr"]:
                            sig = (SIG_SELL, MODE_SIDE, slv, support,
                                   f"side sell resist={resist:.2f} support={support:.2f}", "SR")
        elif mode == MODE_NEWS:
            body = c[t] - o[t]
            if news_win is not None and reversals <= P["news_max_reversals"] and \
               abs(body) >= P["news_momentum_atr"] * a:
                d = SIG_BUY if body > 0 else SIG_SELL
                slv = c[t] - P["news_trail_atr"] * a if d == SIG_BUY else c[t] + P["news_trail_atr"] * a
                sig = (d, MODE_NEWS, slv, 0.0, f"news momentum {d}", "NW")
        if sig is None:
            continue
        bdir, bmode, bsl, btp, why, skey = sig
        # gates
        if sp_t > P["max_spread_price"]:
            skip_counts["spread"] = skip_counts.get("spread", 0) + 1; continue
        if P["friday_stop_hour"] > 0 and ts.dayofweek == 4 and ts.hour >= P["friday_stop_hour"]:
            skip_counts["friday"] = skip_counts.get("friday", 0) + 1; continue
        ok, rr_ = risk_ok(t)
        if not ok:
            skip_counts[rr_] = skip_counts.get(rr_, 0) + 1; continue
        if last_entry_time is not None and \
           (m.t[t] - last_entry_time) < np.timedelta64(P["min_trade_gap_min"], "m"):
            skip_counts["gap"] = skip_counts.get("gap", 0) + 1; continue
        if (skey, bdir) == (last_entry[0], last_entry[1]) and t - last_entry[2] < P["same_setup_bars"]:
            skip_counts["same-setup"] = skip_counts.get("same-setup", 0) + 1; continue
        ref = c[t] + sp_t if bdir == SIG_BUY else c[t]
        riskd = (ref - bsl) if bdir == SIG_BUY else (bsl - ref)
        if riskd <= 0:
            continue
        base_bal = min(balance, balance + floating)
        eff_pct = P["risk_pct"] * (P["dd_risk_mult"] if dd_reduced else 1.0)
        oz = base_bal * eff_pct / 100.0 / riskd
        lots = math.floor(oz / P["contract"] / P["lot_step"]) * P["lot_step"]
        if lots < P["min_lot"]:
            skip_counts["min-lot"] = skip_counts.get("min-lot", 0) + 1; continue
        pos = dict(dir=bdir, entry=ref, sl=bsl, tp=btp, oz=lots * P["contract"],
                   entry_idx=t, entry_time=m.t[t], mode=bmode, sl_init=bsl)
        last_entry = (skey, bdir, t)
        last_entry_time = m.t[t]
        trades_today += 1

    return dict(trades=pd.DataFrame(trades), equity=equity_curve, t=m.t,
                balance=balance, skip=skip_counts, modes=mode_counts,
                peak=peak, i0=i0)


def stats(res):
    tr = res["trades"]
    eq = pd.Series(res["equity"], index=pd.DatetimeIndex(res["t"])).dropna()
    final = eq.iloc[-1]
    net = final - P["start_balance"]
    dd = (eq.cummax() - eq) / eq.cummax() * 100
    maxdd = dd.max()
    if len(tr):
        wins = tr[tr.pnl > 0]; losses = tr[tr.pnl <= 0]
        gw = tr[tr.pnl > 0].pnl.sum(); gl = abs(tr[tr.pnl < 0].pnl.sum())
        pf = gw / gl if gl > 0 else float("inf")
        wr = 100.0 * len(wins) / len(tr)
        avgw = wins.pnl.mean() if len(wins) else 0
        avgl = losses.pnl.mean() if len(losses) else 0
        streak = mx = 0
        for p in tr.pnl:
            streak = streak + 1 if p <= 0 else 0
            mx = max(mx, streak)
    else:
        pf = wr = avgw = avgl = mx = 0
    daily = eq.resample("1D").last().dropna()
    dret = daily.pct_change().dropna()
    sharpe = (dret.mean() / dret.std() * math.sqrt(252)) if len(dret) and dret.std() > 0 else 0

    ext = {}
    if len(tr):
        wstreak = lstreak = wmx = 0
        for p in tr.pnl:
            if p > 0:
                wstreak += 1; lstreak = 0
            else:
                lstreak += 1; wstreak = 0
            wmx = max(wmx, wstreak)
        bt = tr.loc[tr.pnl.idxmax()]; wt = tr.loc[tr.pnl.idxmin()]
        ext["best_trade"] = (bt.pnl, bt.entry_time, bt.exit_time, bt["dir"], bt["mode"], bt["why"])
        ext["worst_trade"] = (wt.pnl, wt.entry_time, wt.exit_time, wt["dir"], wt["mode"], wt["why"])
        hold_min = pd.Series((pd.DatetimeIndex(tr.exit_time) - pd.DatetimeIndex(tr.entry_time))
                             .total_seconds() / 60.0)
        ext["hold_avg_min"] = float(hold_min.mean())
        ext["hold_med_min"] = float(hold_min.median())
        ext["hold_max_min"] = float(hold_min.max())
        ext["win_streak"] = wmx
        byd = tr.assign(day=pd.DatetimeIndex(tr.exit_time).strftime("%Y-%m-%d")).groupby("day").pnl.sum()
        ext["best_day"] = (byd.max(), byd.idxmax())
        ext["worst_day"] = (byd.min(), byd.idxmin())
        dpl = daily.diff().dropna()
        ext["best_close_day"] = (dpl.max(), dpl.idxmax())
        ext["worst_close_day"] = (dpl.min(), dpl.idxmin())
        bymo = tr.assign(mo=pd.DatetimeIndex(tr.exit_time).strftime("%Y-%m")).groupby("mo").pnl.sum()
        ext["best_month"] = (bymo.max(), bymo.idxmax())
        ext["worst_month"] = (bymo.min(), bymo.idxmin())
        buys = tr[tr["dir"] == 1]; sells = tr[tr["dir"] == -1]
        ext["buy_pnl"] = (buys.pnl.sum() if len(buys) else 0.0, len(buys))
        ext["sell_pnl"] = (sells.pnl.sum() if len(sells) else 0.0, len(sells))
        ext["median_trade"] = float(tr.pnl.median())
        ext["expectancy"] = float(tr.pnl.mean())
        ext["max_dd_dollars"] = float((eq.cummax() - eq).max())
        ext["peak_equity"] = float(eq.max())
        ext["trough_equity"] = float(eq.min())
    return dict(net=net, final=final, pf=pf, wr=wr, avgw=avgw, avgl=avgl,
                maxdd=maxdd, trades=len(tr), streak=mx, sharpe=sharpe, eq=eq, dd=dd,
                rows=tr, **ext)


def main():
    import sys
    tf = sys.argv[1] if len(sys.argv) > 1 else "m15"
    assert tf in ("m5", "m15")
    preset = sys.argv[2] if len(sys.argv) > 2 else ""
    if preset == "rt":
        # real-time-equivalent windows: scale bar-based params 3x (M15 -> M5)
        P.update(dict(swing_fresh=9, swing_lookback=360, range_lookback=270,
                      same_setup_bars=72, atr_avg_bars=600, swing_strength=9))
        print("preset rt: bar-based windows scaled x3 for real-time equivalence")
    suffix = "" if tf == "m15" else ("_m5" if preset == "" else f"_m5_{preset}")
    print("Loading data...")
    ent, h1 = load_data(tf)
    end = ent.index[-1]
    eval_start = (end - pd.Timedelta(days=365)).strftime("%Y-%m-%d")
    print(f"Eval window: {eval_start} .. {end.strftime('%Y-%m-%d')} | {tf.upper()} bars {len(ent)}")
    m = Market(ent, h1)
    import time as _t
    t0 = _t.time()
    res = run(m, eval_start)
    print(f"sim done {_t.time()-t0:.1f}s")
    st = stats(res)
    tr = res["trades"]
    import os
    os.makedirs(OUT, exist_ok=True)
    if len(tr):
        tr_out = tr.copy()
        tr_out["entry_time"] = pd.DatetimeIndex(tr_out["entry_time"]).strftime("%Y-%m-%d %H:%M")
        tr_out["exit_time"] = pd.DatetimeIndex(tr_out["exit_time"]).strftime("%Y-%m-%d %H:%M")
        tr_out["mode"] = tr_out["mode"].map(MODE_TXT)
        tr_out["dir"] = tr_out["dir"].map({1: "BUY", -1: "SELL"})
        tr_out.to_csv(f"{OUT}/backtest_trades{suffix}.csv", index=False)
    recon = P["start_balance"] + (tr.pnl.sum() if len(tr) else 0)
    print(f"RECON: {recon:,.2f} vs {st['final']:,.2f} diff {st['final']-recon:+.2f}")

    def fmt_tr(info):
        pnl, e, x, d, mo, why = info
        return (f"${pnl:+,.2f} | {pd.Timestamp(e):%Y-%m-%d %H:%M} -> "
                f"{pd.Timestamp(x):%H:%M} | {'BUY' if d == 1 else 'SELL'} | "
                f"{MODE_TXT[mo]} | exit: {why}")

    L = []
    L.append(f"# XGE v2 Backtest Report ({tf.upper()}) - XAUUSD 1 Year")
    L.append("")
    dsrc = "native M5" if tf == "m5" else "M5 resampled to M15"
    L.append(f"- Data: XAUUSD ({dsrc}, XM broker); window **{eval_start} .. {end.strftime('%Y-%m-%d')}**, warm-up on prior history")
    L.append("- v2 rules: ONLY low-vol = no trade. Uptrend: buy HL exit HH. Downtrend: sell LH exit LL.")
    L.append("  Side: support/resistance. News: momentum + rolling trailing stop-and-reverse (max 3 flips).")
    L.append(f"- Start ${P['start_balance']:,.0f}, risk {P['risk_pct']}%/trade "
             f"({P['risk_pct'] * P['dd_risk_mult']:.1f}% while recovering from a DD halt), "
             f"real broker spread (avg {ent['spread'].mean():.2f})")
    L.append(f"- DD breaker: at {P['max_dd_pct']}% halt {P['dd_halt_days']} days, then resume at reduced risk until full recovery")
    L.append("")
    L.append("## Results")
    L.append("")
    L.append("| Metric | Value |")
    L.append("|---|---|")
    L.append(f"| Net profit | ${st['net']:,.2f} ({100*st['net']/P['start_balance']:+.2f}%) |")
    L.append(f"| Final equity | ${st['final']:,.2f} |")
    L.append(f"| Closed trades | {st['trades']} |")
    L.append(f"| Win rate | {st['wr']:.1f}% |")
    L.append(f"| Profit factor | {st['pf']:.2f} |")
    L.append(f"| Avg win / avg loss | ${st['avgw']:,.2f} / ${st['avgl']:,.2f} |")
    L.append(f"| Max drawdown | {st['maxdd']:.2f}% |")
    L.append(f"| Longest losing streak | {st['streak']} |")
    L.append(f"| Sharpe (daily) | {st['sharpe']:.2f} |")
    L.append("")
    if len(tr):
        L.append("## Extremes (সর্বোচ্চ লাভ / সর্বোচ্চ লস)")
        L.append("")
        L.append("| Item | Detail |")
        L.append("|---|---|")
        L.append(f"| Single best trade (সর্বোচ্চ লাভ) | {fmt_tr(st['best_trade'])} |")
        L.append(f"| Single worst trade (সর্বোচ্চ লস) | {fmt_tr(st['worst_trade'])} |")
        bp, bd = st["best_day"]; wp, wd = st["worst_day"]
        L.append(f"| Best trading day | {bp:+,.2f} on {bd} |")
        L.append(f"| Worst trading day | {wp:+,.2f} on {wd} |")
        bcp, bcd = st["best_close_day"]; wcp, wcd = st["worst_close_day"]
        L.append(f"| Best close-to-close day | {bcp:+,.2f} on {bcd.strftime('%Y-%m-%d')} |")
        L.append(f"| Worst close-to-close day | {wcp:+,.2f} on {wcd.strftime('%Y-%m-%d')} |")
        bmp, bm = st["best_month"]; wmp, wm = st["worst_month"]
        L.append(f"| Best month | {bmp:+,.2f} ({bm}) |")
        L.append(f"| Worst month | {wmp:+,.2f} ({wm}) |")
        L.append(f"| Peak equity | ${st['peak_equity']:,.2f} |")
        L.append(f"| Lowest equity | ${st['trough_equity']:,.2f} |")
        L.append(f"| Max drawdown | {st['maxdd']:.2f}% (${st['max_dd_dollars']:,.2f}) |")
        L.append(f"| Longest winning streak | {st['win_streak']} |")
        L.append(f"| BUY total / SELL total | {st['buy_pnl'][0]:+,.2f} ({st['buy_pnl'][1]} trades) / {st['sell_pnl'][0]:+,.2f} ({st['sell_pnl'][1]} trades) |")
        L.append(f"| Median trade | ${st['median_trade']:+,.2f} |")
        L.append(f"| Expectancy per trade | ${st['expectancy']:+,.2f} |")
        L.append(f"| Hold time (avg / median / max) | {st['hold_avg_min']:.0f} / {st['hold_med_min']:.0f} / {st['hold_max_min']:.0f} min |")
        L.append("")
    if len(tr):
        rows = st["rows"].copy()
        rows["mode_txt"] = rows["mode"].map(MODE_TXT)
        by = rows.assign(month=pd.DatetimeIndex(rows.exit_time).strftime("%Y-%m")).groupby("month").agg(
            trades=("pnl", "size"), pnl=("pnl", "sum"))
        L.append("## Monthly")
        L.append("")
        L.append("| Month | Trades | P/L ($) |")
        L.append("|---|---|---|")
        for mth, row in by.iterrows():
            L.append(f"| {mth} | {int(row.trades)} | {row.pnl:+,.2f} |")
        L.append("")
        bym = rows.groupby("mode_txt").agg(trades=("pnl", "size"), pnl=("pnl", "sum"),
                                           wr=("pnl", lambda x: 100 * (x > 0).mean()))
        L.append("## By regime/strategy")
        L.append("")
        L.append("| Mode | Trades | Win% | P/L ($) |")
        L.append("|---|---|---|---|")
        for s, row in bym.iterrows():
            L.append(f"| {s} | {int(row.trades)} | {row.wr:.0f}% | {row.pnl:+,.2f} |")
        L.append("")
        byw = rows.groupby("why").agg(trades=("pnl", "size"), pnl=("pnl", "sum"))
        L.append("## By exit reason")
        L.append("")
        L.append("| Exit | Trades | P/L ($) |")
        L.append("|---|---|---|")
        for s, row in byw.iterrows():
            L.append(f"| {s} | {int(row.trades)} | {row.pnl:+,.2f} |")
        L.append("")
    tot = sum(res["modes"].values())
    L.append("## Time spent in each regime")
    L.append("")
    for mn, cnt in sorted(res["modes"].items(), key=lambda x: -x[1]):
        L.append(f"- {mn}: {cnt} bars ({100*cnt/tot:.1f}%)")
    L.append("")
    L.append("## Gate blocks")
    L.append("")
    for r, cnt in sorted(res["skip"].items(), key=lambda x: -x[1]):
        L.append(f"- {r}: {cnt}")
    L.append("")
    L.append("> Disclaimer: simulated approximation of the MT5 EA. Validate in the MT5 Strategy")
    L.append("> Tester (every tick, real ticks) before live use.")
    open(f"{OUT}/REPORT{suffix}.md", "w").write("\n".join(L))
    print("\n".join(L))

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    eq = st["eq"]
    i0t = pd.Timestamp(res["t"][res["i0"]])
    price = ent["close"].loc[i0t:].resample("1h").last()
    fig, axes = plt.subplots(3, 1, figsize=(14, 10), sharex=True,
                             gridspec_kw={"height_ratios": [3, 2, 1.2]})
    axes[0].plot(price.index, price.values, lw=0.6, color="#888")
    if len(tr):
        b = tr[tr.dir == 1]; s = tr[tr.dir == -1]
        axes[0].scatter(pd.DatetimeIndex(b.entry_time), b.entry, marker="^", s=26, color="tab:green", zorder=3)
        axes[0].scatter(pd.DatetimeIndex(s.entry_time), s.entry, marker="v", s=26, color="tab:red", zorder=3)
    axes[0].set_title(f"XAUUSD {tf.upper()} v2 entries (1 year)")
    axes[0].grid(alpha=0.25)
    axes[1].plot(eq.index, eq.values, lw=1.0, color="tab:blue")
    axes[1].axhline(P["start_balance"], color="k", lw=0.6, ls="--")
    axes[1].set_title(f"Equity (final ${st['final']:,.0f}, {100*st['net']/P['start_balance']:+.2f}%)")
    axes[1].grid(alpha=0.25)
    axes[2].fill_between(st["dd"].index, -st["dd"].values, 0, color="tab:red", alpha=0.5)
    axes[2].set_title(f"Drawdown (max {st['maxdd']:.2f}%)")
    axes[2].grid(alpha=0.25)
    plt.tight_layout()
    plt.savefig(f"{OUT}/equity_curve{suffix}.png", dpi=110)
    print(f"saved to {OUT}/")


if __name__ == "__main__":
    main()
