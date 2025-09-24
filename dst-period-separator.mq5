//+------------------------------------------------------------------+
//|                Separador de Períodos Universal (base)            |
//|                Manejo flexible de DST (US/EU/None)               |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 0
#property strict

//------------------ INPUTS ------------------//
input int      ServerGMTOffset    = 3;    // Offset del servidor (ej: GMT+3)
input bool     UseDST_USA         = true; // Aplicar DST USA (New York)
input bool     UseDST_Europe      = false;// Aplicar DST Europa
input color    LineColor          = clrGray;
input ENUM_LINE_STYLE LineStyle   = STYLE_DOT;
input int      LineWidth          = 1;

//------------------ FUNCIONES DST ------------------//
datetime GetNthSunday(int year, int month, int n)
{
   int count = 0;
   for(int d=1; d<=31; d++)
   {
      datetime t = StringToTime(IntegerToString(year)+"."+IntegerToString(month)+"."+IntegerToString(d)+" 00:00");
      if(TimeMonth(t)!=month) break;
      if(TimeDayOfWeek(t)==0) // domingo
      {
         count++;
         if(count==n) return t;
      }
   }
   return 0;
}

// DST USA: 2° domingo marzo (start) / 1° domingo noviembre (end)
void GetDST_USA(int year, datetime &start, datetime &end)
{
   start = GetNthSunday(year,3,2)  + 2*3600;
   end   = GetNthSunday(year,11,1) + 2*3600;
}

// DST Europa: último domingo marzo (start) / último domingo octubre (end)
void GetDST_Europe(int year, datetime &start, datetime &end)
{
   datetime lastMarch=0, lastOct=0;
   for(int d=31; d>=1; d--)
   {
      datetime t = StringToTime(IntegerToString(year)+".3."+IntegerToString(d)+" 01:00");
      if(TimeMonth(t)==3 && TimeDayOfWeek(t)==0){ lastMarch=t; break; }
   }
   for(int d=31; d>=1; d--)
   {
      datetime t = StringToTime(IntegerToString(year)+".10."+IntegerToString(d)+" 01:00");
      if(TimeMonth(t)==10 && TimeDayOfWeek(t)==0){ lastOct=t; break; }
   }
   start = lastMarch + 1*3600;
   end   = lastOct   + 1*3600;
}

// Cálculo offset dinámico
int GetTotalOffset(datetime t)
{
   int offset = ServerGMTOffset * 3600;

   int year = TimeYear(t);

   if(UseDST_USA)
   {
      datetime usStart, usEnd;
      GetDST_USA(year,usStart,usEnd);
      if(t>=usStart && t<usEnd) offset += 3600;
   }

   if(UseDST_Europe)
   {
      datetime euStart, euEnd;
      GetDST_Europe(year,euStart,euEnd);
      if(t>=euStart && t<euEnd) offset += 3600;
   }

   return offset;
}

//------------------ DIBUJO ------------------//
int OnInit()
{
   EventSetTimer(60); // refrescar cada minuto
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0,"SepLine_");
}

void OnTimer()
{
   RedrawLines();
}

void OnCalculate(const int rates_total,
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
   RedrawLines();
}

void RedrawLines()
{
   ObjectsDeleteAll(0,"SepLine_");

   MqlDateTime dt;
   datetime start = iTime(NULL,PERIOD_D1,0) - PeriodSeconds(PERIOD_D1)*100;
   datetime end   = TimeCurrent() + PeriodSeconds(_Period);

   for(datetime t=start; t<=end; t+=PeriodSeconds(PERIOD_D1))
   {
      int totalOffset = GetTotalOffset(t);
      datetime estTime = t - totalOffset; // convertir a EST

      TimeToStruct(estTime,dt);

      bool draw=false;
      string label="";

      switch(_Period)
      {
         case PERIOD_M1:
         case PERIOD_M5:
         case PERIOD_M15:
         case PERIOD_M30:
         case PERIOD_H1:
         case PERIOD_H3:
            draw=true;
            label=StringFormat("%02d:%02d",dt.hour,dt.min);
            break;
         case PERIOD_H4:
         case PERIOD_D1:
            if(dt.hour==0) { draw=true; label=TimeToString(estTime,TIME_DATE); }
            break;
         case PERIOD_W1:
            if(dt.mon==1 && dt.mday==1){ draw=true; label="Year "+IntegerToString(dt.year); }
            break;
         case PERIOD_MN1:
            if(dt.mday==1){ draw=true; label=TimeToString(estTime,TIME_DATE); }
            break;
      }

      if(draw)
      {
         string name="SepLine_"+(string)t;
         if(!ObjectCreate(0,name,OBJ_VLINE,0,t,0))
            continue;
         ObjectSetInteger(0,name,OBJPROP_COLOR,LineColor);
         ObjectSetInteger(0,name,OBJPROP_STYLE,LineStyle);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,LineWidth);
         ObjectSetString(0,name,OBJPROP_TEXT,label);
      }
   }
}
