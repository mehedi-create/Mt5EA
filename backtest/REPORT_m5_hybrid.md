# XGE v2 Backtest Report (M5) - XAUUSD 1 Year

- Data: XAUUSD (native M5, XM broker); window **2025-08-21 .. 2026-08-21**, warm-up on prior history
- v2 rules: ONLY low-vol = no trade. Uptrend: buy HL exit HH. Downtrend: sell LH exit LL.
  Side: support/resistance. News: momentum + rolling trailing stop-and-reverse (max 3 flips).
- Start $10,000, risk 1.0%/trade (0.5% while recovering from a DD halt), real broker spread (avg 0.20)
- DD breaker: at 15.0% halt 5 days, then resume at reduced risk until full recovery

## Results

| Metric | Value |
|---|---|
| Net profit | $6,337.05 (+63.37%) |
| Final equity | $16,337.05 |
| Closed trades | 2385 |
| Win rate | 47.1% |
| Profit factor | 1.08 |
| Avg win / avg loss | $76.52 / $-63.07 |
| Max drawdown | 22.62% |
| Longest losing streak | 10 |
| Sharpe (daily) | 1.40 |

## Extremes (সর্বোচ্চ লাভ / সর্বোচ্চ লস)

| Item | Detail |
|---|---|
| Single best trade (সর্বোচ্চ লাভ) | $+890.22 | 2026-08-07 00:00 -> 00:40 | SELL | SIDE | exit: TP |
| Single worst trade (সর্বোচ্চ লস) | $-184.46 | 2026-08-09 22:00 -> 22:05 | BUY | UPTREND | exit: SL |
| Best trading day | +1,517.23 on 2026-08-07 |
| Worst trading day | -644.83 on 2026-08-10 |
| Best close-to-close day | +1,517.22 on 2026-08-07 |
| Worst close-to-close day | -644.83 on 2026-08-10 |
| Best month | +2,129.54 (2025-10) |
| Worst month | -1,372.62 (2025-11) |
| Peak equity | $18,922.48 |
| Lowest equity | $9,826.03 |
| Max drawdown | 22.62% ($3,376.94) |
| Longest winning streak | 9 |
| BUY total / SELL total | +2,434.44 (1264 trades) / +3,902.84 (1121 trades) |
| Median trade | $-5.23 |
| Expectancy per trade | $+2.66 |
| Hold time (avg / median / max) | 31 / 20 / 445 min |

## Monthly

| Month | Trades | P/L ($) |
|---|---|---|
| 2025-08 | 70 | +1,596.59 |
| 2025-09 | 177 | +243.33 |
| 2025-10 | 200 | +2,129.54 |
| 2025-11 | 120 | -1,372.62 |
| 2025-12 | 235 | -753.96 |
| 2026-01 | 204 | +1,364.42 |
| 2026-02 | 202 | -176.10 |
| 2026-03 | 243 | +365.00 |
| 2026-04 | 225 | -814.14 |
| 2026-05 | 186 | -538.01 |
| 2026-06 | 240 | +1,254.13 |
| 2026-07 | 207 | +2,115.39 |
| 2026-08 | 76 | +923.71 |

## By regime/strategy

| Mode | Trades | Win% | P/L ($) |
|---|---|---|---|
| DOWNTREND | 657 | 48% | +2,025.03 |
| NEWS | 695 | 47% | +1,400.21 |
| SIDE | 244 | 34% | +1,450.24 |
| UPTREND | 789 | 51% | +1,461.80 |

## Detailed per-mode breakdown

| Mode | Trades | Win% | P/L ($) | Avg win | Avg loss | Best trade | Worst trade | Avg hold (min) |
|---|---|---|---|---|---|---|---|---|
| DOWNTREND | 657 | 48% | +2,025.03 | +78.27 | -66.17 | +638 (08-03 06:15,SELL) | -168 (08-10 03:50,SELL) | 35 |
| NEWS | 695 | 47% | +1,400.21 | +60.90 | -49.41 | +731 (08-22 13:35,BUY) | -180 (08-07 13:35,BUY) | 30 |
| SIDE | 244 | 34% | +1,450.24 | +163.61 | -73.86 | +890 (08-07 00:00,SELL) | -184 (08-10 01:15,BUY) | 29 |
| UPTREND | 789 | 51% | +1,461.80 | +69.98 | -68.91 | +743 (07-02 12:25,BUY) | -184 (08-09 22:00,BUY) | 30 |

### Per-mode exits (P/L $, count)

| Mode | HIGHER_HIGH | LOWER_LOW | NEWS_END | TP | REGIME_CHG | TREND_REV | WEEKEND | EMERGENCY | SL | TRAIL_STOP |
|---|---|---|---|---|---|---|---|---|---|---|
| DOWNTREND | - | +22,765 (354) | - | - | - | +125 (36) | +1 (2) | -57 (1) | -20,810 (264) | - |
| NEWS | - | - | +13,648 (463) | - | - | - | - | - | - | -12,248 (232) |
| SIDE | - | - | - | +5,721 (17) | +6,969 (90) | - | - | - | -11,239 (137) | - |
| UPTREND | +26,214 (467) | - | - | - | - | +310 (29) | +46 (3) | - | -25,108 (290) | - |

## By exit reason

| Exit | Trades | P/L ($) |
|---|---|---|
| EMERGENCY | 1 | -56.89 |
| HIGHER_HIGH | 467 | +26,213.93 |
| LOWER_LOW | 354 | +22,765.10 |
| NEWS_END | 463 | +13,648.39 |
| REGIME_CHG | 90 | +6,968.89 |
| SL | 691 | -57,157.26 |
| TP | 17 | +5,720.77 |
| TRAIL_STOP | 232 | -12,248.18 |
| TREND_REV | 65 | +435.55 |
| WEEKEND | 5 | +46.98 |

## Time spent in each regime

- UPTREND: 29780 bars (41.9%)
- DOWNTREND: 25633 bars (36.1%)
- NEWS: 10065 bars (14.2%)
- SIDE: 3928 bars (5.5%)
- LOW VOL (no trade): 1653 bars (2.3%)

## Gate blocks

- same-setup: 4355
- loss limit: 1508
- cooldown: 1158
- friday: 898
- max trades/day: 871
- max dd: 472
- spread: 9
- min-lot: 6
- gap: 5

> Disclaimer: simulated approximation of the MT5 EA. Validate in the MT5 Strategy
> Tester (every tick, real ticks) before live use.