//+------------------------------------------------------------------+
//|  NAS100_AI_EA.mq4                                                |
//|  AI自動売買システム - MT4 Expert Advisor                          |
//|                                                                  |
//|  動作概要:                                                        |
//|    - 15分ごとに Rails API (GET /api/v1/signal) をポーリング       |
//|    - action=buy/sell のとき新規エントリー                         |
//|    - action=hold のとき何もしない                                 |
//|    - ポジションは1つのみ保持（既存ポジションがあれば新規エントリーしない）|
//|                                                                  |
//|  セットアップ:                                                    |
//|    1. MT4 → ツール → オプション → エキスパートアドバイザー         |
//|       「WebRequestを許可するURLリスト」に以下を追加:              |
//|       http://133.167.124.112:3000                                |
//|    2. EA をチャートにアタッチ                                     |
//|    3. 自動売買を有効化                                            |
//+------------------------------------------------------------------+

#property copyright "NAS100 AI Trading System"
#property version   "1.00"
#property strict

//--- 入力パラメータ
input string   ApiUrl       = "http://133.167.124.112:3000/api/v1/signal";
input double   LotSize      = 0.01;    // 取引ロット数（デモ口座用最小ロット）
input int      MagicNumber  = 20260331; // EA識別番号
input int      Slippage     = 3;        // 許容スリッページ（pips）
input int      PollMinutes  = 15;       // APIポーリング間隔（分）
input bool     EnableTrading = true;    // 取引有効フラグ（false=シグナル確認のみ）

//--- グローバル変数
datetime lastPollTime = 0;

//+------------------------------------------------------------------+
//| EA初期化                                                          |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("[AI-EA] 初期化完了 | MagicNumber:", MagicNumber, " | Lot:", LotSize);
   Print("[AI-EA] API URL:", ApiUrl);
   Print("[AI-EA] ポーリング間隔:", PollMinutes, "分");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| ティックごとに呼ばれるメイン処理                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   // ポーリング間隔チェック（PollMinutes 分ごとにAPIを叩く）
   if(TimeCurrent() - lastPollTime < PollMinutes * 60)
      return;

   lastPollTime = TimeCurrent();

   // APIからシグナル取得
   string signal = FetchSignal();
   if(signal == "")
   {
      Print("[AI-EA] シグナル取得失敗");
      return;
   }

   // レスポンスをパース
   string action    = ParseJsonString(signal, "action");
   double lot       = ParseJsonDouble(signal, "lot");
   int    sl_pips   = (int)ParseJsonDouble(signal, "sl");
   int    tp_pips   = (int)ParseJsonDouble(signal, "tp");
   string comment   = ParseJsonString(signal, "comment");
   double score     = ParseJsonDouble(signal, "score");

   Print("[AI-EA] シグナル受信 | action:", action, " | score:", score,
         " | SL:", sl_pips, "pips | TP:", tp_pips, "pips");

   if(!EnableTrading)
   {
      Print("[AI-EA] 取引無効（EnableTrading=false）シグナルのみ確認: ", action);
      return;
   }

   if(action == "buy")
      ExecuteBuy(lot > 0 ? lot : LotSize, sl_pips, tp_pips, comment);
   else if(action == "sell")
      ExecuteSell(lot > 0 ? lot : LotSize, sl_pips, tp_pips, comment);
   // hold の場合は何もしない
}

//+------------------------------------------------------------------+
//| Rails API からシグナルを取得                                       |
//+------------------------------------------------------------------+
string FetchSignal()
{
   char   post[];
   char   result[];
   string headers;
   int    timeout = 5000;

   int res = WebRequest("GET", ApiUrl, "", "", timeout, post, 0, result, headers);

   if(res == -1)
   {
      Print("[AI-EA] WebRequest エラー: ", GetLastError(),
            " - MT4設定でURLを許可しているか確認してください");
      return("");
   }

   return(CharArrayToString(result));
}

//+------------------------------------------------------------------+
//| 買いエントリー                                                     |
//+------------------------------------------------------------------+
void ExecuteBuy(double lot, int sl_pips, int tp_pips, string comment)
{
   if(HasOpenPosition())
   {
      Print("[AI-EA] 既存ポジションあり - 新規買いエントリーをスキップ");
      return;
   }

   double ask = MarketInfo(Symbol(), MODE_ASK);
   double sl  = sl_pips  > 0 ? ask - sl_pips  * Point * 10 : 0;
   double tp  = tp_pips  > 0 ? ask + tp_pips  * Point * 10 : 0;

   int ticket = OrderSend(Symbol(), OP_BUY, lot, ask, Slippage,
                          sl, tp, comment, MagicNumber, 0, clrGreen);

   if(ticket > 0)
      Print("[AI-EA] 買いエントリー成功 | チケット:", ticket, " | 価格:", ask,
            " | SL:", sl, " | TP:", tp);
   else
      Print("[AI-EA] 買いエントリー失敗 | エラー:", GetLastError());
}

//+------------------------------------------------------------------+
//| 売りエントリー                                                     |
//+------------------------------------------------------------------+
void ExecuteSell(double lot, int sl_pips, int tp_pips, string comment)
{
   if(HasOpenPosition())
   {
      Print("[AI-EA] 既存ポジションあり - 新規売りエントリーをスキップ");
      return;
   }

   double bid = MarketInfo(Symbol(), MODE_BID);
   double sl  = sl_pips > 0 ? bid + sl_pips * Point * 10 : 0;
   double tp  = tp_pips > 0 ? bid - tp_pips * Point * 10 : 0;

   int ticket = OrderSend(Symbol(), OP_SELL, lot, bid, Slippage,
                          sl, tp, comment, MagicNumber, 0, clrRed);

   if(ticket > 0)
      Print("[AI-EA] 売りエントリー成功 | チケット:", ticket, " | 価格:", bid,
            " | SL:", sl, " | TP:", tp);
   else
      Print("[AI-EA] 売りエントリー失敗 | エラー:", GetLastError());
}

//+------------------------------------------------------------------+
//| この EA が管理するポジションが既に存在するか確認                    |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            return(true);
      }
   }
   return(false);
}

//+------------------------------------------------------------------+
//| JSON文字列から string 値を取得する簡易パーサー                     |
//| 例: {"action":"buy"} → ParseJsonString(json, "action") → "buy"   |
//+------------------------------------------------------------------+
string ParseJsonString(string json, string key)
{
   string search = "\"" + key + "\":\"";
   int    start  = StringFind(json, search);
   if(start == -1) return("");

   start += StringLen(search);
   int end = StringFind(json, "\"", start);
   if(end == -1) return("");

   return(StringSubstr(json, start, end - start));
}

//+------------------------------------------------------------------+
//| JSON文字列から double 値を取得する簡易パーサー                     |
//| 例: {"lot":0.01} → ParseJsonDouble(json, "lot") → 0.01           |
//+------------------------------------------------------------------+
double ParseJsonDouble(string json, string key)
{
   string search = "\"" + key + "\":";
   int    start  = StringFind(json, search);
   if(start == -1) return(0);

   start += StringLen(search);

   // 文字列値（"..."）は除外
   if(StringGetChar(json, start) == '"') return(0);

   string numStr = "";
   for(int i = start; i < StringLen(json); i++)
   {
      ushort c = StringGetChar(json, i);
      if(c == ',' || c == '}' || c == ' ') break;
      numStr += ShortToString(c);
   }

   return(StringToDouble(numStr));
}
