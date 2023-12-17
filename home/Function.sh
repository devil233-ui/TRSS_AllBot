R="[1;31m" G="[1;32m" Y="[1;33m" C="[1;36m" B="[1;m" O="[m"
exec 3>&1
menubox(){ MenuBox="$1";shift;dialog --title "$Title" --backtitle "$BackTitle $(date "+%F %T.%N")" --ok-button "确认" --cancel-button "取消" --menu "$MenuBox" 0 0 0 "$@" 2>&1 >&3;}
trap 'Choose="$(menubox "- 收到信号：SIGINT(2)"\
  1 "继续运行"\
  2 "返回菜单"\
  3 "启动 fish"\
  0 "退出脚本")"&&
case "$Choose" in
  2)tmux detach;;
  3)fish;;
  0)exec tmux detach
esac&&
exec bash "$(basename "$0")" "$@">&3' 2
[ -n "$Rainbow" ]&&exec &> >(trap "" 2;exec lolcat -t >&3)
start(){ echo "$Y[$(date "+%F %T.%N")] 正在启动：[1;38;5;$[RANDOM%256]m$@$O";}
restart(){ [ "$?" = 0 ]&&RsTime=3||((RsTime+=3))
echo "$R[$(date "+%F %T.%N")] 进程停止了，$RsTime秒后尝试重启$O"
sleep "$RsTime";}
geturl(){ curl -sLm3 --connect-timeout 3 "$@" 2>/dev/null||echo -n "$R网络连接失败";}
cd "$(dirname "$0")"
echo "$G欢迎使用 $Title !$C $BackTitle
$Y使用教程：${C}https://TRSS.me/Guide/Command.html$O
"
geturl "https://wttr.in/?F&lang=zh&format=v2"
echo "[1;38;5;$[RANDOM%256]m"
geturl "https://v1.jinrishici.com/all.txt"
echo "[1;38;5;$[RANDOM%256]m"
geturl "https://v1.hitokoto.cn/?encode=text"
echo "$O
"
rm -vrf core.*