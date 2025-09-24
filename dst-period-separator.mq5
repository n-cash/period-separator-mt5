//+------------------------------------------------------------------+
//|                          dinamic-period-separator.mq5           |
//|   Separador dinámico con visibilidad por timeframe               |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property copyright "Open Source"
#property link      ""

// Asegurate de tener la librería daylight.mqh en MQL5/Include/
// https://www.mql5.com/en/code/27860
#include <daylight.mqh>

//--- Inputs configurables
input int   ServerGMT        = 2;    // GMT del broker en horario de invierno
input bool  BrokerAdjustsDST = true; // ¿El broker ya corrige DST automáticamente?
input color SepColor         = clrBlack; // Color de las líneas
input int   SepStyle         = STYLE_DOT; // Estilo
input int   SepWidth         = 1;        // Grosor

//--- Máscaras de visibilidad por timeframe
#define TF_ALL     (OBJ_ALL_PERIODS)
#define TF_DWM     (OBJ_PERIOD_M1|OBJ_PERIOD_M2|OBJ_PERIOD_M3|OBJ_PERIOD_M4|OBJ_PERIOD_M5|OBJ_PERIOD_M6|OBJ_PERIOD_M10|OBJ_PERIOD_M12|OBJ_PERIOD_M15|OBJ_PERIOD_M20|OBJ_PERIOD_M30|OBJ_PERIOD_H1|OBJ_PERIOD_H2) // diarios + todo
#define TF_WMY     (OBJ_PERIOD_H3|OBJ_PERIOD_H4|OBJ_PERIOD_H6|OBJ_PERIOD_H8|OBJ_PERIOD_H12) // semanales + mayores
#define TF_MY      (OBJ_PERIOD_D1) // mensuales + anual
#define TF_Y       (OBJ_PERIOD_W1|OBJ_PERIOD_MN1) // solo anual

//--- Helpers DST NY
bool InDST(datetime t)
{
   datetime dst_start, dst_end;

   MqlDateTime st;
   TimeToStruct(t, st);
   int year = st.year;

   DST_NewYork(year, dst_start, dst_end);
   return (t >= dst_start && t < dst_end);
}

int GetNewYorkOffset(datetime t)
{
   return InDST(t) ? -4 : -5; // NY DST=-4, Standard=-5
}

//--- Calcular offset efectivo entre servidor y NY
int GetEffectiveDiff(datetime t)
{
   int ny_offset = GetNewYorkOffset(t); // -5 o -4

   if(BrokerAdjustsDST)
   {
      // Broker ya sigue DST → diferencia fija
      return ny_offset - ServerGMT;
   }
   else
   {
      // Broker fijo en GMT → calcular offset DST manual para server
      // Simplificado: server_offset = ServerGMT (invierno)
      //               +1 si estamos en verano europeo
      MqlDateTime st;
      TimeToStruct(t, st);

      // último domingo de marzo → empieza DST EU
      datetime eu_start = GetNthSunday(st.year, 3, 5) + 1*3600;
      // último domingo de octubre → termina DST EU
      datetime eu_end   = GetNthSunday(st.year, 10, 5) + 2*3600;

      int server_offset = ServerGMT;
      if(t >= eu_start && t < eu_end)
         server_offset = ServerGMT + 1;

      return ny_offset - server_offset;
   }
}

//--- Determinar tipo de separador
string GetSeparatorType(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);

   if(st.mon == 1 && st.day == 1 && st.hour == 0)
      return "Y"; // Año
   else if(st.day == 1 && st.hour == 0)
      return "M"; // Mes
   else if(st.day_of_week == 1 && st.hour == 0)
      return "W"; // Semana
   else if(st.hour == 0)
      return "D"; // Día
   return "";
}

//--- Limpiar separadores anteriores al cambiar timeframe
void ClearSeparators()
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "SepNY_") == 0)
         ObjectDelete(0, name);
   }
}

//--- Indicador principal
int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   ClearSeparators();
   return(INIT_SUCCEEDED);
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
   // limpiar y redibujar desde cero cada vez
   ClearSeparators();

   for(int i = 0; i < rates_total; i++)
   {
      datetime t = time[i];
      string tipo = GetSeparatorType(t);
      if(tipo == "") continue;

      // decidir si corresponde según timeframe actual
      ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)Period();

      bool dibujar = false;
      int mask = 0;

      if(tf <= PERIOD_H2) // M1..H2 → todo
      {
         dibujar = true;
         if(tipo=="D") mask=TF_DWM;
         else if(tipo=="W") mask=TF_DWM;
         else if(tipo=="M") mask=TF_DWM;
         else if(tipo=="Y") mask=TF_DWM;
      }
      else if(tf >= PERIOD_H3 && tf <= PERIOD_H12) // H3..H12
      {
         if(tipo=="W" || tipo=="M" || tipo=="Y")
         {
            dibujar = true;
            mask=TF_WMY;
         }
      }
      else if(tf == PERIOD_D1) // Diario
      {
         if(tipo=="M" || tipo=="Y")
         {
            dibujar = true;
            mask=TF_MY;
         }
      }
      else if(tf == PERIOD_W1 || tf == PERIOD_MN1) // Semanal / Mensual
      {
         if(tipo=="Y")
         {
            dibujar = true;
            mask=TF_Y;
         }
      }

      if(!dibujar) continue;

      // aplicar offset si corresponde (solo en tf <= H12)
      datetime draw_time = t;
      if(tf <= PERIOD_H12)
      {
         int diff = GetEffectiveDiff(t);
         datetime ny_local = t + (datetime)diff*3600;

         MqlDateTime ny_st;
         TimeToStruct(ny_local, ny_st);
         ny_st.hour=0; ny_st.min=0; ny_st.sec=0;
         datetime ny_midnight_local = StructToTime(ny_st);

         draw_time = ny_midnight_local - (datetime)diff*3600;
      }

      // crear línea
      string name = "SepNY_" + tipo + "_" + IntegerToString((int)draw_time);
      if(ObjectFind(0, name) == -1)
      {
         ObjectCreate(0, name, OBJ_VLINE, 0, draw_time, 0);
         ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, mask);
      }
   }

   return(rates_total);
}
