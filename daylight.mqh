//+------------------------------------------------------------------+
//|                                                     daylight.mqh |
//|                                         Copyright © 2018,Amr Ali |
//|                             https://www.mql5.com/en/users/amrali |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2018,Amr Ali"
#property link      "https://www.mql5.com/en/users/amrali"
#property version   "1.250"
//+------------------------------------------------------------------+
//| Compute the daylight saving time changes in London, UK           |
//| https://www.timeanddate.com/time/change/uk/london                |
//| DST begins at 01:00 local time on the last Sunday of March,      |
//| and ending at 02:00 local time on the last Sunday of October     |
//+------------------------------------------------------------------+
void DST_London(int iYear, datetime &dst_start, datetime &dst_end)
  {
   dst_start = GetNthSunday(iYear,3,5) + 1*3600;
   dst_end  = GetNthSunday(iYear,10,5) + 2*3600;
  }
//+------------------------------------------------------------------+
//| Compute the daylight saving time changes in New York, USA        |
//| https://www.timeanddate.com/time/change/usa/new-york             |
//| DST begins at 02:00 local time on the second Sunday of March,    |
//| and ending at 02:00 local time on the first Sunday of November   |
//+------------------------------------------------------------------+
void DST_NewYork(int iYear, datetime &dst_start, datetime &dst_end)
  {
   dst_start = GetNthSunday(iYear,3,2) + 2*3600;
   dst_end  = GetNthSunday(iYear,11,1) + 2*3600;
  }

//+------------------------------------------------------------------+
//| Return the date for the "Nth" Sunday for the iYear and iMonth.   |
//| If  "Nth"  is larger than the number of Sundays in the month,    |
//| return the last Sunday. If "Nth" is otherwise invalid, return 0. |
//+------------------------------------------------------------------+
datetime GetNthSunday(int iYear, int iMonth, int Nth)
  {
// datetime dt=StringToTime((string)iYear+"."+(string)iMonth+".01"); // get date of first of month
   MqlDateTime st= {};
   st.year=iYear;
   st.mon=iMonth;
   st.day=1;
   datetime dt=StructToTime(st); // get date of first of month
   if(Nth<1)
      return(0);
   if(Nth>5)
      Nth=5;
   TimeToStruct(dt,st);
   int SundayDOM=(7-st.day_of_week)%7;  // 1st Sunday Day of Month
   dt+=(SundayDOM+7*(Nth-1))*86400;
   TimeToStruct(dt,st);
   if(st.mon!=iMonth)
      dt-=7*86400;
   return(dt);
  }
//+------------------------------------------------------------------+ 
