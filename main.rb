require 'binance'
require 'parallel'

RESULTING_CURRENCY = 'GBP'
RESULTING_CURRENCY_REGEX = /GBP$/
# BLACKLIST = ["SHIBBTC","BTCSHIB","SHIBGBP","WBTCETH",'SSVETH',"CRVETH"]
BLACKLIST = []

# put your api key and secret in these Environmental variables on your system
binance = Binance::Client::REST.new(api_key:ENV['binance-scout-key'],secret_key:ENV['binance-scout-secret'])


while true

  whitelisted = binance.book_ticker.delete_if() { |pair| BLACKLIST.include?(pair["symbol"]) }
  resulting_currency_orders = whitelisted.select() { |order| order['symbol'].match? RESULTING_CURRENCY_REGEX }


  def resulting_currency_pairs
  Parallel.map(resulting_currency_orders, in_threads: resulting_currency_orders.length) do |pair|
    pair['symbol']
  end
end

def remove_resulting_currency(order)
  order['symbol'].delete_suffix(RESULTING_CURRENCY)
end

  resulting_currency_pairs = Parallel.map(resulting_currency_orders, in_threads: resulting_currency_orders.length) do |order|
    # remove resulting currency from orders
    remove_resulting_currency order
  end

  trade_one_set = resulting_currency_orders


  trade_two_set =  Parallel.map(resulting_currency_orders, in_threads: resulting_currency_orders.length) do |order|
    # trade1 is order
    search = remove_resulting_currency(order)
    { order => whitelisted.select() { |trade| trade['symbol'].match(/^#{search}/) } }
  end

def get_matching(trade,order_set,resulting_currency_pairs)
  resulting_currency_pairs.map do |pair|
    check = Regexp.new("^#{pair}").match? trade['symbol']
    check2 = Regexp.new("#{pair}$").match? trade['symbol']
    if check || check2
      order_set.select{|order| order['symbol'] == "#{pair}#{RESULTING_CURRENCY}"}
    end
  end
end

  trade_three_set = resulting_currency_orders

def calculate_result(trade1, trade2, trade3)
  # buy asking sell bid sell bid
  product = (1 / trade1['askPrice'].to_f) * trade2['bidPrice'].to_f * trade3['bidPrice'].to_f
  # product / trade1['askPrice'].to_f
  # product - trade1['askPrice'].to_f - needs to be the cross rate
  return product
end

results = Parallel.map(trade_two_set, in_threads: trade_two_set.length) do |trade|
    trade.values.map do |trade2set|
      trade2set.map do |trade2|
        begin
        trade_one_and_three = get_matching(trade2, resulting_currency_orders, resulting_currency_pairs).compact
        trade1 = trade_one_and_three[1][0]
        trade3 = trade_one_and_three[0][0]

        [{ :trade1 => trade1['symbol'], :trade2 => trade2['symbol'], :trade3 => trade3['symbol'], :ask1 => trade1['askPrice'], :ask2 => trade2['askPrice'], :bid3 => trade3['bidPrice'], :result => calculate_result(trade1, trade2, trade3) },
         { :trade1 => trade3['symbol'], :trade2 => trade2['symbol'], :trade3 => trade1['symbol'], :ask1 => trade3['askPrice'], :ask2 => trade2['askPrice'], :bid3 => trade1['bidPrice'], :result => calculate_result(trade3, trade2, trade1) }
        ]
        rescue
          nil
        end
      end
    end
  end

results = results.flatten(4).compact.select(){|chain| chain[:result].is_a?(Float) && !chain[:result].nan? }
results = results.sort_by(){|result| result[:result]}
results = results.uniq.select() {|chain| chain[:result] >= 1.225 && chain[:result].to_f.finite? }
# results = results.uniq.select() {|chain| chain[:result].to_f.finite? }
# result is the cross rate from resulting currency in, displayed in resulting currency out
  puts "scanning"
  puts results[-1]
end