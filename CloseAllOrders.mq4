//+------------------------------------------------------------------+
//|                                               CloseAllOrders.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#define MAX_NUM_TRIALS 5

/*! Script program start function */                                   
void OnStart()
{
   for (int i = OrdersTotal() - 1; i >= 0; --i) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
      	Alert("Emir secilemedi... Hata kodu : ", GetLastError());
      	continue;
      }
      
      int optype = OrderType();
	   int k = 0;
	   double close_price;
	   for (k = 0; k < MAX_NUM_TRIALS; ++k) {
   		if (optype == OP_BUY)
   			close_price = MarketInfo(OrderSymbol(), MODE_BID);
   		else
   			close_price = MarketInfo(OrderSymbol(), MODE_ASK);
   		if (OrderClose(OrderTicket(), OrderLots(), close_price, 10))
   			break;
   		RefreshRates();
	   }// end for trial
      if (k == MAX_NUM_TRIALS) {
         Alert(OrderTicket(), " No'lu emir kapatilamadi close price", close_price, " .... Hata kodu : ", GetLastError());
         break;
      }     
   }// end order total for
   
}

