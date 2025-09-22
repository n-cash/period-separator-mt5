//+------------------------------------------------------------------+
//|                                   dinamic-period-separator.mq5  |
//|   Separador dinámico con visibilidad por timeframe               |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property copyright "Open Source"
#property link      ""

// Asegurate de tener la librería daylight.mqh en MQL5/Include/
// https://www.mql5.com/en/code/27860
#include <daylight.mqh>

//--- Inputs configurables
input int   ServerGMT = 2;                // GMT del servidor del broker
input color SepColor  = clrBlack;         // Color de las líneas
input int   SepStyle  = STYLE_DOT;        // Estilo
input int   SepWidth  = 1;                // Grosor

//--- Máscaras de visibilidad por timeframe
#define TF_DAILY   (OBJ_PERIOD_M1|OBJ_PERIOD_M2|OBJ_PERIOD_M3|OBJ_PERIOD_M4|OBJ_PERIOD_M5|OBJ_PERIOD_M6|OBJ_PERIOD_M10|OBJ_PERIOD_M12|OBJ_PERIOD_M15|OBJ_PERIOD_M20|OBJ_PERIOD_M30|OBJ_PERIOD_H1|OBJ_PERIOD_H2|OBJ_PERIOD_H3|OBJ_PERIOD_H6|OBJ_PERIOD_H8|OBJ_PERIOD_H12)
#define TF_WEEKLY  (OBJ_PERIOD_H4)
#define TF_MONTHLY (OBJ_PERIOD_D1|OBJ_PERIOD_W1)
#define TF_YEARLY  (OBJ_PERIOD_MN1)

//--- Helpers DST
bool InDST(datetime t)
{
   datetime dst_start, dst_end;

   // Obtener año de t
   MqlDateTime st;
   TimeToStruct(t, st);
   int year = st.year;

   // Llamar a la librería de Amr Ali
   DST_NewYork(year, dst_start, dst_end);

   return (t >= dst_start && t < dst_end);
}

int GetNewYorkOffset(datetime t)
{
   return InDST(t) ? -4 : -5; // NY DST=-4, Standard=-5
}

//--- Validar si es nueva apertura de año
bool IsNewYear(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return (st.mon == 1 && st.day == 1 && st.hour == 0);
}

//--- Obtener tipo de separador (D, W, M, Y)
string GetSeparatorType(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);

   if(IsNewYear(t))
      return "Y";  // Año nuevo
   else if(st.day == 1 && st.hour == 0)
      return "M";  // Primer día de mes
   else if(st.day_of_week == 1 && st.hour == 0)
      return "W";  // Lunes
   else if(st.hour == 0)
      return "D";  // Cada día a medianoche
   return "";
}

//--- Indicador principal
int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
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
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
      datetime t = time[i];
      string tipo = GetSeparatorType(t);
      if(tipo == "") continue;

      // 1) Calcular offset NY
      int ny_offset = GetNewYorkOffset(t);

      // 2) Diferencia entre NY y servidor
      int diff = ny_offset - ServerGMT;

      // 3) Convertir timestamp del servidor a “hora local NY”
      datetime ny_local_ts = t + (datetime)diff * 3600;

      // 4) Redondear a medianoche NY
      MqlDateTime ny_st;
      TimeToStruct(ny_local_ts, ny_st);
      ny_st.hour = 0; ny_st.min = 0; ny_st.sec = 0;
      datetime ny_midnight_local_ts = StructToTime(ny_st);

      // 5) Volver a tiempo del servidor
      datetime ny_midnight_server = ny_midnight_local_ts - (datetime)diff * 3600;

      // --- Dibujar línea ---
      string name = "SepNY_" + tipo + "_" + IntegerToString((int)ny_midnight_server);
      if(ObjectFind(0, name) == -1)
      {
         ObjectCreate(0, name, OBJ_VLINE, 0, ny_midnight_server, 0);
         ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);

         // Asignar visibilidad según el tipo
         if(tipo == "D")
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_DAILY);
         else if(tipo == "W")
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_WEEKLY);
         else if(tipo == "M")
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_MONTHLY);
         else if(tipo == "Y")
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, TF_YEARLY);
      }
   }

   return(rates_total);
}
