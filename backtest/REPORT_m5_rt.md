# XGE v2 Backtest Report (M5) - XAUUSD 1 Year

- Data: XAUUSD (native M5, XM broker); window **2025-08-21 .. 2026-08-21**, warm-up on prior history
- v2 rules: ONLY low-vol = no trade. Uptrend: buy HL exit HH. Downtrend: sell LH exit LL.
  Side: support/resistance. News: momentum + rolling trailing stop-and-reverse (max 3 flips).
- Start $10,000, risk 1.0%/trade (0.5% while recovering from a DD halt), real broker spread (avg 0.20)
- DD breaker: at 15.0% halt 5 days, then resume at reduced risk until full recovery

## Results

| Metric | Value |
|---|---|
| Net profit | $-3,132.50 (-31.32%) |
| Final equity | $6,867.50 |
| Closed trades | 2458 |
| Win rate | 39.6% |
| Profit factor | 0.93 |
| Avg win / avg loss | $41.68 / $-29.47 |
| Max drawdown | 38.93% |
| Longest losing streak | 11 |
| Sharpe (daily) | -0.90 |

## Extremes (সর্বোচ্চ লাভ / সর্বোচ্চ লস)

| Item | Detail |
|---|---|
| Single best trade (সর্বোচ্চ লাভ) | $+1,022.83 | 2026-07-27 23:55 -> 05:30 | SELL | DOWNTREND | exit: LOWER_LOW |
| Single worst trade (সর্বোচ্চ লস) | $-101.15 | 2025-08-21 08:30 -> 08:40 | BUY | NEWS | exit: TRAIL_STOP |
| Best trading day | +911.04 on 2026-07-28 |
| Worst trading day | -441.43 on 2025-08-22 |
| Best close-to-close day | +911.05 on 2026-07-28 |
| Worst close-to-close day | -441.43 on 2025-08-22 |
| Best month | +1,045.50 (2025-10) |
| Worst month | -1,390.99 (2026-01) |
| Peak equity | $10,122.68 |
| Lowest equity | $6,181.68 |
| Max drawdown | 38.93% ($3,941.00) |
| Longest winning streak | 10 |
| BUY total / SELL total | -2,530.83 (1252 trades) / -601.75 (1206 trades) |
| Median trade | $-12.61 |
| Expectancy per trade | $-1.27 |
| Hold time (avg / median / max) | 40 / 20 / 1755 min |

## Monthly

| Month | Trades | P/L ($) |
|---|---|---|
| 2025-08 | 31 | -1,319.88 |
| 2025-09 | 188 | -639.70 |
| 2025-10 | 247 | +1,045.50 |
| 2025-11 | 222 | +333.95 |
| 2025-12 | 244 | +74.04 |
| 2026-01 | 186 | -1,390.99 |
| 2026-02 | 188 | -305.92 |
| 2026-03 | 166 | -591.65 |
| 2026-04 | 224 | -458.33 |
| 2026-05 | 187 | +172.84 |
| 2026-06 | 239 | +181.71 |
| 2026-07 | 251 | +418.23 |
| 2026-08 | 85 | -652.38 |

## By regime/strategy

| Mode | Trades | Win% | P/L ($) |
|---|---|---|---|
| DOWNTREND | 415 | 40% | +40.41 |
| NEWS | 1458 | 39% | -1,429.34 |
| SIDE | 137 | 28% | -720.01 |
| UPTREND | 448 | 46% | -1,023.64 |

## Detailed per-mode breakdown

| Mode | Trades | Win% | P/L ($) | Avg win | Avg loss | Best trade | Worst trade | Avg hold (min) |
|---|---|---|---|---|---|---|---|---|
| DOWNTREND | 415 | 40% | +40.41 | +45.97 | -30.48 | +1,023 (07-27 23:55,SELL) | -88 (08-22 00:35,SELL) | 78 |
| NEWS | 1458 | 39% | -1,429.34 | +41.76 | -28.10 | +304 (10-02 13:35,SELL) | -101 (08-21 08:30,BUY) | 21 |
| SIDE | 137 | 28% | -720.01 | +63.46 | -31.63 | +227 (12-18 14:45,BUY) | -91 (08-21 12:15,SELL) | 21 |
| UPTREND | 448 | 46% | -1,023.64 | +33.89 | -32.53 | +300 (11-09 23:30,BUY) | -92 (08-25 16:25,BUY) | 74 |

### Per-mode exits (P/L $, count)

| Mode | HIGHER_HIGH | LOWER_LOW | NEWS_END | TP | REGIME_CHG | TREND_REV | WEEKEND | EMERGENCY | SL | TRAIL_STOP |
|---|---|---|---|---|---|---|---|---|---|---|
| DOWNTREND | - | +7,125 (156) | - | - | - | -633 (78) | +7 (1) | -44 (2) | -6,415 (178) | - |
| NEWS | - | - | +13,784 (518) | - | - | - | - | - | - | -15,213 (940) |
| SIDE | - | - | - | +1,565 (15) | +268 (57) | - | - | - | -2,553 (65) | - |
| UPTREND | +6,392 (194) | - | - | - | - | -519 (69) | +122 (6) | - | -7,018 (179) | - |

## By exit reason

| Exit | Trades | P/L ($) |
|---|---|---|
| EMERGENCY | 2 | -43.91 |
| HIGHER_HIGH | 194 | +6,391.71 |
| LOWER_LOW | 156 | +7,125.30 |
| NEWS_END | 518 | +13,783.80 |
| REGIME_CHG | 57 | +268.18 |
| SL | 422 | -15,986.13 |
| TP | 15 | +1,564.92 |
| TRAIL_STOP | 940 | -15,213.14 |
| TREND_REV | 147 | -1,151.97 |
| WEEKEND | 7 | +128.66 |

## Time spent in each regime

- UPTREND: 28606 bars (40.3%)
- DOWNTREND: 26213 bars (36.9%)
- NEWS: 9974 bars (14.0%)
- SIDE: 4111 bars (5.8%)
- LOW VOL (no trade): 2155 bars (3.0%)

## Gate blocks

- same-setup: 2082
- cooldown: 1398
- max trades/day: 1091
- max dd: 998
- loss limit: 807
- friday: 678
- min-lot: 175
- gap: 15
- spread: 14

> Disclaimer: simulated approximation of the MT5 EA. Validate in the MT5 Strategy
> Tester (every tick, real ticks) before live use.