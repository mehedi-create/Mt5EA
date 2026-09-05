# XGE v2 Backtest Report (M5) - XAUUSD 1 Year

- Data: XAUUSD (native M5, XM broker); window **2025-08-21 .. 2026-08-21**, warm-up on prior history
- v2 rules: ONLY low-vol = no trade. Uptrend: buy HL exit HH. Downtrend: sell LH exit LL.
  Side: support/resistance. News: momentum + rolling trailing stop-and-reverse (max 3 flips).
- Start $10,000, risk 1.0%/trade (0.5% while recovering from a DD halt), real broker spread (avg 0.20)
- DD breaker: at 15.0% halt 5 days, then resume at reduced risk until full recovery

## Results

| Metric | Value |
|---|---|
| Net profit | $-2,943.28 (-29.43%) |
| Final equity | $7,056.72 |
| Closed trades | 2531 |
| Win rate | 40.2% |
| Profit factor | 0.93 |
| Avg win / avg loss | $40.54 / $-29.17 |
| Max drawdown | 42.05% |
| Longest losing streak | 12 |
| Sharpe (daily) | -0.90 |

## Extremes (সর্বোচ্চ লাভ / সর্বোচ্চ লস)

| Item | Detail |
|---|---|
| Single best trade (সর্বোচ্চ লাভ) | $+529.05 | 2026-07-27 23:55 -> 05:30 | SELL | DOWNTREND | exit: LOWER_LOW |
| Single worst trade (সর্বোচ্চ লস) | $-109.59 | 2026-01-07 14:35 -> 14:35 | BUY | NEWS | exit: NEWS_END |
| Best trading day | +485.18 on 2026-07-28 |
| Worst trading day | -450.89 on 2025-12-26 |
| Best close-to-close day | +485.19 on 2026-07-28 |
| Worst close-to-close day | -450.91 on 2025-12-26 |
| Best month | +1,064.57 (2025-10) |
| Worst month | -1,702.03 (2026-01) |
| Peak equity | $10,577.18 |
| Lowest equity | $6,129.40 |
| Max drawdown | 42.05% ($4,447.78) |
| Longest winning streak | 7 |
| BUY total / SELL total | -2,458.67 (1291 trades) / -484.59 (1240 trades) |
| Median trade | $-11.24 |
| Expectancy per trade | $-1.16 |
| Hold time (avg / median / max) | 39 / 20 / 495 min |

## Monthly

| Month | Trades | P/L ($) |
|---|---|---|
| 2025-08 | 31 | -1,319.88 |
| 2025-09 | 186 | -538.10 |
| 2025-10 | 247 | +1,064.57 |
| 2025-11 | 220 | +421.63 |
| 2025-12 | 236 | -81.86 |
| 2026-01 | 175 | -1,702.03 |
| 2026-02 | 166 | -242.80 |
| 2026-03 | 210 | -294.25 |
| 2026-04 | 195 | -598.57 |
| 2026-05 | 211 | +159.45 |
| 2026-06 | 240 | +178.50 |
| 2026-07 | 258 | +648.87 |
| 2026-08 | 156 | -638.79 |

## By regime/strategy

| Mode | Trades | Win% | P/L ($) |
|---|---|---|---|
| DOWNTREND | 427 | 42% | +271.57 |
| NEWS | 1496 | 39% | -2,159.17 |
| SIDE | 138 | 30% | -303.59 |
| UPTREND | 470 | 47% | -752.07 |

## By exit reason

| Exit | Trades | P/L ($) |
|---|---|---|
| EMERGENCY | 2 | -95.70 |
| HIGHER_HIGH | 207 | +6,734.75 |
| LOWER_LOW | 168 | +7,056.67 |
| NEWS_END | 530 | +13,575.47 |
| REGIME_CHG | 57 | +124.12 |
| SL | 428 | -15,801.55 |
| TP | 17 | +2,021.82 |
| TRAIL_STOP | 966 | -15,734.64 |
| TREND_REV | 150 | -954.79 |
| WEEKEND | 6 | +130.59 |

## Time spent in each regime

- UPTREND: 28560 bars (40.2%)
- DOWNTREND: 26278 bars (37.0%)
- NEWS: 9974 bars (14.0%)
- SIDE: 4092 bars (5.8%)
- LOW VOL (no trade): 2155 bars (3.0%)

## Gate blocks

- same-setup: 2213
- cooldown: 1361
- max trades/day: 1117
- max dd: 825
- friday: 681
- loss limit: 598
- min-lot: 182
- gap: 18
- spread: 14

> Disclaimer: simulated approximation of the MT5 EA. Validate in the MT5 Strategy
> Tester (every tick, real ticks) before live use.