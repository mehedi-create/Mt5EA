# XGE v2 Backtest Report (M5) - XAUUSD 1 Year

- Data: XAUUSD (native M5, XM broker); window **2025-08-21 .. 2026-08-21**, warm-up on prior history
- v2 rules: ONLY low-vol = no trade. Uptrend: buy HL exit HH. Downtrend: sell LH exit LL.
  Side: support/resistance. News: momentum + rolling trailing stop-and-reverse (max 3 flips).
- Start $10,000, risk 1.0%/trade (0.5% while recovering from a DD halt), real broker spread (avg 0.20)
- DD breaker: at 15.0% halt 5 days, then resume at reduced risk until full recovery

## Results

| Metric | Value |
|---|---|
| Net profit | $-2,479.71 (-24.80%) |
| Final equity | $7,520.29 |
| Closed trades | 2793 |
| Win rate | 43.5% |
| Profit factor | 0.95 |
| Avg win / avg loss | $39.30 / $-31.88 |
| Max drawdown | 39.96% |
| Longest losing streak | 13 |
| Sharpe (daily) | -0.62 |

## Extremes (সর্বোচ্চ লাভ / সর্বোচ্চ লস)

| Item | Detail |
|---|---|
| Single best trade (সর্বোচ্চ লাভ) | $+512.32 | 2026-07-13 13:45 -> 14:35 | SELL | NEWS | exit: NEWS_END |
| Single worst trade (সর্বোচ্চ লস) | $-103.03 | 2025-08-21 08:30 -> 08:40 | BUY | NEWS | exit: TRAIL_STOP |
| Best trading day | +632.41 on 2026-07-06 |
| Worst trading day | -458.84 on 2026-07-17 |
| Best close-to-close day | +632.41 on 2026-07-06 |
| Worst close-to-close day | -458.84 on 2026-07-17 |
| Best month | +1,155.23 (2025-11) |
| Worst month | -1,435.80 (2025-12) |
| Peak equity | $10,435.23 |
| Lowest equity | $6,265.37 |
| Max drawdown | 39.96% ($4,169.85) |
| Longest winning streak | 9 |
| BUY total / SELL total | -1,237.66 (1441 trades) / -1,241.92 (1352 trades) |
| Median trade | $-7.02 |
| Expectancy per trade | $-0.89 |
| Hold time (avg / median / max) | 24 / 15 / 1770 min |

## Monthly

| Month | Trades | P/L ($) |
|---|---|---|
| 2025-08 | 82 | -171.01 |
| 2025-09 | 155 | -562.03 |
| 2025-10 | 291 | -278.99 |
| 2025-11 | 245 | +1,155.23 |
| 2025-12 | 200 | -1,435.80 |
| 2026-01 | 253 | -295.92 |
| 2026-02 | 251 | -720.37 |
| 2026-03 | 230 | -611.32 |
| 2026-04 | 146 | -528.50 |
| 2026-05 | 270 | +122.80 |
| 2026-06 | 278 | +419.67 |
| 2026-07 | 204 | +391.71 |
| 2026-08 | 188 | +34.95 |

## By regime/strategy

| Mode | Trades | Win% | P/L ($) |
|---|---|---|---|
| DOWNTREND | 677 | 45% | -61.60 |
| NEWS | 1133 | 40% | -1,594.61 |
| SIDE | 248 | 40% | +216.54 |
| UPTREND | 735 | 48% | -1,039.91 |

## Detailed per-mode breakdown

| Mode | Trades | Win% | P/L ($) | Avg win | Avg loss | Best trade | Worst trade | Avg hold (min) |
|---|---|---|---|---|---|---|---|---|
| DOWNTREND | 677 | 45% | -61.60 | +39.76 | -33.35 | +424 (08-21 05:45,SELL) | -98 (12-04 07:30,SELL) | 28 |
| NEWS | 1133 | 40% | -1,594.61 | +41.29 | -30.06 | +512 (07-13 13:45,SELL) | -103 (08-21 08:30,BUY) | 21 |
| SIDE | 248 | 40% | +216.54 | +51.16 | -32.54 | +269 (12-08 05:20,BUY) | -98 (09-01 09:10,BUY) | 13 |
| UPTREND | 735 | 48% | -1,039.91 | +33.02 | -33.41 | +372 (07-02 12:25,BUY) | -103 (12-04 05:05,BUY) | 29 |

### Per-mode exits (P/L $, count)

| Mode | HIGHER_HIGH | LOWER_LOW | NEWS_END | TP | REGIME_CHG | TREND_REV | WEEKEND | EMERGENCY | SL | TRAIL_STOP |
|---|---|---|---|---|---|---|---|---|---|---|
| DOWNTREND | - | +11,077 (320) | - | - | - | -237 (91) | - | - | -10,902 (266) | - |
| NEWS | - | - | +11,167 (428) | - | - | - | - | - | - | -12,762 (705) |
| SIDE | - | - | - | +1,673 (14) | +2,376 (142) | - | - | - | -3,832 (92) | - |
| UPTREND | +10,629 (384) | - | - | - | - | -233 (85) | +23 (1) | - | -11,459 (265) | - |

## By exit reason

| Exit | Trades | P/L ($) |
|---|---|---|
| HIGHER_HIGH | 384 | +10,629.02 |
| LOWER_LOW | 320 | +11,077.11 |
| NEWS_END | 428 | +11,166.93 |
| REGIME_CHG | 142 | +2,375.75 |
| SL | 623 | -26,192.76 |
| TP | 14 | +1,672.75 |
| TRAIL_STOP | 705 | -12,761.54 |
| TREND_REV | 176 | -469.54 |
| WEEKEND | 1 | +22.70 |

## Time spent in each regime

- UPTREND: 29218 bars (41.1%)
- DOWNTREND: 26018 bars (36.6%)
- NEWS: 10065 bars (14.2%)
- SIDE: 4105 bars (5.8%)
- LOW VOL (no trade): 1653 bars (2.3%)

## Gate blocks

- max trades/day: 5472
- same-setup: 2621
- cooldown: 1706
- max dd: 1654
- loss limit: 1604
- friday: 932
- min-lot: 51
- spread: 14
- gap: 7

> Disclaimer: simulated approximation of the MT5 EA. Validate in the MT5 Strategy
> Tester (every tick, real ticks) before live use.