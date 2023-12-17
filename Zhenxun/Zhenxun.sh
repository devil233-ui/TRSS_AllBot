. "$HOME/Function.sh"
if [ -n "$MSYS" ];then
  pg_ctl start -D /win/pgsql/data
else
  [ -d /run/postgresql ]||{ mkdir -vp /run/postgresql&&chown postgres:postgres /run/postgresql;}
  su - postgres -c "pg_ctl start -D /var/lib/postgres/data"
fi
while start Zhenxun;do
poetry run python bot.py
restart
done