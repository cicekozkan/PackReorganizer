//+------------------------------------------------------------------+
//|                                             OpenRandomOrders.mq4 |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict
#property show_inputs

#define MAX_NUM_TRIALS 5
#define NUM_VALID_PARITIES 28

extern int num_orders = 10;   ///< Number of orders to open
extern int ex_magic_no = 11111;  ///< Magic number of the orders
extern string ex_comment = "1_11111"; ///< Comment of the orders
extern double lot = 0.1;  ///< Equivalent USD lot to open
double parity_lots[NUM_VALID_PARITIES]; ///< Lots of other parities with the same USD lot amount 
/// All possible parities
static const string valid_parities[NUM_VALID_PARITIES] = {
         "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD",
         "CADCHF","CADJPY","CHFJPY","EURAUD","EURCAD",
         "EURCHF","EURGBP","EURJPY","EURNZD","EURUSD",
         "GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD",
         "GBPUSD","NZDCAD","NZDCHF","NZDJPY","NZDUSD",
         "USDCAD","USDCHF","USDJPY" }; 

// ------------------------------------------ GLOBAL FUNCTIONS ------------------------------------------------- //

/*! Calculate the lot amount of other parities other than USD that is equivalent to the same USD lot */
void FindParityLots()
{
   for(int i = 0; i < NUM_VALID_PARITIES; i++){
      if(i < 5)
         parity_lots[i] = lot / NormalizeDouble(MarketInfo("AUDUSD", MODE_ASK), 2);      
      else if(i < 7)
         parity_lots[i] = lot / NormalizeDouble(MarketInfo("USDCAD", MODE_ASK), 2);      
      else if(i < 8)
         parity_lots[i] = lot / NormalizeDouble(MarketInfo("USDCHF", MODE_ASK), 2);       
      else if(i < 15)
         parity_lots[i] = lot / NormalizeDouble(MarketInfo("EURUSD", MODE_ASK), 2);         
      else if(i < 21)
         parity_lots[i] = lot / NormalizeDouble(MarketInfo("GBPUSD", MODE_ASK), 2);         
      else if(i < 25)
         parity_lots[i] = lot / NormalizeDouble(MarketInfo("NZDUSD", MODE_ASK), 2);         
      else 
         parity_lots[i] = lot;
   }
}

/*! Script program start function */
void OnStart()
{
   int ticket = -1;
   int k = 0;
   
   FindParityLots();
   
   for (int i=0; i < num_orders; i++){
      int rand_index = MathRand() % NUM_VALID_PARITIES;
      string sym = valid_parities[rand_index];
      double lot_to_open = parity_lots[rand_index];
      int buy = MathRand()%2;
      for (k = 0; k < MAX_NUM_TRIALS; k++){
         ticket = OrderSend(sym, buy, lot_to_open, MarketInfo(sym, buy?MODE_BID:MODE_ASK), 10, 0, 0, ex_comment, ex_magic_no);
         if (ticket != -1) break;
      }//end max trials
      if (k == MAX_NUM_TRIALS)   Print(sym, " Paritesinde emir acilamadi. Hata kodu = ", GetLastError());
   }     
}

