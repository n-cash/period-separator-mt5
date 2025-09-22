//+------------------------------------------------------------------+
//|                                   dst-period-separator.mq5    |
//|   Separador dinámico con visibilidad por timeframe (NY DST opt)   |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property copyright "Open Source"
#property link      ""

// Requiere daylight.mqh de Amr Ali en MQL5/Include/
// https://www.mql5.com/en/code/27860
#include <daylight.mqh>

//--- Inputs configurables
input int   ServerGMT = 2;                // GMT del servidor del broker (ej: 2)
input color SepColor  = clrBlack;         // Color de las líneas (un solo color como nativo)
input int   SepStyle  = STYLE_DOT;        // Estilo
input int   SepWidth  = 1;                // Grosor

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
   // Recorremos al revés por seguridad
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if(StringFind(nm, OBJ_PREFIX) == 0) // empieza con prefix
         ObjectDelete(0, nm);
   }
}

//--------------------------------------------------------------------
// Helper DST: determinamos si un timestamp (server tz) está en DST NY
bool InDST(datetime server_ts)
{
   datetime dst_start = 0, dst_end = 0;
   MqlDateTime st;
   TimeToStruct(server_ts, st);
   int year = st.year;
   DST_NewYork(year, dst_start, dst_end);
   return (server_ts >= dst_start && server_ts < dst_end);
}

int GetNYOffsetForTimestamp(datetime server_ts)
{
   return InDST(server_ts) ? -4 : -5; // DST = -4, Std = -5
}

//--------------------------------------------------------------------
// Construir ny_midnight_server: dado una fecha en NY (year,mon,day) -> timestamp en server
datetime NYLocalDateToServerMidnight(int ny_year, int ny_mon, int ny_day, int serverGMT, datetime anchor_server_now)
{
   // Calculamos diff usando anchor (para obtener si hay DST en ese periodo)
   // Necesitamos saber si esa fecha cae en DST: calculamos a partir de anclaje aproximado:
   // Construimos ny local midnight epoch (based on ny date) then convert to server by subtracting diff*3600
   MqlDateTime ny_st={0};
   ny_st.year = ny_year;
   ny_st.mon  = ny_mon;
   ny_st.day  = ny_day;
   ny_st.hour = 0;
   ny_st.min  = 0;
   ny_st.sec  = 0;
   datetime ny_local_ts = StructToTime(ny_st);

   // Pero StructToTime interpreta la estructura como tiempo en server tz.
   // Para conocer DST at that ny_local_ts we need to compute UTC/NY relation.
   // Simpler robust approach: determine ny_offset by checking DST for a timestamp that corresponds to that NY local time expressed as server time guess.
   // We approximate server representation of that NY local by subtracting (ny_offset_guess - serverGMT)*3600, but ny_offset_guess unknown.
   // Workaround: use TimeToStruct on ny_local_ts + (ServerGMT*3600) shift to move to UTC and then test DST via DST_NewYork on year.
   // Simpler and safe: decide NY offset via calendar rules using DST_NewYork(year).
   datetime dst_start=0, dst_end=0;
   DST_NewYork(ny_year, dst_start, dst_end);
   // NY local midnight epoch as if in UTC reference: we will treat ny_local_ts_utc as the moment
   // The correct server timestamp is: server_ts = ny_local_utc - (ny_offset - ServerGMT)*3600 , but we lack direct "UTC epoch" for ny_local_ts.
   // Instead, compute ny_offset using whether the NY local date (ny_local_ts) is within DST.
   bool isDst = (ny_local_ts >= dst_start && ny_local_ts < dst_end);
   int ny_offset = isDst ? -4 : -5;
   int diff = ny_offset - serverGMT;
   // Now convert: ny_local_ts is naive (StructToTime produced a server-based epoch for same y/m/d 00:00),
   // but the ny_local midnight epoch in server time is ny_local_ts - diff*3600 (this matches earlier derivation).
   datetime ny_midnight_server = ny_local_ts - (datetime)diff * 3600;
   return ny_midnight_server;
}

//--------------------------------------------------------------------
// Generadores por orden (retroceden N unidades)
// Nota: usamos TimeCurrent() como anchor_server_now y calculamos NY local via diff = ny_offset - ServerGMT.

// Dibujar ANUALES (últimos N años)
void DrawYearlySeparators(int years_back)
{
   datetime now_server = TimeCurrent();
   MqlDateTime st;
   TimeToStruct(now_server, st);
   int thisYear = st.year;

   for(int y = thisYear - years_back; y <= thisYear; y++)
   {
      // Para grupos >= D1 no usamos offset (según reglas). Por seguridad, si el timeframe requiere offset, caller pasará la versión con offset
      // Aquí llamamos a función que convierte NY local date->server timestamp pero lo haremos considerando DST del propio año.
      datetime ts = NYLocalDateToServerMidnight(y, 1, 1, ServerGMT, now_server);
      string name = OBJ_PREFIX + "Y_" + IntegerToString((int)ts);
      if(ObjectFind(0, name) == -1)
      {
         ObjectCreate(0, name, OBJ_VLINE, 0, ts, 0);
         ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_YEARLY);
      }
   }
}

// Dibujar MENSUALES (últimos N meses)
// Si useOffset==true generamos midnight en NY local y convertimos a server; si false usamos iTime(PERIOD_MN1,shift) (server months)
void DrawMonthlySeparators(int months_back, bool useOffset)
{
   datetime now_server = TimeCurrent();
   if(!useOffset)
   {
      // Usar iTime mensual (server)
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
         }
      }
   }
   else
   {
      // Con offset: calcular NY local midnight del primer día de cada mes, usando anchor now to determine DST each month
      MqlDateTime stNow; TimeToStruct(now_server, stNow);
      // empezamos desde current month y retrocedemos
      int year = stNow.year;
      int month = stNow.mon;
      for(int k = 0; k < months_back; k++)
      {
         int m = month - k;
         int y = year;
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
         }
      }
   }
}

// Dibujar SEMANALES (últimas N semanas)
// If useOffset true, compute NY local Sunday/Monday? We will use Monday 00:00 as week start (align with your previous spec: week begins Monday)
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
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_H3PLUS); // weekly visible in H3..H12 group per mapping
         }
      }
   }
   else
   {
      // Con offset: calculamos el lunes 00:00 NY para cada semana atrás.
      // Tomamos ny_local_now y retrocedemos semanas.
      int ny_offset_now = GetNYOffsetForTimestamp(now_server);
      int diff_now = ny_offset_now - ServerGMT;
      datetime ny_local_now = now_server + (datetime)diff_now * 3600;
      MqlDateTime ny_st; TimeToStruct(ny_local_now, ny_st);
      // Encontrar fecha del lunes de la current NY week
      int dow = ny_st.day_of_week; // 0=Sunday,1=Monday...
      int days_from_monday = (dow == 0) ? 6 : (dow - 1);
      // monday date components:
      // build ny_monday = ny_local_now - days_from_monday days, then set hour 0
      datetime ny_monday_local = ny_local_now - (datetime)days_from_monday * 86400;
      MqlDateTime monday_st; TimeToStruct(ny_monday_local, monday_st);
      monday_st.hour = 0; monday_st.min = 0; monday_st.sec = 0;
      datetime monday_base_local = StructToTime(monday_st);
      for(int k = 0; k < weeks_back; k++)
      {
         // subtract k weeks
         MqlDateTime wk = monday_st;
         // compute date for week k back
         datetime wk_local = monday_base_local - (datetime)k * 7 * 86400;
         TimeToStruct(wk_local, wk);
         // Convert to server ts by removing diff for that week's year (check DST for the week date)
         // Determine ny_offset for that wk_local (use year from wk)
         int y = wk.year;
         datetime dst_s=0, dst_e=0;
         DST_NewYork(y, dst_s, dst_e);
         bool isDst = (wk_local >= dst_s && wk_local < dst_e);
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
         }
      }
   }
}

// Dibujar DIARIOS (últimos N días)
void DrawDailySeparators(int days_back, bool useOffset)
{
   datetime now_server = TimeCurrent();
   if(!useOffset)
   {
      // usar iTime(PERIOD_D1)
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
         }
      }
   }
   else
   {
      // Con offset: construimos fechas NY midnight retrocediendo desde ny_local_now
      // Determinar current NY offset and ny_local_now
      int ny_offset_now = GetNYOffsetForTimestamp(now_server);
      int diff_now = ny_offset_now - ServerGMT;
      datetime ny_local_now = now_server + (datetime)diff_now * 3600;
      MqlDateTime stNow; TimeToStruct(ny_local_now, stNow);
      // Establecemos midnight de hoy en NY
      stNow.hour = 0; stNow.min = 0; stNow.sec = 0;
      datetime ny_midnight_today_local = StructToTime(stNow);

      for(int k = 0; k < days_back; k++)
      {
         datetime target_local = ny_midnight_today_local - (datetime)k * 86400;
         MqlDateTime tgt; TimeToStruct(target_local, tgt);
         // determinar DST para la fecha
         datetime dst_s=0, dst_e=0;
         DST_NewYork(tgt.year, dst_s, dst_e);
         bool isDst = (target_local >= dst_s && target_local < dst_e);
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
         }
      }
   }
}

//--------------------------------------------------------------------
// Determinar grupo segun Period() actual (basado en tus reglas)
enum TF_GROUP { GROUP_SMALL_INTRADAY, GROUP_H3_PLUS, GROUP_DAILY, GROUP_WEEK_MONTH };

TF_GROUP EvaluateTFGroup(int period)
{
   // "m1..h2" -> GROUP_SMALL_INTRADAY
   if(period == PERIOD_M1 || period == PERIOD_M2 || period == PERIOD_M3 || period == PERIOD_M4 || period == PERIOD_M5 ||
      period == PERIOD_M6 || period == PERIOD_M10 || period == PERIOD_M12 || period == PERIOD_M15 || period == PERIOD_M20 ||
      period == PERIOD_M30 || period == PERIOD_H1 || period == PERIOD_H2)
      return GROUP_SMALL_INTRADAY;

   // "h3,h4,h6,h8,h12" -> GROUP_H3_PLUS
   if(period == PERIOD_H3 || period == PERIOD_H4 || period == PERIOD_H6 || period == PERIOD_H8 || period == PERIOD_H12)
      return GROUP_H3_PLUS;

   // "D1"
   if(period == PERIOD_D1)
      return GROUP_DAILY;

   // "W1, MN1"
   return GROUP_WEEK_MONTH;
}

//--------------------------------------------------------------------
// Redraw central: elimina y genera según grupo
void RedrawSeparatorsForCurrentTF()
{
   // Borrar sólo nuestros objetos
   DeleteAllMyObjects();

   int period = Period();
   TF_GROUP g = EvaluateTFGroup(period);

   // Decide qué dibujar y si usar offset
   bool useOffset = false;
   int daysBack = 0, weeksBack = 0, monthsBack = 0, yearsBack = 0;

   if(g == GROUP_SMALL_INTRADAY)
   {
      // m1..h2 : marcar D, W, M, Y con offset
      useOffset = true;
      daysBack = 400;    // ~1 año
      weeksBack = 200;   // ~4 años of weeks (safe upper)
      monthsBack = 60;   // 5 años
      yearsBack = 10;
      // Dibujar en orden de mayor a menor para evitar overlaps innecesarios
      DrawYearlySeparators(yearsBack);
      DrawMonthlySeparators(monthsBack, true);
      DrawWeeklySeparators(weeksBack, true);
      DrawDailySeparators(daysBack, true);
   }
   else if(g == GROUP_H3_PLUS)
   {
      // h3,h4,h6,h8,h12 : W, M, Y with offset (según tu rule "Aquí también podemos usar el offset horario")
      useOffset = true;
      daysBack = 0;
      weeksBack = 400;   // many weeks
      monthsBack = 120;  // 10 years of months
      yearsBack = 10;
      DrawYearlySeparators(yearsBack);
      DrawMonthlySeparators(monthsBack, true);
      DrawWeeklySeparators(weeksBack, true);
      // No daily
   }
   else if(g == GROUP_DAILY)
   {
      // D1 : M + Y, no offset
      useOffset = false;
      monthsBack = 120; // 10 years months
      yearsBack = 10;
      DrawYearlySeparators(yearsBack);
      DrawMonthlySeparators(monthsBack, false);
   }
   else // GROUP_WEEK_MONTH (W1, MN1)
   {
      // W1, MN1: only annuals, no offset
      useOffset = false;
      yearsBack = 20;
      DrawYearlySeparators(yearsBack);
   }
}

//--------------------------------------------------------------------
// Inicialización y cálculo
int OnInit()
{
   // indicador sin buffers
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   // forzar dibujado al iniciar
   RedrawSeparatorsForCurrentTF();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   // No borramos automáticamente, dejar al usuario la opción
   // si querés borrar al quitar el indicador, descomenta:
   // DeleteAllMyObjects();
}

// OnCalculate se ejecuta continuamente; aquí detectamos cambios y redibujamos
int prevPeriod = 0;
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
   int curPeriod = Period();
   if(curPeriod != prevPeriod)
   {
      // Cambió la TF -> redibujar según reglas del nuevo TF
      RedrawSeparatorsForCurrentTF();
      prevPeriod = curPeriod;
   }

   // también redibujamos si no hay objetos (p.e. al cargar plantilla)
   // comprobamos si existe al menos un objeto con nuestro prefijo
   bool any = false;
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = ObjectName(0, i);
      if(StringFind(nm, OBJ_PREFIX) == 0) { any = true; break; }
   }
   if(!any)
      RedrawSeparatorsForCurrentTF();

   return(rates_total);
}


