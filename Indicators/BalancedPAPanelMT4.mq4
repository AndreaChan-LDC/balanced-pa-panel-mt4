#property strict
#property indicator_chart_window
#property indicator_buffers 0

#property description "Balanced PA Panel MT4"
#property description "Independent MT4 price-action dashboard with session value, Wyckoff context, Brooks triggers, and breakout/pullback arrows."

input int    InpLookbackBars              = 240;
input int    InpStructureWindowBars       = 48;
input int    InpEqualWindowStartBars      = 24;
input int    InpEqualWindowEndBars        = 8;
input int    InpAtrPeriod                 = 14;
input int    InpEmaFast                   = 20;
input int    InpEmaMid                    = 50;
input int    InpEmaSlow                   = 100;

input int    InpSessionOffsetHours        = 5;     // broker time -> session-analysis time, default fits a UTC+3 broker
input int    InpAsiaSessionStartHour      = 8;
input int    InpAsiaSessionEndHour        = 14;
input int    InpMinSessionBars            = 12;

input bool   InpShowPanel                 = true;
input bool   InpPanelMovable              = true;
input int    InpPanelCorner               = 0;
input int    InpPanelX                    = 14;
input int    InpPanelY                    = 128;
input int    InpPanelWidth                = 820;
input int    InpPanelHeight               = 192;
input string InpPanelFontName             = "Arial";
input int    InpHeaderFontSize            = 10;
input int    InpLineFontSize              = 10;
input bool   InpCompactPanelLayout        = true;
input int    InpCompactPanelMinWidth      = 820;
input int    InpPanelPaddingX             = 12;
input int    InpPanelPaddingY             = 10;
input int    InpPanelBottomPadding        = 22;
input int    InpPanelLineGap              = 28;
input bool   InpAutoPlacePanel            = true;
input bool   InpAutoFitPanelWidth         = true;

input color  InpPanelBgColor              = clrBlack;
input color  InpPanelBorderColor          = clrDimGray;
input color  InpPrimaryTextColor          = clrWhite;
input color  InpAccentTextColor           = clrGold;
input color  InpBullTextColor             = clrLime;
input color  InpBearTextColor             = clrOrange;
input color  InpMutedTextColor            = clrSilver;
input color  InpInfoTextColor             = clrAqua;

input bool   InpShowBreakoutArrows        = true;
input int    InpBreakoutArrowCodeLong     = 233;
input int    InpBreakoutArrowCodeShort    = 234;
input int    InpPullbackArrowCodeLong     = 233;
input int    InpPullbackArrowCodeShort    = 234;
input color  InpBreakoutLongColor         = clrAqua;
input color  InpBreakoutShortColor        = clrOrangeRed;
input color  InpPullbackLongColor         = clrLime;
input color  InpPullbackShortColor        = clrGold;
input int    InpArrowWidth                = 2;
input int    InpBreakoutArrowShiftPoints  = 90;
input int    InpPullbackArrowShiftPoints  = 130;
input int    InpArrowSignalLookbackBars   = 12;

input string InpObjectPrefix              = "BalancedPAPanel";

#define PANEL_MAX_LINE_COUNT 11

#define VALUE_INSUFFICIENT 0
#define VALUE_ACCEPTED_ABOVE 1
#define VALUE_ACCEPTED_BELOW 2
#define VALUE_REJECTED_ABOVE 3
#define VALUE_REJECTED_BELOW 4
#define VALUE_INSIDE 5

#define WYCKOFF_RANGE 0
#define WYCKOFF_ACCUMULATION 1
#define WYCKOFF_DISTRIBUTION 2
#define WYCKOFF_MARKUP 3
#define WYCKOFF_MARKDOWN 4

#define BROOKS_WAIT 0
#define BROOKS_SECOND_ENTRY_LONG 1
#define BROOKS_SECOND_ENTRY_SHORT 2
#define BROOKS_BREAKOUT_PULLBACK_LONG 3
#define BROOKS_BREAKOUT_PULLBACK_SHORT 4

struct CandleBar
{
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   long     volume;
};

struct PaZones
{
   double supplyTop;
   double supplyBottom;
   double demandTop;
   double demandBottom;
   double equalHigh;
   double equalLow;
};

struct ProfileSummary
{
   bool   valid;
   double low;
   double high;
   double step;
   double poc;
   double vah;
   double val;
};

struct SessionWindow
{
   bool valid;
   int  startIndex;
   int  endIndex;
   int  dayKey;
};

struct SessionContext
{
   bool          valid;
   SessionWindow currentSession;
   SessionWindow previousSession;
   ProfileSummary currentProfile;
   ProfileSummary previousProfile;
   bool          hasCurrentAsia;
   bool          hasPreviousAsia;
   double        currentAsiaHigh;
   double        currentAsiaLow;
   double        previousAsiaHigh;
   double        previousAsiaLow;
   double        previousHigh;
   double        previousLow;
};

struct SweepState
{
   double level;
   bool   swept;
   bool   rejected;
   bool   accepted;
};

struct ValueState
{
   int    key;
   string label;
   string bias;
   string routeText;
};

struct WyckoffState
{
   int    key;
   string label;
   string bias;
   string note;
};

struct BrooksState
{
   int    key;
   string label;
   string bias;
   string note;
};

struct PaAnalysis
{
   double current;
   double dayOpen;
   double dayHigh;
   double dayLow;
   double dailyChange;
   double dailyPct;
   double emaFastLast;
   double emaMidLast;
   double emaSlowLast;
   double vwapLast;
   double atrValue;
   double avgRange;
   double rangeUnit;
   double bearPct;
   double bullPct;
   double neutralPct;
   string marketBias;
   string bos;
   string choch;
   string bias;
   string atrState;
   PaZones zones;
};

string   g_prefix = "";
string   g_statePrefix = "";
datetime g_lastBarTime = 0;
int      g_panelCorner = 0;
int      g_panelX = 0;
int      g_panelY = 0;

string   g_panelText[PANEL_MAX_LINE_COUNT];
color    g_panelColor[PANEL_MAX_LINE_COUNT];
int      g_panelLineCount = 9;

int OnInit()
{
   IndicatorShortName("Balanced PA Panel MT4");
   g_prefix = InpObjectPrefix + "_" + Symbol() + "_" + IntegerToString(Period()) + "_";
   g_statePrefix = InpObjectPrefix + "_" + Symbol() + "_" + IntegerToString(Period()) + "_STATE_";
   g_panelCorner = InpPanelCorner;
   g_panelX = InpPanelX;
   g_panelY = InpPanelY;
   LoadPanelState();
   EventSetTimer(1);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   SavePanelState();
   EventKillTimer();
   DeleteObjectsByPrefix(g_prefix);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 90)
      return(rates_total);

   datetime currentBar = iTime(NULL, 0, 0);
   if(prev_calculated == 0 || currentBar != g_lastBarTime)
   {
      g_lastBarTime = currentBar;
      RefreshDashboard();
   }
   else if(InpShowPanel)
   {
      SyncPanelPositionFromObject();
      ApplyPanelLayout();
   }

   return(rates_total);
}

void OnTimer()
{
   if(!InpShowPanel)
      return;

   SyncPanelPositionFromObject();
   ApplyPanelLayout();
}

void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_DRAG && sparam == ObjName("PANEL_BG"))
   {
      SyncPanelPositionFromObject();
      SavePanelState();
      ApplyPanelLayout();
   }
}

void RefreshDashboard()
{
   CandleBar candles[];
   int count = LoadRecentCandles(candles);
   if(count < 80)
      return;

   PaAnalysis analysis;
   AnalyzeCandles(candles, count, analysis);

   SessionContext sessionContext;
   BuildSessionContext(candles, count, sessionContext);

   ValueState valueState;
   WyckoffState wyckoffState;
   BrooksState brooksState;

   SweepState previousHighSweep;
   SweepState previousLowSweep;
   SweepState asiaHighSweep;
   SweepState asiaLowSweep;
   SweepState valueHighSweep;
   SweepState valueLowSweep;

   ResolveValueState(candles, count, analysis, sessionContext, valueState);
   DetectSweepAgainstLevel(candles, count, sessionContext.previousHigh, 1, MathMax(sessionContext.previousProfile.step * 0.5, 0.4), 12, previousHighSweep);
   DetectSweepAgainstLevel(candles, count, sessionContext.previousLow, -1, MathMax(sessionContext.previousProfile.step * 0.5, 0.4), 12, previousLowSweep);
   DetectSweepAgainstLevel(candles, count, sessionContext.hasCurrentAsia ? sessionContext.currentAsiaHigh : sessionContext.previousAsiaHigh, 1, MathMax(sessionContext.previousProfile.step * 0.5, 0.4), 12, asiaHighSweep);
   DetectSweepAgainstLevel(candles, count, sessionContext.hasCurrentAsia ? sessionContext.currentAsiaLow : sessionContext.previousAsiaLow, -1, MathMax(sessionContext.previousProfile.step * 0.5, 0.4), 12, asiaLowSweep);
   DetectSweepAgainstLevel(candles, count, sessionContext.previousProfile.vah, 1, MathMax(sessionContext.previousProfile.step * 0.5, 0.4), 12, valueHighSweep);
   DetectSweepAgainstLevel(candles, count, sessionContext.previousProfile.val, -1, MathMax(sessionContext.previousProfile.step * 0.5, 0.4), 12, valueLowSweep);

   ResolveWyckoffState(analysis, valueState, previousHighSweep, previousLowSweep, asiaHighSweep, asiaLowSweep, valueHighSweep, valueLowSweep, wyckoffState);
   ResolveBrooksState(candles, count, analysis, sessionContext, valueState, brooksState);

   double bullFvgLow = 0.0;
   double bullFvgHigh = 0.0;
   double bearFvgLow = 0.0;
   double bearFvgHigh = 0.0;
   bool bullFvgFound = FindNearestFvg(candles, count, 1, analysis.current, bullFvgLow, bullFvgHigh);
   bool bearFvgFound = FindNearestFvg(candles, count, -1, analysis.current, bearFvgLow, bearFvgHigh);

   string execution = BuildExecutionLabel(analysis, valueState, brooksState);
   string decision = BuildDecisionLabel(analysis, valueState, wyckoffState, brooksState);
   string riskText = BuildRiskLabel(analysis, brooksState);
   string currentArea = ResolveCurrentArea(analysis);
   string planText = BuildPlanLabel(analysis, valueState, brooksState);

   ComposePanel(
      analysis,
      sessionContext,
      valueState,
      wyckoffState,
      brooksState,
      execution,
      decision,
      riskText,
      currentArea,
      planText,
      bullFvgFound,
      bullFvgLow,
      bullFvgHigh,
      bearFvgFound,
      bearFvgLow,
      bearFvgHigh
   );

   if(InpShowPanel)
      ApplyPanelLayout();
   else
      DeletePanelObjects();

   if(InpShowBreakoutArrows)
      DrawSignalArrows(candles, count, analysis, sessionContext, valueState, brooksState);
   else
      DeleteArrowObjects();

   ChartRedraw();
}

int LoadRecentCandles(CandleBar &candles[])
{
   int count = MathMin(InpLookbackBars, Bars - 2);
   if(count < 80)
   {
      ArrayResize(candles, 0);
      return(0);
   }

   ArrayResize(candles, count);
   int index = 0;
   for(int shift = count; shift >= 1; --shift)
   {
      candles[index].time = iTime(NULL, 0, shift);
      candles[index].open = iOpen(NULL, 0, shift);
      candles[index].high = iHigh(NULL, 0, shift);
      candles[index].low = iLow(NULL, 0, shift);
      candles[index].close = iClose(NULL, 0, shift);
      candles[index].volume = iVolume(NULL, 0, shift);
      index++;
   }
   return(count);
}

void AnalyzeCandles(CandleBar &candles[], const int count, PaAnalysis &analysis)
{
   double closes[];
   double emaFast[];
   double emaMid[];
   double emaSlow[];
   double vwapValues[];

   ArrayResize(closes, count);
   for(int i = 0; i < count; ++i)
      closes[i] = candles[i].close;

   ComputeEma(closes, count, MathMin(InpEmaFast, count), emaFast);
   ComputeEma(closes, count, MathMin(InpEmaMid, count), emaMid);
   ComputeEma(closes, count, MathMin(InpEmaSlow, count), emaSlow);
   ComputeVwap(candles, count, vwapValues);

   RefreshRates();
   analysis.current = Bid > 0.0 ? Bid : candles[count - 1].close;
   analysis.dayOpen = iOpen(NULL, PERIOD_D1, 0);
   analysis.dayHigh = iHigh(NULL, PERIOD_D1, 0);
   analysis.dayLow = iLow(NULL, PERIOD_D1, 0);
   if(analysis.dayHigh <= 0.0 || analysis.dayLow <= 0.0)
   {
      analysis.dayHigh = HighestHigh(candles, count);
      analysis.dayLow = LowestLow(candles, count);
      analysis.dayOpen = candles[0].open;
   }
   analysis.dailyChange = analysis.current - analysis.dayOpen;
   analysis.dailyPct = analysis.dayOpen > 0.0 ? (analysis.dailyChange / analysis.dayOpen) * 100.0 : 0.0;
   analysis.emaFastLast = emaFast[count - 1];
   analysis.emaMidLast = emaMid[count - 1];
   analysis.emaSlowLast = emaSlow[count - 1];
   analysis.vwapLast = vwapValues[count - 1];
   analysis.atrValue = iATR(NULL, 0, InpAtrPeriod, 1);
   analysis.avgRange = AverageRange(candles, count, 20);
   analysis.rangeUnit = MathMax((HighestHigh(candles, MathMin(count, InpStructureWindowBars)) - LowestLow(candles, MathMin(count, InpStructureWindowBars))) / 18.0, MaxPointValue() * 60.0);
   analysis.bos = DetectBos(candles, count);
   analysis.choch = DetectChoch(candles, count);
   FindZones(candles, count, analysis.zones);
   analysis.marketBias = ResolveMarketBias(analysis.current, analysis.emaFastLast, analysis.emaMidLast, analysis.vwapLast);
   analysis.atrState = ResolveAtrState(analysis.atrValue, analysis.avgRange);
   ComputeBiasScores(analysis);
   analysis.bias = ClassifyBias(analysis);
}

void ComputeBiasScores(PaAnalysis &analysis)
{
   int sellScore =
      (analysis.current < analysis.emaFastLast ? 1 : 0) +
      (analysis.emaFastLast < analysis.emaMidLast ? 1 : 0) +
      (analysis.current < analysis.vwapLast ? 1 : 0) +
      (analysis.bos == "Down BOS" ? 1 : 0) +
      (StringFind(analysis.choch, "Bearish", 0) >= 0 ? 1 : 0);

   int buyScore =
      (analysis.current > analysis.emaFastLast ? 1 : 0) +
      (analysis.emaFastLast > analysis.emaMidLast ? 1 : 0) +
      (analysis.current > analysis.vwapLast ? 1 : 0) +
      (analysis.bos == "Up BOS" ? 1 : 0) +
      (StringFind(analysis.choch, "Bullish", 0) >= 0 ? 1 : 0);

   double rawBear = ClampValue(40.0 + sellScore * 11.0 - buyScore * 3.0, 15.0, 75.0);
   double rawBull = ClampValue(25.0 + buyScore * 11.0 - sellScore * 2.0, 15.0, 70.0);
   double rawNeutral = ClampValue(16.0 + ((analysis.dayHigh - analysis.dayLow) / MathMax(analysis.current, 1.0)) * 300.0 - MathAbs(sellScore - buyScore) * 2.0, 8.0, 34.0);
   double total = rawBear + rawBull + rawNeutral;

   analysis.bearPct = rawBear / total * 100.0;
   analysis.bullPct = rawBull / total * 100.0;
   analysis.neutralPct = 100.0 - analysis.bearPct - analysis.bullPct;
}

string DetectBos(CandleBar &candles[], const int count)
{
   if(count < 16)
      return("Waiting");

   double recentHigh = -1.0e100;
   double recentLow = 1.0e100;
   double priorHigh = -1.0e100;
   double priorLow = 1.0e100;

   for(int i = count - 4; i < count; ++i)
   {
      recentHigh = MathMax(recentHigh, candles[i].high);
      recentLow = MathMin(recentLow, candles[i].low);
   }
   for(int j = count - 16; j < count - 4; ++j)
   {
      priorHigh = MathMax(priorHigh, candles[j].high);
      priorLow = MathMin(priorLow, candles[j].low);
   }

   if(recentHigh > priorHigh)
      return("Up BOS");
   if(recentLow < priorLow)
      return("Down BOS");
   return("In Range");
}

string DetectChoch(CandleBar &candles[], const int count)
{
   if(count < 20)
      return("None");

   double leftSlope = candles[count - 11].close - candles[count - 20].close;
   double rightSlope = candles[count - 1].close - candles[count - 10].close;

   if(leftSlope > 0.0 && rightSlope < 0.0)
      return("Bearish CHOCH");
   if(leftSlope < 0.0 && rightSlope > 0.0)
      return("Bullish CHOCH");
   return("No CHOCH");
}

void FindZones(CandleBar &candles[], const int count, PaZones &zones)
{
   int window = MathMin(InpStructureWindowBars, count);
   int start = count - window;
   double recentHigh = -1.0e100;
   double recentLow = 1.0e100;

   for(int i = start; i < count; ++i)
   {
      recentHigh = MathMax(recentHigh, candles[i].high);
      recentLow = MathMin(recentLow, candles[i].low);
   }

   double range = MathMax(recentHigh - recentLow, MaxPointValue() * 240.0);
   int eqStart = MathMax(0, count - InpEqualWindowStartBars);
   int eqEnd = MathMax(eqStart + 1, count - InpEqualWindowEndBars);
   double equalHigh = -1.0e100;
   double equalLow = 1.0e100;

   for(int j = eqStart; j < eqEnd; ++j)
   {
      equalHigh = MathMax(equalHigh, candles[j].high);
      equalLow = MathMin(equalLow, candles[j].low);
   }

   zones.supplyTop = recentHigh - range * 0.10;
   zones.supplyBottom = recentHigh - range * 0.24;
   zones.demandTop = recentLow + range * 0.22;
   zones.demandBottom = recentLow + range * 0.08;
   zones.equalHigh = equalHigh;
   zones.equalLow = equalLow;
}

bool FindNearestFvg(CandleBar &candles[],
                    const int count,
                    const int direction,
                    const double currentPrice,
                    double &zoneLow,
                    double &zoneHigh)
{
   bool found = false;
   double bestDistance = 1.0e100;

   for(int i = 2; i < count; ++i)
   {
      if(direction > 0)
      {
         if(candles[i - 2].high >= candles[i].low)
            continue;
         double low = candles[i - 2].high;
         double high = candles[i].low;
         double midpoint = (low + high) / 2.0;
         if(midpoint > currentPrice + MathMaxPointSpan(240.0))
            continue;
         double distance = MathAbs(midpoint - currentPrice);
         if(distance < bestDistance)
         {
            bestDistance = distance;
            zoneLow = low;
            zoneHigh = high;
            found = true;
         }
      }
      else
      {
         if(candles[i - 2].low <= candles[i].high)
            continue;
         double low = candles[i].high;
         double high = candles[i - 2].low;
         double midpoint = (low + high) / 2.0;
         if(midpoint < currentPrice - MathMaxPointSpan(240.0))
            continue;
         double distance = MathAbs(midpoint - currentPrice);
         if(distance < bestDistance)
         {
            bestDistance = distance;
            zoneLow = low;
            zoneHigh = high;
            found = true;
         }
      }
   }

   return(found);
}

void BuildSessionContext(CandleBar &candles[], const int count, SessionContext &ctx)
{
   ResetSessionContext(ctx);

   SessionWindow sessions[];
   int sessionCount = BuildSessionWindows(candles, count, sessions);
   if(sessionCount < 2)
      return;

   int validCount = 0;
   for(int i = 0; i < sessionCount; ++i)
   {
      if(sessions[i].valid)
         validCount++;
   }
   if(validCount < 2)
      return;

   int currentIndex = -1;
   int previousIndex = -1;
   for(int j = sessionCount - 1; j >= 0; --j)
   {
      if(!sessions[j].valid)
         continue;
      if(currentIndex < 0)
      {
         currentIndex = j;
         continue;
      }
      previousIndex = j;
      break;
   }

   if(currentIndex < 0 || previousIndex < 0)
      return;

   ctx.currentSession = sessions[currentIndex];
   ctx.previousSession = sessions[previousIndex];
   BuildProfileSummary(candles, ctx.currentSession.startIndex, ctx.currentSession.endIndex, ctx.currentProfile);
   BuildProfileSummary(candles, ctx.previousSession.startIndex, ctx.previousSession.endIndex, ctx.previousProfile);
   ctx.previousHigh = SessionHigh(candles, ctx.previousSession.startIndex, ctx.previousSession.endIndex);
   ctx.previousLow = SessionLow(candles, ctx.previousSession.startIndex, ctx.previousSession.endIndex);
   ctx.hasCurrentAsia = BuildAsiaRange(candles, ctx.currentSession.startIndex, ctx.currentSession.endIndex, ctx.currentAsiaHigh, ctx.currentAsiaLow);
   ctx.hasPreviousAsia = BuildAsiaRange(candles, ctx.previousSession.startIndex, ctx.previousSession.endIndex, ctx.previousAsiaHigh, ctx.previousAsiaLow);
   ctx.valid = ctx.previousProfile.valid;
}

int BuildSessionWindows(CandleBar &candles[], const int count, SessionWindow &sessions[])
{
   ArrayResize(sessions, 0);
   if(count <= 0)
      return(0);

   int currentKey = LocalDayKey(candles[0].time);
   int startIndex = 0;

   for(int i = 1; i < count; ++i)
   {
      int nextKey = LocalDayKey(candles[i].time);
      if(nextKey == currentKey)
         continue;

      AppendSessionWindow(sessions, startIndex, i - 1, currentKey);
      startIndex = i;
      currentKey = nextKey;
   }

   AppendSessionWindow(sessions, startIndex, count - 1, currentKey);
   return(ArraySize(sessions));
}

void AppendSessionWindow(SessionWindow &sessions[], const int startIndex, const int endIndex, const int dayKey)
{
   int size = ArraySize(sessions);
   ArrayResize(sessions, size + 1);
   sessions[size].startIndex = startIndex;
   sessions[size].endIndex = endIndex;
   sessions[size].dayKey = dayKey;
   sessions[size].valid = (endIndex - startIndex + 1) >= InpMinSessionBars;
}

void BuildProfileSummary(CandleBar &candles[], const int startIndex, const int endIndex, ProfileSummary &profile)
{
   profile.valid = false;
   if(startIndex < 0 || endIndex < startIndex)
      return;

   double high = SessionHigh(candles, startIndex, endIndex);
   double low = SessionLow(candles, startIndex, endIndex);
   if(high <= low)
      return;

   double step = ResolveProfileStep(high, low);
   double levels[];
   int counts[];
   int used = 0;

   ArrayResize(levels, 0);
   ArrayResize(counts, 0);

   for(int i = startIndex; i <= endIndex; ++i)
   {
      double startPrice = RoundToStep(MathFloor(candles[i].low / step) * step, step);
      double endPrice = RoundToStep(MathCeil(candles[i].high / step) * step, step);
      for(double price = startPrice; price <= endPrice + step / 3.0; price += step)
      {
         double bucket = RoundToStep(price, step);
         int idx = FindLevelIndex(levels, used, bucket, step * 0.25);
         if(idx < 0)
         {
            ArrayResize(levels, used + 1);
            ArrayResize(counts, used + 1);
            levels[used] = bucket;
            counts[used] = 1;
            used++;
         }
         else
         {
            counts[idx]++;
         }
      }
   }

   if(used <= 0)
      return;

   SortLevels(levels, counts, used);

   double midpoint = (high + low) / 2.0;
   int pocIndex = 0;
   for(int j = 1; j < used; ++j)
   {
      if(counts[j] > counts[pocIndex])
         pocIndex = j;
      else if(counts[j] == counts[pocIndex] && MathAbs(levels[j] - midpoint) < MathAbs(levels[pocIndex] - midpoint))
         pocIndex = j;
   }

   int totalTpos = 0;
   for(int k = 0; k < used; ++k)
      totalTpos += counts[k];

   bool covered[];
   ArrayResize(covered, used);
   for(int c = 0; c < used; ++c)
      covered[c] = false;

   covered[pocIndex] = true;
   int coveredCount = counts[pocIndex];
   int leftIndex = pocIndex - 1;
   int rightIndex = pocIndex + 1;

   while((double)coveredCount / MathMax(totalTpos, 1) < 0.70 && (leftIndex >= 0 || rightIndex < used))
   {
      int pickIndex = -1;
      if(leftIndex < 0)
         pickIndex = rightIndex;
      else if(rightIndex >= used)
         pickIndex = leftIndex;
      else if(counts[leftIndex] > counts[rightIndex])
         pickIndex = leftIndex;
      else if(counts[rightIndex] > counts[leftIndex])
         pickIndex = rightIndex;
      else
      {
         double leftDistance = MathAbs(levels[leftIndex] - levels[pocIndex]);
         double rightDistance = MathAbs(levels[rightIndex] - levels[pocIndex]);
         pickIndex = leftDistance <= rightDistance ? leftIndex : rightIndex;
      }

      if(pickIndex < 0)
         break;

      covered[pickIndex] = true;
      coveredCount += counts[pickIndex];
      if(pickIndex == leftIndex)
         leftIndex--;
      else
         rightIndex++;
   }

   double vah = levels[pocIndex];
   double val = levels[pocIndex];
   for(int m = 0; m < used; ++m)
   {
      if(!covered[m])
         continue;
      vah = MathMax(vah, levels[m]);
      val = MathMin(val, levels[m]);
   }

   profile.valid = true;
   profile.low = low;
   profile.high = high;
   profile.step = step;
   profile.poc = levels[pocIndex];
   profile.vah = vah;
   profile.val = val;
}

void ResolveValueState(CandleBar &candles[],
                       const int count,
                       PaAnalysis &analysis,
                       SessionContext &sessionContext,
                       ValueState &valueState)
{
   valueState.key = VALUE_INSUFFICIENT;
   valueState.label = "Not enough history; use structure first";
   valueState.bias = "neutral";
   valueState.routeText = "Wait for one full prior-session value profile";

   if(!sessionContext.valid || !sessionContext.previousProfile.valid)
      return;

   int start = MathMax(0, count - 6);
   int aboveCount = 0;
   int belowCount = 0;
   bool sweptAbove = false;
   bool sweptBelow = false;

   for(int i = start; i < count; ++i)
   {
      if(candles[i].close > sessionContext.previousProfile.vah)
         aboveCount++;
      else if(candles[i].close < sessionContext.previousProfile.val)
         belowCount++;

      if(candles[i].high > sessionContext.previousProfile.vah)
         sweptAbove = true;
      if(candles[i].low < sessionContext.previousProfile.val)
         sweptBelow = true;
   }

   int insideCount = (count - start) - aboveCount - belowCount;
   double pocShift = sessionContext.currentProfile.valid ? sessionContext.currentProfile.poc - sessionContext.previousProfile.poc : 0.0;

   if(analysis.current > sessionContext.previousProfile.vah && aboveCount >= 4)
   {
      valueState.key = VALUE_ACCEPTED_ABOVE;
      valueState.label = "Accepted above value";
      valueState.bias = "bull";
      valueState.routeText = pocShift > sessionContext.previousProfile.step * 0.5 ? "POC shifted up; auction is migrating higher" : "Holding above value; still wait for pullback confirmation";
      return;
   }

   if(analysis.current < sessionContext.previousProfile.val && belowCount >= 4)
   {
      valueState.key = VALUE_ACCEPTED_BELOW;
      valueState.label = "Accepted below value";
      valueState.bias = "bear";
      valueState.routeText = pocShift < -sessionContext.previousProfile.step * 0.5 ? "POC shifted down; markdown is cleaner" : "Holding below value; still wait for rally-fail confirmation";
      return;
   }

   if(sweptAbove && analysis.current < sessionContext.previousProfile.vah && insideCount >= 2)
   {
      valueState.key = VALUE_REJECTED_ABOVE;
      valueState.label = "Sweep above rejected";
      valueState.bias = "bear";
      valueState.routeText = "Treat as UTAD / failed breakout; do not chase first leg";
      return;
   }

   if(sweptBelow && analysis.current > sessionContext.previousProfile.val && insideCount >= 2)
   {
      valueState.key = VALUE_REJECTED_BELOW;
      valueState.label = "Sweep below rejected";
      valueState.bias = "bull";
      valueState.routeText = "Treat as Spring / Test; wait for second-entry confirmation";
      return;
   }

   valueState.key = VALUE_INSIDE;
   valueState.label = "Still inside prior value area";
   valueState.bias = "neutral";
   valueState.routeText = "Watch which liquidity gets swept, then wait for value migration";
}

void ResolveWyckoffState(PaAnalysis &analysis,
                         ValueState &valueState,
                         SweepState &previousHighSweep,
                         SweepState &previousLowSweep,
                         SweepState &asiaHighSweep,
                         SweepState &asiaLowSweep,
                         SweepState &valueHighSweep,
                         SweepState &valueLowSweep,
                         WyckoffState &wyckoffState)
{
   wyckoffState.key = WYCKOFF_RANGE;
   wyckoffState.label = "Neutral range";
   wyckoffState.bias = analysis.current < analysis.vwapLast ? "bear" : analysis.current > analysis.vwapLast ? "bull" : "neutral";
   wyckoffState.note = "The larger phase is not fully expanded yet; read value migration first, then use liquidity for direction";

   if(valueState.key == VALUE_REJECTED_BELOW && (StringFind(analysis.choch, "Bullish", 0) >= 0 || analysis.current > analysis.vwapLast))
   {
      wyckoffState.key = WYCKOFF_ACCUMULATION;
      wyckoffState.label = "Accumulation / Spring-Test";
      wyckoffState.bias = "bull";
      wyckoffState.note = "Sweep below snapped back into value; prefer a Test or last point of support";
      return;
   }

   if(valueState.key == VALUE_REJECTED_ABOVE && (StringFind(analysis.choch, "Bearish", 0) >= 0 || analysis.current < analysis.vwapLast))
   {
      wyckoffState.key = WYCKOFF_DISTRIBUTION;
      wyckoffState.label = "Distribution / UTAD-LPSY";
      wyckoffState.bias = "bear";
      wyckoffState.note = "Sweep above fell back into value; prefer failed retest of VAH / prior high";
      return;
   }

   if(valueState.key == VALUE_ACCEPTED_ABOVE && (analysis.bos == "Up BOS" || analysis.current > analysis.emaFastLast))
   {
      wyckoffState.key = WYCKOFF_MARKUP;
      wyckoffState.label = "Markup";
      wyckoffState.bias = "bull";
      wyckoffState.note = "Accepted above value; prefer trend-following pullback support";
      return;
   }

   if(valueState.key == VALUE_ACCEPTED_BELOW && (analysis.bos == "Down BOS" || analysis.current < analysis.emaFastLast))
   {
      wyckoffState.key = WYCKOFF_MARKDOWN;
      wyckoffState.label = "Markdown";
      wyckoffState.bias = "bear";
      wyckoffState.note = "Accepted below value; prefer trend-following rally failure";
      return;
   }

   bool abovePressure = previousHighSweep.rejected || asiaHighSweep.rejected || valueHighSweep.rejected;
   bool belowSupport = previousLowSweep.rejected || asiaLowSweep.rejected || valueLowSweep.rejected;
   if(abovePressure || belowSupport)
      wyckoffState.label = "Testing / Range Rotation";
}

void ResolveBrooksState(CandleBar &candles[],
                        const int count,
                        PaAnalysis &analysis,
                        SessionContext &sessionContext,
                        ValueState &valueState,
                        BrooksState &brooksState)
{
   brooksState.key = BROOKS_WAIT;
   brooksState.label = "Waiting for second confirmation";
   brooksState.bias = "neutral";
   brooksState.note = "Brooks is the trigger, not the map";

   if(!sessionContext.valid || !sessionContext.previousProfile.valid || count < 8)
      return;

   double step = sessionContext.previousProfile.step > 0.0 ? sessionContext.previousProfile.step : 1.0;
   bool aboveHeld = true;
   bool belowHeld = true;
   for(int i = count - 4; i < count; ++i)
   {
      if(candles[i].low < sessionContext.previousProfile.vah - step * 0.5)
         aboveHeld = false;
      if(candles[i].high > sessionContext.previousProfile.val + step * 0.5)
         belowHeld = false;
   }

   CandleBar last = candles[count - 1];

   if(valueState.key == VALUE_REJECTED_BELOW && (StringFind(analysis.choch, "Bullish", 0) >= 0 || last.close > analysis.vwapLast))
   {
      brooksState.key = BROOKS_SECOND_ENTRY_LONG;
      brooksState.label = "Second-entry long / Spring-Test";
      brooksState.bias = "bull";
      brooksState.note = "Recover first, then wait for the first failed pullback; do not chase the first bounce";
      return;
   }

   if(valueState.key == VALUE_REJECTED_ABOVE && (StringFind(analysis.choch, "Bearish", 0) >= 0 || last.close < analysis.vwapLast))
   {
      brooksState.key = BROOKS_SECOND_ENTRY_SHORT;
      brooksState.label = "Second-entry short / UTAD-LPSY";
      brooksState.bias = "bear";
      brooksState.note = "Return into value first, then wait for failed rally; do not chase the first drop";
      return;
   }

   if(valueState.key == VALUE_ACCEPTED_ABOVE && aboveHeld)
   {
      brooksState.key = BROOKS_BREAKOUT_PULLBACK_LONG;
      brooksState.label = "Breakout-pullback long";
      brooksState.bias = "bull";
      brooksState.note = "After acceptance, do not chase the first bar; wait for VAH / FVG pullback to hold";
      return;
   }

   if(valueState.key == VALUE_ACCEPTED_BELOW && belowHeld)
   {
      brooksState.key = BROOKS_BREAKOUT_PULLBACK_SHORT;
      brooksState.label = "Breakout-pullback short";
      brooksState.bias = "bear";
      brooksState.note = "After breakdown acceptance, do not bottom-pick; wait for VAL / FVG rally to fail";
      return;
   }
}

void DetectSweepAgainstLevel(CandleBar &candles[],
                             const int count,
                             const double level,
                             const int side,
                             const double tolerance,
                             const int lookbackBars,
                             SweepState &sweep)
{
   sweep.level = level;
   sweep.swept = false;
   sweep.rejected = false;
   sweep.accepted = false;

   if(level <= 0.0 || count < 3)
      return;

   int start = MathMax(0, count - lookbackBars);
   double recentHigh = -1.0e100;
   double recentLow = 1.0e100;
   for(int i = start; i < count; ++i)
   {
      recentHigh = MathMax(recentHigh, candles[i].high);
      recentLow = MathMin(recentLow, candles[i].low);
   }

   CandleBar last = candles[count - 1];
   if(side > 0)
   {
      sweep.swept = recentHigh > level + tolerance;
      sweep.rejected = sweep.swept && last.close < level - tolerance * 0.10;
      sweep.accepted = sweep.swept && RecentClosesHold(candles, count, level - tolerance * 0.10, 1, 3);
   }
   else
   {
      sweep.swept = recentLow < level - tolerance;
      sweep.rejected = sweep.swept && last.close > level + tolerance * 0.10;
      sweep.accepted = sweep.swept && RecentClosesHold(candles, count, level + tolerance * 0.10, -1, 3);
   }
}

bool RecentClosesHold(CandleBar &candles[], const int count, const double level, const int side, const int barsToCheck)
{
   if(count < barsToCheck)
      return(false);

   for(int i = count - barsToCheck; i < count; ++i)
   {
      if(side > 0 && candles[i].close <= level)
         return(false);
      if(side < 0 && candles[i].close >= level)
         return(false);
   }
   return(true);
}

string BuildDecisionLabel(PaAnalysis &analysis,
                          ValueState &valueState,
                          WyckoffState &wyckoffState,
                          BrooksState &brooksState)
{
   if(wyckoffState.bias == "bear" && (brooksState.bias == "bear" || analysis.bias == "bear"))
      return("Bearish execution active");
   if(wyckoffState.bias == "bull" && (brooksState.bias == "bull" || analysis.bias == "bull"))
      return("Bullish execution active");
   if(valueState.key == VALUE_REJECTED_ABOVE)
      return("Bearish watch after sweep-high rejection");
   if(valueState.key == VALUE_REJECTED_BELOW)
      return("Bullish watch after sweep-low rejection");
   if(analysis.bias == "bear")
      return("Bearish context; wait for setup");
   if(analysis.bias == "bull")
      return("Bullish context; wait for setup");
   return("Range; stay patient");
}

string BuildExecutionLabel(PaAnalysis &analysis, ValueState &valueState, BrooksState &brooksState)
{
   bool inSupply = IsInsideZone(analysis.current, analysis.zones.supplyBottom, analysis.zones.supplyTop, analysis.rangeUnit * 0.30);
   bool inDemand = IsInsideZone(analysis.current, analysis.zones.demandBottom, analysis.zones.demandTop, analysis.rangeUnit * 0.30);

   if(brooksState.key == BROOKS_BREAKOUT_PULLBACK_LONG)
      return("Accepted breakout; wait for long pullback");
   if(brooksState.key == BROOKS_BREAKOUT_PULLBACK_SHORT)
      return("Accepted breakdown; wait for short rally");
   if(brooksState.key == BROOKS_SECOND_ENTRY_LONG)
      return("Sweep-low recovery; wait for second-entry long");
   if(brooksState.key == BROOKS_SECOND_ENTRY_SHORT)
      return("Sweep-high rejection; wait for second-entry short");

   if(analysis.bias == "bear")
   {
      if(analysis.bos == "Down BOS" && analysis.current < analysis.vwapLast && analysis.current <= analysis.zones.equalLow + analysis.rangeUnit * 0.20)
         return("Break below, then short the rally");
      if(inSupply && analysis.current < analysis.vwapLast)
         return("Short after failed rally");
      return("Bearish context; wait for retrace");
   }

   if(analysis.bias == "bull")
   {
      if(analysis.bos == "Up BOS" && analysis.current > analysis.vwapLast && analysis.current >= analysis.zones.equalHigh - analysis.rangeUnit * 0.20)
         return("Break above, then buy the pullback");
      if(inDemand && analysis.current > analysis.vwapLast)
         return("Buy after pullback support");
      return("Bullish context; wait for pullback");
   }

   if(valueState.key == VALUE_INSIDE)
      return("Inside value; wait for a sweep");
   return("Mid-range; stand aside");
}

string BuildRiskLabel(PaAnalysis &analysis, BrooksState &brooksState)
{
   if(analysis.atrState == "High vol")
      return("Keep stop outside structure; do not chase first leg");
   if(brooksState.key == BROOKS_BREAKOUT_PULLBACK_LONG || brooksState.key == BROOKS_BREAKOUT_PULLBACK_SHORT)
      return("Only trade confirmed pullback/rally-fail; do not chase first breakout bar");
   if(brooksState.key == BROOKS_SECOND_ENTRY_LONG || brooksState.key == BROOKS_SECOND_ENTRY_SHORT)
      return("Wait for second confirmation; first leg is observation only");
   if(analysis.bias == "neutral")
      return("Do not chase mid-range price; wait for confirmation");
   if(analysis.bias == "bear")
      return("Invalidation first if supply top gets reclaimed");
   return("Invalidation first if demand base breaks");
}

string BuildPlanLabel(PaAnalysis &analysis, ValueState &valueState, BrooksState &brooksState)
{
   if(brooksState.key == BROOKS_BREAKOUT_PULLBACK_LONG)
      return("Work around VAH / bull FVG; wait for pullback confirmation");
   if(brooksState.key == BROOKS_BREAKOUT_PULLBACK_SHORT)
      return("Work around VAL / bear FVG; wait for rally-fail confirmation");
   if(brooksState.key == BROOKS_SECOND_ENTRY_LONG)
      return("After Spring/Test, wait for first failed pullback");
   if(brooksState.key == BROOKS_SECOND_ENTRY_SHORT)
      return("After UTAD/LPSY, wait for first failed rally");
   if(valueState.key == VALUE_REJECTED_ABOVE || analysis.bias == "bear")
      return(FormatZone(analysis.zones.supplyBottom, analysis.zones.supplyTop) + " watch supply pressure; do not chase first leg");
   if(valueState.key == VALUE_REJECTED_BELOW || analysis.bias == "bull")
      return(FormatZone(analysis.zones.demandBottom, analysis.zones.demandTop) + " watch demand support; do not grab first bounce");
   return(FormatPrice(analysis.zones.equalLow) + " / " + FormatPrice(analysis.zones.equalHigh) + " whichever gets swept first becomes the first read");
}

string ResolveCurrentArea(PaAnalysis &analysis)
{
   if(IsInsideZone(analysis.current, analysis.zones.supplyBottom, analysis.zones.supplyTop, analysis.rangeUnit * 0.20))
      return("Premium / supply");
   if(IsInsideZone(analysis.current, analysis.zones.demandBottom, analysis.zones.demandTop, analysis.rangeUnit * 0.20))
      return("Discount / demand");
   return("Mid-range");
}

void ComposePanel(PaAnalysis &analysis,
                  SessionContext &sessionContext,
                  ValueState &valueState,
                  WyckoffState &wyckoffState,
                  BrooksState &brooksState,
                  const string execution,
                  const string decision,
                  const string riskText,
                  const string currentArea,
                  const string planText,
                  const bool bullFvgFound,
                  const double bullFvgLow,
                  const double bullFvgHigh,
                  const bool bearFvgFound,
                  const double bearFvgLow,
                  const double bearFvgHigh)
{
   for(int clearIndex = 0; clearIndex < PANEL_MAX_LINE_COUNT; ++clearIndex)
   {
      g_panelText[clearIndex] = "";
      g_panelColor[clearIndex] = InpPrimaryTextColor;
   }

   string stateLine = analysis.marketBias + " / " + (analysis.current < analysis.vwapLast ? "Below VWAP" : "Above VWAP") + " / " + analysis.atrState;
   string probabilityLine = "Bear " + DoubleToString(analysis.bearPct, 0) + " / Bull " + DoubleToString(analysis.bullPct, 0) + " / Range " + DoubleToString(analysis.neutralPct, 0);
   string valueLine = sessionContext.previousProfile.valid
                      ? "POC " + FormatPrice(sessionContext.previousProfile.poc) + " / EqH " + FormatPrice(analysis.zones.equalHigh) + " / EqL " + FormatPrice(analysis.zones.equalLow)
                      : "POC / EqH / EqL waiting for prior session";
   string asiaLine = sessionContext.hasCurrentAsia
                     ? "Asia " + FormatPrice(sessionContext.currentAsiaHigh) + "/" + FormatPrice(sessionContext.currentAsiaLow)
                     : sessionContext.hasPreviousAsia
                       ? "Asia " + FormatPrice(sessionContext.previousAsiaHigh) + "/" + FormatPrice(sessionContext.previousAsiaLow)
                       : "Asia pending";
   string fvgText = "Upper " + (bearFvgFound ? FormatZone(bearFvgLow, bearFvgHigh) : "--") + " / Lower " + (bullFvgFound ? FormatZone(bullFvgLow, bullFvgHigh) : "--");
   string liquidityLine = "H " + (sessionContext.previousHigh > 0.0 ? FormatPrice(sessionContext.previousHigh) : "--") +
                          " / VAH " + (sessionContext.previousProfile.valid ? FormatPrice(sessionContext.previousProfile.vah) : "--") +
                          " / L " + (sessionContext.previousLow > 0.0 ? FormatPrice(sessionContext.previousLow) : "--") +
                          " / VAL " + (sessionContext.previousProfile.valid ? FormatPrice(sessionContext.previousProfile.val) : "--");
   string compactCurrentArea = CompactSlashLabel(currentArea);
   string planDisplay = planText + " | " + valueState.routeText;
   string planLine1 = "";
   string planLine2 = "";
   string planLine3 = "";
   SplitPlanText(planDisplay, 40, planLine1, planLine2, planLine3);

   g_panelText[0] = "Decision: " + decision;
   g_panelText[1] = "State: " + stateLine + " / " + probabilityLine;
   g_panelText[2] = "Execution: " + execution;
   g_panelText[3] = "Read: " + CompactValueLabel(valueState) + " / " + CompactWyckoffLabel(wyckoffState) + " / " + CompactBrooksLabel(brooksState);
   g_panelText[4] = "Liquidity: " + liquidityLine;
   g_panelText[5] = "Session: " + valueLine + " | " + asiaLine;
   g_panelText[6] = "Structure: " + analysis.bos + " / " + analysis.choch + " | " + compactCurrentArea;
   g_panelText[7] = "FVG: " + fvgText;
   g_panelText[8] = "Plan: " + planLine1;
   g_panelLineCount = 9;
   if(planLine2 != "")
   {
      g_panelText[9] = "      " + planLine2;
      g_panelLineCount = 10;
   }
   if(planLine3 != "")
   {
      g_panelText[10] = "      " + planLine3;
      g_panelLineCount = 11;
   }

   g_panelColor[0] = wyckoffState.bias == "bear" ? InpBearTextColor : wyckoffState.bias == "bull" ? InpBullTextColor : InpPrimaryTextColor;
   g_panelColor[1] = InpMutedTextColor;
   g_panelColor[2] = brooksState.bias == "bear" ? InpBearTextColor : brooksState.bias == "bull" ? InpBullTextColor : InpAccentTextColor;
   g_panelColor[3] = valueState.bias == "bear" ? InpBearTextColor : valueState.bias == "bull" ? InpBullTextColor : InpInfoTextColor;
   g_panelColor[4] = InpAccentTextColor;
   g_panelColor[5] = InpMutedTextColor;
   g_panelColor[6] = InpPrimaryTextColor;
   g_panelColor[7] = InpMutedTextColor;
   g_panelColor[8] = InpPrimaryTextColor;
   if(g_panelLineCount > 9)
      g_panelColor[9] = InpPrimaryTextColor;
   if(g_panelLineCount > 10)
      g_panelColor[10] = InpPrimaryTextColor;
}

void ApplyPanelLayout()
{
   if(!InpShowPanel)
      return;

   EnsurePanelBackground();
   AutoPlacePanelIfNeeded();

   int paddingX = MathMax(4, InpPanelPaddingX);
   int paddingY = MathMax(4, InpPanelPaddingY);
   int bottomPadding = MathMax(12, InpPanelBottomPadding);
   int lineGap = MathMax(InpLineFontSize + 12, InpPanelLineGap);
   int lastLineTop = paddingY + (g_panelLineCount - 1) * lineGap;
   int lastLineBottom = lastLineTop + InpLineFontSize + 4;
   int compactHeight = lastLineBottom + bottomPadding;
   int width = ResolvePanelWidth(paddingX);
   int height = InpCompactPanelLayout ? compactHeight : MathMax(InpPanelHeight, compactHeight);
   string bgName = ObjName("PANEL_BG");

   ObjectSetInteger(0, bgName, OBJPROP_CORNER, g_panelCorner);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, g_panelX);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, g_panelY);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, height);

   for(int i = 0; i < g_panelLineCount; ++i)
   {
      string name = ObjName("PANEL_LINE_" + IntegerToString(i));
      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0, name, OBJPROP_CORNER, g_panelCorner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, g_panelX + paddingX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, g_panelY + paddingY + i * lineGap);
      ObjectSetInteger(0, name, OBJPROP_COLOR, g_panelColor[i]);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, i == 0 ? InpHeaderFontSize : InpLineFontSize);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, InpPanelFontName);
      ObjectSetString(0, name, OBJPROP_TEXT, g_panelText[i]);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, "\n");
   }

   for(int cleanupIndex = g_panelLineCount; cleanupIndex < PANEL_MAX_LINE_COUNT; ++cleanupIndex)
      ObjectDelete(0, ObjName("PANEL_LINE_" + IntegerToString(cleanupIndex)));
}

void EnsurePanelBackground()
{
   string bgName = ObjName("PANEL_BG");
   if(ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, InpPanelBgColor);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, InpPanelBorderColor);
   ObjectSetInteger(0, bgName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, bgName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, InpPanelMovable);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTED, false);
   ObjectSetString(0, bgName, OBJPROP_TOOLTIP, "\n");
}

void AutoPlacePanelIfNeeded()
{
   if(!InpAutoPlacePanel)
      return;

   int safeTopArea = MathMax(InpPanelY, 118);
   bool legacyTopLeft = g_panelCorner == 0 && g_panelX <= 50 && g_panelY <= 90;
   bool legacyRightTop = g_panelCorner == 1 && g_panelX <= 50 && g_panelY <= 60;
   bool overlapsTradePanel = g_panelCorner == 0 && g_panelX <= 60 && g_panelY < safeTopArea;
   if(legacyTopLeft || legacyRightTop || overlapsTradePanel)
   {
      g_panelCorner = InpPanelCorner;
      g_panelX = InpPanelX;
      g_panelY = safeTopArea;
      SavePanelState();
   }
}

int EstimateLinePixelWidth(const string text, const int fontSize)
{
   int charWidth = MathMax(7, fontSize + 1);
   return(StringLen(text) * charWidth);
}

int ResolvePanelWidth(const int paddingX)
{
   int width = InpCompactPanelLayout ? MathMax(InpPanelWidth, InpCompactPanelMinWidth) : InpPanelWidth;
   if(InpAutoFitPanelWidth)
   {
      int estimated = width;
      for(int i = 0; i < g_panelLineCount; ++i)
      {
         int fontSize = i == 0 ? InpHeaderFontSize : InpLineFontSize;
         estimated = MathMax(estimated, EstimateLinePixelWidth(g_panelText[i], fontSize) + paddingX * 2 + 18);
      }

      width = estimated;
      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      if(chartWidth > 120)
         width = MathMin(width, chartWidth - 24);
   }

   return(MathMax(width, 520));
}

void DeletePanelObjects()
{
   for(int i = 0; i < PANEL_MAX_LINE_COUNT; ++i)
      ObjectDelete(0, ObjName("PANEL_LINE_" + IntegerToString(i)));
   ObjectDelete(0, ObjName("PANEL_BG"));
}

void DrawSignalArrows(CandleBar &candles[],
                      const int count,
                      PaAnalysis &analysis,
                      SessionContext &sessionContext,
                      ValueState &valueState,
                      BrooksState &brooksState)
{
   DeleteArrowObjects();
   if(count < 3)
      return;

   if(!sessionContext.previousProfile.valid)
      return;

   double step = sessionContext.previousProfile.step > 0.0 ? sessionContext.previousProfile.step : MathMax(analysis.rangeUnit * 0.12, 0.4);
   double tolerance = MathMax(step * 0.75, analysis.rangeUnit * 0.10);
   double breakoutLongLevel = MathMax(sessionContext.previousProfile.vah, analysis.zones.equalHigh);
   double breakoutShortLevel = MathMin(sessionContext.previousProfile.val, analysis.zones.equalLow);
   double pullbackLongLevel = (brooksState.key == BROOKS_SECOND_ENTRY_LONG || valueState.key == VALUE_REJECTED_BELOW)
                              ? sessionContext.previousProfile.val
                              : sessionContext.previousProfile.vah;
   double pullbackShortLevel = (brooksState.key == BROOKS_SECOND_ENTRY_SHORT || valueState.key == VALUE_REJECTED_ABOVE)
                               ? sessionContext.previousProfile.vah
                               : sessionContext.previousProfile.val;

   bool bullContext = IsBullArrowContext(analysis, valueState, brooksState);
   bool bearContext = IsBearArrowContext(analysis, valueState, brooksState);

   int breakoutLongIndex = FindRecentBreakoutLong(candles, count, breakoutLongLevel, analysis.vwapLast, tolerance, bullContext);
   int breakoutShortIndex = FindRecentBreakoutShort(candles, count, breakoutShortLevel, analysis.vwapLast, tolerance, bearContext);
   int pullbackLongIndex = FindRecentPullbackLong(candles, count, pullbackLongLevel, tolerance, bullContext);
   int pullbackShortIndex = FindRecentPullbackShort(candles, count, pullbackShortLevel, tolerance, bearContext);

   if(breakoutLongIndex >= 0)
      DrawArrow(ObjName("ARROW_BREAKOUT_LONG"), candles[breakoutLongIndex].time, candles[breakoutLongIndex].low - InpBreakoutArrowShiftPoints * Point, InpBreakoutArrowCodeLong, InpBreakoutLongColor);
   if(breakoutShortIndex >= 0)
      DrawArrow(ObjName("ARROW_BREAKOUT_SHORT"), candles[breakoutShortIndex].time, candles[breakoutShortIndex].high + InpBreakoutArrowShiftPoints * Point, InpBreakoutArrowCodeShort, InpBreakoutShortColor);
   if(pullbackLongIndex >= 0)
      DrawArrow(ObjName("ARROW_PULLBACK_LONG"), candles[pullbackLongIndex].time, candles[pullbackLongIndex].low - InpPullbackArrowShiftPoints * Point, InpPullbackArrowCodeLong, InpPullbackLongColor);
   if(pullbackShortIndex >= 0)
      DrawArrow(ObjName("ARROW_PULLBACK_SHORT"), candles[pullbackShortIndex].time, candles[pullbackShortIndex].high + InpPullbackArrowShiftPoints * Point, InpPullbackArrowCodeShort, InpPullbackShortColor);
}

void DeleteArrowObjects()
{
   ObjectDelete(0, ObjName("ARROW_BREAKOUT_LONG"));
   ObjectDelete(0, ObjName("ARROW_BREAKOUT_SHORT"));
   ObjectDelete(0, ObjName("ARROW_PULLBACK_LONG"));
   ObjectDelete(0, ObjName("ARROW_PULLBACK_SHORT"));
}

void DrawArrow(const string name,
               const datetime when,
               const double price,
               const int arrowCode,
               const color clr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, when, price);
   else
      ObjectMove(0, name, 0, when, price);

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, InpArrowWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

bool IsBullArrowContext(PaAnalysis &analysis, ValueState &valueState, BrooksState &brooksState)
{
   if(brooksState.bias == "bull" || analysis.bias == "bull")
      return(true);
   return(valueState.key == VALUE_ACCEPTED_ABOVE || valueState.key == VALUE_REJECTED_BELOW);
}

bool IsBearArrowContext(PaAnalysis &analysis, ValueState &valueState, BrooksState &brooksState)
{
   if(brooksState.bias == "bear" || analysis.bias == "bear")
      return(true);
   return(valueState.key == VALUE_ACCEPTED_BELOW || valueState.key == VALUE_REJECTED_ABOVE);
}

int ArrowScanStartIndex(const int count)
{
   int lookback = EffectiveArrowLookbackBars();
   return(MathMax(0, count - lookback));
}

int EffectiveArrowLookbackBars()
{
   int lookback = MathMax(1, InpArrowSignalLookbackBars);
   if(Period() <= PERIOD_M5)
      return(MathMax(lookback, 36));
   if(Period() <= PERIOD_M15)
      return(MathMax(lookback, 24));
   if(Period() <= PERIOD_M30)
      return(MathMax(lookback, 18));
   return(lookback);
}

double EffectiveArrowTolerance(const double baseTolerance)
{
   if(Period() <= PERIOD_M5)
      return(baseTolerance * 1.45);
   if(Period() <= PERIOD_M15)
      return(baseTolerance * 1.25);
   if(Period() <= PERIOD_M30)
      return(baseTolerance * 1.10);
   return(baseTolerance);
}

bool BullishArrowBody(CandleBar &bar, const double vwapLast)
{
   if(bar.close >= bar.open)
      return(true);
   double barMid = (bar.high + bar.low) * 0.5;
   return(bar.close >= barMid || bar.close > vwapLast);
}

bool BearishArrowBody(CandleBar &bar, const double vwapLast)
{
   if(bar.close <= bar.open)
      return(true);
   double barMid = (bar.high + bar.low) * 0.5;
   return(bar.close <= barMid || bar.close < vwapLast);
}

int FindRecentBreakoutLong(CandleBar &candles[],
                           const int count,
                           const double level,
                           const double vwapLast,
                           const double tolerance,
                           const bool bullContext)
{
   if(!bullContext)
      return(-1);

   int start = ArrowScanStartIndex(count);
   for(int i = count - 1; i >= start; --i)
   {
      double localTolerance = EffectiveArrowTolerance(tolerance);
      bool closesAbove = candles[i].close >= level - localTolerance * 0.22;
      bool reachesAbove = candles[i].high >= level + localTolerance * 0.05;
      bool bodySupport = BullishArrowBody(candles[i], vwapLast);
      if(closesAbove && reachesAbove && bodySupport)
         return(i);
   }
   return(-1);
}

int FindRecentBreakoutShort(CandleBar &candles[],
                            const int count,
                            const double level,
                            const double vwapLast,
                            const double tolerance,
                            const bool bearContext)
{
   if(!bearContext)
      return(-1);

   int start = ArrowScanStartIndex(count);
   for(int i = count - 1; i >= start; --i)
   {
      double localTolerance = EffectiveArrowTolerance(tolerance);
      bool closesBelow = candles[i].close <= level + localTolerance * 0.22;
      bool reachesBelow = candles[i].low <= level - localTolerance * 0.05;
      bool bodyPressure = BearishArrowBody(candles[i], vwapLast);
      if(closesBelow && reachesBelow && bodyPressure)
         return(i);
   }
   return(-1);
}

int FindRecentPullbackLong(CandleBar &candles[],
                           const int count,
                           const double level,
                           const double tolerance,
                           const bool bullContext)
{
   if(!bullContext)
      return(-1);

   int start = ArrowScanStartIndex(count);
   for(int i = count - 1; i >= start; --i)
   {
      double localTolerance = EffectiveArrowTolerance(tolerance);
      bool taggedLevel = candles[i].low <= level + localTolerance * 1.20;
      bool heldLevel = candles[i].close >= level - localTolerance * 0.25;
      bool bullishBar = BullishArrowBody(candles[i], level);
      if(taggedLevel && heldLevel && bullishBar)
         return(i);
   }
   return(-1);
}

int FindRecentPullbackShort(CandleBar &candles[],
                            const int count,
                            const double level,
                            const double tolerance,
                            const bool bearContext)
{
   if(!bearContext)
      return(-1);

   int start = ArrowScanStartIndex(count);
   for(int i = count - 1; i >= start; --i)
   {
      double localTolerance = EffectiveArrowTolerance(tolerance);
      bool taggedLevel = candles[i].high >= level - localTolerance * 1.20;
      bool heldLevel = candles[i].close <= level + localTolerance * 0.25;
      bool bearishBar = BearishArrowBody(candles[i], level);
      if(taggedLevel && heldLevel && bearishBar)
         return(i);
   }
   return(-1);
}

void ComputeEma(double &values[], const int count, const int period, double &out[])
{
   ArrayResize(out, count);
   double alpha = 2.0 / (period + 1.0);
   double prev = values[0];
   for(int i = 0; i < count; ++i)
   {
      if(i == 0)
         prev = values[0];
      else
         prev = alpha * values[i] + (1.0 - alpha) * prev;
      out[i] = prev;
   }
}

void ComputeVwap(CandleBar &candles[], const int count, double &out[])
{
   ArrayResize(out, count);
   double cumulativePv = 0.0;
   double cumulativeVol = 0.0;

   for(int i = 0; i < count; ++i)
   {
      double typical = (candles[i].high + candles[i].low + candles[i].close) / 3.0;
      double volume = candles[i].volume > 0 ? (double)candles[i].volume : 1.0;
      cumulativePv += typical * volume;
      cumulativeVol += volume;
      out[i] = cumulativeVol > 0.0 ? cumulativePv / cumulativeVol : typical;
   }
}

double AverageRange(CandleBar &candles[], const int count, const int window)
{
   int size = MathMin(window, count);
   if(size <= 0)
      return(0.0);

   double total = 0.0;
   for(int i = count - size; i < count; ++i)
      total += candles[i].high - candles[i].low;
   return(total / size);
}

double HighestHigh(CandleBar &candles[], const int count)
{
   double value = -1.0e100;
   for(int i = 0; i < count; ++i)
      value = MathMax(value, candles[i].high);
   return(value);
}

double LowestLow(CandleBar &candles[], const int count)
{
   double value = 1.0e100;
   for(int i = 0; i < count; ++i)
      value = MathMin(value, candles[i].low);
   return(value);
}

double SessionHigh(CandleBar &candles[], const int startIndex, const int endIndex)
{
   double value = -1.0e100;
   for(int i = startIndex; i <= endIndex; ++i)
      value = MathMax(value, candles[i].high);
   return(value);
}

double SessionLow(CandleBar &candles[], const int startIndex, const int endIndex)
{
   double value = 1.0e100;
   for(int i = startIndex; i <= endIndex; ++i)
      value = MathMin(value, candles[i].low);
   return(value);
}

bool BuildAsiaRange(CandleBar &candles[], const int startIndex, const int endIndex, double &asiaHigh, double &asiaLow)
{
   bool found = false;
   asiaHigh = -1.0e100;
   asiaLow = 1.0e100;

   for(int i = startIndex; i <= endIndex; ++i)
   {
      int hour = LocalHour(candles[i].time);
      if(hour < InpAsiaSessionStartHour || hour >= InpAsiaSessionEndHour)
         continue;
      asiaHigh = MathMax(asiaHigh, candles[i].high);
      asiaLow = MathMin(asiaLow, candles[i].low);
      found = true;
   }
   return(found);
}

double ResolveProfileStep(const double high, const double low)
{
   double raw = MathMax((high - low) / 24.0, 0.5);
   return(ClampValue(MathRound(raw * 2.0) / 2.0, 0.5, 4.0));
}

double RoundToStep(const double value, const double step)
{
   return(NormalizeDouble(MathRound(value / step) * step, 2));
}

int FindLevelIndex(double &levels[], const int used, const double price, const double tolerance)
{
   for(int i = 0; i < used; ++i)
   {
      if(MathAbs(levels[i] - price) <= tolerance)
         return(i);
   }
   return(-1);
}

void SortLevels(double &levels[], int &counts[], const int used)
{
   for(int i = 0; i < used - 1; ++i)
   {
      for(int j = i + 1; j < used; ++j)
      {
         if(levels[j] < levels[i])
         {
            double levelTmp = levels[i];
            int countTmp = counts[i];
            levels[i] = levels[j];
            counts[i] = counts[j];
            levels[j] = levelTmp;
            counts[j] = countTmp;
         }
      }
   }
}

int LocalDayKey(const datetime brokerTime)
{
   datetime shifted = brokerTime + InpSessionOffsetHours * 3600;
   return(TimeYear(shifted) * 10000 + TimeMonth(shifted) * 100 + TimeDay(shifted));
}

int LocalHour(const datetime brokerTime)
{
   datetime shifted = brokerTime + InpSessionOffsetHours * 3600;
   return(TimeHour(shifted));
}

void ResetSessionContext(SessionContext &ctx)
{
   ctx.valid = false;
   ctx.currentSession.valid = false;
   ctx.currentSession.startIndex = 0;
   ctx.currentSession.endIndex = 0;
   ctx.currentSession.dayKey = 0;
   ctx.previousSession.valid = false;
   ctx.previousSession.startIndex = 0;
   ctx.previousSession.endIndex = 0;
   ctx.previousSession.dayKey = 0;
   ctx.currentProfile.valid = false;
   ctx.currentProfile.low = 0.0;
   ctx.currentProfile.high = 0.0;
   ctx.currentProfile.step = 0.0;
   ctx.currentProfile.poc = 0.0;
   ctx.currentProfile.vah = 0.0;
   ctx.currentProfile.val = 0.0;
   ctx.previousProfile.valid = false;
   ctx.previousProfile.low = 0.0;
   ctx.previousProfile.high = 0.0;
   ctx.previousProfile.step = 0.0;
   ctx.previousProfile.poc = 0.0;
   ctx.previousProfile.vah = 0.0;
   ctx.previousProfile.val = 0.0;
   ctx.hasCurrentAsia = false;
   ctx.hasPreviousAsia = false;
   ctx.currentAsiaHigh = 0.0;
   ctx.currentAsiaLow = 0.0;
   ctx.previousAsiaHigh = 0.0;
   ctx.previousAsiaLow = 0.0;
   ctx.previousHigh = 0.0;
   ctx.previousLow = 0.0;
}

double ClampValue(const double value, const double minimum, const double maximum)
{
   return(MathMin(maximum, MathMax(minimum, value)));
}

bool IsInsideZone(const double value, const double zoneLow, const double zoneHigh, const double tolerance)
{
   double low = MathMin(zoneLow, zoneHigh) - tolerance;
   double high = MathMax(zoneLow, zoneHigh) + tolerance;
   return(value >= low && value <= high);
}

double MaxPointValue()
{
   return(MathMax(Point, 0.01));
}

double MathMaxPointSpan(const double points)
{
   return(points * MaxPointValue());
}

string ResolveMarketBias(const double current,
                         const double emaFast,
                         const double emaMid,
                         const double vwapLast)
{
   bool downwardAligned = current < emaFast && emaFast < emaMid;
   bool upwardAligned = current > emaFast && emaFast > emaMid;

   if(downwardAligned)
      return("Strong bear");
   if(upwardAligned)
      return("Strong bull");
   if(current < vwapLast)
      return("Range leaning bear");
   return("Range leaning bull");
}

string ResolveAtrState(const double atrValue, const double avgRange)
{
   if(atrValue <= 0.0 || avgRange <= 0.0)
      return("ATR pending");
   if(atrValue > avgRange * 1.20)
      return("High vol");
   if(atrValue < avgRange * 0.80)
      return("Low vol");
   return("Normal vol");
}

string ClassifyBias(PaAnalysis &analysis)
{
   if(analysis.bearPct >= 54.0)
      return("bear");
   if(analysis.bullPct >= 52.0)
      return("bull");
   return("neutral");
}

string ShortenText(const string value, const int maxChars)
{
   if(maxChars <= 3 || StringLen(value) <= maxChars)
      return(value);
   return(StringSubstr(value, 0, maxChars) + "...");
}

bool IsPlanWrapDelimiter(const string ch)
{
   return(ch == " " || ch == "/" || ch == "|" || ch == "," || ch == "." || ch == "?" || ch == ";");
}

string TrimPanelText(const string value)
{
   int start = 0;
   int finish = StringLen(value);
   while(start < finish && StringSubstr(value, start, 1) == " ")
      start++;
   while(finish > start && StringSubstr(value, finish - 1, 1) == " ")
      finish--;
   return(StringSubstr(value, start, finish - start));
}

string NextWrappedPlanSegment(const string value, int &startIndex, const int maxChars)
{
   int totalLength = StringLen(value);
   while(startIndex < totalLength && StringSubstr(value, startIndex, 1) == " ")
      startIndex++;

   if(startIndex >= totalLength)
      return("");

   int remaining = totalLength - startIndex;
   if(remaining <= maxChars)
   {
      string tail = TrimPanelText(StringSubstr(value, startIndex, remaining));
      startIndex = totalLength;
      return(tail);
   }

   int minBreak = startIndex + MathMax(4, maxChars / 2);
   int breakIndex = startIndex + maxChars;
   for(int i = breakIndex; i > minBreak; --i)
   {
      if(IsPlanWrapDelimiter(StringSubstr(value, i - 1, 1)))
      {
         breakIndex = i;
         break;
      }
   }

   string segment = TrimPanelText(StringSubstr(value, startIndex, breakIndex - startIndex));
   startIndex = breakIndex;
   return(segment);
}

void SplitPlanText(const string value,
                   const int maxChars,
                   string &line1,
                   string &line2,
                   string &line3)
{
   int startIndex = 0;
   line1 = NextWrappedPlanSegment(value, startIndex, maxChars);
   line2 = NextWrappedPlanSegment(value, startIndex, maxChars);
   line3 = NextWrappedPlanSegment(value, startIndex, maxChars);

   if(line1 == "")
      line1 = value;

   if(startIndex < StringLen(value) && line3 != "")
      line3 = line3 + " ...";
}

string CompactSlashLabel(const string value)
{
   int pos = StringFind(value, " / ", 0);
   if(pos > 0)
      return(StringSubstr(value, 0, pos));
   return(value);
}

string CompactValueLabel(ValueState &valueState)
{
   if(valueState.key == VALUE_ACCEPTED_ABOVE)
      return("Accepted above");
   if(valueState.key == VALUE_ACCEPTED_BELOW)
      return("Accepted below");
   if(valueState.key == VALUE_REJECTED_ABOVE)
      return("Sweep-high reject");
   if(valueState.key == VALUE_REJECTED_BELOW)
      return("Sweep-low reject");
   if(valueState.key == VALUE_INSIDE)
      return("Inside value");
   return("No value read");
}

string CompactWyckoffLabel(WyckoffState &wyckoffState)
{
   if(wyckoffState.key == WYCKOFF_ACCUMULATION)
      return("Accumulation");
   if(wyckoffState.key == WYCKOFF_DISTRIBUTION)
      return("Distribution");
   if(wyckoffState.key == WYCKOFF_MARKUP)
      return("Markup");
   if(wyckoffState.key == WYCKOFF_MARKDOWN)
      return("Markdown");
   if(StringFind(wyckoffState.label, "Testing", 0) >= 0)
      return("Rotation");
   return("Range");
}

string CompactBrooksLabel(BrooksState &brooksState)
{
   if(brooksState.key == BROOKS_SECOND_ENTRY_LONG)
      return("2nd-entry long");
   if(brooksState.key == BROOKS_SECOND_ENTRY_SHORT)
      return("2nd-entry short");
   if(brooksState.key == BROOKS_BREAKOUT_PULLBACK_LONG)
      return("BO-PB long");
   if(brooksState.key == BROOKS_BREAKOUT_PULLBACK_SHORT)
      return("BO-PB short");
   return("Waiting");
}

string FormatPrice(const double value)
{
   int displayDigits = Digits;
   if(displayDigits > 3)
      displayDigits = 3;
   return(DoubleToString(value, displayDigits));
}

string FormatZone(const double low, const double high)
{
   double zoneLow = MathMin(low, high);
   double zoneHigh = MathMax(low, high);
   return(FormatPrice(zoneLow) + "-" + FormatPrice(zoneHigh));
}

string ObjName(const string suffix)
{
   return(g_prefix + suffix);
}

void DeleteObjectsByPrefix(const string prefix)
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; --i)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(0, name);
   }
}

void SyncPanelPositionFromObject()
{
   string bgName = ObjName("PANEL_BG");
   if(ObjectFind(0, bgName) < 0)
      return;

   g_panelCorner = (int)ObjectGetInteger(0, bgName, OBJPROP_CORNER);
   g_panelX = (int)ObjectGetInteger(0, bgName, OBJPROP_XDISTANCE);
   g_panelY = (int)ObjectGetInteger(0, bgName, OBJPROP_YDISTANCE);
}

void SavePanelState()
{
   GlobalVariableSet(g_statePrefix + "CORNER", g_panelCorner);
   GlobalVariableSet(g_statePrefix + "X", g_panelX);
   GlobalVariableSet(g_statePrefix + "Y", g_panelY);
}

void LoadPanelState()
{
   if(GlobalVariableCheck(g_statePrefix + "CORNER"))
      g_panelCorner = (int)GlobalVariableGet(g_statePrefix + "CORNER");
   if(GlobalVariableCheck(g_statePrefix + "X"))
      g_panelX = (int)GlobalVariableGet(g_statePrefix + "X");
   if(GlobalVariableCheck(g_statePrefix + "Y"))
      g_panelY = (int)GlobalVariableGet(g_statePrefix + "Y");
}
