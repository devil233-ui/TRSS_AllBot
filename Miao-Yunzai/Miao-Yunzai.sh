. "$HOME/Function.sh"
if [ -x "$HOME/Dragonfly/Dragonfly" ];then
  "$HOME/Dragonfly/Dragonfly" --logtostdout --colorlogtostdout&
else
  redis-server --stop-writes-on-bgsave-error no $([ "$(uname -m)" = aarch64 ]&&echo "--ignore-warnings ARM64-COW-BUG")&
fi
bash "$HOME/../Main.sh" qss start
export PUPPETEER_EXECUTABLE_PATH="$(if [ -n "$MSYS" ];then command -v chromium|cygpath -wf-;else command -v chromium;fi)"
while start Miao-Yunzai;do
node app&&
{ node_modules/.bin/pm2 kill&}
restart
done