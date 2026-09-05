# XGE v2 Backtest Report (M5) - XAUUSD 1 Year

- Data: XAUUSD (native M5, XM broker); window **2025-08-21 .. 2026-08-21**, warm-up on prior history
- v2 rules: ONLY low-vol = no trade. Uptrend: buy HL exit HH. Downtrend: sell LH exit LL.
  Side: support/resistance. News: momentum + rolling trailing stop-and-reverse (max 3 flips).
- Start $10,000, risk 1.0%/trade (0.5% while recovering from a DD halt), real broker spread (avg 0.20)
- DD breaker: at 15.0% halt 5 days, then resume at reduced risk until full recovery

## Results

| Metric | Value |
|---|---|
| Net profit | $-1,095.92 (-10.96%) |
| Final equity | $8,904.08 |
| Closed trades | 2962 |
| Win rate | 44.2% |
| Profit factor | 0.98 |
| Avg win / avg loss | $40.91 / $-33.10 |
| Max drawdown | 30.40% |
| Longest losing streak | 9 |
| Sharpe (daily) | -0.14 |

## Extremes (সর্বোচ্চ লাভ / সর্বোচ্চ লস)

| Item | Detail |
|---|---|
| Single best trade (সর্বোচ্চ লাভ) | $+597.70 | 2026-07-13 13:45 -> 14:35 | SELL | NEWS | exit: NEWS_END |
| Single worst trade (সর্বোচ্চ লস) | $-103.03 | 2025-08-21 08:30 -> 08:40 | BUY | NEWS | exit: TRAIL_STOP |
| Best trading day | +734.38 on 2026-07-06 |
| Worst trading day | -403.94 on 2026-07-23 |
| Best close-to-close day | +734.37 on 2026-07-06 |
| Worst close-to-close day | -403.96 on 2026-07-23 |
| Best month | +1,027.70 (2025-11) |
| Worst month | -1,259.24 (2026-01) |
| Peak equity | $10,461.49 |
| Lowest equity | $7,198.05 |
| Max drawdown | 30.40% ($3,143.88) |
| Longest winning streak | 9 |
| BUY total / SELL total | -588.26 (1542 trades) / -507.74 (1420 trades) |
| Median trade | $-7.11 |
| Expectancy per trade | $-0.37 |
| Hold time (avg / median / max) | 24 / 15 / 215 min |

## Monthly

| Month | Trades | P/L ($) |
|---|---|---|
| 2025-08 | 82 | -172.26 |
| 2025-09 | 211 | -524.55 |
| 2025-10 | 290 | -320.65 |
| 2025-11 | 243 | +1,027.70 |
| 2025-12 | 276 | -31.35 |
| 2026-01 | 231 | -1,259.24 |
| 2026-02 | 238 | -556.26 |
| 2026-03 | 276 | -527.90 |
| 2026-04 | 180 | -94.85 |
| 2026-05 | 269 | +273.97 |
| 2026-06 | 276 | +566.91 |
| 2026-07 | 201 | +478.18 |
| 2026-08 | 189 | +44.30 |

## By regime/strategy

| Mode | Trades | Win% | P/L ($) |
|---|---|---|---|
| DOWNTREND | 709 | 46% | +434.01 |
| NEWS | 1195 | 40% | -957.19 |
| SIDE | 261 | 42% | +499.67 |
| UPTREND | 797 | 49% | -1,072.49 |

## By exit reason

| Exit | Trades | P/L ($) |
|---|---|---|
| HIGHER_HIGH | 417 | +12,330.34 |
| LOWER_LOW | 343 | +12,190.76 |
| NEWS_END | 452 | +12,548.16 |
| REGIME_CHG | 148 | +2,694.55 |
| SL | 654 | -28,889.98 |
| TP | 19 | +2,083.29 |
| TRAIL_STOP | 743 | -13,505.35 |
| TREND_REV | 185 | -564.80 |
| WEEKEND | 1 | +17.03 |

## Time spent in each regime

- UPTREND: 29219 bars (41.1%)
- DOWNTREND: 26008 bars (36.6%)
- NEWS: 10065 bars (14.2%)
- SIDE: 4114 bars (5.8%)
- LOW VOL (no trade): 1653 bars (2.3%)

## Gate blocks

- max trades/day: 6003
- same-setup: 2916
- cooldown: 1751
- max dd: 1193
- friday: 945
- loss limit: 935
- min-lot: 27
- spread: 14
- gap: 7

> Disclaimer: simulated approximation of the MT5 EA. Validate in the MT5 Strategy
> Tester (every tick, real ticks) before live use.