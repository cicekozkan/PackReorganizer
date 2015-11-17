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
#define  INITIAL_PACK_VEC_SIZE 128
#define  NUM_VALID_PARITIES 28

extern int ex_magic_no = 12345;  ///< Magic number of target orders
extern int ex_tp1 = 10;          ///< Take profit pips 1
extern int ex_tp2 = 20;          ///< Take profit pips 2
extern int ex_tp3 = 30;          ///< Take profit pips 3

/*! Pack class; represents a package */
class Pack{
   int imTicketarray [MAX_ORDERS_IN_A_PACK] ;  ///< An array to hold ticket number of orders of the package
   string smSymbols [MAX_ORDERS_IN_A_PACK] ;   ///< An array to hold symbols of orders of the package
   int counter ;           ///< Number of orders in the package
   int m_total_profit_pip; ///< Total profit of the pack in pips
   int m_target_profit_pip; ///< Target profit of the pack in pips
public:
   /*!Default constructor*/
   Pack(): counter(0), m_total_profit_pip(0), m_target_profit_pip(0){}
   bool isInsertable(const int);
   /*!\return Number of positions*/
   int size(){return counter;}
   int Add(const int);
   void Display(void);
   bool ClosePack(void);
   int GetProfit(void);  
   int GetTargetProfit(void); 
   bool hasOrder(int);
   /*!\return Indexed pack's ticket number*/
   int GetTicket(int index){return imTicketarray[index];}
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

   if(!(OrderSelect(cTicket, SELECT_BY_TICKET)==true)){
      Print("Order Secilemedi , Hata Kodu :  ",GetLastError());
      return -1;
   }
   imTicketarray[counter] = cTicket;
   int lastArraySize = ArraySize(imTicketarray);   
   smSymbols[counter] = OrderSymbol();
   counter++;
   m_total_profit_pip = GetProfit();
   m_target_profit_pip = GetTargetProfit();
   return lastArraySize;
}

/*!Display the package*/
void Pack::Display(void){

   for(int i =0 ; i < ArraySize(smSymbols);++i )
   Print(smSymbols[i]);
}

/*!Close all the positions in the package
   \return True if success; false otherwise
*/
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
         Alert(ticket, " No'lu emir kapatilamadi. Close price: ", close_price, ".... Hata kodu : ", GetLastError());
         return false;
      }
   }// end for counter
      
   m_target_profit_pip = 0; // update these variables (doubt we will need a closed pack's variables; just do it to be safe)
   m_total_profit_pip = 0;
   return true;
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

/*!\return The target profit pips of the package */
int Pack::GetTargetProfit(void)
{
   int tp = -1;
   int total = 0;
   for (int i=0; i < counter; i++){
      if (!OrderSelect(imTicketarray[i], SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(imTicketarray[i], " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return -1;
	   }
      total += GetOrderTarget();
   }//end for - traverse orders
   return total;
}

/*!\param ticket: Ticket number of the order
   \return True if the order with given ticket number is in the pack; false otherwise
*/
bool Pack::hasOrder(int ticket)
{
   for (int i = 0; i < counter; i++)
      if (imTicketarray[i] == ticket)  return true;
   return false;
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
   bool PackVector::push_back(Pack *value);
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
   \return True if success; false if memory allocation and array resize fails
*/
bool PackVector::push_back(Pack *value)
{
   static int capacity = INITIAL_PACK_VEC_SIZE;
   if (m_index + 1 == capacity) capacity *= 2;
   if (ArrayResize(m_pack, m_index + 1, capacity) == -1 ) return false; 
   else m_pack[m_index++] = value;
   return true;
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

/*!\return The target profit pips of the order. The order must be selected with OrderSelect() function before calling this function*/
int GetOrderTarget(void)
{
   int target = 0;
   int tp;
   tp = StringToInteger(StringSubstr(OrderComment(), 0, 1));
   switch(tp){
      case 1:
         target = ex_tp1;
         break;
      case 2:
         target = ex_tp2;
         break;
      case 3:
         target = ex_tp3;
         break;
      default:
         Alert("Gecersiz comment...");
         target = -1;      
   }//end switch case - take profit
   return target;
}

/// All possible parities
const string valid_parities[NUM_VALID_PARITIES] = {
            "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD",
            "CADCHF","CADJPY","CHFJPY","EURAUD","EURCAD",
            "EURCHF","EURGBP","EURJPY","EURNZD","EURUSD",
            "GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD",
            "GBPUSD","NZDCAD","NZDCHF","NZDJPY","NZDUSD",
            "USDCAD","USDCHF","USDJPY" }; 
            
/*! ArrayBsearch function not used because it returns 
    index of a found element. If the wanted value isn't found, the function returns the index of an element nearest in value.
   \param parity Parity of the order to check
   \return True if the parity is valid; false otherwise*/
bool IsValidParity(const string parity)
{
   for(int i = 0; i < NUM_VALID_PARITIES; i++)
      if(valid_parities[i] == parity)  return true;
   return false;
}

/*!Check the comment format. **TODO**: This function can be implemented with regular expressions but MQL does not support
   regular expressions. In C++ regex can be used. Here is the python implementation
   
   import re
   def comment_match(comment):
       pattern = '[1-3]+_[0-9]{5}'
       m = re.match(pattern,comment)
       if m == None:
           return False
       else:
           return m.group(0) == comment

   \param comment Order comment
   \return Return true if comment starts with 1, 2, 3 followed by _ and then followed by a 5 digit number. False otherwise
*/
bool IsValidComment(const string comment)
{
   if (StringSubstr(comment, 1, 1) != '_')  return false;
   int first_num = StringSubstr(comment, 0, 1);
   if (first_num != 1 && first_num != 2 && first_num != 3)  return false;
   int magic_num = StringToInteger(StringSubstr(comment, 2));
   if ( magic_num < 0 || magic_num > 99999) return false;
   return true;
}

/*! Check magic number format. For now it only checks if the magic number is within the range [0, 1000000) or not
   \return True if magic number is in range [0, 1000000); false otherwise
*/
bool IsValidMagic(const int magic)
{
   return !(magic < 0 || magic > 99999);
}

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

/// Log file name
string log_file_name = "PackReorganizeLog.txt";
/// Log file handle
int lfh = INVALID_HANDLE;

/*! Log packs to a tab delimetd text file */
void Log(void)
{
   MqlDateTime str; 
   TimeToStruct(TimeCurrent(), str);
   string date = IntegerToString(str.year) + "/" + IntegerToString(str.mon) + "/" + IntegerToString(str.day);
   string time = IntegerToString(str.hour) + ":" + IntegerToString(str.min) + ":" + IntegerToString(str.sec);
   
   for (int i = 0; i < pvec.size(); i++){
      for (int j = 0; j < pvec[i].size(); j++){ 
         OrderSelect(pvec[i].GetTicket(j), SELECT_BY_TICKET);
         FileWrite(lfh, date +  
                        time +  
                        OrderSymbol() + 
                        DoubleToStr(OrderOpenPrice()) + 
                        OrderComment() + 
                        IntegerToString(OrderMagicNumber()) + 
                        IntegerToString(OrderTicket()) + 
                        IntegerToString((int)NormalizeDouble(OrderProfit(), Digits) / Point) +  
                        IntegerToString(GetOrderTarget()) + 
                        IntegerToString(pvec[i].GetProfit()) + 
                        IntegerToString(pvec[i].GetTargetProfit()));                        
      }//end for - traverse orders in the pack
   }//end for - traverse pack vector
   
}

// ------------------------------------------------- EXPERT FUNCTIONS ----------------------------------------------- //

/*! Expert initialization function */   
int OnInit()
{
   lfh = FileOpen(log_file_name, FILE_WRITE | FILE_TXT, '\t'); 
   if (lfh == INVALID_HANDLE){
      Alert(log_file_name, " cannot be opened. The error code = ", GetLastError());
      ExpertRemove();
   }
   FileWrite(lfh, "Date" + "Time" + "OrderSymbol" + "OrderOpenPrice" + "OrderComment" + "OrderMagicNumber" + 
                  "OrderTicketNumber" + "OrderProfitPips" + "OrderTargetProfitPips" + 
                  "PackProfitPips" + "PackTargetProfitPips");
   PackReorganize();
   Log();
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




///////////////////////////////
/*
+ Degisiklik yapiyoruz: Her bir tickte butun orderlar gezilir; secilen order
		comment convention ve magic number istedigimiz gibi mi degil mi kontrol edilir.
		Istedigimiz gibi degilse sonraki ordera gecilir. Istedigimiz gibiyse paketlerde
		var mi diye bakilir (hasOrder). Varsa bir sonraki ordera gecer; hicbir 
		pakette yoksa ilk uygun pakete eklenir. 14/11/2015



for OrrderTotal() {
    !is valid comment
        continue;
    !is valid magic
        continue;
    pack.hasContain
        continue;
    for (PACK.Size()
        is insertable
            pack.add
            flag = true;
}

if (flag == true)
    log
    flag = false;

*/
