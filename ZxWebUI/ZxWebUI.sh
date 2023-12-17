. "$HOME/Function.sh"
echo "${Y}WebUI 访问地址：
$C"
Port="$(sed -nE "s/.*listen (.*);/\1/p" nginx.conf)"
if [ -n "$MSYS" ];then
  IP="$(ipconfig|tr -d " "|rg "^IPv(4|6)")"
  IPv4="$(rg "^IPv4"<<<"$IP"|cut -d: -f2-)"
  IPv6="$(rg "^IPv6"<<<"$IP"|cut -d: -f2-)"
else
  IP="$(ip a|rg "inet")"
  IPv4="$(rg "inet "<<<"$IP"|sed -E "s/.*inet //;s|/.*||")"
  IPv6="$(rg "inet6 "<<<"$IP"|sed -E "s/.*inet6 //;s|/.*||")"
fi
[ -n "$IPv4" ]&&while read i;do echo "http://$i:$Port";done<<<"$IPv4"
[ -n "$IPv6" ]&&while read i;do echo "http://[$i]:$Port";done<<<"$IPv6"
echo "$O"
nginx&
while start WebUI;do
tail -Fn0 access.log
restart
done