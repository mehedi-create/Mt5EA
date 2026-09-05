//+------------------------------------------------------------------+
//|                                                XGE_Dashboard.mqh |
//|             XAUUSD Adaptive Pro EA - on-chart dashboard          |
//+------------------------------------------------------------------+
#ifndef XGE_DASHBOARD_MQH
#define XGE_DASHBOARD_MQH

#include "XGE_Define.mqh"

class CDashboard
  {
public:
   bool     m_enabled;
   int      m_x, m_y;
   int      m_lineH, m_fontSize, m_pad;
   int      m_width;
   string   m_font;

   CDashboard(void)
     {
      m_enabled = true;
      m_x = 12; m_y = 22;
      m_lineH = 17; m_fontSize = 9; m_pad = 8;
      m_width = 372;
      m_font = "Consolas";
     }

   void Init(const bool enabled, const int x, const int y, const int fontSize)
     {
      m_enabled = enabled;
      m_x = x; m_y = y;
      if(fontSize > 0)
         m_fontSize = fontSize;
      m_lineH = m_fontSize + 8;
     }

   void Deinit(void)
     {
      ObjectsDeleteAll(0, XGE_PREFIX);
     }

   void Update(string &txt[], color &clr[], const int n)
     {
      if(!m_enabled)
         return;
      EnsureObjects(n);
      for(int i = 0; i < n; i++)
        {
         string nm = LineName(i);
         ObjectSetString(0, nm, OBJPROP_TEXT, txt[i]);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, clr[i]);
        }
      string bg = XGE_PREFIX + "dash_bg";
      ObjectSetInteger(0, bg, OBJPROP_YSIZE, m_pad * 2 + n * m_lineH + 2);
      ChartRedraw();
     }

private:
   string LineName(const int i)
     {
      return(XGE_PREFIX + "dash_l" + IntegerToString(i));
     }

   void EnsureObjects(const int n)
     {
      string bg = XGE_PREFIX + "dash_bg";
      if(ObjectFind(0, bg) < 0)
        {
         ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, m_x - 6);
         ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, m_y - 6);
         ObjectSetInteger(0, bg, OBJPROP_XSIZE, m_width);
         ObjectSetInteger(0, bg, OBJPROP_YSIZE, m_pad * 2 + n * m_lineH + 2);
         ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'16,18,24');
         ObjectSetInteger(0, bg, OBJPROP_COLOR, C'70,74,86');
         ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, bg, OBJPROP_BACK, false);
         ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, bg, OBJPROP_ZORDER, 0);
        }
      for(int i = 0; i < n; i++)
        {
         string nm = LineName(i);
         if(ObjectFind(0, nm) < 0)
           {
            ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, m_x);
            ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, m_y + i * m_lineH);
            ObjectSetString(0, nm, OBJPROP_FONT, m_font);
            ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, m_fontSize);
            ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
            ObjectSetInteger(0, nm, OBJPROP_BACK, false);
            ObjectSetInteger(0, nm, OBJPROP_ZORDER, 1);
            ObjectSetString(0, nm, OBJPROP_TEXT, "");
           }
        }
     }
  };

#endif // XGE_DASHBOARD_MQH
