//+------------------------------------------------------------------+
//|                                   dst-period-separator.mq5       |
//|   Separador dinámico con visibilidad por timeframe (DST toggles) |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property copyright "Open Source"
#property link      ""

// Requiere daylight.mqh de Amr Ali en MQL5/Include/
// https://www.mql5.com/en/code/27860
#include <daylight.mqh>

//--- Inputs configurables
input int   ServerGMT   = 2;                 // GMT del servidor del broker (ej: 2)
enum DSTMode { DST_NONE, DST_US, DST_EU };
input DSTMode DSTAdjust = DST_US;            // Ajuste DST: Ninguno / América / Europa
input color SepColor    = clrBlack;          // Color de las líneas
input int   SepStyle    = STYLE_DOT;         // Estilo
input int   SepWidth    = 1;                 // Grosor

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
// Helper: determinar si timestamp (UTC-based) está en DST según región
bool InDST_US(datetime ts)
{
   datetime start=0, end=0;
   MqlDateTime st; TimeToStruct(ts, st);
   DST_NewYork(st.year, start, end);
   return (ts >= start && ts < end);
}

bool InDST_EU(datetime ts)
{
   datetime start=0, end=0;
   MqlDateTime st; TimeToStruct(ts, st);
   DST_Europe(st.year, start, end);
   return (ts >= start && ts < end);
}

//--------------------------------------------------------------------
// Obtener offset NY/EU según modo DST seleccionado
int GetOffset(datetime ts)
{
   if(DSTAdjust == DST_NONE) 
      return 0;

   if(DSTAdjust == DST_US)
      return InDST_US(ts) ? -4 : -5;

   if(DSTAdjust == DST_EU)
      return InDST_EU(ts) ? +2 : +1;  // ejemplo: CET/CEST
     
   return 0;
}

//--------------------------------------------------------------------
// Construir midnight en server time desde fecha local NY/EU
datetime LocalDateToServerMidnight(int year, int mon, int day, int serverGMT)
{
   // armar fecha base
   MqlDateTime dt={0};
   dt.year=year; dt.mon=mon; dt.day=day;
   datetime local_ts = StructToTime(dt);

   int tz_offset = GetOffset(local_ts);
   int diff = tz_offset - serverGMT;

   return local_ts - (datetime)diff * 3600;
}

//--------------------------------------------------------------------
// Crear línea con estilo estándar
void CreateLine(string name, datetime ts, long tfmask)
{
   if(ObjectFind(0, name) != -1) return;

   ObjectCreate(0, name, OBJ_VLINE, 0, ts, 0);
   ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
   ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, tfmask);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);  // ← DIBUJAR DETRÁS
}

//--------------------------------------------------------------------
// Dibujar ANUALES
void DrawYearlySeparators(int years_back)
{
   datetime now_server = TimeCurrent();
   MqlDateTime st; TimeToStruct(now_server, st);
   int thisYear = st.year;

   for(int y = thisYear - years_back; y <= thisYear; y++)
   {
      datetime ts = LocalDateToServerMidnight(y,1,1,ServerGMT);
      CreateLine(OBJ_PREFIX+"Y_"+IntegerToString((int)ts), ts, TF_YEARLY);
   }
}

// Dibujar MENSUALES
void DrawMonthlySeparators(int months_back, bool useOffset)
{
   datetime now_server = TimeCurrent();
   MqlDateTime st; TimeToStruct(now_server, st);
   int year = st.year, month = st.mon;

   for(int k = 0; k < months_back; k++)
   {
      int m = month-k, y=year;
      while(m <= 0) { m+=12; y--; }

      datetime ts;
      if(useOffset)
         ts = LocalDateToServerMidnight(y,m,1,ServerGMT);
      else
         ts = iTime(_Symbol, PERIOD_MN1, k);

      if(ts == 0) break;
      CreateLine(OBJ_PREFIX+"M_"+IntegerToString((int)ts), ts, TF_MONTHLY);
   }
}

// Dibujar SEMANALES
void DrawWeeklySeparators(int weeks_back, bool useOffset)
{
   datetime now_server = TimeCurrent();
   if(!useOffset)
   {
      for(int s=0;s<weeks_back;s++)
      {
         datetime ts=iTime(_Symbol,PERIOD_W1,s);
         if(ts==0) break;
         CreateLine(OBJ_PREFIX+"W_"+IntegerToString((int)ts),ts,TF_H3PLUS);
      }
   }
   else
   {
      for(int k=0;k<weeks_back;k++)
      {
         datetime ts = LocalDateToServerMidnight(Year(),Month(),Day()-7*k,ServerGMT);
         CreateLine(OBJ_PREFIX+"W_"+IntegerToString((int)ts),ts,TF_H3PLUS);
      }
   }
}

// Dibujar DIARIOS
void DrawDailySeparators(int days_back, bool useOffset)
{
   datetime now_server = TimeCurrent();
   for(int k=0;k<days_back;k++)
   {
      datetime ts;
      if(useOffset)
         ts = LocalDateToServerMidnight(Year(),Month(),Day()-k,ServerGMT);
      else
         ts = iTime(_Symbol,PERIOD_D1,k);

      if(ts==0) break;
      CreateLine(OBJ_PREFIX+"D_"+IntegerToString((int)ts),ts,TF_DAILY);
   }
}

//--------------------------------------------------------------------
// Redraw central
enum TF_GROUP { GROUP_SMALL_INTRADAY, GROUP_H3_PLUS, GROUP_DAILY, GROUP_WEEK_MONTH };
TF_GROUP EvaluateTFGroup(int period)
{
   if(period<=PERIOD_H2) return GROUP_SMALL_INTRADAY;
   if(period<=PERIOD_H12) return GROUP_H3_PLUS;
   if(period==PERIOD_D1) return GROUP_DAILY;
   return GROUP_WEEK_MONTH;
}

void RedrawSeparatorsForCurrentTF()
{
   DeleteAllMyObjects();
   int period=Period();
   TF_GROUP g=EvaluateTFGroup(period);

   if(g==GROUP_SMALL_INTRADAY)
   {
      DrawYearlySeparators(10);
      DrawMonthlySeparators(60,true);
      DrawWeeklySeparators(200,true);
      DrawDailySeparators(400,true);
   }
   else if(g==GROUP_H3_PLUS)
   {
      DrawYearlySeparators(10);
      DrawMonthlySeparators(120,true);
      DrawWeeklySeparators(400,true);
   }
   else if(g==GROUP_DAILY)
   {
      DrawYearlySeparators(10);
      DrawMonthlySeparators(120,false);
   }
   else
   {
      DrawYearlySeparators(20);
   }
}

//--------------------------------------------------------------------
// Inicialización
int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS,0);
   RedrawSeparatorsForCurrentTF();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   //DeleteAllMyObjects(); // opcional
}

int prevPeriod=0;
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
   int curPeriod=Period();
   if(curPeriod!=prevPeriod)
   {
      RedrawSeparatorsForCurrentTF();
      prevPeriod=curPeriod;
   }

   if(ObjectsTotal(0)==0)
      RedrawSeparatorsForCurrentTF();

   return(rates_total);
}
