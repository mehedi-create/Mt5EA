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

See [`Experts/XauusdAdaptiveEA/README.md`](Experts/XauusdAdaptiveEA/README.md) for installation, parameters and backtesting guidance.

> **Disclaimer:** Trading involves substantial risk of loss. This software is provided as-is, with no warranty and no profit guarantee. Past backtest results do not guarantee future performance. Always backtest and forward-test on a demo account before live use.
