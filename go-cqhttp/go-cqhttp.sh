. "$HOME/Function.sh"
bash "$HOME/../Main.sh" qss start
while start go-cqhttp;do
FORCE_TTY=1 ../go-cqhttp/go-cqhttp -faststart
restart
done