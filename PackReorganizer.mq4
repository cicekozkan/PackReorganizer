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

extern int ex_magic_no = 11111;  ///< Magic number of target orders
extern int ex_tp1 = 10;          ///< Take profit pips 1
extern int ex_tp2 = 20;          ///< Take profit pips 2
extern int ex_tp3 = 30;          ///< Take profit pips 3

/*! Pack class; represents a package */
class Pack{
   int imTicketarray [] ;  ///< An array to hold ticket number of orders of the package
   string smSymbols [] ;   ///< An array to hold symbols of orders of the package
   int counter ;           ///< Number of orders in the package
   int m_total_profit_pip; ///< Total profit of the pack in pips
   int m_target_profit_pip; ///< Target profit of the pack in pips
   int m_id;                 ///< unique id of the pack
   int GetOrderTarget(void);
public:
   /*!Default constructor*/
   Pack(): counter(0), m_total_profit_pip(0), m_target_profit_pip(0), m_id(0){ArrayResize(imTicketarray,0,MAX_ORDERS_IN_A_PACK);ArrayResize(smSymbols,0,MAX_ORDERS_IN_A_PACK);}
   bool isInsertable(int);
   /*!\return Number of positions*/
   int size(){return counter;}
   int Add(int);
   void Display(void);
   bool ClosePack(void);
   double GetProfit(void);  
   int GetTargetProfit(void); 
   /*!\return Indexed order's ticket number*/
   int GetTicket(int index){return imTicketarray[index];}
   bool ShouldBeClosed(void);
   int GetId(void){return m_id;}
};

/*!\return The target profit pips of the order */
int Pack::GetOrderTarget(void)
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

/*! Checks whether given position can be inserted to the package or not
   \param cTicket Ticket number 
   \return True if the position with given ticket number can be inserted to the package; false otherwise 
*/
bool Pack::isInsertable(int cTicket){
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
int Pack::Add(int cTicket){

   if(!(OrderSelect(cTicket, SELECT_BY_TICKET)==true)){
      Print("Order Secilemedi , Hata Kodu :  ",GetLastError());
      return -1;
   }
   int lastArraySize = ArraySize(imTicketarray);
   ArrayResize(imTicketarray, lastArraySize + 1);
   ArrayResize(smSymbols, lastArraySize + 1);   // they should always have same size!
   imTicketarray[counter] = cTicket;      
   smSymbols[counter] = OrderSymbol();
   counter++;
   m_total_profit_pip = GetProfit();
   m_target_profit_pip = GetTargetProfit();
   m_id += OrderTicket();
   return lastArraySize + 1;
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
   //if (LOG_ACTIONS)  FileWrite(alfh, "************Pack::ClosePack called*********************");
   for(int i = counter-1; i >=0 ; --i){
      int ticket = imTicketarray[i];
   	if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(ticket, " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return false;
	   }
	   int optype = OrderType();
	   //if (LOG_ACTIONS)  FileWrite(alfh, "Ticket#: ", ticket, optype==OP_BUY?", Buy":(optype==OP_SELL?", Sell":", Other optype"));
	   int k = 0;
	   double close_price;
	   for (k = 0; k < MAX_NUM_TRIALS; ++k) {
   		if (optype == OP_BUY)
   			close_price = MarketInfo(smSymbols[i], MODE_BID);
   		else
   			close_price = MarketInfo(smSymbols[i], MODE_ASK);
   		//if (LOG_ACTIONS)  FileWrite(alfh, "Order lots: ", OrderLots(), ", Close price: ", close_price);
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
   counter = 0;
   return true;
}

/*!\return Total profit pips of the package */ 
double Pack::GetProfit(void)
{
   double total = 0.;
   for (int i=0; i < counter; ++i){
      if (!OrderSelect(imTicketarray[i], SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(imTicketarray[i], " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return -1;
	   }
	   total += NormalizeDouble(OrderProfit(), Digits);
   }//end for - traverse orders
   return total;
}

/*!\return The target profit pips of the package */
int Pack::GetTargetProfit(void)
{
   int tp = -1;
   int total = 0;
   for (int i=0; i < counter; ++i){
      if (!OrderSelect(imTicketarray[i], SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(imTicketarray[i], " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return -1;
	   }
      total += GetOrderTarget();
   }//end for - traverse orders
   return total;
}

/*!   \return True if the sum of the profits of orders in the package is equal to or greater than the target. False otherwise */ 
bool Pack::ShouldBeClosed(void)
{
   return GetProfit() >= GetTargetProfit();
}

// ------------------------------------------- PACK VECTOR CLASS --------------------------------------------------------- //
/*! Represents a pack vector */
class PackVector {
   Pack *m_pack[];    ///< An array of Packs
   int m_num_packs;      ///< Number of packs in the vector
   int m_total_orders;  ///< Number of total orders in the pack vector
public:
   /*! Default constructor. Initializes the vector with 0 Packs*/
   PackVector() : m_num_packs(0) {ArrayResize(m_pack, m_num_packs, 1024);}
   bool PackVector::push_back(Pack *value);
   Pack *operator[](int index);
   bool remove(int index);
   /*!\return Number of packages inside the vector*/
   int size(void){return m_num_packs;}
   int GetNumTotalOrders(void);
   bool hasOrder(int);
   void sort(void);
};

/*! Mmics C++ vector<> push_back method. Places given pack 
   to the vector. 
   \param value Package pointer
   \return True if success; false if memory allocation and array resize fails
*/
bool PackVector::push_back(Pack *value)
{
   static int capacity = INITIAL_PACK_VEC_SIZE;
   if (m_num_packs + 1 == capacity) capacity *= 2;
   if (ArrayResize(m_pack, m_num_packs + 1, capacity) == -1 ) return false; 
   else m_pack[m_num_packs++] = value;
   return true;
}

/*! 
   \param index Index of the package in the vector
   \return Selected pack's pointer   
*/
Pack *PackVector::operator[](int index)
{
   return m_pack[index];
}

/*!Close all orders in indexed package, remove it from the vector, shrink package and update size
   \param index Index of the package in the vector
   \return true if successful, false otherwise.
*/
bool PackVector::remove(int index)
{
   //if (LOG_ACTIONS)  {
   //   FileWrite(alfh, "*********PackVector::remove called************");
   //   FileWrite(alfh, "Vector size before closing the pack: ", ArraySize(m_pack));
   //} 
    
   if(!m_pack[index].ClosePack()) return false; 
   sort();     // closed pack will be shifted to the end of the array. No chance that there will be 2 packs with 0 elements
   --m_num_packs; 
   if (ArrayResize(m_pack, m_num_packs) == -1) return false; // delete 
   //if (mcs_log_actions)  {
   //   FileWrite(alfh, "Pack", index, " closed successfully");
   //    FileWrite(alfh, "Vector size after closing the pack: ", ArraySize(m_pack), "\n");
   //}   
   return true;
}

/*!\return Number of total orders in the pack vector
*/
int PackVector::GetNumTotalOrders(void)
{
   int total = 0;
   for (int i = 0; i < m_num_packs; i++){
      total += m_pack[i].size();
   }//end for - traverse packs in the pack vector
   return total;
}

/*!\param ticket: Ticket number of the order
   \return True if the order with given ticket number is in the pack vector; false otherwise
*/
bool PackVector::hasOrder(int ticket)
{
   for (int i = 0; i < m_num_packs; i++){
      for (int j = 0; j < m_pack[i].size(); j++){
         if (m_pack[i].GetTicket(j) == ticket)  return true;
      }//end for - pack
   }//end for - pack vector
   return false;
}

/*!Sort packs in descending direction. Inserting sort algorithm is selected since it is adaptive. Any other ideas? */
void PackVector::sort(void)
{ 
   Pack *current = new Pack;
   for (int i = 1; i < m_num_packs; i++){
      int j = i;
      current = m_pack[i];
      while ( (j > 0) && (m_pack[j-1].size() < current.size())){
         m_pack[j] = m_pack[j-1];
         --j;
      }//end while
      m_pack[j] = current;              
   }//end for - pack traverse in vector
}

// ---------------------------------------------------- REORGANIZER CLASS ---------------------------------------------------------- //
/*! Reorganizer class. The results unknown in case multiple objects instantiated */
class Reorganizer{
static const string mcs_valid_parities[NUM_VALID_PARITIES]; ///< All possible parities
PackVector  m_pvec; ///< Engine will hold packs in this pack vector 
int m_num_ordes; ///< Number of orders
static const string mcs_log_filename; ///< Log file name
static int ms_lfh;  ///< Log file handle
static const string mcs_log_actions_filename; ///< Second log file to keep track of what's going on
static int ms_alfh; ///< Second log file handle
bool IsValidParity(string parity);
bool IsValidComment(string comment);
bool IsValidMagic(void);
void Log(string comment_log);
int GetNumValidOrders(); 
void Organize(void);

public:
void Init(void);
void Run(void);
void Stop(void);

};

const string Reorganizer::mcs_valid_parities[NUM_VALID_PARITIES] = {
            "AUDCAD","AUDCHF","AUDJPY","AUDNZD","AUDUSD",
            "CADCHF","CADJPY","CHFJPY","EURAUD","EURCAD",
            "EURCHF","EURGBP","EURJPY","EURNZD","EURUSD",
            "GBPAUD","GBPCAD","GBPCHF","GBPJPY","GBPNZD",
            "GBPUSD","NZDCAD","NZDCHF","NZDJPY","NZDUSD",
            "USDCAD","USDCHF","USDJPY" };            
const string Reorganizer::mcs_log_filename = "PackReorganizeLog.csv";
const string Reorganizer::mcs_log_actions_filename = "LogActions.txt";
int Reorganizer::ms_alfh = INVALID_HANDLE;
int Reorganizer::ms_lfh = INVALID_HANDLE; 
            
/*! ArrayBsearch function not used because it returns 
    index of a found element. If the wanted value isn't found, the function returns the index of an element nearest in value.
   \param parity Parity of the order to check
   \return True if the parity is valid; false otherwise*/
bool Reorganizer::IsValidParity(string parity)
{
   for(int i = 0; i < NUM_VALID_PARITIES; i++)
      if(mcs_valid_parities[i] == parity)  return true;
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
bool Reorganizer::IsValidComment(string comment)
{
   if (StringSubstr(comment, 1, 1) != "_")  return false;
   int first_num = StringToInteger(StringSubstr(comment, 0, 1));
   if (first_num != 1 && first_num != 2 && first_num != 3)  return false;
   int magic_num = StringToInteger(StringSubstr(comment, 2));
   if ( magic_num < 0 || magic_num > 99999) return false;
   return true;
}

/*! Check magic number format. The order must be selected before calling this function 
   \return True if magic number in the comment matches the order magic number; false otherwise
*/
bool Reorganizer::IsValidMagic(void)
{ 
   int magic_comment = StringToInteger(StringSubstr(OrderComment(), 2));    
   return (magic_comment == OrderMagicNumber()) && (magic_comment == ex_magic_no);
}

/*! Log packs to a tab delimetd csv file */
void Reorganizer::Log(string comment_log)
{
   MqlDateTime str; 
   TimeToStruct(TimeCurrent(), str);
   string date = IntegerToString(str.year) + "/" + IntegerToString(str.mon) + "/" + IntegerToString(str.day);
   string time = IntegerToString(str.hour) + ":" + IntegerToString(str.min) + ":" + IntegerToString(str.sec);
   string sym, open, comment, magic, ticket, pack_profit, pack_target;
   double p;
   int pack_id;
   
   for (int i = 0; i < m_pvec.size(); i++){
      for (int j = 0; j < m_pvec[i].size(); j++){ 
         if (!OrderSelect(m_pvec[i].GetTicket(j), SELECT_BY_TICKET)){
            Alert(m_pvec[i].GetTicket(j), " orderi secilemedi");
         }
         sym = OrderSymbol(); 
         open = DoubleToString(OrderOpenPrice());
         comment = OrderComment();
         magic = IntegerToString(OrderMagicNumber());
         ticket = IntegerToString(OrderTicket());
         p = NormalizeDouble(OrderProfit(), Digits);
         pack_id = m_pvec[i].GetId();
         pack_profit = DoubleToString(m_pvec[i].GetProfit());
         pack_target = IntegerToString(m_pvec[i].GetTargetProfit());
         FileWrite(ms_lfh, date,  
                  time,
                  comment_log,  
                  IntegerToString(i),
                  sym, 
                  open, 
                  comment, 
                  magic, 
                  ticket,                      
                  pack_id,
                  pack_profit, 
                  pack_target);                            
      }//end for - traverse orders in the pack
   }//end for - traverse pack vector
}

/*!\return The number of valid orders*/
int Reorganizer::GetNumValidOrders()
{
   //if (LOG_ACTIONS)  FileWrite(alfh, "*********GetNumValidOrders called************");   
   int total = 0;
   string comment, sym;
   int magic;
   for (int k = OrdersTotal() - 1; k >= 0; --k) {
      if (!OrderSelect(k, SELECT_BY_POS, MODE_TRADES)) {
      	Alert("Emir secilemedi... Hata kodu : ", GetLastError());
      	continue;
      }
      comment = OrderComment();
      magic = OrderMagicNumber();
      sym = OrderSymbol();
      if (/*LOG_ACTIONS*/FALSE){
         FileWrite(ms_alfh, "Order", k, " comment = ", comment, ", magic# = ", magic, ", symbol = ", sym);
         FileWrite(ms_alfh, "Valid Comment = ",  IsValidComment(comment)?"Yes":"No", ", Valid Magic = ", IsValidMagic()?"Yes":"No",
                        ", Valid Parity = ", IsValidParity(sym)?"Yes":"No");
      }
      if (IsValidComment(comment) && IsValidMagic() && IsValidParity(sym))   ++total;      
   }//end for
   return total; 
}

/*! Organize packages. Traverses all open orders and 
places target orders whose magic number matches the desired magic number ex_magic_no
to the first available package. Creates a new package if all packages are full or 
none is available and places the order to that new package.
*/
void Reorganizer::Organize(void)
{
   
   for (int k = OrdersTotal() - 1; k >= 0; --k) {
      if (!OrderSelect(k, SELECT_BY_POS, MODE_TRADES)) {
      	Alert("Emir secilemedi... Hata kodu : ", GetLastError());
      	continue;
      }
      
      if (!IsValidComment(OrderComment())) continue;
      if (!IsValidMagic()) continue;
      if (m_pvec.hasOrder(OrderTicket())) continue; // order is already in a pack
      int i;
      m_pvec.sort();
      for(i = 0; i < m_pvec.size(); i++){         
         if (m_pvec[i].isInsertable(OrderTicket())){             
            m_pvec[i].Add(OrderTicket());
            break;
         }
      }//end for - traverse orders in the pack   
      if (i==m_pvec.size()) {
         m_pvec.push_back(new Pack);
         m_pvec[i].Add(OrderTicket());
      }
   }// end for - traverse all orders 
   m_pvec.sort(); // sort at the end again
}

void Reorganizer::Run(void)
{
   int total_valid_orders = -1;
   int total_orders_in_vec = -1;
   total_valid_orders = GetNumValidOrders();
   total_orders_in_vec = m_pvec.GetNumTotalOrders();
   
   if (total_valid_orders != total_orders_in_vec){    // a new order 
      Log("BeforeNewOrder");
      FileWrite(ms_alfh, "\nNew Order! Num Valid Orders = ", total_valid_orders, " Num orders in pack vector = ", total_orders_in_vec, "\n");
      Organize(); 
      Log("AfterNewOrder");       
   }else{
      //if (LOG_ACTIONS)  FileWrite(alfh, "Num Valid Orders = ", total_valid_orders, " Num orders in pack vector = ", total_orders_in_vec);
   }
   
   int i = 0;
   while (i < m_pvec.size()){
      if (m_pvec[i].ShouldBeClosed()){
         Log("BeforePackClose"); 
         FileWrite(ms_alfh,"Close Pack", i, ". Pack id = ", m_pvec[i].GetId());
         m_pvec.remove(i);
         Log("AfterPackClose");
      }else{
         ++i;
      }
   }//end while
}

void Reorganizer::Init(void)
{
   ms_lfh = FileOpen(mcs_log_filename, FILE_WRITE | FILE_CSV); 
   if (ms_lfh == INVALID_HANDLE){
      Alert(mcs_log_filename, " cannot be opened. The error code = ", GetLastError());
      ExpertRemove();
   }
   FileWrite(ms_lfh, "Date", "Time", "Comment", "PackIndex", "OrderSymbol", "OrderOpenPrice", "OrderComment", "OrderMagicNumber", 
                  "OrderTicketNumber", "PackID", "PackProfitPips", "PackTargetProfitPips");   

   ms_alfh = FileOpen(mcs_log_actions_filename, FILE_WRITE | FILE_TXT);
   if (ms_alfh == INVALID_HANDLE){
      Alert(mcs_log_actions_filename, " cannot be opened. The error code = ", GetLastError());
      ExpertRemove();
   }
   FileWrite(ms_alfh, "Here we go!\n");
   
   Run();
   Log("FirstOrganization");
   //t_Log();
}

void Reorganizer::Stop(void)
{
   if(ms_lfh != INVALID_HANDLE)   FileClose(ms_lfh);
   if(ms_alfh != INVALID_HANDLE)   FileClose(ms_alfh);
}

// ------------------------------------------ GLOBAL FUNCTIONS AND VARIABLES ------------------------------------------------- //

Reorganizer reorg_engine;  ///< Reorganizer object

// ------------------------------------------------- EXPERT FUNCTIONS ----------------------------------------------- //

/*! Expert initialization function */   
int OnInit()
{
   reorg_engine.Init();   
   return(INIT_SUCCEEDED);
}

/*! Expert deinitialization function */                           
void OnDeinit(const int reason)
{
   reorg_engine.Stop();
}

/*! Expert tick function */                                          
void OnTick()
{
  reorg_engine.Run();
}