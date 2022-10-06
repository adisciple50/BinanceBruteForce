require 'binance'
require 'parallel'

RESULTING_CURRENCY = 'GBP'
RESULTING_CURRENCY_REGEX = /GBP$/
BLACKLIST = ["SHIBBTC","BTCSHIB","SHIBGBP","WBTCETH",'SSVETH',"CRVETH"]

# put your api key and secret in these Environmental variables on your system
binance = Binance::Client::REST.new(api_key:ENV['binance-scout-key'],secret_key:ENV['binance-scout-secret'])

ORDER_BOOK = binance.book_ticker.delete_if(){|pair| BLACKLIST.include?(pair["symbol"])}
RESULTING_CURRENCY_ORDERS = ORDER_BOOK.select(){|order| order['symbol'].match? RESULTING_CURRENCY_REGEX}

def resulting_currency_pairs
  Parallel.map(RESULTING_CURRENCY_ORDERS,in_threads:RESULTING_CURRENCY_ORDERS.length) do |pair|
    pair['symbol']
  end
end

def remove_resulting_currency(order)
  order['symbol'].delete_prefix(RESULTING_CURRENCY).delete_suffix(RESULTING_CURRENCY)
end

RESULTING_CURRENCY_PAIRS = Parallel.map(RESULTING_CURRENCY_ORDERS,in_threads:RESULTING_CURRENCY_ORDERS.length) do |order|
  # remove resulting currency from orders
  remove_resulting_currency order
end

TRADE1_SET = RESULTING_CURRENCY_ORDERS

TRADE2_SET = Parallel.map(RESULTING_CURRENCY_ORDERS,in_threads:RESULTING_CURRENCY_ORDERS.length) do |order|
  # trade1 is order
  search = remove_resulting_currency(order)
  {order => ORDER_BOOK.select(){|trade| trade['symbol'].include? search }}
end

def get_matching(trade,order_set,resulting_currency_pairs)
  resulting_currency_pairs.map do |pair|
    if trade['symbol'].include? pair
      order_set.select{|order| order['symbol'] == "#{pair}#{RESULTING_CURRENCY}"}
    end
  end
end

TRADE3_SET = RESULTING_CURRENCY_ORDERS

def calculate_result(trade1, trade2, trade3)
  product = trade1['askPrice'].to_f * trade2['askPrice'].to_f * trade3['askPrice'].to_f
  product = product / trade1['askPrice'].to_f
  product - trade1['askPrice'].to_f
end

results = Parallel.map(TRADE2_SET,in_threads:TRADE2_SET.length) do |trade|
    trade.values.map do |trade2set|
      trade2set.map do |trade2|
        begin
        trade_one_and_three = get_matching(trade2,RESULTING_CURRENCY_ORDERS,RESULTING_CURRENCY_PAIRS).compact
        trade1 = trade_one_and_three[1][0]
        trade3 = trade_one_and_three[0][0]

        {:trade1 => trade1['symbol'],:trade2 => trade2['symbol'],:trade3 => trade3['symbol'],:ask1 => trade1['askPrice'],:ask2 => trade2['askPrice'],:ask3 => trade3['askPrice'],:result => calculate_result(trade1, trade2, trade3) }
        rescue
          nil
        end
      end
    end
  end

results = results.flatten(3).compact.select(){|chain| chain[:result].is_a?(Float) && !chain[:result].nan? }
results = results.sort_by(){|result| result[:result]}
results = results.uniq
# result is the profit of 1 resulting currency in, displayed in resulting currency out
puts results
