require 'binance'
require 'parallel'

RESULTING_CURRENCY = 'GBP'
RESULTING_CURRENCY_REGEX = /GBP$/
BLACKLIST = ["SHIBBTC","BTCSHIB","SHIBGBP"]

# put your api key and secret in these Environmental variables on your system
binance = Binance::Client::REST.new(api_key:ENV['binance-scout-key'],secret_key:ENV['binance-scout-secret'])

ORDER_BOOK = binance.book_ticker.delete_if(){|pair| BLACKLIST.include?(pair["symbol"])}
RESULTING_CURRENCY_ORDERS = ORDER_BOOK.select(){|order| order['symbol'].match? RESULTING_CURRENCY_REGEX}

def resulting_currency_pairs
  Parallel.map(RESULTING_CURRENCY_ORDERS,in_threads:RESULTING_CURRENCY_ORDERS.length) do |pair|
    pair['symbol']
  end
end

RESULTING_CURRENCY_PAIRS = resulting_currency_pairs

def sorted_orders(resulting_currency_orders)
  result = resulting_currency_orders.sort_by(){|order| order['askPrice'].to_f <=> order['askPrice'].to_f}
  return result
end

def highest_value(order_set)
  order_set[-1]
end

def cheapest_pair(order_set)
  order_set[0]
end

RESULTING_CURRENCY_SORTED_ORDERS = sorted_orders(RESULTING_CURRENCY_ORDERS)

TRADE1_SET = cheapest_pair RESULTING_CURRENCY_SORTED_ORDERS



TRADE2_SET = Parallel.map(RESULTING_CURRENCY_ORDERS,in_threads:RESULTING_CURRENCY_ORDERS.length) do |order|
  # trade1 is order
  search = order['symbol'].delete_prefix(RESULTING_CURRENCY).delete_suffix(RESULTING_CURRENCY)
  {order => ORDER_BOOK.select(){|trade| trade['symbol'].include? search }}
end
# see if any coin list
def search_for_partial_matches(symbol,coin_list)
  begin
    check = coin_list.map(){|coin| symbol.include? coin}
  rescue
  end

  check.any? if check
end

TRADE3_SET = TRADE2_SET.map do |trade|
  Parallel.map(trade,in_threads:trade.values.length) do |orders|
    result = orders.map do |order|
        if order
          puts "new order"
          puts order
          if order.is_a? Array
            order.map do |item|
              # puts "new item"
              # puts item
              trade if search_for_partial_matches(item['symbol'],RESULTING_CURRENCY_PAIRS)
            end
          elsif order.is_a? Hash
            # puts "new item"
            # puts "order length is 1"
            # puts order
            trade if search_for_partial_matches(order['symbol'],RESULTING_CURRENCY_PAIRS)
          end
        end
      end
    result.compact.flatten(0)
  end
end

puts TRADE3_SET
