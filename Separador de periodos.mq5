//+------------------------------------------------------------------+
//| Universal Period Separator with DST (New York)                   |
//| Prototipo                                                        |
//+------------------------------------------------------------------+
#property copyright "Open-Source"
#property link      "https://github.com/"
#property version   "0.1"
#property indicator_chart_window

#include "daylight.mqh"   // asegurate de tener la librería en MQL5/Include/ - https://www.mql5.com/en/code/27860

input int   ServerGMT = 2;          // GMT del servidor del broker
input color SepColor  = clrBlack;  // Color de las líneas
input int   SepStyle  = STYLE_DOT;  // Estilo
input int   SepWidth  = 1;          // Grosor

//--- Helpers para DST
bool InDST(datetime t)
{
   datetime dst_start, dst_end;
   DST_NewYork(TimeYear(t), dst_start, dst_end);
   return (t >= dst_start && t < dst_end);
}

int GetNewYorkOffset(datetime t)
{
   return InDST(t) ? -4 : -5; // NY DST=-4, Standard=-5
}

//--- Helpers para validar si es nueva apertura
bool IsNewYear(datetime t)
{
   MqlDateTime st; TimeToStruct(t, st);
   return (st.mon == 1 && st.day == 1 && st.hour == 0);
}

bool IsNewMonth(datetime t)
{
   MqlDateTime st; TimeToStruct(t, st);
   return (st.day == 1 && st.hour == 0);
}

bool IsNewWeek(datetime t)
{
   MqlDateTime st; TimeToStruct(t, st);
   return (st.day_of_week == 0 && st.hour == 0); // domingo 00:00
}

bool IsNewDay(datetime t)
{
   MqlDateTime st; TimeToStruct(t, st);
   return (st.hour == 0 && st.min == 0);
}

//--- OnCalculate
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
   // Limpio líneas viejas
   ObjectsDeleteAll(0,"Sep_");

   ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;

   for(int i=0; i<rates_total; i++)
   {
      datetime t = time[i];

      // offset dinámico NY vs server
      int ny_offset = GetNewYorkOffset(t);
      int diff      = ny_offset - ServerGMT;

      // construyo medianoche NY (convertida a tiempo server)
      MqlDateTime st; TimeToStruct(t, st);
      st.hour=0; st.min=0; st.sec=0;
      datetime ny_midnight = StructToTime(st) - diff*3600;

      bool draw=false;

      if(tf==PERIOD_MN1 && IsNewYear(ny_midnight)) draw=true;
      if((tf==PERIOD_W1 || tf==PERIOD_D1) && IsNewMonth(ny_midnight)) draw=true;
      if(tf==PERIOD_H4 && IsNewWeek(ny_midnight)) draw=true;
      if(tf<=PERIOD_H3 && IsNewDay(ny_midnight)) draw=true;

      if(draw)
      {
         string name = "Sep_"+(string)ny_midnight;
         if(!ObjectCreate(0,name,OBJ_VLINE,0,ny_midnight,0))
            continue;

         ObjectSetInteger(0,name,OBJPROP_COLOR,SepColor);
         ObjectSetInteger(0,name,OBJPROP_STYLE,SepStyle);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,SepWidth);
      }
   }
   return(rates_total);
}
