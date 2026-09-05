# Mt5EA

MetaTrader 5 Expert Advisors.

## XAUUSD Adaptive Pro EA (v2 — regime trading)

A professional, adaptive Expert Advisor for **XAUUSD (Gold)** built around one idea:

> **Trade every market state with the right playbook — the only true no-trade state is dead (low) volatility — and protect capital first when things go wrong.**

v2 was rebuilt from v1 around a lesson learned in backtesting: heavy filtering only
reduces the trade count, it does not create profit. So v2 replaces the filter stack
with four structured trading modes and keeps only the protections that matter.

Location: [`Experts/XauusdAdaptiveEA/`](Experts/XauusdAdaptiveEA/)

```
Experts/XauusdAdaptiveEA/
├── XauusdAdaptiveEA.mq5        # main EA module (inputs, gates, orchestration)
├── Include/
│   ├── XGE_Define.mqh          # enums (mode, state), text helpers
│   ├── XGE_Market.mqh          # regime engine: trend, swings, range, volatility
│   ├── XGE_Strategy.mqh        # mode signals: HL-buy, LH-sell, S/R, news momentum
│   ├── XGE_Risk.mqh            # sizing, daily/weekly/DD limits, recoverable DD breaker
│   ├── XGE_Trade.mqh           # execution, per-mode management, trailing, stop-and-reverse
│   └── XGE_Dashboard.mqh       # on-chart status dashboard
└── README.md                   # full documentation (Bangla + English)
```

### The four operating modes

| Mode | Entry | Exit |
|---|---|---|
| **UPTREND** | BUY at a *fresh* Higher Low (confirmed swing, ≤ N bars old) | Higher High (structure exit), trailing stop, or trend reversal |
| **DOWNTREND** | SELL at a *fresh* Lower High | Lower Low (structure exit), trailing stop, or trend reversal |
| **SIDE (range)** | BUY at support / SELL at resistance zone (never mid-range) | Opposite side of the range (TP), R:R ≥ 1.0 |
| **NEWS** | Momentum direction when the window opens/price breaks (body ≥ 0.4×ATR) | Rolling trailing stop (1.2×ATR); on stop-out the EA **reverses** with a fresh trailing stop (max 3 flips), flat at window end |
| LOW VOL | **No trade** — the only blocked state (ATR ratio < 0.55) | — |

News windows default to 13:30 / 15:00 / 19:00 server time (±30 min), tunable.

### Capital protection (kept minimal on purpose)

- Risk-% sizing off the smaller of balance/equity, structural SL clamped to 0.8–4.0×ATR, lot cap, margin check
- Daily 3% / weekly 6% realized-loss limits
- **Recoverable max-drawdown breaker:** at 15% from peak new entries pause for 5 days,
  then trading resumes at **half risk** until equity recovers to the pre-halt peak
- Consecutive-loss cooldown, max trades/day, min entry gap, same-setup dedupe, spread guard
- Friday entry stop + weekend flatten, emergency exit on 5×ATR adverse move
- Every entry reason and every skip reason is logged (CSV + Experts log)

### Included backtests (1 year, real XM broker data)

`backtest/` contains a faithful Python mirror of the EA
([`backtest/xge_backtest.py`](backtest/xge_backtest.py)) run on 1 year of XAUUSD
(2025-08-21 → 2026-08-21, warmed up on 3.7 years of prior history), $10,000 start, 1% risk:

| Config | Net | Trades | PF | Max DD | Report |
|---|---|---|---|---|---|
| **M15** (recommended) | **+24.92%** | 1,962 | 1.04 | 22.96% | [`REPORT.md`](backtest/REPORT.md) |
| **M5 hybrid** (HTF regime) | **+63.37%** | 2,385 | 1.08 | 22.62% | [`REPORT_m5_hybrid.md`](backtest/REPORT_m5_hybrid.md) |
| M5 raw (v2.0 detection) | −24.80% | 2,793 | 0.95 | 39.96% | [`REPORT_m5.md`](backtest/REPORT_m5.md) |

**v2.1 detection upgrade:** M5 charts previously mis-detected trends because 3-bar
windows become 15-minute windows and micro-swings pollute structure. v2.1 fixes this with
(1) an **amplitude-filtered swing model** (a swing only counts when it is ≥ 0.5×ATR beyond
the previous opposite swing — improves M15 *and* M5) and (2) an **HTF-anchored regime**
for M5: trend/S&R come from completed M15 swings while entry timing stays on M5. Do **not**
run raw v2.0 logic on M5 — it loses to spread costs and noise.

Honest caveats on the M5 number: it comes from the trail-2.0 configuration and M5 results
are sensitive to the news trail distance (1.5×→+28%, 1.8–2.0×→+63/+68%, 2.5×→+21% on this
one year). Treat the M5 figure as optimistic until re-validated in the MT5 Strategy Tester
on out-of-sample data; the M15 configuration is the more robust one.

This is a **simulation approximation**, not an MT5 tester run. Always validate in the
MT5 Strategy Tester ("Every tick based on real ticks") before any live use.

See [`Experts/XauusdAdaptiveEA/README.md`](Experts/XauusdAdaptiveEA/README.md) for installation, parameters and backtesting guidance.

> **Disclaimer:** Trading involves substantial risk of loss. This software is provided as-is, with no warranty and no profit guarantee. Past backtest results do not guarantee future performance. Always backtest and forward-test on a demo account before live use.
