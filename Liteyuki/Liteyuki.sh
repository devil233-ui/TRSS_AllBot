. "$HOME/Function.sh"
rm -vrf src/*/setup.py
while start Liteyuki;do
poetry run python bot.py
restart
done