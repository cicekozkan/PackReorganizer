//+------------------------------------------------------------------+
//|                                             OpenRandomOrders.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

#define MAX_NUM_ORDERS 10
#define MAX_NUM_TRIALS 5

// ------------------------------------------ GLOBAL FUNCTIONS ------------------------------------------------- //

/*!A global function to get a random parity 
   \return A random parity
*/
string getRandomOrder()
{
	static const string mp[28] = { "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD",
		"EURGBP", "EURJPY", "EURCHF", "EURAUD", "EURCAD", "EURNZD",
		"GBPJPY", "GBPCHF", "GBPAUD", "GBPCAD", "GBPNZD",
		"CHFJPY", "AUDJPY", "CADJPY", "NZDJPY",
		"AUDCHF", "CADCHF", "NZDCHF",
		"AUDCAD", "NZDCAD",
		"AUDNZD" };
	return mp[MathRand() % 28];
}

/*! Script program start function */
void OnStart()
{
   int ticket = -1;
   int k = 0;
   for (int i=0; i < MAX_NUM_ORDERS; i++){
      string sym = getRandomOrder();
      int buy = MathRand()%2;
      for (k = 0; k < MAX_NUM_TRIALS; k++){
         ticket = OrderSend(sym, buy, 0.1, MarketInfo(sym, buy?MODE_BID:MODE_ASK), 10, 0, 0, "1_11111", 11111);
         if (ticket != -1) break;
      }//end max trials
      if (k == MAX_NUM_TRIALS)   Print(sym, " Paritesinde emir acilamadi. Hata kodu = ", GetLastError());
   }      
      
}
