/*!\file PackReorganizer.mq4
*/
//+------------------------------------------------------------------+
//|                                              PackReorganizer.mq4 |
//|                                Copyright 2015, MQL Project Group |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Necati Ergin & Ozkan Cicek"
#property link      ""
#property version   "1.0.0.0"
#property strict

#define  MAX_ORDERS_IN_A_PACK 4
#define  MAX_NUM_TRIALS 3
#define  PACK_VEC_SIZE 512
#define  NUM_VALID_PARITIES 28

extern int ex_magic_no = 11111;  ///< Magic number of target orders
extern double ex_tp1 = 10.0;          ///< Take profit 1
extern double ex_tp2 = 20.0;          ///< Take profit 2
extern double ex_tp3 = 30.0;          ///< Take profit 3
extern double ex_lot = 1.0;           ///< Amount of order to open

/*! Pack class; represents a package */
class Pack{
   int m_tickets [MAX_ORDERS_IN_A_PACK] ;  ///< An array to hold ticket number of orders of the package
   string m_symbols [MAX_ORDERS_IN_A_PACK] ;   ///< An array to hold symbols of orders of the package
   int m_num_orders ;           ///< Number of orders in the package
   double m_total_profit_pip; ///< Total profit of the pack in pips
   double m_target_profit_pip; ///< Target profit of the pack in pips
   int m_id;                 ///< unique id of the pack
   double GetOrderTarget(void);
public:
   /*!Default constructor*/
   Pack(): m_num_orders(0), m_total_profit_pip(0.0), m_target_profit_pip(0.0), m_id(0){}
   bool IsInsertable(int);
   /*!\return Number of positions*/
   int Size(){return m_num_orders;}
   int Add(int);
   void Display(void);
   bool ClosePack(void);
   double GetProfit(void);  
   double GetTargetProfit(void); 
   /*!\return Indexed order's ticket number*/
   int GetTicket(int index){return m_tickets[index];}
   bool ShouldBeClosed(void);
   int GetId(void){return m_id;}
};

/*!\return The target profit pips of the order */
double Pack::GetOrderTarget(void)
{
   double target = 0;
   int tp;
   tp = (int)StringToInteger(StringSubstr(OrderComment(), 0, 1));
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
bool Pack::IsInsertable(int ticket){
  
   if(m_num_orders == MAX_ORDERS_IN_A_PACK)
      return false;
   if(m_num_orders == 0)
      return true;

   if(!(OrderSelect(ticket, SELECT_BY_TICKET)==true)){
      Print("Order Secilemedi , Hata Kodu :  ",GetLastError());
      return false;
   }
   string newSymbol = OrderSymbol();
   
   for(int i = 0; i < m_num_orders ; ++i){
      if(StringSubstr(newSymbol,0,3) == StringSubstr(m_symbols[i],0,3) || StringSubstr(newSymbol,0,3) == StringSubstr(m_symbols[i],3,3) ||
         StringSubstr(newSymbol,3,3) == StringSubstr(m_symbols[i],0,3) || StringSubstr(newSymbol,3,3) == StringSubstr(m_symbols[i],3,3))
         return false;  
   }
   return true;  
}

/*!Adds given position to the pack
   \param cTicket Ticket number
   \return If successful: number of positions; otherwise -1
*/
int Pack::Add(int ticket){

   if(!(OrderSelect(ticket, SELECT_BY_TICKET)==true)){
      Print("Order Secilemedi , Hata Kodu :  ",GetLastError());
      return -1;
   }
   //int lastArraySize = ArraySize(m_tickets);
   //ArrayResize(m_tickets, lastArraySize + 1);
   //ArrayResize(m_symbols, lastArraySize + 1);   // they should always have same size!
   m_tickets[m_num_orders] = ticket;      
   m_symbols[m_num_orders] = OrderSymbol();
   m_num_orders++;
   m_total_profit_pip = GetProfit();
   m_target_profit_pip = GetTargetProfit();
   m_id += OrderTicket();
   //return lastArraySize + 1;
   return m_num_orders;
}

/*!Display the package*/
void Pack::Display(void){

   for(int i =0 ; i < ArraySize(m_symbols);++i )
   Print(m_symbols[i]);
}

/*!Close all the positions in the package
   \return True if success; false otherwise
*/
bool Pack::ClosePack(void)
{
   //if (LOG_ACTIONS)  FileWrite(alfh, "************Pack::ClosePack called*********************");
   for(int i = m_num_orders-1; i >=0 ; --i){
      int ticket = m_tickets[i];
   	if (!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(ticket, " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return false;
	   }
	   int optype = OrderType();
	   //if (LOG_ACTIONS)  FileWrite(alfh, "Ticket#: ", ticket, optype==OP_BUY?", Buy":(optype==OP_SELL?", Sell":", Other optype"));
	   int k = 0;
	   double close_price = -99.0;
	   for (k = 0; k < MAX_NUM_TRIALS; ++k) {
   		if (optype == OP_BUY)
   			close_price = MarketInfo(m_symbols[i], MODE_BID);
   		else
   			close_price = MarketInfo(m_symbols[i], MODE_ASK);
   		//if (LOG_ACTIONS)  FileWrite(alfh, "Order lots: ", OrderLots(), ", Close price: ", close_price);
   		if (OrderClose(ticket, OrderLots(), close_price, 10))
   			break;
   		RefreshRates();
	   }// end for trial
      if (k == MAX_NUM_TRIALS) {
         Alert(ticket, " No'lu emir kapatilamadi. Close price: ", close_price, ".... Hata kodu : ", GetLastError());
         return false;
      }
   }// end for m_num_orders
      
   m_target_profit_pip = 0; // update these variables (doubt we will need a closed pack's variables; just do it to be safe)
   m_total_profit_pip = 0;
   m_num_orders = 0;
   return true;
}

/*!\return Total profit pips of the package */ 
double Pack::GetProfit(void)
{
   double total = 0.;
   for (int i=0; i < m_num_orders; ++i){
      if (!OrderSelect(m_tickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(m_tickets[i], " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return -1;
	   }
	   total += NormalizeDouble(OrderProfit(), Digits);
   }//end for - traverse orders
   return total;
}

/*!\return The target profit pips of the package */
double Pack::GetTargetProfit(void)
{
   int tp = -1;
   double total = 0;
   for (int i=0; i < m_num_orders; ++i){
      if (!OrderSelect(m_tickets[i], SELECT_BY_TICKET, MODE_TRADES)) {
		   Alert(m_tickets[i], " No'lu emir secilemedi... Hata kodu : ", GetLastError());
		   return -1;
	   }
      total += GetOrderTarget();
   }//end for - traverse orders
   return total;
}

/*!   \return True if the sum of the profits of orders in the package is equal to or greater than the target. False otherwise */ 
bool Pack::ShouldBeClosed(void)
{
   return (GetProfit() >= GetTargetProfit()) || (GetProfit() <= (-3)*(GetTargetProfit()));
}

// ------------------------------------------- PACK VECTOR CLASS --------------------------------------------------------- //
/*! Represents a pack vector */
class PackVector {
   Pack *m_packs[PACK_VEC_SIZE];    ///< An array of Packs
   int m_num_packs;      ///< Number of packs in the vector
   int m_total_orders;  ///< Number of total orders in the pack vector
public:
   /*! Default constructor. Initializes the vector with 0 Packs*/
   PackVector() : m_num_packs(0) {}
   bool PackVector::push_back(Pack *value);
   Pack *operator[](int index);
   bool Remove(int index);
   /*!\return Number of packages inside the vector*/
   int Size(void){return m_num_packs;}
   int GetNumTotalOrders(void);
   bool HasOrder(int);
   void Sort(void);
};

/*! Mmics C++ vector<> push_back method. Places given pack 
   to the vector. 
   \param value Package pointer
   \return True if success; false if memory allocation and array resize fails
*/
bool PackVector::push_back(Pack *value)
{
   if(m_num_packs == PACK_VEC_SIZE)  return false;
   else m_packs[m_num_packs++] = value;   
   return true;
}

/*! 
   \param index Index of the package in the vector
   \return Selected pack's pointer   
*/
Pack *PackVector::operator[](int index)
{
   return m_packs[index];
}

/*!Close all orders in indexed package, remove it from the vector, shrink package and update size
   \param index Index of the package in the vector
   \return true if successful, false otherwise.
*/
bool PackVector::Remove(int index)
{
   //if (LOG_ACTIONS)  {
   //   FileWrite(alfh, "*********PackVector::Remove called************");
   //   FileWrite(alfh, "Vector size before closing the pack: ", ArraySize(m_pack));
   //} 
    
   if(!m_packs[index].ClosePack()) return false; 
   Sort();     // closed pack will be shifted to the end of the array. No chance that there will be 2 packs with 0 elements
   --m_num_packs; 
   //if (ArrayResize(m_pack, m_num_packs) == -1) return false; // delete 
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
      total += m_packs[i].Size();
   }//end for - traverse packs in the pack vector
   return total;
}

/*!\param ticket: Ticket number of the order
   \return True if the order with given ticket number is in the pack vector; false otherwise
*/
bool PackVector::HasOrder(int ticket)
{
   for (int i = 0; i < m_num_packs; i++){
      for (int j = 0; j < m_packs[i].Size(); j++){
         if (m_packs[i].GetTicket(j) == ticket)  return true;
      }//end for - pack
   }//end for - pack vector
   return false;
}

/*!Sort packs in descending direction. Inserting sort algorithm is selected since it is adaptive. Any other ideas? */
void PackVector::Sort(void)
{ 
   Pack *current = new Pack;
   for (int i = 1; i < m_num_packs; i++){
      int j = i;
      current = m_packs[i];
      while ( (j > 0) && (m_packs[j-1].Size() < current.Size())){
         m_packs[j] = m_packs[j-1];
         --j;
      }//end while
      m_packs[j] = current;              
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
   double m_parity_lots[NUM_VALID_PARITIES]; ///< Lots of other parities with the same USD lot amount 
   double m_time_ms;
   double m_total_profit;
   MqlDateTime m_start_date;
   int  m_order_open_method; ///< How to open new orders? 0=Random? 1=Necati
   bool m_order_opened_directions[2*NUM_VALID_PARITIES]; ///< First index is sell, second index is buy for each order in mcs_valid_parities array  
   bool IsValidParity(string parity);
   bool IsValidComment(string comment);
   bool IsValidMagic(void);
   void Log(string comment_log);
   int GetNumValidOrders(); 
   void Organize(void);
   void FindParityLots(double target_usd_lot);
   int TimeToOpenNewOrders(void);
   int OpenRandomOrders(void);
   int OpenOrdersNecatiMethod(void);
public:
   Reorganizer():m_total_profit(0), m_order_open_method(1){
     m_time_ms = TimeLocal();
     int i;
     for(i = 0; i < (2*NUM_VALID_PARITIES); i++)
       m_order_opened_directions[i] = false;  
   }
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
   int first_num = (int)StringToInteger(StringSubstr(comment, 0, 1));
   if (first_num != 1 && first_num != 2 && first_num != 3)  return false;
   int magic_num = (int)StringToInteger(StringSubstr(comment, 2));
   if ( magic_num < 0 || magic_num > 99999) return false;
   return true;
}

/*! Check magic number format. The order must be selected before calling this function 
   \return True if magic number in the comment matches the order magic number; false otherwise
*/
bool Reorganizer::IsValidMagic(void)
{ 
   int magic_comment = (int)StringToInteger(StringSubstr(OrderComment(), 2));    
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
   
   for (int i = 0; i < m_pvec.Size(); i++){
      for (int j = 0; j < m_pvec[i].Size(); j++){ 
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
         pack_target = DoubleToString(m_pvec[i].GetTargetProfit());
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
      if (m_pvec.HasOrder(OrderTicket())) continue; // order is already in a pack
      int i;
      m_pvec.Sort();
      for(i = 0; i < m_pvec.Size(); i++){         
         if (m_pvec[i].IsInsertable(OrderTicket())){             
            m_pvec[i].Add(OrderTicket());
            break;
         }
      }//end for - traverse orders in the pack   
      if (i==m_pvec.Size()) {
         m_pvec.push_back(new Pack);
         m_pvec[i].Add(OrderTicket());
      }
   }// end for - traverse all orders 
   m_pvec.Sort(); // sort at the end again
}

/*! Calculate the lot amount of other parities other than USD that is equivalent to the same USD lot */
void Reorganizer::FindParityLots(double target_usd_lot)
{
   for(int i = 0; i < NUM_VALID_PARITIES; i++){
      if(i < 5)
         m_parity_lots[i] = target_usd_lot / NormalizeDouble(MarketInfo("AUDUSD", MODE_ASK), 2);      
      else if(i < 7)
         m_parity_lots[i] = target_usd_lot / NormalizeDouble(MarketInfo("USDCAD", MODE_ASK), 2);      
      else if(i < 8)
         m_parity_lots[i] = target_usd_lot / NormalizeDouble(MarketInfo("USDCHF", MODE_ASK), 2);       
      else if(i < 15)
         m_parity_lots[i] = target_usd_lot / NormalizeDouble(MarketInfo("EURUSD", MODE_ASK), 2);         
      else if(i < 21)
         m_parity_lots[i] = target_usd_lot / NormalizeDouble(MarketInfo("GBPUSD", MODE_ASK), 2);         
      else if(i < 25)
         m_parity_lots[i] = target_usd_lot / NormalizeDouble(MarketInfo("NZDUSD", MODE_ASK), 2);         
      else 
         m_parity_lots[i] = target_usd_lot;
   }
}

/*! \return True if pre-determined time has elapsed to open new orders */
int Reorganizer::TimeToOpenNewOrders(void)
{
   double interval_ms = 30; // open new orders in every interval_ms 
   double current_time_ms = TimeLocal();
   int is_it = 0;
    
   if((current_time_ms - m_time_ms) > interval_ms){
      m_time_ms = current_time_ms;
      is_it = 1;
   }
   return is_it;
}

/*! Open random orders for each comment
  \return 0: success, -1: fail
*/
int Reorganizer::OpenRandomOrders(void)
{
   int ticket = -1;
   int k = 0;
   int max_num_trials = 5; 
   int num_orders_to_open = 1; 
   string comment;
   int i_comment;
   
   FindParityLots(ex_lot);     
   
   for(int i=0; i < num_orders_to_open; i++){      
      for(i_comment = 1; i_comment <= 3; i_comment++){
        comment = StringConcatenate(IntegerToString(i_comment), "_", IntegerToString(ex_magic_no));
        int rand_index = MathRand() % NUM_VALID_PARITIES;
        string sym = mcs_valid_parities[rand_index];
        double lot_to_open = m_parity_lots[rand_index];
        int buy = MathRand()%2;
        for (k = 0; k < max_num_trials; k++){
           ticket = OrderSend(sym, buy, lot_to_open, MarketInfo(sym, buy?MODE_BID:MODE_ASK), 10, 0, 0, comment, ex_magic_no);
           if (ticket != -1) break;
        }//end max trials
        if (k == max_num_trials)  return -1;
      }//end i_comment     
   }//end for
   
   return 0; 
}

int Reorganizer::OpenOrdersNecatiMethod(void)
{
  int i;
  string comment;
  int i_comment;
  int ticket = -1;
  int i_try = 0, num_max_trials = 5;
   
  FindParityLots(ex_lot);
  
  for(i = 0; i < NUM_VALID_PARITIES; i++){
    i_comment = MathRand()%3 + 1;
    comment = StringConcatenate(IntegerToString(i_comment), "_", IntegerToString(ex_magic_no));
    
    double lot_to_open = m_parity_lots[i];
    if(lot_to_open < 0.1) lot_to_open = 0.1; // the minimum amount of lot is 0.1
    string sym = mcs_valid_parities[i];
    
    if(m_order_opened_directions[2*i] == false){
      for(i_try = 0; i_try < num_max_trials; i_try++){
        ticket = OrderSend(sym, OP_SELL, lot_to_open, MarketInfo(sym, MODE_BID), 10, 0, 0, comment, ex_magic_no);
        if (ticket != -1) break;
      }//end max trials
      if(i_try < num_max_trials){
        m_order_opened_directions[2*i] = true;
      }else{
        FileWrite(ms_alfh, "\nCannot open sell order for ", sym, " parity. The amount of the lot = ", lot_to_open);
      }
    }//end if sell
    
    if(m_order_opened_directions[2*i+1] == false){
      for(i_try = 0; i_try < num_max_trials; i_try++){
        ticket = OrderSend(sym, OP_BUY, lot_to_open, MarketInfo(sym, MODE_ASK), 10, 0, 0, comment, ex_magic_no);
        if (ticket != -1) break;
      }//end max trials
      if(i_try < num_max_trials){
        m_order_opened_directions[2*i+1] = true;
      }else{
        FileWrite(ms_alfh, "\nCannot open buy order for ", sym, " parity. The amount of the lot = ", lot_to_open);
      }  
    }//end if buy
       
  }//end for NUM_VALID_PARITIES
  
  return 0;
}

void Reorganizer::Run(void)
{
   int total_valid_orders = -1;
   int total_orders_in_vec = -1;
   int num_min_orders = 10;
   static int i_attemp = 0;
   int num_max_attemp = 10;
   total_valid_orders = GetNumValidOrders();
   total_orders_in_vec = m_pvec.GetNumTotalOrders();
   
   if (total_valid_orders > total_orders_in_vec){    // a new order 
      Log("BeforeNewOrder");
      FileWrite(ms_alfh, "\nNew Order! Num Valid Orders = ", total_valid_orders, " Num orders in pack vector = ", total_orders_in_vec, "\n");
      Organize(); 
      Log("AfterNewOrder");       
   }else{
      //if (LOG_ACTIONS)  FileWrite(alfh, "Num Valid Orders = ", total_valid_orders, " Num orders in pack vector = ", total_orders_in_vec);
   }
   
   int i = 0;
   while (i < m_pvec.Size()){
      if (m_pvec[i].ShouldBeClosed()){
         Log("BeforePackClose");
         if(m_pvec.Remove(i)){
           // pack removed successfully            
           m_total_profit += m_pvec[i].GetProfit();
           FileWrite(ms_alfh,"Close Pack", i, ". Pack id = ", m_pvec[i].GetId());
           Log("AfterPackClose");
           i_attemp = 0;
         }else{
           // couldn't remove pack. Run method will try to remove it again
           FileWrite(ms_alfh,"Try closing pack", i, " for the ", i_attemp, "th time. Pack id = ", m_pvec[i].GetId());
           ++i_attemp; 
           if(i_attemp == num_max_attemp){
             // to avoid infinite loop try num_max_attemp times
             // move to next order. The Run method will try again in the next tick
             ++i;
           }
         }         
      }else{
         ++i;
      }//end if ShouldBeClosed
   }//end while
      
   if(TimeToOpenNewOrders()){
      FileWrite(ms_alfh,"Open new orders");
      if(m_order_open_method == 0){
        // open random orders
        OpenRandomOrders();
      }else if(m_order_open_method == 1){
        // open orders in short and long
        OpenOrdersNecatiMethod();
      }//end if m_order_open_method
   }//end open random orders   
}

void Reorganizer::Init(void)
{
   TimeToStruct(TimeCurrent(), m_start_date);   
   
   ms_lfh = FileOpen(mcs_log_filename, FILE_WRITE | FILE_CSV); 
   if (ms_lfh == INVALID_HANDLE){
      Alert(mcs_log_filename, " cannot be opened. The error code = ", GetLastError());
      ExpertRemove();
   }
   FileWrite(ms_lfh, "Date", "Time", "Comment", "PackIndex", "OrderSymbol", "OrderOpenPrice", "OrderComment", "OrderMagicNumber", 
                  "OrderTicketNumber", "PackID", "PackProfit", "PackTargetProfit");   

   ms_alfh = FileOpen(mcs_log_actions_filename, FILE_WRITE | FILE_TXT);
   if (ms_alfh == INVALID_HANDLE){
      Alert(mcs_log_actions_filename, " cannot be opened. The error code = ", GetLastError());
      ExpertRemove();
   }
   FileWrite(ms_alfh, "Here we go!\n");
   
   Organize();
   Log("FirstOrganization");
   //t_Log();
}

void Reorganizer::Stop(void)
{
   MqlDateTime end_date;
   TimeToStruct(TimeCurrent(), end_date);
   
   FileWrite(ms_alfh, "Total profit between " + IntegerToString(m_start_date.day) + "/" + IntegerToString(m_start_date.mon) + 
            "/" + IntegerToString(m_start_date.year) + " " + IntegerToString(m_start_date.hour) + ":" + 
            IntegerToString(m_start_date.min) + ":" + IntegerToString(m_start_date.sec) + " and " + 
            IntegerToString(end_date.day) + "/" + IntegerToString(end_date.mon) + 
            "/" + IntegerToString(end_date.year) + " " + IntegerToString(end_date.hour) + ":" + 
            IntegerToString(end_date.min) + ":" + IntegerToString(end_date.sec) + " = " + DoubleToString(m_total_profit));             
   
  FileClose(ms_lfh);
  FileClose(ms_alfh);
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