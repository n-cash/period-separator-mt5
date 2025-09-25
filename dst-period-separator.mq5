//+------------------------------------------------------------------+
//|                                   dst-period-separator.mq5       |
//|   Separador dinámico con visibilidad por timeframe (NY DST opt)  |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property copyright "Open Source"
#property link      ""

// Requiere daylight.mqh de Amr Ali en MQL5/Include/
// https://www.mql5.com/en/code/27860
#include <daylight.mqh>

//--- Inputs configurables
input int   ServerGMT   = 2;                // GMT del servidor del broker (ej: 2)
input bool  ApplyNYDST  = true;             // Aplicar corrección DST de NY
input color SepColor    = clrBlack;         // Color de las líneas
input int   SepStyle    = STYLE_DOT;        // Estilo
input int   SepWidth    = 1;                // Grosor

//--- Máscaras de visibilidad (tabla OBJPROP_TIMEFRAMES)
#define TF_DAILY   (OBJ_PERIOD_M1|OBJ_PERIOD_M2|OBJ_PERIOD_M3|OBJ_PERIOD_M4|OBJ_PERIOD_M5|OBJ_PERIOD_M6|OBJ_PERIOD_M10|OBJ_PERIOD_M12|OBJ_PERIOD_M15|OBJ_PERIOD_M20|OBJ_PERIOD_M30|OBJ_PERIOD_H1|OBJ_PERIOD_H2)
#define TF_H3PLUS  (OBJ_PERIOD_H3|OBJ_PERIOD_H4|OBJ_PERIOD_H6|OBJ_PERIOD_H8|OBJ_PERIOD_H12)
#define TF_MONTHLY (OBJ_PERIOD_D1|OBJ_PERIOD_W1)
#define TF_YEARLY  (OBJ_PERIOD_MN1)

//--- Prefijo objetos
string OBJ_PREFIX = "SepNY_";

//--------------------------------------------------------------------
// Utility: eliminar objetos creados por este indicador
void DeleteAllMyObjects()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if(StringFind(nm, OBJ_PREFIX) == 0) 
         ObjectDelete(0, nm);
   }
}

//--------------------------------------------------------------------
// Helper DST: determinamos si un timestamp (server tz) está en DST NY
bool InDST(datetime server_ts)
{
   if(!ApplyNYDST) return false; // ignorar DST si está apagado
   datetime dst_start = 0, dst_end = 0;
   MqlDateTime st;
   TimeToStruct(server_ts, st);
   int year = st.year;
   DST_NewYork(year, dst_start, dst_end);
   return (server_ts >= dst_start && server_ts < dst_end);
}

int GetNYOffsetForTimestamp(datetime server_ts)
{
   if(!ApplyNYDST) return -5; // fijo EST
   return InDST(server_ts) ? -4 : -5; 
}

//--------------------------------------------------------------------
// Construir ny_midnight_server: dado una fecha en NY -> timestamp en server
datetime NYLocalDateToServerMidnight(int ny_year, int ny_mon, int ny_day, int serverGMT, datetime anchor_server_now)
{
   MqlDateTime ny_st={0};
   ny_st.year = ny_year; ny_st.mon = ny_mon; ny_st.day = ny_day;
   datetime ny_local_ts = StructToTime(ny_st);

   datetime dst_start=0, dst_end=0;
   DST_NewYork(ny_year, dst_start, dst_end);
   bool isDst = (ApplyNYDST && ny_local_ts >= dst_start && ny_local_ts < dst_end);
   int ny_offset = isDst ? -4 : -5;
   int diff = ny_offset - serverGMT;
   datetime ny_midnight_server = ny_local_ts - (datetime)diff * 3600;
   return ny_midnight_server;
}

//--------------------------------------------------------------------
// Generadores
void DrawYearlySeparators(int years_back)
{
   datetime now_server = TimeCurrent();
   MqlDateTime st; TimeToStruct(now_server, st);
   int thisYear = st.year;

   for(int y = thisYear - years_back; y <= thisYear; y++)
   {
      datetime ts = NYLocalDateToServerMidnight(y, 1, 1, ServerGMT, now_server);
      string name = OBJ_PREFIX + "Y_" + IntegerToString((int)ts);
      if(ObjectFind(0, name) == -1)
      {
         ObjectCreate(0, name, OBJ_VLINE, 0, ts, 0);
         ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_YEARLY);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
      }
   }
}

void DrawMonthlySeparators(int months_back, bool useOffset)
{
   datetime now_server = TimeCurrent();
   if(!useOffset)
   {
      for(int s = 0; s < months_back; s++)
      {
         datetime ts = iTime(_Symbol, PERIOD_MN1, s);
         if(ts == 0) break;
         string name = OBJ_PREFIX + "M_" + IntegerToString((int)ts);
         if(ObjectFind(0, name) == -1)
         {
            ObjectCreate(0, name, OBJ_VLINE, 0, ts, 0);
            ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
            ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_MONTHLY);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
         }
      }
   }
   else
   {
      MqlDateTime stNow; TimeToStruct(now_server, stNow);
      int year = stNow.year, month = stNow.mon;
      for(int k = 0; k < months_back; k++)
      {
         int m = month - k, y = year;
         while(m <= 0) { m += 12; y -= 1; }
         datetime ts = NYLocalDateToServerMidnight(y, m, 1, ServerGMT, now_server);
         string name = OBJ_PREFIX + "M_" + IntegerToString((int)ts);
         if(ObjectFind(0, name) == -1)
         {
            ObjectCreate(0, name, OBJ_VLINE, 0, ts, 0);
            ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
            ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_MONTHLY);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
         }
      }
   }
}

void DrawWeeklySeparators(int weeks_back, bool useOffset)
{
   datetime now_server = TimeCurrent();
   if(!useOffset)
   {
      for(int s = 0; s < weeks_back; s++)
      {
         datetime ts = iTime(_Symbol, PERIOD_W1, s);
         if(ts == 0) break;
         string name = OBJ_PREFIX + "W_" + IntegerToString((int)ts);
         if(ObjectFind(0, name) == -1)
         {
            ObjectCreate(0, name, OBJ_VLINE, 0, ts, 0);
            ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
            ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_H3PLUS);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
         }
      }
   }
   else
   {
      int ny_offset_now = GetNYOffsetForTimestamp(now_server);
      int diff_now = ny_offset_now - ServerGMT;
      datetime ny_local_now = now_server + (datetime)diff_now * 3600;
      MqlDateTime ny_st; TimeToStruct(ny_local_now, ny_st);

      int dow = ny_st.day_of_week;
      int days_from_monday = (dow == 0) ? 6 : (dow - 1);
      datetime ny_monday_local = ny_local_now - (datetime)days_from_monday * 86400;
      MqlDateTime monday_st; TimeToStruct(ny_monday_local, monday_st);
      monday_st.hour = 0; monday_st.min = 0; monday_st.sec = 0;
      datetime monday_base_local = StructToTime(monday_st);

      for(int k = 0; k < weeks_back; k++)
      {
         datetime wk_local = monday_base_local - (datetime)k * 7 * 86400;
         MqlDateTime wk; TimeToStruct(wk_local, wk);

         datetime dst_s=0, dst_e=0;
         DST_NewYork(wk.year, dst_s, dst_e);
         bool isDst = (ApplyNYDST && wk_local >= dst_s && wk_local < dst_e);
         int ny_offset = isDst ? -4 : -5;
         int diff = ny_offset - ServerGMT;
         datetime wk_server = wk_local - (datetime)diff * 3600;

         string name = OBJ_PREFIX + "W_" + IntegerToString((int)wk_server);
         if(ObjectFind(0, name) == -1)
         {
            ObjectCreate(0, name, OBJ_VLINE, 0, wk_server, 0);
            ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
            ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_H3PLUS);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
         }
      }
   }
}

void DrawDailySeparators(int days_back, bool useOffset)
{
   datetime now_server = TimeCurrent();
   if(!useOffset)
   {
      for(int s = 0; s < days_back; s++)
      {
         datetime ts = iTime(_Symbol, PERIOD_D1, s);
         if(ts == 0) break;
         string name = OBJ_PREFIX + "D_" + IntegerToString((int)ts);
         if(ObjectFind(0, name) == -1)
         {
            ObjectCreate(0, name, OBJ_VLINE, 0, ts, 0);
            ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
            ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_DAILY);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
         }
      }
   }
   else
   {
      int ny_offset_now = GetNYOffsetForTimestamp(now_server);
      int diff_now = ny_offset_now - ServerGMT;
      datetime ny_local_now = now_server + (datetime)diff_now * 3600;
      MqlDateTime stNow; TimeToStruct(ny_local_now, stNow);
      stNow.hour = 0; stNow.min = 0; stNow.sec = 0;
      datetime ny_midnight_today_local = StructToTime(stNow);

      for(int k = 0; k < days_back; k++)
      {
         datetime target_local = ny_midnight_today_local - (datetime)k * 86400;
         MqlDateTime tgt; TimeToStruct(target_local, tgt);

         datetime dst_s=0, dst_e=0;
         DST_NewYork(tgt.year, dst_s, dst_e);
         bool isDst = (ApplyNYDST && target_local >= dst_s && target_local < dst_e);
         int ny_offset = isDst ? -4 : -5;
         int diff = ny_offset - ServerGMT;
         datetime target_server = target_local - (datetime)diff * 3600;

         string name = OBJ_PREFIX + "D_" + IntegerToString((int)target_server);
         if(ObjectFind(0, name) == -1)
         {
            ObjectCreate(0, name, OBJ_VLINE, 0, target_server, 0);
            ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
            ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_DAILY);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
         }
      }
   }
}

//--------------------------------------------------------------------
enum TF_GROUP { GROUP_SMALL_INTRADAY, GROUP_H3_PLUS, GROUP_DAILY, GROUP_WEEK_MONTH };

TF_GROUP EvaluateTFGroup(int period)
{
   if(period <= PERIOD_H2) return GROUP_SMALL_INTRADAY;
   if(period == PERIOD_H3 || period == PERIOD_H4 || period == PERIOD_H6 || period == PERIOD_H8 || period == PERIOD_H12)
      return GROUP_H3_PLUS;
   if(period == PERIOD_D1) return GROUP_DAILY;
   return GROUP_WEEK_MONTH;
}

//--------------------------------------------------------------------
void RedrawSeparatorsForCurrentTF()
{
   DeleteAllMyObjects();
   int period = Period();
   TF_GROUP g = EvaluateTFGroup(period);

   bool useOffset = false;
   int daysBack=0,weeksBack=0,monthsBack=0,yearsBack=0;

   if(g == GROUP_SMALL_INTRADAY)
   {
      useOffset = true;
      daysBack = 400; weeksBack = 200; monthsBack = 60; yearsBack = 10;
      DrawYearlySeparators(yearsBack);
      DrawMonthlySeparators(monthsBack, true);
      DrawWeeklySeparators(weeksBack, true);
      DrawDailySeparators(daysBack, true);
   }
   else if(g == GROUP_H3_PLUS)
   {
      useOffset = true;
      weeksBack = 400; monthsBack = 120; yearsBack = 10;
      DrawYearlySeparators(yearsBack);
      DrawMonthlySeparators(monthsBack, true);
      DrawWeeklySeparators(weeksBack, true);
   }
   else if(g == GROUP_DAILY)
   {
      useOffset = false;
      monthsBack = 120; yearsBack = 10;
      DrawYearlySeparators(yearsBack);
      DrawMonthlySeparators(monthsBack, false);
   }
   else
   {
      useOffset = false;
      yearsBack = 20;
      DrawYearlySeparators(yearsBack);
   }
}

//--------------------------------------------------------------------
int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   RedrawSeparatorsForCurrentTF();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // DeleteAllMyObjects();
}

int prevPeriod = 0;
int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],
                const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   int curPeriod = Period();
   if(curPeriod != prevPeriod)
   {
      RedrawSeparatorsForCurrentTF();
      prevPeriod = curPeriod;
   }

   bool any=false; int total = ObjectsTotal(0);
   for(int i=total-1;i>=0;i--)
   {
      string nm = ObjectName(0,i);
      if(StringFind(nm,OBJ_PREFIX)==0){ any=true; break; }
   }
   if(!any) RedrawSeparatorsForCurrentTF();

   return(rates_total);
}
