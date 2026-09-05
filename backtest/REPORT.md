# XGE v2 Backtest Report - XAUUSD 1 Year

- Data: XAUUSD M5 (XM) resampled M15; window **2025-08-21 .. 2026-08-21**, warm-up on prior history
- v2 rules: ONLY low-vol = no trade. Uptrend: buy HL exit HH. Downtrend: sell LH exit LL.
  Side: support/resistance. News: momentum + rolling trailing stop-and-reverse (max 3 flips).
- Start $10,000, risk 1.0%/trade (0.5% while recovering from a DD halt), real broker spread (avg 0.20)
- DD breaker: at 15.0% halt 5 days, then resume at reduced risk until full recovery

## Results

| Metric | Value |
|---|---|
| Net profit | $1,721.50 (+17.22%) |
| Final equity | $11,721.50 |
| Closed trades | 1943 |
| Win rate | 45.3% |
| Profit factor | 1.03 |
| Avg win / avg loss | $63.20 / $-50.81 |
| Max drawdown | 26.25% |
| Longest losing streak | 11 |
| Sharpe (daily) | 0.60 |

## Monthly

| Month | Trades | P/L ($) |
|---|---|---|
| 2025-08 | 57 | +1,336.13 |
| 2025-09 | 166 | +846.28 |
| 2025-10 | 168 | +1,130.50 |
| 2025-11 | 141 | -322.95 |
| 2025-12 | 154 | -1,110.78 |
| 2026-01 | 169 | -328.25 |
| 2026-02 | 144 | -167.95 |
| 2026-03 | 163 | +888.77 |
| 2026-04 | 168 | -379.10 |
| 2026-05 | 157 | -19.29 |
| 2026-06 | 175 | +772.10 |
| 2026-07 | 159 | -1,030.16 |
| 2026-08 | 122 | +106.63 |

## By regime/strategy

| Mode | Trades | Win% | P/L ($) |
|---|---|---|---|
| DOWNTREND | 444 | 46% | +882.82 |
| NEWS | 882 | 44% | +453.56 |
| SIDE | 115 | 41% | +119.99 |
| UPTREND | 502 | 49% | +265.56 |

## By exit reason

| Exit | Trades | P/L ($) |
|---|---|---|
| HIGHER_HIGH | 244 | +12,771.19 |
| LOWER_LOW | 201 | +12,031.77 |
| NEWS_END | 553 | +17,019.47 |
| REGIME_CHG | 71 | +2,122.12 |
| SL | 376 | -26,594.81 |
| TP | 5 | +892.83 |
| TRAIL_STOP | 329 | -16,565.91 |
| TREND_REV | 153 | -207.62 |
| WEEKEND | 11 | +252.89 |

## Time spent in each regime

- UPTREND: 9878 bars (41.7%)
- DOWNTREND: 8482 bars (35.8%)
- NEWS: 3844 bars (16.2%)
- SIDE: 1304 bars (5.5%)
- LOW VOL (no trade): 187 bars (0.8%)

## Gate blocks

- same-setup: 1578
- cooldown: 397
- friday: 308
- loss limit: 214
- max dd: 127
- min-lot: 64
- max trades/day: 23
- gap: 12
- spread: 6

> Disclaimer: simulated approximation of the MT5 EA. Validate in the MT5 Strategy
> Tester (every tick, real ticks) before live use.