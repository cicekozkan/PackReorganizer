/*!\file PackReorganizer.mq4
*/
//+------------------------------------------------------------------+
//|                                              PackReorganizer.mq4 |
//|                        Copyright 2015, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

extern int ex_magic_no = 12345;  ///< Magic number of target orders
extern int ex_tp1 = 10;          ///< Take profit pips 1
extern int ex_tp2 = 20;          ///< Take profit pips 2
extern int ex_tp3 = 30;          ///< Take profit pips 3

/*! Pack class; represents a package */
class Pack{
   int imTicketarray [] ;  ///< An array to hold ticket number of orders of the package
   string smSymbols [] ;   ///< An array to hold symbols of orders of the package
   int counter ;           ///< Number of orders in the package
public:
   /*!Default constructor*/
   Pack(){}
   bool isInsertable(const int);
   /*!\return Number of positions*/
   int GetSize(){return counter;}
   int Add(const int);
   /*!Displays the package*/
   void Display();
   /*!Closes all the positions in the package*/
   bool ClosePack(void);
};

/*! Checks whether given position can be inserted to the package or not
   \param cTicket Ticket number 
   \return True if the position with given ticket number can be inserted to the package; false otherwise 
*/
bool Pack::isInsertable(const int cTicket){
   int ticketArraySize = ArraySize(imTicketarray);
   
   if(ticketArraySize == 4)
      return false;
   if(ticketArraySize == 0)
      return true;

   if(!(OrderSelect(cTicket, SELECT_BY_TICKET)==true)){
      Print("Order Secilemedi , Hata Kodu :  ",GetLastError());
      return false;
   }
   string newSymbol = OrderSymbol();
   Print(cTicket, " Nolu Order secildi , OrderSymbol : ", newSymbol);
   
   for(int i = 0; i < ticketArraySize ; ++i)
   {
      if(StringSubstr(newSymbol,0,3) == StringSubstr(smSymbols[i],0,3) || StringSubstr(newSymbol,0,3) == StringSubstr(smSymbols[i],3,3) ||
         StringSubstr(newSymbol,3,3) == StringSubstr(smSymbols[i],0,3) || StringSubstr(newSymbol,3,3) == StringSubstr(smSymbols[i],3,3))
         return false;  
   }
 return true;  
}

/*!Adds given position to the pack
   \param cTicket Ticket number
   \return If successful: number of positions; otherwise -1
*/
int Pack::Add(const int cTicket){

   imTicketarray[counter] = cTicket;
   int lastArraySize = ArraySize(imTicketarray);
      
   if(!(OrderSelect(cTicket, SELECT_BY_TICKET)==true)){
      Print("Order Secilemedi , Hata Kodu :  ",GetLastError());
      return -1;
   }
   
   smSymbols[counter] = OrderSymbol();
   counter++;
   return lastArraySize;
}

void Pack::Display(void){

   for(int i =0 ; i < ArraySize(smSymbols);++i )
   Print(smSymbols[i]);
   
}

bool Pack::ClosePack(void)
{
   for(int i = 0; i < counter; i++){
      int ticket = imTicketarray[i];
   	if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(ticket, " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return false;
	   }
	   
	   int optype = OrderType();
	   int k = 0;
	   double close_price;
	   for (k = 0; k < 3; ++k) {
   		if (optype == OP_BUY)
   			close_price = MarketInfo(smSymbols[i], MODE_BID);
   		else
   			close_price = MarketInfo(smSymbols[i], MODE_ASK);
   		if (OrderClose(ticket, OrderLots(), close_price, 10))
   			break;
   		RefreshRates();
	   }// end for trial
      if (k == 3) {
         Alert(ticket, " No'lu emir kapatilamadi close price", close_price, " .... Hata kodu : ", GetLastError());
         break;
      }
   }// end for counter
   
   return false;
}

// ------------------------------------------- PACK VECTOR CLASS --------------------------------------------------------- //
/*! Represents a pack vector */
class PackVector {
   Pack m_pack[];    ///< An array of Packs
   int m_index;      ///< index
public:
   /*! Default constructor. Initializes the vector with 0 Packs*/
   PackVector() : m_index(0) {}
   void push_back(int ticket);
   Pack *operator[](int index);
   void remove(int index);
};

/*! Mmics C++ vector<> push_back method. Places given position 
   to the vector. **TODO**: Should place a package to the vector not
   a position
   \param ticket Ticket number
*/
void PackVector::push_back(const int ticket)
{
   m_pack[m_index++].add(ticket);
}

/*! 
   \param index Index of the package in the vector
   \return Selected pack's pointer   
*/
Pack *PackVector::operator[](const int index)
{
   return &m_pack[index];
}

/*!Remove selected package from the vector
   \param index Index of the package in the vector
*/
void PackVector::remove(int index)
{
   
}

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

int pack_index = 0;
Pack p;
Pack p_arr[];

/*! A global function to re-organize packages. Traveses all open orders and 
places target orders whose magic number matches the desired magic number ex_magic_no
to the first available package. Creates a new package if all packages are full or 
none is available and places the order to that new package.
*/
void PackReorginize(void)
{
   for (int k = OrdersTotal() - 1; k >= 0; --k) {
      if (!OrderSelect(k, SELECT_BY_POS, MODE_TRADES)) {
      	Alert("Emir secilemedi... Hata kodu : ", GetLastError());
      	continue;
      }
      if(OrderMagicNumber() == ex_magic_no && StringToInteger(StringSubstr(OrderComment(), 2)) == ex_magic_no){
         int i;
         for(i = 0; i < pack_index; i++){
            if (p_arr[i].isInsertable(OrderTicket())){ 
               p_arr[i].Add(OrderTicket());
               break;
            }
         }//end pack array traverse for
         if (i==pack_index) p_arr[pack_index++].Add(OrderTicket());
      }      
   }// end order total for
}

// ------------------------------------------------- EXPERT FUNCTIONS ----------------------------------------------- //

/*! Expert initialization function */   
int OnInit()
{
   int ticket = -1;
   for (int i=0; i<50; i++){
      string sym = getRandomOrder();
      int buy = MathRand()%2;
      ticket = OrderSend(sym, buy, 0.1, MarketInfo(sym, buy?MODE_BID:MODE_ASK), 10, 0, 0, "1_11111", 11111);
      if (ticket < 0) Print(sym, " Paritesinde emir acilamadi. Hata kodu = ", GetLastError());
   }      
   return(INIT_SUCCEEDED);
}

/*! Expert deinitialization function */                           
void OnDeinit(const int reason)
{
        
}

/*! Expert tick function */                                          
void OnTick()
{
   
}

