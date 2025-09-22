//+------------------------------------------------------------------+
//|                                             dinamic-period-separator.mq5 |
//|                                 Ejemplo de separador dinámico por sesiones |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property copyright "Tu nombre"
#property link      ""

// Asegurate de tener la librería daylight.mqh en MQL5/Include/
// https://www.mql5.com/en/code/27860
#include <daylight.mqh>

//--- Inputs configurables
input int   ServerGMT = 2;                // GMT del servidor del broker
input color SepColor  = clrBlack;         // Color de las líneas
input int   SepStyle  = STYLE_DOT;        // Estilo
input int   SepWidth  = 1;                // Grosor

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

//--- Validar si es nueva apertura (ejemplo Año Nuevo)
bool IsNewYear(datetime t)
{
   MqlDateTime st;
   TimeToStruct(t, st);
   return (st.mon == 1 && st.day == 1 && st.hour == 0);
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
   // Procesar solo las nuevas barras
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
   {
      datetime t = time[i];

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

      // --- Dibujar línea si corresponde ---
      string name = "SepNY_" + IntegerToString((int)ny_midnight_server);
      if(ObjectFind(0, name) == -1)
      {
         ObjectCreate(0, name, OBJ_VLINE, 0, ny_midnight_server, 0);
         ObjectSetInteger(0, name, OBJPROP_COLOR, SepColor);
         ObjectSetInteger(0, name, OBJPROP_STYLE, SepStyle);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, SepWidth);
      }
   }

   return(rates_total);
}
