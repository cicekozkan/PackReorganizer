/*!\file PackReorganizer.mq4
*/
//+------------------------------------------------------------------+
//|                                              PackReorganizer.mq4 |
//|                                Copyright 2015, MQL Project Group |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#define  MAX_ORDERS_IN_A_PACK 4
#define  MAX_NUM_TRIALS 3

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
   int size(){return counter;}
   int Add(const int);
   /*!Displays the package*/
   void Display();
   /*!Closes all the positions in the package*/
   bool ClosePack(void);
   int GetProfit(void);  
   int GetTargetProfit(void); 
};

/*! Checks whether given position can be inserted to the package or not
   \param cTicket Ticket number 
   \return True if the position with given ticket number can be inserted to the package; false otherwise 
*/
bool Pack::isInsertable(const int cTicket){
   int ticketArraySize = ArraySize(imTicketarray);
   
   if(ticketArraySize == MAX_ORDERS_IN_A_PACK)
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
	   for (k = 0; k < MAX_NUM_TRIALS; ++k) {
   		if (optype == OP_BUY)
   			close_price = MarketInfo(smSymbols[i], MODE_BID);
   		else
   			close_price = MarketInfo(smSymbols[i], MODE_ASK);
   		if (OrderClose(ticket, OrderLots(), close_price, 10))
   			break;
   		RefreshRates();
	   }// end for trial
      if (k == MAX_NUM_TRIALS) {
         Alert(ticket, " No'lu emir kapatilamadi close price", close_price, " .... Hata kodu : ", GetLastError());
         break;
      }
   }// end for counter
   
   return false;
}

/*!\return Total profit pips of the package */ 
int Pack::GetProfit(void)
{
   int total = 0;
   for (int i=0; i < counter; i++){
      if (!OrderSelect(imTicketarray[i], SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(imTicketarray[i], " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return -1;
	   }
	   total += (int)NormalizeDouble(OrderProfit(), Digits) / Point;
   }//end for - traverse orders
   return total;
}

/*!\return The target profit of the package */
int Pack::GetTargetProfit(void)
{
   int tp = -1;
   int total = 0;
   for (int i=0; i < counter; i++){
      if (!OrderSelect(imTicketarray[i], SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(imTicketarray[i], " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return -1;
	   }
      tp = StringToInteger(StringSubstr(OrderComment(), 0, 1));
      switch(tp){
         case 1:
            total += ex_tp1;
            break;
         case 2:
            total += ex_tp2;
            break;
         case 3:
            total += ex_tp3;
            break;
         default:
            Alert(imTicketarray[i], " No'lu emirde gecersiz comment...");
            return -1;      
      }//end switch case - take profit
   }//end for - traverse orders
   return total;
}

// ------------------------------------------- PACK VECTOR CLASS --------------------------------------------------------- //
/*! Represents a pack vector */
class PackVector {
   Pack *m_pack[];    ///< An array of Packs
   int m_index;      ///< index
   int m_total_orders;  ///< Number of total orders in the pack vector
public:
   /*! Default constructor. Initializes the vector with 0 Packs*/
   PackVector() : m_index(0) {ArrayResize(m_pack, m_index, 1024);}
   void PackVector::push_back(Pack *value);
   Pack *operator[](int index);
   bool remove(int index);
   /*!\return Number of packages inside the vector*/
   int size(void){return m_index;}
   bool checkTakeProfit(int index);
   int GetNumTotalOrders(void);
};

/*! Mmics C++ vector<> push_back method. Places given pack 
   to the vector. 
   \param value Package pointer
*/
void PackVector::push_back(Pack *value)
{
   m_pack[m_index++] = value;
}

/*! 
   \param index Index of the package in the vector
   \return Selected pack's pointer   
*/
Pack *PackVector::operator[](const int index)
{
   return m_pack[index];
}

/*!Close all orders in indexed package, remove it from the vector, shrink package and update size
   \param index Index of the package in the vector
   \return true if successful, false otherwise.
*/
bool PackVector::remove(int index)
{
   if(!m_pack[index].ClosePack()) return false;
   --m_index; 
   if (ArrayResize(m_pack, m_index, 1024) == -1) return false;
   return true;
}

/*!\param index: Index of the package to check
   \return True if the sum of the profits of orders in the package is equal to or greater than the target. False otherwise
*/ 
bool PackVector::checkTakeProfit(int index)
{
   return m_pack[index].GetProfit() != m_pack[index].GetTargetProfit();
}

/*!\return Number of total orders in the pack vector
*/
int PackVector::GetNumTotalOrders(void)
{
   int total = 0;
   for (int i = 0; i < m_index; i++){
      total += m_pack[i].size();
   }//end for - traverse packs in the pack vector
   return total;
}
// ------------------------------------------ GLOBAL FUNCTIONS AND VARIABLES ------------------------------------------------- //

PackVector pvec;     ///< Global PackVector class object
int num_orders = 0;  ///< Number of orders

/*! A global function to re-organize packages. Traverses all open orders and 
places target orders whose magic number matches the desired magic number ex_magic_no
to the first available package. Creates a new package if all packages are full or 
none is available and places the order to that new package.
*/
void PackReorganize(void)
{
   for (int k = OrdersTotal() - 1; k >= 0; --k) {
      if (!OrderSelect(k, SELECT_BY_POS, MODE_TRADES)) {
      	Alert("Emir secilemedi... Hata kodu : ", GetLastError());
      	continue;
      }
      if(OrderMagicNumber() == ex_magic_no && StringToInteger(StringSubstr(OrderComment(), 2)) == ex_magic_no){
         int i;
         for(i = 0; i < pvec.size(); i++){
            if (pvec[i].isInsertable(OrderTicket())){ 
               pvec[i].Add(OrderTicket());
               break;
            }
         }//end pack array traverse for
         if (i==pvec.size()) {
            pvec.push_back(new Pack);
            pvec[i].Add(OrderTicket());
         }
      }      
   }// end order total for
   Alert("Package reorganized");
}

// ------------------------------------------------- EXPERT FUNCTIONS ----------------------------------------------- //

/*! Expert initialization function */   
int OnInit()
{
   PackReorganize();
   return(INIT_SUCCEEDED);
}

/*! Expert deinitialization function */                           
void OnDeinit(const int reason)
{
        
}

/*! Expert tick function */                                          
void OnTick()
{
   if (pvec.GetNumTotalOrders() != OrdersTotal()) PackReorganize();
}

