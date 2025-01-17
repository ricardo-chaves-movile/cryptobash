#!/usr/bin/env bash

# https://github.com/daniel-lalaina-movile/cryptobash

set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
script_name="./$(basename "${BASH_SOURCE[0]}")"
tdir=$script_dir/temp

binance_uri="api.binance.com"
gateio_uri="api.gateio.ws"
source $script_dir/.credentials

residential_country_currency="BRL"
LC_NUMERIC="en_US.UTF-8"

usage() {
 cat << EOF
Usage: ${script_name} [-h] [-v] [-t] -p <order|balance|runaway> arg1 [arg2...]

Available options:

-h, --help      Print this help.
-v, --verbose   Run with debug
-t, --test      Use Binance test endpoint. (Works with "order" or "runaway" params)
-p, --param     Main action parameter
		-p balance
		-p order
		Caution: When using a list of tokenpairs, it must be the same quote pair.
		EX: -p order binance BUY ADAUSDT,ETHUSDT,BTCUSDT |runaway]
-w, --web	Turn off progress bar. (To use with shell2http and display on web) (TODO: Explain how to use shell2http)

Examples:

Buy 50 USDT of ADAUSDT
$script_name -p order binance BUY ADAUSDT 50
$script_name -p order gateio BUY ADAUSDT 50

Buy 50 USDT of each ADA ETH BTC
$script_name -p order binance BUY ADAUSDT,ETHUSDT,BTCUSDT
$script_name -p order gateio BUY ADAUSDT,ETHUSDT,BTCUSDT

Show your balance.
$script_name -p balance all
$script_name -p balance binance
$script_name -p balance gateio

Sell every token that you have, at market price.
$script_name -p runaway binance
$script_name -p runaway gateio
$script_name -p runaway all

EOF
exit
}

cleanup() {
 trap - SIGINT SIGTERM ERR EXIT
 #rm -rf $tdir/*
}

msg() {
  echo >&2 -e "${1-}"
}

die() {
  local msg=$1
  local code=${2-1} # default exit status 1
  msg "$msg"
  exit "$code"
}

parse_params() {
  test=""
  method="GET"
  param=''
  web="false"

  while :; do
    case "${1-}" in
    --docker)
      script_name="docker run cryptobash"
      #web="true"
      ;;
    -h | --help) usage ;;
    -v | --verbose) set -x ;;
    --no-color) NO_COLOR=1 ;;
    -t | --test) test="/test";;
    -w | --web) web="true";;
    -p | --param)
      param="${2-}"
      shift
      ;;
    -?*) die "Unknown option: $1" ;;
    *) break ;;
    esac
    shift
  done

  args=("$@")

  # Checking exchange keys

  if echo ${@-} |grep -q "binance"; then
   echo -n "$binance_key$binance_secret" |wc -c |grep -Eq "^128$|^0$" || die "Invalid binance_key/binance_secret, if you don't have account in this exchange, please leave both fields empty"
  elif echo ${@-} |grep -q "gateio"; then
   echo -n "$gateio_key$gateio_secret" |wc -c |grep -Eq "^96$|^0$" || die "Invalid gateio_key/gateio_secret, if you don't have account in this exchange, please leave both fields empty"
  elif echo ${@-} |grep -q "all"; then
   echo -n "$gateio_key$gateio_secret$binance_key$binance_secret" |wc -c |grep -Eq "^0$" && die "You must configure a pair of key/secret for at least one of the exchanges."
  fi

  # Checking required params and arguments

  if [[ "${param}" != @(order|balance|runaway) ]]; then die "Missing main parameter: -p <order|balance|runaway>"; fi
  if [[ "${param}" == @(balance|runaway) ]]; then
   exchange=$(echo ${@-} |grep -oPi "(binance|gateio|all)" || die "Exchange argument is required for param runaway.\nEx\n${script_name} -p runaway binance\n${script_name} -p runaway gateio\n${script_name} -p runaway all")
  fi
  if [ ${param} == "order" ]; then
   side=$(echo ${@-} |grep -oP "\b(SELL|BUY)\b" || die "SIDE argument is required for param order.\nExamples:\n${script_name} -p order SELL ADAUSDT 30")
   symbol=$(echo ${@-} |grep -oP "\b[A-Z0-9]+(USDT|BTC)\b" || die "SYMBOL argument is required for param order. Examples\nTo SELL 30 USDT of ADA:\n${script_name} -p order SELL ADAUSDT 30\nTo buy 30 USDT of each ADA,SOL,LUNA:\n${script_name} -p order SELL ADAUSDT,SOLUSDT,LUNAUSDT 30")
   qty=$(echo ${@-} |grep -oP "\b[0-9.]+\b" || die "QUOTEQTY argument (which is the amount you want to spend, not the ammount of coins you want to buy/sell) is required for param order.\nExamples:\n/$script_name -p order SELL ADAUSDT 30")
   exchange=$(echo ${@-} |grep -oPi "(binance|gateio)" || die "Exchange argument is required for param order.\nExamples:\n${script_name} -p order binance SELL ADAUSDT 30\n${script_name} -p order gateio SELL ADAUSDT 30\n -p order binance-gateio SELL ADAUSDT 30")
  fi

  return 0
}

parse_params "$@"

banner() {
clear
msg "\033[0;34m
██████╗ ██╗      ██████╗  ██████╗██╗  ██╗ ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗    ██████╗  ██████╗  ██████╗██╗  ██╗███████╗
██╔══██╗██║     ██╔═══██╗██╔════╝██║ ██╔╝██╔════╝██║  ██║██╔══██╗██║████╗  ██║    ██╔══██╗██╔═══██╗██╔════╝██║ ██╔╝██╔════╝
██████╔╝██║     ██║   ██║██║     █████╔╝ ██║     ███████║███████║██║██╔██╗ ██║    ██████╔╝██║   ██║██║     █████╔╝ ███████╗
██╔══██╗██║     ██║   ██║██║     ██╔═██╗ ██║     ██╔══██║██╔══██║██║██║╚██╗██║    ██╔══██╗██║   ██║██║     ██╔═██╗ ╚════██║
██████╔╝███████╗╚██████╔╝╚██████╗██║  ██╗╚██████╗██║  ██║██║  ██║██║██║ ╚████║    ██║  ██║╚██████╔╝╚██████╗██║  ██╗███████║
╚═════╝ ╚══════╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝    ╚═╝  ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝╚══════╝
\033[0m"
}
if [ ! ${param} == "balance" ]; then banner; fi

progress_bar() {
 pid=$!
 banner
 while kill -0 $pid 2> /dev/null; do
  for ((k = 0; k <= 30 ; k++)); do
   echo -n "[ "
   for ((i = 0 ; i <= k; i++)); do echo -n "\$\$\$\$"; done
   #for ((j = i ; j <= 30 ; j++)); do echo -n "   "; done
   v=$((k * 30))
   echo -n " ] "
   kill -0 $pid 2>/dev/null || break
   echo -n "$v %" $'\r'
   sleep 0.3
  done
 done
   echo -ne "\r"
 msg "[ \$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$\$ ] 1000 %"
}

func_timestamp() {
 echo -n $(($(date +%s%N)/1000000))
}

curl_usd() {
  fiat_usd_rate="$(curl -s -H 'user-agent: Mozilla' -H 'Accept-Language: en-US,en;q=0.9,it;q=0.8' "https://www.google.com/search?q=1+usd+to+$residential_country_currency" |grep -oP "USD = [0-9]+\\.[0-9]+ $residential_country_currency" |head -n1 |grep -oP "[0-9]+\\.[0-9]+" |tr -d '\n')"
}

curl_binance() {
 curl -s -X $method -H "X-MBX-APIKEY: $binance_key" "https://$binance_uri/$binance_endpoint?$binance_query_string&signature=$binance_signature"
}

curl_binance_24hr() {
 curl -s -X $method 'https://'$binance_uri'/api/v3/ticker/24hr'
}

curl_gateio() {
 curl -s -X $method -H "Timestamp: $timestamp" -H "KEY: $gateio_key" -H "SIGN: $gateio_signature" "https://$gateio_uri/$gateio_endpoint?"
}

curl_gateio_24hr() {
 curl -s -X $method 'https://'$gateio_uri'/api/v4/spot/tickers'
}

if [ ${param} == "runaway" ]; then
 if [[ $exchange =~ binance|all ]] ; then
  if [ -z $test ]; then read -p "Are you sure? This will convert all your assets to USDT (y/n)" -n 1 -r; if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit; fi; fi
  binance_endpoint="sapi/v1/capital/config/getall"
  timestamp=$(func_timestamp)
  binance_query_string="timestamp=$timestamp"
  binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
  curl_binance |jq '.[] |{coin: .coin, free: .free} | select((.free|tonumber>0.0001) and (.coin!="USDT"))' |grep -oP "[A-Z0-9.]+" |paste - - |while read symbol qty; do
   method="POST"
   binance_endpoint="api/v3/order$test"
   timestamp=$(func_timestamp)
   binance_query_string="quantity=$(echo -n $qty |sed 's/\..*//g')&symbol=${symbol}USDT&side=SELL&type=MARKET&timestamp=$timestamp"
   binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
   curl_binance |grep -v "Invalid symbol" || \
    binance_query_string="quantity=$qty&symbol=${symbol}BTC&side=SELL&type=MARKET&timestamp=$timestamp" \
    binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}') \
    curl_binance &
  done
 fi
 if [[ $exchange =~ gateio|all ]]; then
  # TODO
  echo "gateio order is not supported yet. I'm still thinking about it, cause they don't support orders at MARKET price :-("
 fi
 exit
fi

if [ ${param} == "balance" ]; then
 rm -f $tdir/*
 curl -s -m3 'https://'$gateio_uri'/api/v4/spot/tickers?currency_pair=USDT_USD' |jq -r .[].last |grep -E "[0-9]+\.[0-9]+" > $tdir/usdtusd || echo "1" > $tdir/usdtusd &
 fiat_deposits=$(awk '{dep+=$1}END{print dep}' $script_dir/.fiat_deposits 2>/dev/null &)
 $(
 if [ $residential_country_currency == "USD" ]; then fiat_usd_rate="1"; else curl_usd; fi
 if echo -n $binance_key$binance_secret |wc -c |grep -Eq "^128$" && [[ $exchange =~ binance|all ]]; then
  binance_endpoint="sapi/v1/capital/config/getall"
  timestamp=$(func_timestamp)
  binance_query_string="timestamp=$timestamp"
  binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
  curl_binance |jq ' .[] | {symbol: .coin, available: .free, locked: .locked} | select(.available!="0" or .locked!="0") | to_entries[] | .value' |paste - - - > $tdir/binance_balance
  curl_binance_24hr |jq '.[] | {symbol: .symbol, price: .lastPrice, last24hr: .priceChangePercent|tonumber} | select(.price!="0.00000000" and .price!="0.00" and .price!="0") | to_entries[] | .value' |paste - - - > $tdir/binance_24hr
  sed -i 's/"//g' $tdir/binance_24hr $tdir/binance_balance
  btcusdt=$(grep -E "^BTCUSDT\b" $tdir/binance_24hr |awk '{print $2}')
  cat $tdir/binance_balance |while read symbol available locked; do
   amount=$(echo "$available + $locked" | bc -l)
   if grep -q "^${symbol}USDT" $tdir/binance_24hr; then
    read usdt_pair_price last24hr <<<$(grep "^${symbol}USDT" $tdir/binance_24hr |awk '{print $2,$3}')
   elif [[ ${symbol} =~ USDT|BUSD|USDC ]]; then
    usdt_pair_price="1"
    last24hr="0"
   elif grep -Eq "^${symbol}BTC\b" $tdir/binance_24hr; then
    read btc_pair_price last24hr <<<$(grep "^${symbol}BTC" $tdir/binance_24hr |awk '{print $2,$3}')
    usdt_pair_price=$(echo "$btc_pair_price * ${btcusdt}" |bc -l)
   #else
   #usdt_pair_price=$(curl_usd)
   fi
   usdt_available=$(echo "$available * $usdt_pair_price" |bc -l)
   usdt_locked=$(echo "$locked * $usdt_pair_price" |bc -l)
   usdt_total=$(echo "$usdt_available + $usdt_locked" |bc -l)
   until [ -f $tdir/usdtusd ]; do sleep 0.1; done
   usdtusd=$(head -1 $tdir/usdtusd)
   if [ $residential_country_currency == "USD" ]; then
    fiat_total=$(echo "$usdt_total * $usdtusd" |bc -l)
   else
    fiat_total=$(echo "$usdt_total * $usdtusd * $fiat_usd_rate" |bc -l)
   fi
   btc_total=$(echo "$usdt_total / $btcusdt" |bc -l)
   echo $symbol $amount $usdt_available $usdt_locked $usdt_total $btc_total $fiat_total $last24hr >> $tdir/binance_final
  done
 fi &
 if echo -n $gateio_key$gateio_secret |wc -c |grep -Eq "^96$" && [[ $exchange =~ gateio|all ]]; then
  gateio_query_string=""
  gateio_body=""
  gateio_endpoint="api/v4/spot/accounts"
  gateio_body_hash=$(printf "$gateio_body" | openssl sha512 | awk '{print $NF}')
  timestamp=$(date +%s)
  gateio_sign_string="$method\n/$gateio_endpoint\n$gateio_query_string\n$gateio_body_hash\n$timestamp"
  gateio_signature=$(printf "$gateio_sign_string" | openssl sha512 -hmac "$gateio_secret" | awk '{print $NF}')
  curl_gateio |jq ' .[] | {symbol: .currency, available: .available, locked: .locked} | select(.available!="0" or .locked!="0") | to_entries[] | .value' |paste - - - > $tdir/gateio_balance
  curl_gateio_24hr |jq '.[] | {symbol: .currency_pair, price: .last, last24hr: .change_percentage|tonumber} | select(.price!="0.00000000" and .price!="0.00" and .price!="0") | to_entries[] | .value' |sed 's/_//g' |paste - - - > $tdir/gateio_24hr
  sed -i 's/"//g' $tdir/gateio_24hr $tdir/gateio_balance
  btcusdt=$(grep -E "^BTCUSDT\b" $tdir/gateio_24hr |awk '{print $2}')
  cat $tdir/gateio_balance |while read symbol available locked; do
   amount=$(echo "$available + $locked" | bc -l)
   if grep -q "^${symbol}USDT" $tdir/gateio_24hr; then
    read usdt_pair_price last24hr <<<$(grep "^${symbol}USDT" $tdir/gateio_24hr |awk '{print $2,$3}')
   elif [[ ${symbol} =~ USDT|BUSD|USDC ]]; then
    usdt_pair_price="1"
    last24hr="0"
   elif grep -Eq "^${symbol}BTC\b" $tdir/gateio_24hr; then
    read btc_pair_price last24hr <<<$(grep "^${symbol}BTC" $tdir/gateio_24hr |awk '{print $2,$3}')
    usdt_pair_price=$(echo "$btc_pair_price * ${btcusdt}" |bc -l)
  #else
   #usdt_pair_price=$(curl_usd)
   fi
   usdt_available=$(echo "$available * $usdt_pair_price" |bc -l)
   usdt_locked=$(echo "$locked * $usdt_pair_price" |bc -l)
   usdt_total=$(echo "$usdt_available + $usdt_locked" |bc -l)
   until [ -f $tdir/usdtusd ]; do sleep 0.1; done
   usdtusd=$(head -1 $tdir/usdtusd)
   if [ $residential_country_currency == "USD" ]; then
    fiat_total=$(echo "$usdt_total * $usdtusd" |bc -l)
   else
    fiat_total=$(echo "$usdt_total * $usdtusd * $fiat_usd_rate" |bc -l)
   fi
   btc_total=$(echo "$usdt_total / $btcusdt" |bc -l)
   echo $symbol $amount $usdt_available $usdt_locked $usdt_total $btc_total $fiat_total $last24hr >> $tdir/gateio_final
  done
 fi 
 ) &

 if [ $web == "false" ]; then progress_bar; else wait; fi
 # Unifying and summing up the amounts of same assets from multiple exchanges.
 awk '{a[$1]+=$2;b[$1]+=$3;c[$1]+=$4;d[$1]+=$5;e[$1]+=$6;f[$1]+=$7;g[$1]+=$8}END{for(i in a)print i, a[i], b[i], c[i], d[i], e[i], f[i], g[i]/2"%"}' $tdir/*_final > $tdir/total_final1
 # Including percentage allocation column.
 awk 'FNR==NR{s+=$5;next;} {print $0,100*$5/s"%"}' $tdir/total_final1 $tdir/total_final1 |sort -n -k5 > $tdir/total_final2
 # Including footer with total sum of each column.
 awk '{for(i=2;i<=8;i++)a[i]+=$i;print $0} END{l="Total";i=2;while(i in a){l=l" "a[i];i++};print l" X"}' $tdir/total_final2 > $tdir/total_final3
 tail -1 $tdir/total_final3 |awk '{print $1" X "$3" "$4" "$5" "$6" "$7" X "$9}' > $tdir/footer
 sed -i '$ d' $tdir/total_final3
 # Including header
 sed -i '1i\Token Amount USDT-free USDT-locked in-USDT in-BTC in-'$residential_country_currency' Last24hr Allocation' $tdir/total_final3
 # Fixing column versions compatibility due to -o, coloring, and printing
 msg "\n$(cat $tdir/total_final3 $tdir/footer |column -t $(column -h |grep -q "\-o," && printf '%s' -o ' | ') |sed -E 's/\|/ \| /g; s/^/\\033\[0;34m/g; s/ (-[0-9\.]+%)/ \\033\[0;31m\1\\033\[0;34m/g' |tee $tdir/total_final4)"

 if [[ $exchange == "all" ]] ; then
  echo -e "Exchange USDT BTC $residential_country_currency" > $tdir/total_per_exchange
  for exchange in `ls -1 ${tdir}/*_final |sed -E 's/(^.*\/|_final)//g'`; do
   echo -n "${exchange^}" >> $tdir/total_per_exchange
   awk '{usdt+=$5;btc+=$6;rcc+=$7} END{print " "usdt" "btc" "rcc}' ${tdir}/${exchange}_final >> $tdir/total_per_exchange
  done
  echo "Total $(tail -1 $tdir/total_final4 |awk -F'[| ]+' '{print $5" "$6" "$7}')" >> $tdir/total_per_exchange
  msg "\n\033[0;34m$(cat $tdir/total_per_exchange |column -t $(column -h |grep -q "\-o," && printf '%s' -o ' | ') |sed 's/|/ | /g' |grep --color ".*")\033[0m"
 fi
 if [ ! -z $fiat_deposits ]; then
  echo "Return Percentage $residential_country_currency" >> $tdir/total_result
  current_total=$(tail -1 $tdir/total_final4 |awk -F'[| ]+' '{print $7}')
  echo ">>>>> $(echo "scale=2;100 * $current_total / $fiat_deposits - 100" |bc -l)% $(echo "$current_total - $fiat_deposits" |bc -l)" >> $tdir/total_result
  msg "\n$(cat $tdir/total_result |column -t $(column -h |grep -q "\-o," && printf '%s' -o ' | ') |sed -E 's/\|/ \| /g; s/^/\\033\[0;34m/g; s/ (-[0-9\.]+%)/ \\033\[0;31m\1\\033\[0;34m/g')\033[0m"
 fi
 exit
fi

if [ ${param} == "order" ]; then

 for symbol in `echo $symbol`; do

  if [ $exchange == "binance" ] ; then
   method="POST"
   binance_endpoint="api/v3/order$test"
   timestamp=$(func_timestamp)
   binance_query_string="quoteOrderQty=$qty&symbol=$symbol&side=$side&type=MARKET&timestamp=$timestamp"
   binance_signature=$(echo -n "$binance_query_string" |openssl dgst -sha256 -hmac "$binance_secret" |awk '{print $2}')
   curl_binance
  fi
 
  if [ $exchange == "gateio" ] ; then
   # TODO
   echo "gateio order is not supported yet. I'm still thinking about it, cause they don't support orders at MARKET price :-("
  fi

 done
 exit
fi
