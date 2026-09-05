# XAUUSD Adaptive Pro EA (MT5)

একটি অ্যাডাপটিভ, মাল্টি-স্ট্র্যাটেজি, ক্যাপিটাল-প্রোটেকশন-ফার্স্ট MetaTrader 5 Expert Advisor — XAUUSD (Gold)-এর জন্য।

> মূল নীতি / Core principle:
> **GOOD MARKET → TRADE | BAD MARKET → NO TRADE | UNCERTAIN MARKET → WAIT | DANGEROUS MARKET → PROTECT CAPITAL**
>
> "Every market movement is NOT a trading opportunity."

এই EA কোনো holy grail নয় — সব ট্রেড প্রফিটেবল হবে এমন কোনো গ্যারান্টি নেই। লক্ষ্য একটাই: **যেখানে ভালো সুযোগ আছে সেখানে ট্রেড করা, যেখানে edge নেই সেখানে ট্রেড না করা।**

---

## ইনস্টলেশন / Installation

1. পুরো `XauusdAdaptiveEA` ফোল্ডারটি কপি করুন:
   `...\MQL5\Experts\XauusdAdaptiveEA\`
   (ফোল্ডার স্ট্রাকচার এমন হতে হবে: `MQL5\Experts\XauusdAdaptiveEA\XauusdAdaptiveEA.mq5` এবং `...\Include\*.mqh`)
2. MetaEditor খুলে `XauusdAdaptiveEA.mq5` ওপেন করুন এবং **Compile (F7)** করুন। `0 errors` আসতে হবে।
3. টার্মিনালে ফিরে **Algo Trading** বাটন চালু করুন।
4. `XAUUSD` চার্টে (যেকোনো টাইমফ্রেম চলবে — EA তার নিজস্ব টাইমফ্রেম ব্যবহার করে) ইন্ডিকেটর লিস্ট থেকে **XauusdAdaptiveEA** ড্র্যাগ করুন।
5. "Allow Algo Trading" টিক দিন। চার্টের উপরে বাম দিকে ড্যাশবোর্ড দেখা যাবে।

## এটি কীভাবে কাজ করে / How it works

```
Market Data (HTF + Entry TF)
        │
        ▼
Market Condition Engine ── volatility, trend, structure (HH/HL/LH/LL),
        │                   range, breakout, pullback, reversal, BOS/CHoCH
        ▼
Strategy Selector ── Trend / Pullback / Breakout / Retest / Range / Reversal / Sweep
        │
        ▼
Conflict Resolution ── opposite signal থাকলে → ট্রেড নেই
        ▼
Protective Gates ── spread, session, news, volatility, risk limits,
        │            cooldown, HTF alignment, confidence, R:R
        ▼
Execution + Trade Management ── break-even, trailing, partial, smart exit
```

### Market conditions (১৩+ অবস্থা)
Strong/Weak Uptrend, Strong/Weak Downtrend, Pullback (Bull/Bear), Breakout (Bull/Bear), Range, Reversal (Bull/Bear), Low Volatility, Extreme Volatility, Abnormal, Uncertain। প্রতিটি বারে একটি অবস্থা নির্বাচিত হয় এবং ড্যাশবোর্ডে দেখানো হয়।

### স্ট্র্যাটেজি / Strategies
| Strategy | কখন | ডিফল্ট |
|---|---|---|
| Trend-Follow | শক্তিশালী/দুর্বল ট্রেন্ডে মোমেন্টাম ক্যান্ডেল | চালু |
| Pullback | ট্রেন্ডে EMA জোনে রিট্রেস + রিজেকশন ক্যান্ডেল | চালু |
| Breakout | ভ্যালিডেটেড রেঞ্জ ব্রেকআউট (টাচ-কাউন্ট সহ) | চালু |
| Breakout-Retest | ব্রেকআউট লেভেল রিটেস্ট হোল্ড | চালু |
| Range | রেঞ্জের উপরের/নিচের জোনে (মাঝখানে ট্রেড নেই) | চালু |
| Reversal | CHoCH + ডাইভারজেন্স + কনফার্মেশন (খুব কনজারভেটিভ) | বন্ধ |
| Liquidity-Sweep | সুইং লিকুইডিটি সুইপের পর ফেরা | চালু |

### প্রোটেকশন / Protection
- **Risk:** প্রতি ট্রেডে % রিস্ক ভিত্তিক লট সাইজ, স্ট্রাকচারাল স্টপ, সর্বোচ্চ লট ক্যাপ, মার্জিন চেক
- **Drawdown:** ডেইলি লস লিমিট, উইকলি লস লিমিট, সর্বোচ্চ ড্রডাউন হল্ট
- **Consecutive loss:** টানা লসে কুলডাউন
- **Overtrading:** দৈনিক ট্রেড লিমিট, এন্ট্রি গ্যাপ, একই সেটআপ পুনরাবৃত্তি ব্লক, বিপরীত পজিশন লক
- **Spread:** অস্বাভাবিক স্প্রেডে ট্রেড বন্ধ
- **Slippage:** রিকোট/ফেইল এক্সিকিউশনের পর ট্রেড পজ
- **News:** ফিক্সড নিউজ উইন্ডো (ব্যাকটেস্টে) + লাইভে হাই-ইমপ্যাক্ট USD ইকোনমিক ক্যালেন্ডার
- **Session:** লন্ডন/নিউ ইয়র্ক ডিফল্ট; সিডনি/টোকিও অপশনাল; শুক্রবার স্টপ + উইকেন্ড ফ্ল্যাটেন
- **Extreme market:** ট্রেড বন্ধ, ট্রেইলিং টাইট, এমার্জেন্সি এক্সিট

### ড্যাশবোর্ড / Dashboard
চার্টে লাইভ স্ট্যাটাস: কন্ডিশন, ট্রেন্ড ও শক্তি, স্ট্রাকচার (HH/HL/LH/LL + BOS), ভোলাটিলিটি, রেঞ্জ, সিগন্যাল, বায়াস, পজিশন, ডেইলি P/L, ড্রডাউন, সেশন, নিউজ, স্প্রেড, স্ট্যাটাস।

### ডিসিশন লগ / Decision log
প্রতিটি ট্রেডের কারণ এবং প্রতিটি স্কিপের কারণ লগ হয়:
`MQL5\Files\XGE_Logs\XGE_YYYY-MM-DD.csv`
(`InpFileLog=false` দিলে বন্ধ থাকে।)

---

## ব্যাকটেস্ট গাইড / Backtest guide

1. Strategy Tester → Symbol: **XAUUSD**, EA: XauusdAdaptiveEA
2. Timeframe: যেকোনো (EA তার ইনপুট টাইমফ্রেম নিজে ব্যবহার করে)
3. Modelling: **"Every tick based on real ticks"** (সবচেয়ে নির্ভরযোগ্য)
4. ডেটা রেঞ্জ: অন্তত ২–৩ বছর (ট্রেন্ড + রেঞ্জ + হাই ভোলাটিলিটি — সব ধরনের মার্কেট থাকতে হবে)
5. বিচার করুন শুধু প্রফিট দিয়ে নয়: **Drawdown, Profit Factor, Consistency, Losing streak, Recovery, Stability**
6. ইনপুট কিঞ্চিৎ বদলে ফলাফল ভেঙে পড়লে সেটা ওভারফিটিং — ডিফল্ট প্যারামিটার সামঞ্জস্যপূর্ণ রাখা হয়েছে।

দ্রষ্টব্য: ব্যাকটেস্টে ইকোনমিক ক্যালেন্ডার থাকে না, তাই `InpNewsHours`-এর ফিক্সড উইন্ডো ব্যবহৃত হয়। লাইভে আসল হাই-ইমপ্যাক্ট নিউজও যুক্ত হয়।

## গুরুত্বপূর্ণ ইনপুট (সারাংশ)

| গ্রুপ | মূল প্যারামিটার |
|---|---|
| Timeframes | HTF=H1 (কনটেক্সট), Entry=M15 (সিগন্যাল) |
| Strategies | প্রতিটি স্ট্র্যাটেজি আলাদাভাবে অন/অফ, MinConfidence=62, MinRR=1.2, RR TP=1.8 |
| Risk | RiskPercent=1.0, SL 0.8–4.0 x ATR, MaxLot=10 |
| Drawdown | Daily 3%, Weekly 6%, MaxDD 15%, ৪ টানা লসে ১৮০ মিনিট কুলডাউন |
| Overtrading | সর্বোচ্চ ৬ ট্রেড/দিন, ২০ মিনিট গ্যাপ, ১ পজিশন, একই সেটআপ ২৪ বারের মধ্যে নয় |
| Filters | স্প্রেড ≤ ৫০ পয়েন্ট, লন্ডন+নিউইয়র্ক সেশন, নিউজ ৩০/৩০ মিনিট, শুক্রবার ২১টার পর বন্ধ |
| Management | ব্রেক-ইভেন ১.০ ATR, ট্রেইলিং ১.৫ ATR, পার্শিয়াল ১.০R-এ ৫০%, স্মার্ট এক্সিট |

## ঝুঁকি সতর্কতা / Risk disclaimer

ট্রেডিংয়ে লোকসানের ঝুঁকি আছে। এই সফটওয়্যার "যেমন আছে তেমন" প্রদান করা হয়; কোনো প্রকার ওয়ারেন্টি বা প্রফিট গ্যারান্টি নেই। লাইভ অ্যাকাউন্টে ব্যবহারের আগে অবশ্যই ব্যাকটেস্ট ও ডেমো ফরওয়ার্ড টেস্ট করুন। সেশন ঘণ্টা আপনার ব্রোকারের সার্ভার টাইম অনুযায়ী অ্যাডজাস্ট করে নিন।
