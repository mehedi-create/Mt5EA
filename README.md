# Mt5EA

MetaTrader 5 Expert Advisors.

## XAUUSD Adaptive Pro EA

A professional, adaptive, multi-strategy Expert Advisor for **XAUUSD (Gold)** built around one rule:

> **GOOD MARKET → TRADE · BAD MARKET → NO TRADE · UNCERTAIN MARKET → WAIT · DANGEROUS MARKET → PROTECT CAPITAL**

Location: [`Experts/XauusdAdaptiveEA/`](Experts/XauusdAdaptiveEA/)

```
Experts/XauusdAdaptiveEA/
├── XauusdAdaptiveEA.mq5        # main EA module (inputs, gates, orchestration)
├── Include/
│   ├── XGE_Define.mqh          # enums, structures, text helpers
│   ├── XGE_Market.mqh          # market condition engine (13+ conditions)
│   ├── XGE_Strategy.mqh        # 7 strategy modules + conflict resolution
│   ├── XGE_Risk.mqh            # sizing, daily/weekly/DD limits, cooldowns
│   ├── XGE_Trade.mqh           # execution, break-even, trailing, partial, smart exit
│   └── XGE_Dashboard.mqh       # on-chart status dashboard
└── README.md                   # full documentation (Bangla + English)
```

### Highlights

- **Market classification:** strong/weak up/down trends, pullbacks, breakouts (+false-breakout/sweep detection), ranges, reversals, low/high/extreme/abnormal volatility, uncertain market
- **Multi-timeframe:** higher TF for context & direction, entry TF for setups
- **Structure engine:** swing-based HH/HL/LH/LL, BOS and CHoCH detection
- **Strategy selection:** trend-follow, pullback, breakout, breakout-retest, range, reversal, liquidity-sweep — chosen by market condition, conflicts resolved or skipped
- **Capital protection first:** risk-% sizing, daily/weekly loss limits, max-drawdown halt, consecutive-loss cooldown, overtrading limits, spread/slippage/news/session/extreme-market guards
- **Trade management:** break-even, ATR trailing, partial profit, smart exit on condition flip, emergency exit, weekend flatten
- **Full transparency:** on-chart dashboard + CSV decision log (every trade *and* every skip is explained)
- **Backtest friendly:** all logic price-derived; fixed news windows for the tester; no lookahead

### Included backtest (1 year)

`backtest/` contains a faithful Python mirror of the EA
([`backtest/xge_backtest.py`](backtest/xge_backtest.py)) run on 1 year of real XAUUSD M15 data
(2025-08-21 → 2026-08-21, warmed up on 3.7 years of prior history):

- Net +5.73% with 1%/trade risk; 161 round-turn trades, 52.2% win rate
- After a ~25% equity run-up, the Nov-2025 gold crash took the account -15.5% from peak;
  the max-drawdown protection then correctly halted all new entries for the rest of the year
- Artifacts: [`backtest/REPORT.md`](backtest/REPORT.md), `backtest/equity_curve.png`, `backtest/backtest_trades.csv`

See [`Experts/XauusdAdaptiveEA/README.md`](Experts/XauusdAdaptiveEA/README.md) for installation, parameters and backtesting guidance.

> **Disclaimer:** Trading involves substantial risk of loss. This software is provided as-is, with no warranty and no profit guarantee. Always backtest and forward-test on a demo account before live use.
