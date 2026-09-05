# XGE v2 Backtest Report (M15) - XAUUSD 1 Year

- Data: XAUUSD (M5 resampled to M15, XM broker); window **2025-08-21 .. 2026-08-21**, warm-up on prior history
- v2 rules: ONLY low-vol = no trade. Uptrend: buy HL exit HH. Downtrend: sell LH exit LL.
  Side: support/resistance. News: momentum + rolling trailing stop-and-reverse (max 3 flips).
- Start $10,000, risk 1.0%/trade (0.5% while recovering from a DD halt), real broker spread (avg 0.20)
- DD breaker: at 15.0% halt 5 days, then resume at reduced risk until full recovery

## Results

| Metric | Value |
|---|---|
| Net profit | $2,491.66 (+24.92%) |
| Final equity | $12,491.66 |
| Closed trades | 1962 |
| Win rate | 45.6% |
| Profit factor | 1.04 |
| Avg win / avg loss | $65.71 / $-52.67 |
| Max drawdown | 22.96% |
| Longest losing streak | 11 |
| Sharpe (daily) | 0.78 |

## Extremes (সর্বোচ্চ লাভ / সর্বোচ্চ লস)

| Item | Detail |
|---|---|
| Single best trade (সর্বোচ্চ লাভ) | $+922.99 | 2025-08-22 13:30 -> 14:45 | BUY | NEWS | exit: NEWS_END |
| Single worst trade (সর্বোচ্চ লস) | $-146.37 | 2025-11-18 23:45 -> 01:00 | BUY | UPTREND | exit: SL |
| Best trading day | +1,075.05 on 2025-08-22 |
| Worst trading day | -569.06 on 2025-11-20 |
| Best close-to-close day | +1,074.89 on 2025-08-22 |
| Worst close-to-close day | -569.05 on 2025-11-20 |
| Best month | +1,336.13 (2025-08) |
| Worst month | -1,032.43 (2026-07) |
| Peak equity | $15,372.45 |
| Lowest equity | $9,872.78 |
| Max drawdown | 22.96% ($3,529.18) |
| Longest winning streak | 7 |
| BUY total / SELL total | +1,656.51 (1017 trades) / +835.52 (945 trades) |
| Median trade | $-7.38 |
| Expectancy per trade | $+1.27 |
| Hold time (avg / median / max) | 64 / 45 / 1545 min |

## Monthly

| Month | Trades | P/L ($) |
|---|---|---|
| 2025-08 | 57 | +1,336.13 |
| 2025-09 | 162 | +1,056.10 |
| 2025-10 | 180 | +1,289.92 |
| 2025-11 | 138 | -442.44 |
| 2025-12 | 156 | -773.91 |
| 2026-01 | 170 | -280.99 |
| 2026-02 | 152 | +137.97 |
| 2026-03 | 163 | +1,068.29 |
| 2026-04 | 170 | -641.61 |
| 2026-05 | 155 | -115.41 |
| 2026-06 | 177 | +850.95 |
| 2026-07 | 158 | -1,032.43 |
| 2026-08 | 124 | +39.46 |

## By regime/strategy

| Mode | Trades | Win% | P/L ($) |
|---|---|---|---|
| DOWNTREND | 445 | 46% | +1,644.08 |
| NEWS | 909 | 43% | -108.69 |
| SIDE | 115 | 40% | -133.28 |
| UPTREND | 493 | 50% | +1,089.92 |

## Detailed per-mode breakdown

| Mode | Trades | Win% | P/L ($) | Avg win | Avg loss | Best trade | Worst trade | Avg hold (min) |
|---|---|---|---|---|---|---|---|---|
| DOWNTREND | 445 | 46% | +1,644.08 | +71.98 | -55.17 | +583 (11-17 15:15,SELL) | -142 (11-21 10:45,SELL) | 95 |
| NEWS | 909 | 43% | -108.69 | +63.09 | -48.70 | +923 (08-22 13:30,BUY) | -144 (11-19 08:00,SELL) | 38 |
| SIDE | 115 | 40% | -133.28 | +81.15 | -56.03 | +446 (11-19 02:00,BUY) | -142 (11-20 13:15,SELL) | 40 |
| UPTREND | 493 | 50% | +1,089.92 | +61.80 | -57.62 | +632 (11-09 23:30,BUY) | -146 (11-18 23:45,BUY) | 89 |

### Per-mode exits (P/L $, count)

| Mode | HIGHER_HIGH | LOWER_LOW | NEWS_END | TP | REGIME_CHG | TREND_REV | WEEKEND | EMERGENCY | SL | TRAIL_STOP |
|---|---|---|---|---|---|---|---|---|---|---|
| DOWNTREND | - | +13,021 (207) | - | - | - | -81 (82) | - | - | -11,297 (156) | - |
| NEWS | - | - | +17,982 (568) | - | - | - | - | - | - | -18,091 (341) |
| SIDE | - | - | - | +963 (5) | +2,003 (70) | - | - | - | -3,100 (40) | - |
| UPTREND | +13,408 (245) | - | - | - | - | -133 (71) | +255 (10) | - | -12,440 (167) | - |

## By exit reason

| Exit | Trades | P/L ($) |
|---|---|---|
| HIGHER_HIGH | 245 | +13,407.51 |
| LOWER_LOW | 207 | +13,021.44 |
| NEWS_END | 568 | +17,981.88 |
| REGIME_CHG | 70 | +2,003.26 |
| SL | 363 | -26,836.16 |
| TP | 5 | +963.19 |
| TRAIL_STOP | 341 | -18,090.57 |
| TREND_REV | 153 | -213.36 |
| WEEKEND | 10 | +254.84 |

## Time spent in each regime

- UPTREND: 9845 bars (41.5%)
- DOWNTREND: 8521 bars (36.0%)
- NEWS: 3844 bars (16.2%)
- SIDE: 1298 bars (5.5%)
- LOW VOL (no trade): 187 bars (0.8%)

## Gate blocks

- same-setup: 1616
- cooldown: 371
- friday: 305
- loss limit: 184
- max dd: 120
- min-lot: 36
- max trades/day: 22
- gap: 11
- spread: 6

> Disclaimer: simulated approximation of the MT5 EA. Validate in the MT5 Strategy
> Tester (every tick, real ticks) before live use.