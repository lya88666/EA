//+------------------------------------------------------------------+
//|                                                    TopBottom.mq4 |
//|                                                    4H EUR/USD    |
//|                                       Copyright © 2012, Luo Yang |
//|                                        http://www.metaquotes.net |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2012, Luo Yang"
#property link      "http://www.metaquotes.net"

double lot = 0.01;
int slippage = 5;
int graphPeriod = PERIOD_H1;
int frames = 20;
int margin1 = 100;
int margin2 = 400;
int stopLoss = 750;
int takeProfit = 1500;
int TrailingStop = 0;
int timeToExpire = 10800;//3600 * 24;
double MACDOpenLevel=10;//3
double MACDCloseLevel=2;
double MATrendPeriod=18;

int MaxOrders = 1;

double MacdCurrent;
double MacdPrevious;
double SignalCurrent;
double SignalPrevious;
double MaCurrent;
double MaPrevious;

int direction;
datetime currentTime = 0;
datetime lastCloseTime;
//+------------------------------------------------------------------+
//| expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
{
//----
   MathSrand(TimeLocal());
//----
	return(0);
}
//+------------------------------------------------------------------+
//| expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
{
//----

//----
	return(0);
}

void RefreshMACD()
{
	MacdCurrent = iMACD(NULL,graphPeriod,12,26,9,PRICE_CLOSE,MODE_MAIN,0);
	MacdPrevious = iMACD(NULL,graphPeriod,12,26,9,PRICE_CLOSE,MODE_MAIN,1);
	SignalCurrent = iMACD(NULL,graphPeriod,12,26,9,PRICE_CLOSE,MODE_SIGNAL,0);
	SignalPrevious = iMACD(NULL,graphPeriod,12,26,9,PRICE_CLOSE,MODE_SIGNAL,1);
	MaCurrent = iMA(NULL,graphPeriod,MATrendPeriod,0,MODE_EMA,PRICE_CLOSE,0);
	MaPrevious = iMA(NULL,graphPeriod,MATrendPeriod,0,MODE_EMA,PRICE_CLOSE,1);
}

//1 - long, -1 - short
int MACDTrend()
{
	static double diff = 0;
	
	if(!IsNewBar())
		return (0);
		
	//Print("New bar! macd: " + MacdCurrent + ", signal: " + SignalCurrent + ", diff: " + (MacdCurrent - SignalCurrent));
	
	//for SELL orders
	if(direction == OP_SELL)
	{
		if( MacdCurrent > SignalCurrent)
			return (1);
			
		//if(diff < SignalCurrent - MacdCurrent)
		//{
		//	diff = SignalCurrent - MacdCurrent;
		//	return (0);
		//}
		//else
		//{
		//	diff = 0;
		//	return (1);
		//}
	}
	else
	{
		if( MacdCurrent < SignalCurrent)
		{
			//Print("Buy order trend changed: macdcurrent: " + MacdCurrent + ", SignalCurrent: " + SignalCurrent);
			return (-1);
		}
	
		//if(diff < MacdCurrent - SignalCurrent)
		//{
		//	diff = MacdCurrent - SignalCurrent;
		//	return (0);
		//}
		//else
		//{
		//	diff = 0;
		//	return (-1);
		//}
	}
	
	return (0);
}

int MACDSignal()
{
	//buy signal
	if(MacdCurrent<0 && MacdCurrent>SignalCurrent && MacdPrevious<SignalPrevious &&
         MathAbs(MacdCurrent)>(MACDOpenLevel*Point) && MaCurrent>MaPrevious)
    {
    	return (1);
    }
    
    //sell signal
    if(MacdCurrent>0 && MacdCurrent<SignalCurrent && MacdPrevious>SignalPrevious && 
         MacdCurrent>(MACDOpenLevel*Point) && MaCurrent<MaPrevious)
	{
		return (-1);
	}
	
	//no signal
	return (0);
}

int PlaceOrders(int signal)
{
	//lot = NormalizeDouble(0.01 * AccountBalance() / 100, 2);
		
	if(signal == 0)
		return (0);
	else if(signal == 1)
	{
		//buy signal
		//OrderSend(Symbol(), OP_BUY, lot, Ask, slippage, Ask - stopLoss * Point, Ask + takeProfit * Point, NULL, 3);
		OrderSend(Symbol(), OP_BUY, lot, Ask, slippage, 0, 0, NULL, 3);
		direction = OP_BUY;
	}
	else
	{
		//sell signal
		//OrderSend(Symbol(), OP_SELL, lot, Bid, slippage, Bid + stopLoss * Point, Bid - takeProfit * Point, NULL, 4);
		OrderSend(Symbol(), OP_SELL, lot, Bid, slippage, 0, 0, NULL, 4);
		direction = OP_SELL;
	}
	
}

int CloseOrder(int ticket, double size, double price)
{
	//return (0);
	OrderClose(ticket, size, price, slippage);
	lastCloseTime = TimeCurrent();
	
	return (0);
}

bool IsNewBar()
{
	if(TimeCurrent() == Time[0] && currentTime != Time[0])
	{
		currentTime = Time[0];
		return (true);
	}
	else
		return (false);
}

bool ShouldTrade()
{
	int highest = iHighest(NULL, graphPeriod, MODE_HIGH, frames, 0);
	double high = iHigh(NULL, graphPeriod, highest);
	int lowest = iLowest(NULL, graphPeriod, MODE_LOW, frames, 0);
	double low = iLow(NULL, graphPeriod, lowest);
	
	if(high - low < 500 * Point)
		return (false);
	
	return (true);	
}
//+------------------------------------------------------------------+
//| expert start function                                            |
//+------------------------------------------------------------------+
int start()
{
//----
	//see if we can trade now
	bool canTrade = IsTradeAllowed();
	
	if(!canTrade)
		return (0);
	
	//should it trade now?
	if(!ShouldTrade())
		return (0);	
	
	RefreshMACD();
	int signal = MACDSignal();
	int trend = MACDTrend();
	
	if(OrdersTotal() < MaxOrders)
	{
		//avoid frequent trading
		if(TimeCurrent() - lastCloseTime < 3600)
			return (0);
			
		PlaceOrders(signal);
	}
	else
	{
		//if we already have open order
		int total = OrdersTotal();
		for(int i = 0; i < total; i++)
		{
			//try to select order
			if(OrderSelect(i, SELECT_BY_POS) == false)
				continue;
			
			//if this is a pending order
			int orderType = OrderType();
			
			//Print("Trend: " + trend + ", op type: " + orderType + ", signal: " + signal);
			
			//order should be open for at least 60 minutes
			if(TimeCurrent() - OrderOpenTime() < 3600)
				continue;
			
			if(orderType == OP_BUY)
			{
				if(MacdCurrent>0 && MacdCurrent<SignalCurrent && MacdPrevious>SignalPrevious && MacdCurrent>(MACDCloseLevel*Point))
				{
					Print("Trend: " + trend + ", op type: " + orderType + ", signal: " + signal);
					CloseOrder(OrderTicket(), OrderLots(), Bid);
				}
				else if(trend < 0)
				{
					CloseOrder(OrderTicket(), OrderLots(), Bid);
				}
				else if(TrailingStop>0)  
          		{                 
           			if(Bid-OrderOpenPrice()>Point*TrailingStop)
             		{
              			if(OrderStopLoss()<Bid-Point*TrailingStop)
                		{
                 			OrderModify(OrderTicket(),OrderOpenPrice(),Bid-Point*TrailingStop,OrderTakeProfit()+Point*TrailingStop,0,Green);
                		}
             		}
          		}
			}
			else if(orderType == OP_SELL)
			{
				if(MacdCurrent<0 && MacdCurrent>SignalCurrent && MacdPrevious<SignalPrevious && MathAbs(MacdCurrent)>(MACDCloseLevel*Point))
				{
					CloseOrder(OrderTicket(), OrderLots(), Ask);
				}
				else if(trend > 0)
				{
					CloseOrder(OrderTicket(), OrderLots(), Ask);
				}
				else if(TrailingStop>0)  
              	{                 
               		if((OrderOpenPrice()-Ask)>(Point*TrailingStop))
                 	{
                  		if((OrderStopLoss()>(Ask+Point*TrailingStop)) || (OrderStopLoss()==0))
                    	{
                     		OrderModify(OrderTicket(),OrderOpenPrice(),Ask+Point*TrailingStop,OrderTakeProfit()-Point*TrailingStop,0,Red);
                    	}
                 	}
              	}
			}
		}
		
		//total = OrdersTotal();
		
		//if(total < MaxOrders)
		//{
		//	PlaceOrders();
		//}
	}
//----
	return(0);
}
//+------------------------------------------------------------------+