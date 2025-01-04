#!/system/bin/sh

dev_tun=$(ip ro | grep tun | cut -d " " -f3)
[ "${dev_tun}" == '' ] && dev_tun='tun0'
iptables=""

log() {
  export TZ=Asia/Shanghai
  now=$(date +"[%Y-%m-%d %H:%M:%S %Z]")
  case $1 in
    Info)
      [ -t 1 ] && echo -e "\033[1;32m${now} [Info]: $2\033[0m" || echo "${now} [Info]: $2"
      ;;
    Warn)
      [ -t 1 ] && echo -e "\033[1;33m${now} [Warn]: $2\033[0m" || echo "${now} [Warn]: $2"
      ;;
    Error)
      [ -t 1 ] && echo -e "\033[1;31m${now} [Error]: $2\033[0m" || echo "${now} [Error]: $2"
      ;;
    *)
      [ -t 1 ] && echo -e "\033[1;30m${now} [$1]: $2\033[0m" || echo "${now} [$1]: $2"
      ;;
  esac
}

enable() {
  iptables=""
  [ "$1" == '' ] && iptables="iptables -w 100"
  [ "$1" == '-4' ] && iptables="iptables -w 100"
  [ "$1" == '-6' ] && iptables="ip6tables -w 100"
  [ "$iptables=" == '' ] && log Error 'bad option for enable/disable' && exit 1
  
  ${iptables} -t filter -L tetherctrl_counters >> /dev/null 2>&1
  if [ $? = "0" ]; then
    ${iptables} -N tetherctrl_counters_tun
    ${iptables} -A tetherctrl_counters -j tetherctrl_counters_tun
    
    ${iptables} -A tetherctrl_counters -o ${dev_tun} -j RETURN
    ${iptables} -A tetherctrl_counters -i ${dev_tun} -j RETURN

    ${iptables} -N tetherctrl_FORWARD_tun
    ${iptables} -D tetherctrl_FORWARD -j DROP
    ${iptables} -A tetherctrl_FORWARD -g tetherctrl_FORWARD_tun
    ${iptables} -A tetherctrl_FORWARD -j DROP

    ${iptables} -A tetherctrl_FORWARD_tun -i ${dev_tun} -m state --state RELATED,ESTABLISHED -g tetherctrl_counters
    ${iptables} -A tetherctrl_FORWARD_tun -o ${dev_tun} -m state --state INVALID -j DROP
    ${iptables} -A tetherctrl_FORWARD_tun -o ${dev_tun} -g tetherctrl_counters
  else
    ${iptables} -I tetherctrl_FORWARD_tun -i ${dev_tun} -m state --state RELATED,ESTABLISHED -j ACCEPT
    ${iptables} -I FORWARD -o ${dev_tun} -j ACCEPT
  fi
  log Info "Tun on tether enabled."
}

disable() {
  iptables=""
  [ "$1" == '' ] && iptables="iptables -w 100"
  [ "$1" == '-4' ] && iptables="iptables -w 100"
  [ "$1" == '-6' ] && iptables="ip6tables -w 100"
  [ "$iptables=" == '' ] && log Error 'bad option for enable/disable' && exit 1
  
  ${iptables} -t filter -L tetherctrl_counters >> /dev/null 2>&1
  if [ $? = "0" ]; then
    ${iptables} -D tetherctrl_counters -j tetherctrl_counters_tun >/dev/null 2>&1
    ${iptables} -F tetherctrl_counters_tun >/dev/null 2>&1
    
    ${iptables} -D tetherctrl_FORWARD -g tetherctrl_FORWARD_tun >/dev/null 2>&1
    ${iptables} -F tetherctrl_FORWARD_tun >/dev/null 2>&1
    
    ${iptables} -X tetherctrl_counters_tun >/dev/null 2>&1
    ${iptables} -X tetherctrl_FORWARD_tun >/dev/null 2>&1
  else
    ${iptables} -D tetherctrl_FORWARD_tun -i ${dev_tun} -m state --state RELATED,ESTABLISHED -j ACCEPT
    ${iptables} -D FORWARD -o ${dev_tun} -j ACCEPT
  fi
  log Info "Tun on tether disabled."
}

case "$1" in
enable)
  enable -4 && enable -6
  ;;
disable)
  disable -4 && disable -6
  ;;
*)
  echo "$0:  usage:  $0 {enable|disable}"
  ;;
esac
