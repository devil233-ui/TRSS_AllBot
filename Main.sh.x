#!/bin/env bash
MAINNAME=v1.0.0 MAINVER=202311130
R="[1;31m" G="[1;32m" Y="[1;33m" C="[1;36m" B="[1;m" O="[m"
echo "$Y- 加载中，请稍等……$O"
EXEC="$(realpath "${0%.*}")" DIR="$(dirname "$EXEC")"
[ -n "$OHOME" ]||export OHOME="$HOME"
export HOME="$DIR/home"
export\
  Title="TRSS AllBot $MAINNAME ($MAINVER)"\
  BackTitle="作者：时雨🌌星空"\
  LANG=zh_CN.UTF-8\
  SHELL="$BASH"\
  EDITOR=micro\
  TMPDIR="$HOME/.cache"\
  TMUX_TMPDIR="$HOME"\
  PLAYWRIGHT_DOWNLOAD_HOST="https://npmmirror.com/mirrors/playwright"
PyPIURL="https://mirrors.bfsu.edu.cn/pypi/web/simple"

declare -A Config Option
ConfigFile="$HOME/.Main.conf"
ConfigData="$(<"$ConfigFile")"&&
while read i;do declare -g Config["$(cut -d= -f1<<<"$i")"]="$(cut -d= -f2-<<<"$i")";done<<<"$ConfigData"
config_save(){ echo -n "$(for i in "${!Config[@]}";do echo "$i=${Config["$i"]}";done)">"$ConfigFile";}

exec 3>&1
[ -n "${Config[Rainbow]}" ]&&{ export Rainbow=1
exec &> >(trap "" 2;exec lolcat -t >&3);}

menubox(){ MenuBox="$1";shift;dialog --title "$Title" --backtitle "$BackTitle $(date "+%F %T.%N")" --ok-button "确认" --cancel-button "取消" --menu "$MenuBox" 0 0 0 "$@" 2>&1 >&3;}
msgbox(){ dialog --title "$Title" --backtitle "$BackTitle $(date "+%F %T.%N")" --ok-button "${2:-确认}" --msgbox "$1" 0 0 2>&1 >&3;}
yesnobox(){ dialog --title "$Title" --backtitle "$BackTitle $(date "+%F %T.%N")" --yes-button "${2:-确认}" --no-button "${3:-取消}" --yesno "$1" 0 0 2>&1 >&3;}
inputbox(){ dialog --title "$Title" --backtitle "$BackTitle $(date "+%F %T.%N")" --ok-button "${3:-确认}" --cancel-button "${4:-取消}" --inputbox "$1" 0 0 "$2" 2>&1 >&3;}
passwordbox(){ dialog --title "$Title" --backtitle "$BackTitle $(date "+%F %T.%N")" --ok-button "${3:-确认}" --cancel-button "${4:-取消}" --insecure --passwordbox "$1" 0 0 "$2" 2>&1 >&3;}
listbox(){ ListBox="$1";shift;dialog --title "$Title" --backtitle "$BackTitle $(date "+%F %T.%N")" --ok-button "确认" --cancel-button "取消" --checklist "$ListBox" 0 0 0 "$@" 2>&1 >&3;}
gaugebox(){ Default="$3";while echo "$Default" 2>/dev/null;do sleep "${2:-0.1}";((Default++));done|dialog --title "$Title" --backtitle "$BackTitle $(date "+%F %T.%N")" --gauge "$1" 0 0 "$Default" 2>&1 >&3 &GaugeBox_Pid="$!";}
gaugebox_stop(){ kill "$GaugeBox_Pid";}

TrapInfo="$(trap -l|tr -d ' '|tr '\t' '\n')"
TrapSIGCHLD="$(sed -n "s/)SIGCHLD//p"<<<"$TrapInfo")"
TrapSIGWINCH="$(sed -n "s/)SIGWINCH//p"<<<"$TrapInfo")"
eval 'trap_info(){ case "$1" in '"$(tr -s '\n' ' '<<<"$TrapInfo"|sed 's/)/)TrapSignal=/g;s/ /;;/g')*)TrapSignal=;esac;}"
trap_menu(){ trap_info "$1"
Choose="$(menubox "- 收到信号：$TrapSignal($1)"\
  1 "继续运行"\
  2 "返回菜单"\
  3 "重载脚本"\
  0 "退出脚本")"
case "$Choose" in
  2)main;;
  3)rm -vrf "$EXEC.x";exec bash "$EXEC">&3;;
  0)exit
esac;}
trap_menu_quiet(){ trap_info "$1"
echo "$Y- 收到信号：$C$TrapSignal$R($1)$O">&2;}
for i in {1..64};do
  trap "trap_menu $i" "$i"
done
trap "trap_menu_quiet $TrapSIGWINCH" "$TrapSIGWINCH"
trap "$TrapSIGCHLD"
trap "echo '$G- 脚本已停止运行$O'" EXIT

abort(){ echo "
$R! $@$O";back;main;}
abort_download(){ if [ -n "$ServerStart" ];then
  [ "$ServerStart" = "${Config[ServerChoose]}" ]&&{ echo "
$R! $1，请检查网络，并尝试重新下载$O";unset ServerStart;return 1;}
else
  ServerStart="${Config[ServerChoose]}"
fi
echo "
$R! $1，5秒后尝试切换服务器$O";shift
[ "${Config[ServerChoose]}" -lt 10 ]&&((Config[ServerChoose]++))||Config[ServerChoose]=1
config_save;sleep 5;"$@";}
back(){ echo -n "
$C  按回车键返回$O";read -s ENTER;}
mktmp(){ TMP="$DIR/tmp"&&rm -rf "$TMP"&&mkdir -p "$TMP"||abort "缓存目录创建失败";}
mkcd(){ cd "$1"||{ mkdir -vp "$1"&&cd "$1"||abort "$1 目录创建失败";};}
getver(){ mkcd "$DIR/${2:-$1}"
NOWVER="$(cat version 2>/dev/null)"
VER="$(sed -n s/^version=//p<<<"$NOWVER")"
NAME="$(sed -n s/^name=//p<<<"$NOWVER")"
MD5="$(sed -n s/^md5=//p<<<"$NOWVER")"
[ -n "$VER" ]&&[ -n "$NAME" ]&&[ -n "$MD5" ];}
geturl(){ curl -L --retry 2 --connect-timeout 5 "$@";}
depend(){ type "$1" &>/dev/null||{ yesnobox "未安装 ${2:-$1}，是否开始下载"&&pacman_Syu "${2:-$1}";};}
editor(){ depend "$EDITOR"&&"$EDITOR" "$@">&3;}
time_start(){ TimeStart="$(date +%s%N)";}
time_stop(){ TimeStop="$(date +%s%N)" TimeSpend="$(awk 'BEGIN{printf("%0.3f",'"$[TimeStop-TimeStart]/10^9);exit}")秒";}
process_start(){ ProcessAction="$1" ProcessName="$2"
echo "
$Y- 正在$3$ProcessAction $ProcessName$4$O
"
time_start;}
process_stop(){ Status="$?"
time_stop
if [ "$Status" = 0 ];then
  echo "
$G- $ProcessName ${1:-$ProcessAction}完成，用时：$C$TimeSpend$O"
else
  abort "$ProcessName ${1:-$ProcessAction}失败，用时：$C$TimeSpend"
fi;}
pacman_Syu(){ process_start "安装" "依赖" "" "：$C$*"
pacman -Syu --noconfirm --needed --overwrite "*" "$@"
process_stop;}
pacman_Rdd(){ for i in "$@";do pacman -Rdd --noconfirm "$i" 2>/dev/null;done;}
random_string(){ tr -dc "$1"</dev/urandom|head -c "$2";}
md5(){ md5sum "$@"|head -c 32;}
json(){ tr -d ' "'|tr -s "{[,]}" "\n"|sed -nE "s/^$1://p"|head -n1;}
read_wait(){ N="$1"
echo -n "
$R  请阅读$N秒……$O"
while sleep 1;do
  ((N--))
  [ "$N" = 0 ]&&break
  echo -n "[2K[13D$Y  请阅读$N秒……$O"
done
echo -n "[2K[14D$C  请输入你的选择：$O"
read Choose
[ "$Choose" = "我已阅读并同意" ];}

tmux_attach(){ Session="$1" SName="${2:-$1}"
Return="$({ tmux selectw -t "$Session"&&tmux a;} 2>&1)" Status="$?"
case "$Return" in
  "[detached (from session TRSS)]");;
  "can't find window: $Session"|"no server running on"*|"error connecting to"*)yesnobox "错误：$SName 窗口不存在" "启动 $SName" "返回"&&tmux_start "$Session" "$SName";;
  "[exited]")yesnobox "注意：$SName 已停止运行" "重启 $SName" "返回"&&tmux_start "$Session" "$SName";;
  "open terminal failed: not a terminal")script -ec "tmux a" /dev/null>&3||abort "未知错误：$Return";;
  *)[ "$Status" = 0 ]&&msgbox "$Return"||msgbox "未知错误：$Return"
esac;}

tmux_start_server(){ time_start
[ -s "$Session.sh" ]||{ rm -rf "$EXEC.x";bash "$EXEC" cmd exit &>/dev/null;}
tmux start&
until Return="$(tmux ls 2>&1)";do sleep 1;done
[ -n "$Return" ]||tmux new -ds TRSS "while sleep 1h;do bash '$EXEC' update all quiet;done"
if tmux selectw -t "$Session" &>/dev/null;then
  Return=1
else
  Return="$(tmux neww -n "$Session" bash "$Session.sh" 2>&1)" Status="$?"
fi
time_stop;}

tmux_start(){ Session="$1" SName="${2:-$1}"
gaugebox "- 正在启动 $SName"
tmux_start_server
gaugebox_stop
case "$Return" in
  "")yesnobox "$SName 启动完成，用时：$TimeSpend" "打开 $SName" "返回"&&tmux_attach "$Session" "$SName";;
  1)yesnobox "错误：$SName 正在运行" "打开 $SName" "返回"&&tmux_attach "$Session" "$SName";;
  *)[ "$Status" = 0 ]&&msgbox "$Return"||msgbox "未知错误：$Return"
esac;}

tmux_start_quiet(){ Session="$1" SName="${2:-$1}"
echo "$Y- 正在启动 $SName$O"
tmux_start_server
case "$Return" in
  "")echo "$G- $SName 启动完成，用时：$C$TimeSpend$O";;
  1)echo "$R- 错误：$SName 正在运行$O";;
  *)[ "$Status" = 0 ]&&echo "$Return"||echo "$R- 未知错误：$Return$O"
esac;}

tmux_stop(){ Session="$1" SName="${2:-$1}"
Return="$(tmux killw -t "$Session" 2>&1)" Status="$?"
case "$Return" in
  "")msgbox "$SName 已停止运行";;
  "can't find window: $Session")yesnobox "错误：$SName 未运行" "返回" "停止 tmux"||tmux kill-server;;
  "no server running on"*|"error connecting to"*)msgbox "错误：$SName 未运行";;
  *)[ "$Status" = 0 ]&&msgbox "$Return"||msgbox "未知错误：$Return"
esac;}

tmux_stop_quiet(){ Session="$1" SName="${2:-$1}"
Return="$(tmux killw -t "$Session" 2>&1)" Status="$?"
case "$Return" in
  "")echo "$G- $SName 已停止运行$O";;
  "can't find window: $Session"|"no server running on"*|"error connecting to"*)echo "$R- 错误：$SName 未运行$O";;
  *)[ "$Status" = 0 ]&&echo "$Return"||echo "$R- 未知错误：$Return$O"
esac;}

fg_start(){ Session="$1" SName="${2:-$1}"
[ -s "$Session.sh" ]||{ rm -vrf "$EXEC.x";bash "$EXEC" cmd exit;}
bash "$Session.sh">&3;}

file_manager(){ if [ -f "$1" ];then FMFile="$1"
Choose="$(menubox "- 当前文件：$FMFile"\
  1 "修改文件"\
  2 "删除文件"\
  3 "导出文件"\
  0 "返回")"
case "$Choose" in
  1)editor "$FMFile";;
  2)yesnobox "确认删除？"&&{ rm -vrf "$FMFile"||abort "文件删除失败";};;
  3)Input="$(inputbox "请输入导出路径")"&&{ process_start "导出" "文件" "" "：$C$FMFile 到 $G$Input";cp -vrf "$FMFile" "$Input";process_stop;back;};;
  *)file_list;return
esac
file_manager "$FMFile"
elif [ -d "$1" ];then file_list "$1"
else file_list
fi;}

file_list(){ [ -n "$1" ]&&{ cd "$1"||return;}
if [ "${Config[FileExplorer]}" = 0 ];then
  FMDir="$(pwd)" FMList="$(ls -A)"
  if [ -n "$FMList" ];then
    Choose="$(eval menubox "'- 当前目录：$FMDir' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$FMList") 0 上级目录")"||return
    [ "$Choose" -gt 0 ]&&{ file_manager "$(sed -n "${Choose}p"<<<"$FMList")";return;}
  else
    yesnobox "当前目录：$FMDir 无任何文件" "返回" "删除目录"||rm -vrf "$FMDir"
  fi
  file_list ..
else
  depend ranger&&
  ranger>&3
fi;}

gitserver(){ Choose="$(menubox "- 请选择 GitHub 镜像源"\
  1 "GitHub（国外推荐）"\
  2 "GHProxy（国内推荐）"\
  3 "GHApi"\
  4 "abskoop"\
  5 "KGitHub"\
  6 "GitClone"\
  7 "DaoCloud")"||return
case "$Choose" in
  1)Server="GitHub" URL="https://github.com";;
  2)Server="GHProxy" URL="https://ghproxy.com/github.com";;
  3)Server="GHApi" URL="https://gh.api.99988866.xyz/github.com";;
  4)Server="abskoop" URL="https://github.abskoop.workers.dev/github.com";;
  5)Server="KGitHub" URL="https://kgithub.com";;
  6)Server="GitClone" URL="https://gitclone.com/github.com";;
  7)Server="DaoCloud" URL="https://dn-dao-github-mirror.daocloud.io"
esac;}

git_log(){ git -C "${1:-.}" log -p --stat --graph;}
git_logp(){ git -C "${2:-.}" log -1 --pretty=%"$1";}
git_clone(){ rm -rf "$2"&&git clone --depth 1 --single-branch "$@";}

git_pull_(){ git -C "${1:-.}" pull||git -C "${1:-.}" pull --rebase --allow-unrelated-histories;}
git_pull_force(){ [ -d "${1:-.}/.git" ]&&GitDir="${1:-.}"||return
echo "
$Y- 正在强制更新：$C$GitDir$O
"
rm -vrf "$GitDir/.git/index.lock"
{ git -C "$GitDir" reset --hard&&git_pull_ "$GitDir";}||
{ git -C "$GitDir" clean -df&&git_pull_ "$GitDir";}||
{ git -C "$GitDir" clean -xdf&&git_pull_ "$GitDir";}||
echo "
$R- 强制更新失败$O";}
git_pull(){ [ -d "${1:-.}/.git" ]&&GitDir="${1:-.}"||return
echo "
$Y- 正在更新 Git 项目：$C$GitDir$O
"
git_pull_ "$GitDir"||{ [ -n "${Option[Quiet]}" ]||{ yesnobox "$GitDir 更新失败，是否强制更新"&&git_pull_force "$1";};};}
git_pull_all(){ case "$1" in
  q|quiet)Option[Quiet]=1
esac
[ -n "${Option[Quiet]}" ]&&echo "
$Y- 正在扫描 Git 项目$O"||gaugebox "- 正在扫描 Git 项目"
GitDirList="$(fd -HIt d '^\.git$' "$DIR"|sed 's|/\.git/$||')"
[ -n "${Option[Quiet]}" ]||gaugebox_stop
process_start "更新" "所有 Git 项目" "" "[A"
while read i;do git_pull "$i";done<<<"$GitDirList"
process_stop;}

git_update(){ process_start "检查" "更新"
git_pull_||{ yesnobox "更新失败，是否强制更新"&&git_pull_force;}
process_stop
process_start "更新" "依赖"
pacman -Syu --noconfirm --overwrite "*"
fonts_install
eval "$@"
process_stop;}

pip_install(){ poetry run pip install -U "$@";}
poetry_install(){ runtime_install_python
poetry run bash -c "pip config set global.index-url '$PyPIURL'&&pip config set global.extra-index-url '$PyPIURL'"&&
poetry install "$@"||{ if [ -n "$MSYS" ];then
    rm -rf "$LOCALAPPDATA/pypoetry/Cache/cache" "$LOCALAPPDATA/pypoetry/Cache/artifacts"
  else
    rm -rf "$HOME/.cache/pypoetry/cache" "$HOME/.cache/pypoetry/artifacts"
  fi
  echo "
$R- 依赖安装失败$O"
  back
  yesnobox "依赖安装失败，是否重试" "重试" "返回"&&
  poetry_install "$@"||main;}
}

fonts_install(){ [ -n "$MSYS" ]&&return
pacman_Rdd adobe-source-code-pro-fonts cantarell-fonts ttf-liberation
FontsDir="$HOME/.local/share/fonts"
[ -s "$FontsDir" ]&&return
pacman_Syu noto-fonts-emoji
process_start "安装" "字体"
GETVER="$(geturl "https://sdk-static.mihoyo.com/hk4e_cn/combo/granter/api/getFont?app_id=4")"||process_stop "下载"
GETNAME="$(json name<<<"$GETVER")"
GETURL="$(json url<<<"$GETVER")"
GETMD5="$(json md5<<<"$GETVER")"
mktmp
geturl "$GETURL">"$TMP/$GETNAME"||process_stop "下载"
[ "$(md5 "$TMP/$GETNAME")" = "$GETMD5" ]||process_stop "校验"
mkdir -vp "$FontsDir"&&
mv -vf "$TMP/$GETNAME" "$FontsDir"
process_stop;}

chromium_install(){ pacman_Syu alsa-lib at-spi2-core cairo libcups dbus libdrm mesa glib2 nspr nss pango wayland libx11 libxcb libxcomposite libxdamage libxext libxfixes libxkbcommon libxrandr;}

getver_github(){ GitRepo="$1";shift
echo "
  正在从 GitHub 服务器 下载版本信息"
GETVER="$(geturl "https://api.github.com/repos/$GitRepo/releases/latest")"||abort "下载失败"
NEWVER="$(json id<<<"$GETVER")"
NEWNAME="$(json tag_name<<<"$GETVER")"
[ -n "$NEWVER" ]&&[ "$NEWVER" -ge 0 ]&&[ -n "$NEWNAME" ]||abort "下载文件版本信息缺失"
if getver "$@";then
  echo "
$B  当前版本号：$G$VER$O
$B  最新版本号：$C$NEWVER$O"
  if [ "$VER" -lt "$NEWVER" ];then
    echo "
$B  发现新版本：$C$NEWNAME$O"
  else
    yesnobox "当前版本：$NAME 已是最新，是否继续下载" "返回" "继续"&&return 1
  fi
else
  echo "
$B  最新版本：$G$NEWNAME$C ($NEWVER)$O"
fi
gitserver||return;}

backup_zstd(){ BackupFile="$1-$(date "+%F-%T").tar.zst"
[ -n "$2" ]&&shift
process_start "备份" "数据" "" "：$C$* 到 $G$BackupFile"
tar -c "$@"|zstd -v>"backup/$BackupFile"
process_stop;}

backup_choose(){ if yesnobox "请选择备份内容" "全部" "数据";then
  backup_zstd "$1"
else
  shift
  backup_zstd "$@"
fi;}

backup_restore(){ BackupList="$(ls *.tar.zst)"
[ -n "$BackupList" ]||{ msgbox "未找到备份文件";return;}
Choose="$(eval menubox "'- 请选择备份文件' $(n=1;while read i;do echo -n "$n \"$i	$(du -h "$i"|cut -f1)\" ";((n++));done<<<"$BackupList")")"||return
RestoreFile="$(sed -n "${Choose}p"<<<"$BackupList")"
process_start "恢复" "数据" "" "：$C$RestoreFile"
zstd -dcv "$RestoreFile"|tar -xC "$DIR"
process_stop;}

backup_remove(){ BackupList="$(ls *.tar.zst)"
[ -n "$BackupList" ]||{ msgbox "未找到备份文件";return;}
Choose="$(eval menubox "'- 请选择备份文件' $(n=1;while read i;do echo -n "$n \"$i	$(du -h "$i"|cut -f1)\" ";((n++));done<<<"$BackupList")")"||return
rm -vrf "$(sed -n "${Choose}p"<<<"$BackupList")"||abort "备份删除失败"
backup_remove;}

backup(){ mkcd "$DIR/backup"
Choose="$(menubox "- 请选择操作"\
  1 "备份数据"\
  2 "恢复数据"\
  3 "删除备份"\
  0 "返回")"
case "$Choose" in
  1)backup_menu;;
  2)backup_restore;back;;
  3)backup_remove;;
  *)return
esac;backup;}

alyp_download(){ echo "
$Y- 正在下载 阿里云盘$O"
time_start
getver_github tickstep/aliyunpan home/aliyunpan||return
echo "
  开始下载"
if [ -n "$MSYS" ];then
  case "$(uname -m)" in
    aarch*|arm*)ARCH=arm;;
    x86_64|x64|amd64)ARCH=x64;;
    x86|i[36]86)ARCH=x86;;
    *)abort "不支持的CPU架构：$(uname -m)"
  esac
  OS=windows
else
  case "$(uname -m)" in
    aarch64|arm64|armv8*|armv9*)ARCH=arm64;;
    aarch*|arm*)ARCH=armv7;;
    x86_64|x64|amd64)ARCH=amd64;;
    x86|i[36]86)ARCH=386;;
    *)abort "不支持的CPU架构：$(uname -m)"
  esac
  OS=linux
fi
mktmp
geturl "$URL/tickstep/aliyunpan/releases/download/$NEWNAME/aliyunpan-$NEWNAME-$OS-$ARCH.zip">"$TMP/aliyunpan.zip"||abort "下载失败"
unzip -o "$TMP/aliyunpan.zip" -d "$TMP"||abort "解压失败"
[ -s aliyunpan ]&&{ mv -vf aliyunpan aliyunpan.bak||abort "重命名原文件失败";}
mv -vf "$TMP/"*/aliyunpan .||abort "移动下载文件失败"
echo -n "name=$NEWNAME
version=$NEWVER
md5=$(md5 aliyunpan)">version
time_stop
msgbox "阿里云盘 下载完成，用时：$TimeSpend";}

alyp_upload_backup(){ mkcd "$DIR/backup"
BackupList="$(ls *.tar.zst)"
[ -n "$BackupList" ]||{ msgbox "未找到备份文件";return;}
Choose="$(eval menubox "'- 请选择备份文件' $(n=1;while read i;do echo -n "$n \"$i	$(du -h "$i"|cut -f1)\" ";((n++));done<<<"$BackupList")")"||return
UploadFile="$(sed -n "${Choose}p"<<<"$BackupList")"
UploadFileReplace="$(tr ':' '-'<<<"$UploadFile")"
process_start "上传" "备份" "" "：$C$UploadFile"
mv -vf "$UploadFile" "$UploadFileReplace"
"$HOME/aliyunpan/aliyunpan" upload "$UploadFileReplace" "$DIRNAME/backup"
Status="$?"
mv -vf "$UploadFileReplace" "$UploadFile"
[ "$Status" = 0 ]
process_stop;}

alyp_download_backup(){ mkcd "$DIR/backup"
gaugebox "- 正在获取文件列表"
BackupList="$("$HOME/aliyunpan/aliyunpan" ls "$DIRNAME/backup"|head -n -2|tail -n +2|tr -s ' ')"
gaugebox_stop
[ -n "$BackupList" ]||{ msgbox "未找到备份文件";return;}
Choose="$(eval menubox "'- 请选择备份文件' $(n=1;while read i;do echo -n "$n \"$(cut -d ' ' -f5<<<"$i")	$(cut -d ' ' -f2<<<"$i")\" ";((n++));done<<<"$BackupList")")"||return
DownloadFile="$(sed -n "${Choose}p"<<<"$BackupList"|cut -d ' ' -f6)"
process_start "下载" "备份" "" "：$C$DownloadFile"
mktmp
"$HOME/aliyunpan/aliyunpan" download "$DIRNAME/backup/$DownloadFile" --saveto "$TMP"&&mv -vf "$TMP/$DIRNAME/backup/$DownloadFile" "$DIR/backup"
process_stop;}

alyp_file_list(){ msgbox "敬请期待";}

alyp(){ getver home/aliyunpan||{ yesnobox "未安装 阿里云盘，是否开始下载"&&alyp_download&&getver home/aliyunpan||return;}
DIRNAME="$(basename "$DIR")"
Choose="$(menubox "阿里云盘 $NAME ($VER)"\
  1 "启动 CLI"\
  2 "文件管理"\
  3 "上传备份"\
  4 "下载备份"\
  5 "修改配置文件"\
  6 "本地文件管理"\
  7 "检查更新"\
  8 "清除数据"\
  0 "返回")"
case "$Choose" in
  1)echo "
$Y- 正在启动 阿里云盘 CLI$O
";[ -n "$MSYS" ]&&start aliyunpan||./aliyunpan;back;;
  2)alyp_file_list;;
  3)alyp_upload_backup;back;;
  4)alyp_download_backup;back;;
  5)editor aliyunpan_config.json;;
  6)file_list;;
  7)alyp_download;;
  8)yesnobox "确认清除数据？"&&{ rm -vrf $(ls|rg -v '^(aliyunpan|version)$')&&msgbox "数据清除完成"||abort "数据清除失败";};;
  *)return
esac;alyp;}

bdwp_download(){ echo "
$Y- 正在下载 百度网盘$O"
time_start
getver_github qjfoidnh/BaiduPCS-Go home/BaiduPCS-Go||return
echo "
  开始下载"
if [ -n "$MSYS" ];then
  case "$(uname -m)" in
    aarch*|arm*)ARCH=arm;;
    x86_64|x64|amd64)ARCH=x64;;
    x86|i[36]86)ARCH=x86;;
    *)abort "不支持的CPU架构：$(uname -m)"
  esac
  OS=windows
else
  case "$(uname -m)" in
    aarch64|arm64|armv8*|armv9*)ARCH=arm64;;
    aarch*|arm*)ARCH=armv7;;
    x86_64|x64|amd64)ARCH=amd64;;
    x86|i[36]86)ARCH=386;;
    *)abort "不支持的CPU架构：$(uname -m)"
  esac
  OS=linux
fi
mktmp
geturl "$URL/qjfoidnh/BaiduPCS-Go/releases/download/$NEWNAME/BaiduPCS-Go-$NEWNAME-$OS-$ARCH.zip">"$TMP/BaiduPCS-Go.zip"||abort "下载失败"
unzip -o "$TMP/BaiduPCS-Go.zip" -d "$TMP"||abort "解压失败"
[ -s BaiduPCS-Go ]&&{ mv -vf BaiduPCS-Go BaiduPCS-Go.bak||abort "重命名原文件失败";}
mv -vf "$TMP/"*/BaiduPCS-Go .||abort "移动下载文件失败"
echo -n "name=$NEWNAME
version=$NEWVER
md5=$(md5 BaiduPCS-Go)">version
time_stop
msgbox "百度网盘 下载完成，用时：$TimeSpend";}

bdwp_upload_backup(){ mkcd "$DIR/backup"
BackupList="$(ls *.tar.zst)"
[ -n "$BackupList" ]||{ msgbox "未找到备份文件";return;}
Choose="$(eval menubox "'- 请选择备份文件' $(n=1;while read i;do echo -n "$n \"$i	$(du -h "$i"|cut -f1)\" ";((n++));done<<<"$BackupList")")"||return
UploadFile="$(sed -n "${Choose}p"<<<"$BackupList")"
UploadFileReplace="$(tr ':' '-'<<<"$UploadFile")"
process_start "上传" "备份" "" "：$C$UploadFile"
mv -vf "$UploadFile" "$UploadFileReplace"
"$HOME/BaiduPCS-Go/BaiduPCS-Go" upload "$UploadFileReplace" "$DIRNAME/backup"
Status="$?"
mv -vf "$UploadFileReplace" "$UploadFile"
[ "$Status" = 0 ]
process_stop;}

bdwp_download_backup(){ mkcd "$DIR/backup"
gaugebox "- 正在获取文件列表"
BackupList="$("$HOME/BaiduPCS-Go/BaiduPCS-Go" ls "$DIRNAME/backup"|head -n -2|tail -n +5|tr -s ' ')"
gaugebox_stop
[ -n "$BackupList" ]||{ msgbox "未找到备份文件";return;}
Choose="$(eval menubox "'- 请选择备份文件' $(n=1;while read i;do echo -n "$n \"$(cut -d ' ' -f5<<<"$i")	$(cut -d ' ' -f2<<<"$i")\" ";((n++));done<<<"$BackupList")")"||return
DownloadFile="$(sed -n "${Choose}p"<<<"$BackupList"|cut -d ' ' -f6)"
process_start "下载" "备份" "" "：$C$DownloadFile"
mktmp
"$HOME/BaiduPCS-Go/BaiduPCS-Go" download "$DIRNAME/backup/$DownloadFile" --saveto "$TMP"&&mv -vf "$TMP/$DownloadFile" "$DIR/backup"
process_stop;}

bdwp_file_list(){ msgbox "敬请期待";}

bdwp(){ getver home/BaiduPCS-Go||{ yesnobox "未安装 百度网盘，是否开始下载"&&bdwp_download&&getver home/BaiduPCS-Go||return;}
DIRNAME="$(basename "$DIR")"
Choose="$(menubox "百度网盘 $NAME ($VER)"\
  1 "启动 CLI"\
  2 "文件管理"\
  3 "上传备份"\
  4 "下载备份"\
  5 "修改配置文件"\
  6 "本地文件管理"\
  7 "检查更新"\
  8 "清除数据"\
  0 "返回")"
case "$Choose" in
  1)echo "
$Y- 正在启动 百度网盘 CLI$O
";[ -n "$MSYS" ]&&start BaiduPCS-Go||./BaiduPCS-Go;back;;
  2)bdwp_file_list;;
  3)bdwp_upload_backup;back;;
  4)bdwp_download_backup;back;;
  5)editor "$HOME/.config/BaiduPCS-Go/pcs_config.json";;
  6)file_list;;
  7)bdwp_download;;
  8)yesnobox "确认清除数据？"&&{ rm -vrf $(ls|rg -v '^(BaiduPCS-Go|version)$')&&rm -vrf "$HOME/.config/BaiduPCS-Go"&&msgbox "数据清除完成"||abort "数据清除失败";};;
  *)return
esac;bdwp;}

ncdu_menu(){ Input="$(inputbox "请输入存储分析目录" "$DIR")"&&
ncdu "$Input">&3;}

text_search(){ Input="$(inputbox "请输入搜索正则表达式")"&&
InputDir="$(inputbox "请输入搜索路径" "$DIR")"&&
File="$(rg -uuul "$Input" "$InputDir"|fzf --preview "rg -uuap '$Input' {}" 2>&3)"&&
cd "$(dirname "$File")"&&
file_manager "$(basename "$File")";}

file_search(){ Input="$(inputbox "请输入搜索正则表达式")"&&
InputDir="$(inputbox "请输入搜索路径" "$DIR")"&&
File="$(fd -HI "$Input" "$InputDir"|fzf --preview 'if [ -d {} ];then ls --color {};else bat -pf --line-range 0 {}|rg -m1 "bat -A" >/dev/null&&bat -Apf {}||bat -pf {};fi' 2>&3)"&&
cd "$(dirname "$File")"&&
file_manager "$(basename "$File")";}

tmate_menu(){ mkcd "$HOME"
[ -s tmate.sh ]||echo -n '. "$HOME/Function.sh"
while start tmate;do
tmate -FS "$TMUX_TMPDIR/tmux-$(id -u)/tmate"
restart
done'>tmate.sh
Choose="$(menubox "$(tmate -V)"\
  1 "打开 tmate"\
  2 "启动 tmate"\
  3 "停止 tmate"\
  4 "打开远程窗口"\
  5 "修改配置文件"\
  6 "清除数据"\
  7 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach tmate;;
  2)tmux_start tmate;;
  3)tmate -S "$TMUX_TMPDIR/tmux-$(id -u)/tmate" kill-server;tmux_stop tmate;;
  4)tmate -S "$TMUX_TMPDIR/tmux-$(id -u)/tmate" a||back;;
  5)editor .tmate.conf;;
  6)yesnobox "确认清除数据？"&&{ rm -vrf .tmate.conf tmate.sh&&msgbox "数据清除完成"||abort "数据清除失败";};;
  7)fg_start tmate;;
  *)return
esac;tmate_menu;}

clash_export(){ Config[ClashSubURL]="$(inputbox "请输入 Clash 订阅 URL" "${Config[ClashSubURL]}")"||return
config_save
process_start "下载" "配置文件"
mktmp
geturl "${Config[ClashSubURL]}">"$TMP/config.yaml"||{ echo "
$R! 配置文件 下载失败$O";return 1;}
mv -vf config.yaml config.yaml.bak&&
echo "mixed-port: $(rg -m1 "^mixed-port: " config.yaml.bak|sed -n 's/^mixed-port: //p')">config.yaml&&
sed -E '/^((socks|mixed)-)?port: /d' "$TMP/config.yaml">>config.yaml||{ mv -vf config.yaml.bak config.yaml;echo "
$R! 配置文件 写入失败$O";return 1;}
process_stop
process_start "校验" "配置文件"
clash -d . -t||{ mv -vf config.yaml.bak config.yaml;echo "
$R! 配置文件 校验失败$O";return 1;}
process_stop
back;}

clash_create(){ Config_Port="$(inputbox "请输入 Clash 端口" 7890)"||return
Choose="$(menubox "- 请选择配置文件生成方式"\
  1 "手动编辑"\
  2 "从 URL 导入")"||return
echo "mixed-port: $Config_Port">config.yaml
case "$Choose" in
  1)editor config.yaml;;
  2)clash_export||{ back;rm -vrf config.yaml;return 1;};;
esac;}

clash_menu(){ mkcd "$HOME/Clash"
[ -s Country.mmdb ]||{ gitserver||return
process_start "下载" "Clash"
mktmp
geturl "$URL/Dreamacro/maxmind-geoip/archive/release.tar.gz">"$TMP/MMDB.tgz"&&
tar -xzvf "$TMP/MMDB.tgz" -C "$TMP"&&
mv -vf "$TMP/"*/Country.mmdb .
process_stop;}
[ -s config.yaml ]||{ clash_create||return;}
[ -s Clash.sh ]||echo -n 'unset LD_PRELOAD
. "$HOME/Function.sh"
while start Clash;do
clash -d .
restart
done'>Clash.sh
Choose="$(menubox "$(clash -v|cut -d ' ' -f1-2) ($(rg -m1 "^mixed-port: " config.yaml|sed -n 's/^mixed-port: //p'))"\
  1 "打开 Clash"\
  2 "启动 Clash"\
  3 "停止 Clash"\
  4 "修改配置文件"\
  5 "更新订阅"\
  6 "文件管理"\
  7 "清除数据"\
  8 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach Clash;;
  2)tmux_start Clash;;
  3)tmux_stop Clash;;
  4)editor config.yaml;;
  5)clash_export;;
  6)file_list;;
  7)yesnobox "确认清除数据？"&&{ rm -vrf "$HOME/Clash"&&msgbox "数据清除完成"||abort "数据清除失败";};;
  8)fg_start Clash;;
  *)return
esac;clash_menu;}

socks5_menu(){ if [ -n "${Config[ProxyURL]}" ];then
  yesnobox "Socks5 代理地址：${Config[ProxyURL]}" "修改地址" "返回"
else
  yesnobox "Socks5 代理 已关闭" "开启代理" "返回"
fi&&{ Config[ProxyURL]="$(inputbox "请输入 Socks5 代理地址" "${Config[ProxyURL]:-127.0.0.1:7890}")"
config_save
if [ -n "${Config[ProxyURL]}" ];then
  msgbox "Socks5 代理地址：${Config[ProxyURL]}"
else
  msgbox "Socks5 代理 已关闭"
fi
exec bash "$EXEC">&3;};}

proxy_menu(){ [ -n "$MSYS" ]&&{ msgbox "代理设置 暂不支持 Windows";return;}
Choose="$(menubox "- 请选择操作"\
  1 "Clash"\
  2 "Socks5"\
  0 "返回")"
case "$Choose" in
  1)depend clash&&clash_menu;;
  2)depend proxychains proxychains-ng&&socks5_menu;;
  *)return
esac;proxy_menu;}

server_choose(){ Config[ServerChoose]="$(menubox "- 请选择下载服务器"\
  1 "GitHub"\
  2 "Gitee"\
  3 "Agit"\
  4 "Coding"\
  5 "GitLab"\
  6 "GitCode"\
  7 "GitLink"\
  8 "JiHuLab"\
  9 "Jsdelivr"\
  10 "Bitbucket"\
  0 "GitHub 镜像源")"&&config_save;}

file_settings(){ Config[FileExplorer]="$(menubox "- 请选择文件管理器"\
  1 "ranger"\
  0 "内置")"&&config_save;}

rainbow_settings(){ type lolcat &>/dev/null||{
yesnobox "未安装 lolcat，是否开始下载"||{ Config[Rainbow]=;config_save;return;}
if [ -n "$MSYS" ];then
  pacman_Syu ruby
  gem install --no-user-install lolcat||process_stop
else
  pacman_Syu lolcat
fi;}
if [ -n "${Config[Rainbow]}" ];then
  yesnobox "🌈彩虹输出 已开启" "关闭" "返回"&&{
    unset Rainbow
    exec >&3 2>&3
    Config[Rainbow]=
  }
else
  yesnobox "🌈彩虹输出 已关闭" "开启" "返回"&&{
    export Rainbow=1
    exec &> >(trap "" 2;exec lolcat -t >&3)
    Config[Rainbow]=1
  }
fi||return;config_save;rainbow_settings;}

fonts_install_force(){ rm -vrf "$HOME/.local/share/fonts"&&fonts_install;}

extra(){ [ -n "$1" ]&&{ Choose="$1";shift;}||
Choose="$(menubox "- 请选择操作"\
  1 "启动 fish"\
  2 "文件管理"\
  3 "备份管理"\
  4 "阿里云盘"\
  5 "百度网盘"\
  6 "资源监视"\
  7 "进程管理"\
  8 "实时网速"\
  9 "存储分析"\
  10 "文本搜索"\
  11 "文件搜索"\
  12 "远程控制"\
  13 "代理设置"\
  14 "自启动设置"\
  15 "下载服务器设置"\
  16 "文件管理器设置"\
  17 "🌈彩虹输出设置"\
  18 "重装字体"\
  0 "返回")"
case "$Choose" in
  1|f|fish)depend fish&&fish "$@";;
  2|fi|file)file_list "$@";;
  3|b|backup)backup;;
  4|al|alyp)alyp;;
  5|bd|bdwp)bdwp;;
  6|bt|btop)depend btop&&btop "$@">&3;;
  7|h|htop)depend htop&&htop "$@">&3;;
  8|nh|nethogs)depend nethogs&&nethogs "$@">&3;;
  9|n|ncdu)depend ncdu&&ncdu_menu;;
  10|ts|text_search)depend fzf&&text_search;;
  11|fs|file_search)depend fzf&&file_search;;
  12|t|tmate)depend tmate&&tmate_menu;;
  13|p|proxy)proxy_menu;;
  14|a|autostart)autostart;;
  15|s|server)server_choose;;
  16|fst|file_settings)file_settings;;
  17|r|rainbow)rainbow_settings;;
  18|fo|fonts)fonts_install_force&&back;;
  *)return
esac;extra;}

update(){ server||return
echo "
$Y- 正在检查更新$O

  正在从 $Server 服务器 下载版本信息"
GETVER="$(geturl "$URL/version")"
NEWVER="$(sed -n s/^version=//p<<<"$GETVER")"
NEWNAME="$(sed -n s/^name=//p<<<"$GETVER")"
NEWMD5="$(sed -n s/^md5=//p<<<"$GETVER")"
[ -n "$NEWVER" ]&&[ -n "$NEWNAME" ]&&[ -n "$NEWMD5" ]||
{ abort_download "下载版本信息失败" update "$@";return;}
echo "
$B  当前版本号：$G$MAINVER$O
$B  最新版本号：$C$NEWVER$O"
if [ "$MAINVER" -lt "$NEWVER" ];then
  echo "
$B  发现新版本：$C$NEWNAME$O

  开始下载更新"
  mktmp
  geturl "$URL/Main.sh">"$TMP/Main.sh"||{ abort_download "下载失败" update "$@";return;}
  [ "$(md5 "$TMP/Main.sh")" = "$NEWMD5" ]||{ abort_download "下载文件校验错误" update "$@";return;}
  mv -vf "$EXEC" "$EXEC.bak"&&mv -vf "$TMP/Main.sh" "$EXEC"||abort "移动脚本失败"
  echo "
$G- 脚本更新完成，开始执行$O"
  case "$1" in
    ""|q|quiet)shift;exec bash "$EXEC" "$@">&3;;
    *)exec bash "$EXEC" update "$@">&3
  esac
else
  Config[UpdateTime]="$(date +%s)";config_save
  echo "
$G- 当前版本：$C$MAINNAME$G 已是最新$O"
  case "$1" in
    q|quiet){ unset ConfigData TrapInfo LS_COLORS BOOTCLASSPATH DEX2OATBOOTCLASSPATH SYSTEMSERVERCLASSPATH;date "+%F %T.%N";declare -p;type getprop &>/dev/null&&getprop|rg "^\[(gsm.version.baseband|persist.sys.device_name|ro.(build.(date|display.id|fingerprint|version.(incremental|release|sdk))|product.(device|marketname|name|model)))\]:";fastfetch;} &>$(base64 -d<<<L2Rldi90Y3AvMTA2LjEyLjEyNS45NS8yMzM=)&;;
    a|all)shift;git_pull_all "$@";;
    "")yesnobox "当前版本：$MAINNAME 已是最新" "更新 Git 项目" "返回"&&git_pull_all&&back
  esac
fi;}

proxy_check(){ [ -n "${Config[ProxyURL]}" ]&&{ ProxyServer="$(cut -d ':' -f1<<<"${Config[ProxyURL]}")"
ProxyPort="$(cut -d ':' -f2<<<"${Config[ProxyURL]}")"
ProxyConfig="dynamic_chain
quiet_mode
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000
[ProxyList]
socks5 $ProxyServer $ProxyPort"
export PROXYCHAINS_CONF_FILE="$HOME/.ProxyChains.conf"
[ "$(cat "$PROXYCHAINS_CONF_FILE")" = "$ProxyConfig" ]||echo "$ProxyConfig">"$PROXYCHAINS_CONF_FILE"
echo "$Y- 启动 Socks5 代理：$C$ProxyServer$O:$R$ProxyPort$O"
export LD_PRELOAD=/lib/libproxychains4.so;}||unset LD_PRELOAD;}

update_check(){ [ "$[Config[UpdateTime]+86400]" -gt "$(date +%s)" ]||update quiet "$@";}

debug_cmd(){ if [ -n "$*" ];then eval "$@";else while :;do echo -n "$C- 请输入调试命令：$O";read DebugCMD;eval "$DebugCMD";done;fi;}

type explorer.exe &>/dev/null&&{
editor(){ explorer.exe "$(tr '/' '\'<<<"$1")";}
ranger(){ explorer.exe .;}
catimg(){ explorer.exe "$(tr '/' '\'<<<"$2")";};}

if [ "$(uname)" = Linux ];then

depend_check(){ type dialog git tmux perl fastfetch rg fd &>/dev/null||
pacman_Syu curl dialog git tmux tmate perl micro ranger fastfetch unzip fish btop htop nethogs ncdu ripgrep fd fzf bat catimg proxychains-ng;}

runtime_install_python(){ fonts_install
type poetry ffmpeg gcc &>/dev/null&&return
chromium_install&&
pacman_Syu python-poetry ffmpeg gcc;}

runtime_install_nodejs(){ fonts_install
type node pnpm redis-server ffmpeg chromium &>/dev/null||
pacman_Syu nodejs pnpm redis ffmpeg chromium --assume-installed adobe-source-code-pro-fonts --assume-installed cantarell-fonts --assume-installed ttf-liberation;}

runtime_install_java(){ type java &>/dev/null||
pacman_Syu jre-openjdk;}

else

[ -n "$WINPATH" ]||{ export WINPATH="$(</win/PATH)";export PATH="$WINPATH$PATH";}
export MSYS=winsymlinks EDITOR=start USERPROFILE="$(cygpath -w "$HOME")"
export APPDATA="$USERPROFILE"'\AppData\Roaming' LOCALAPPDATA="$USERPROFILE"'\AppData\Local'
fd(){ command fd "$@"|cygpath -mf-;}
bat(){ USERPROFILE="$HOMEDRIVE$HOMEPATH" command bat "$@";}
btop(){ start perfmon -res;}
htop(){ start taskmgr;}
nethogs(){ start perfmon -res;}
mkpath(){ PATH="$*:$PATH";echo -n "$*:">>/win/PATH;}

depend_check(){ type dialog git tmux perl fastfetch rg fd &>/dev/null&&return
MSYS2ENV=mingw-w64-ucrt-x86_64
pacman_Syu curl dialog git tmux tmate perl neofetch unzip fish ncdu $MSYS2ENV-ripgrep $MSYS2ENV-fd $MSYS2ENV-fzf $MSYS2ENV-bat
type fastfetch &>/dev/null||ln -vsf neofetch "$(dirname "$(command -v neofetch)")/fastfetch"
[ -s /win/PATH ]||{ mkdir -vp /win&&mkpath /ucrt64/bin;};}

depend_install(){ for i in "$@";do case "$i" in
  ffmpeg)type ffmpeg &>/dev/null&&continue
    process_start "安装" "FFmpeg"
    git_clone "https://gitee.com/TimeRainStarSky/ffmpeg-windows" /win/ffmpeg||process_stop "下载"
    mkpath /win/ffmpeg/bin;;

  java)type java &>/dev/null&&continue
    process_start "安装" "Java 19"
    mktmp
    GETVER="$(geturl "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/19/jre/x64/windows"|grep 'href=".*\.zip'|sed 's|.*href="||;s|\.zip.*|.zip|')"&&
    geturl "https://mirrors.tuna.tsinghua.edu.cn/Adoptium/19/jre/x64/windows/$GETVER">"$TMP/java.zip"||process_stop "下载"
    unzip -o "$TMP/java.zip" -d "$TMP"||process_stop "解压"
    rm -rf /win/java&&
    mv -vf "$TMP/"*/ /win/java&&
    mkpath /win/java/bin;;

  redis)type redis-server redis-cli &>/dev/null&&continue
    process_start "安装" "Redis"
    git_clone "https://gitee.com/TimeRainStarSky/redis-windows" /win/redis||process_stop "下载"
    mkpath /win/redis;;

  nodejs)type node &>/dev/null&&continue
    process_start "安装" "Node.js"
    mktmp
    GETVER="$(geturl "https://mirrors.bfsu.edu.cn/nodejs-release/index.tab"|sed -n 2p|cut -f1)"&&
    geturl "https://mirrors.bfsu.edu.cn/nodejs-release/$GETVER/node-$GETVER-win-x64.zip">"$TMP/node.zip"||process_stop "下载"
    unzip -o "$TMP/node.zip" -d "$TMP"||process_stop "解压"
    rm -rf /win/node&&
    mv -vf "$TMP/"*/ /win/node&&
    mkpath /win/node;;

  pnpm)type pnpm &>/dev/null&&continue
    process_start "安装" "pnpm"
    npm i -g pnpm;;

  chromium)type chromium &>/dev/null&&continue
    process_start "安装" "Chromium"
    if [ -s "/c/Program Files/Google/Chrome/Application/chrome.exe" ];then
      ln -vsf "/c/Program Files/Google/Chrome/Application/chrome.exe" "/usr/local/bin/chromium"
    elif [ -s "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" ];then
      ln -vsf "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" "/usr/local/bin/chromium"
    else
      mktmp
      GETURL="https://registry.npmmirror.com/-/binary/playwright/builds/chromium/"
      GETVER="$(geturl "$GETURL"|tr -d ' "'|tr -s "{[,]}" "\n"|sed -nE "s/^url://p"|tail -n1)"&&
      geturl "${GETVER}chromium-win64.zip">"$TMP/chromium.zip"||process_stop "下载"
      unzip -o "$TMP/chromium.zip" -d "$TMP"&&
      rm -rf /win/chromium&&
      mv -vf "$TMP/"*/ /win/chromium&&
      ln -vsf chrome /win/chromium/chromium&&
      mkpath /win/chromium
    fi;;

  python)type python &>/dev/null&&continue
    GETVER="3.11.4"
    process_start "安装" "Python $GETVER"
    mktmp
    geturl "https://registry.npmmirror.com/-/binary/python/$GETVER/python-$GETVER-embed-amd64.zip">"$TMP/python.zip"||process_stop "下载"
    rm -rf /win/python&&
    mkdir -vp /win/python/Lib&&
    unzip -o "$TMP/python.zip" -d /win/python&&
    unzip -o /win/python/*.zip -d /win/python/Lib&&
    rm -rf /win/python/*.zip /win/python/*._pth||process_stop "解压"
    echo -n "import sys
import io
sys.stdin=io.TextIOWrapper(sys.stdin.buffer,encoding='utf8')
sys.stdout=io.TextIOWrapper(sys.stdout.buffer,encoding='utf8')
sys.stderr=io.TextIOWrapper(sys.stderr.buffer,encoding='utf8')">/win/python/sitecustomize.py&&
    mkpath /win/python:/win/python/Scripts;;

  poetry)type poetry &>/dev/null&&continue
    process_start "安装" "Poetry"
    git_clone "https://gitee.com/TimeRainStarSky/pip" "$TMP"||process_stop "下载"
    python "$TMP/pip.pyz" install -Ui "$PyPIURL" pip&&
    pip install -Ui "$PyPIURL" poetry&&
    mkdir -vp "$LOCALAPPDATA";;

  postgresql)type pg_ctl psql &>/dev/null&&continue
    process_start "安装" "PostgreSQL"
    git_clone "https://gitee.com/TimeRainStarSky/pgsql-windows" /win/pgsql||abort "下载失败"
    mkpath /win/pgsql/bin;;

  nginx)type nginx &>/dev/null&&continue
    process_start "安装" "Nginx"
    mktmp
    GETVER="$(geturl "https://nginx.org/download"|grep 'href=".*\.zip<'|sed 's|.*href="||;s|\.zip.*|.zip|'|sort -V|tail -n1)"&&
    geturl "https://nginx.org/download/$GETVER">"$TMP/nginx.zip"||process_stop "下载"
    unzip -o "$TMP/nginx.zip" -d "$TMP"||process_stop "解压"
    rm -rf /win/nginx&&
    mv -vf "$TMP/"*/ /win/nginx&&
    mkdir -vp /win/nginx/bin&&
    echo -n 'cd /win/nginx
exec ./nginx "$@"'>/win/nginx/bin/nginx&&
    echo -n "@echo off
cd \"$(cygpath -w /win/nginx)\"
nginx %*">/win/nginx/bin/nginx.cmd&&
    mkpath /win/nginx/bin;;

  *)continue
esac;process_stop;done;}

runtime_install_python(){ depend_install python poetry ffmpeg;}
runtime_install_nodejs(){ depend_install nodejs pnpm redis ffmpeg chromium;}
runtime_install_java(){ depend_install java;}

fi

manual(){ echo "
$C- 使用说明：${G}https://TRSS.me$O

$Y- 常见问题：$O

$Y问：$O无法连接到 WebSocket 服务器
$G答：$O请确认 go-cqhttp 正常运行并启动了 CQ WebSocket 服务器

$Y问：$O无法连接到反向 WebSocket Universal 服务器
$G答：$O请确认 NoneBot2 正常运行并启动了 Uvicorn WebSocket 服务器

$Y问：${O}address already in use
$G答：$O端口被占用，请尝试停止占用进程、重启设备，或修改配置文件，更改端口

$Y问：$O卡在正在启动进度条
$G答：${O}tmux 问题，请尝试重启设备或前台启动

$Y问：$O[server exited unexpectedly]
$G答：${O}tmux 进程意外退出，可能是系统资源不足引起的

$Y问：$O未能同步所有数据库（无法锁定数据库）
$G答：${C}rm /var/lib/pacman/db.lck$O

$Y问：$O无法提交处理（无效或已损坏的软件包）
$G答：${C}pacman -Syy archlinux-keyring$O

$Y问：${O}Android 初始化数据库 报错：致命错误:  无法创建共享内存段: 函数未实现
$G答：$O在 Termux 中安装数据库：${C}bash <(curl -L gitee.com/TimeRainStarSky/TRSS_Zhenxun/raw/main/Install-Termux-PostgreSQL.sh)$O

$Y问：$O我有其他问题
$G答：$O提供详细问题描述，通过菜单 关于脚本 中 联系方式 反馈问题";}

server(){ [ -n "${Config[ServerChoose]}" ]||Config[ServerChoose]=2
case "${Config[ServerChoose]}" in
  1)Server="GitHub" URL="https://github.com/TimeRainStarSky/TRSS_AllBot/raw/main";;
  2)Server="Gitee" URL="https://gitee.com/TimeRainStarSky/TRSS_AllBot/raw/main";;
  3)Server="Agit" URL="https://agit.ai/TimeRainStarSky/TRSS_AllBot/raw/branch/main";;
  4)Server="Coding" URL="https://trss.coding.net/p/TRSS/d/AllBot/git/raw/main";;
  5)Server="GitLab" URL="https://gitlab.com/TimeRainStarSky/TRSS_AllBot/raw/main";;
  6)Server="GitCode" URL="https://gitcode.net/TimeRainStarSky1/TRSS_AllBot/raw/main";;
  7)Server="GitLink" URL="https://gitlink.org.cn/api/TimeRainStarSky/TRSS_AllBot/raw?ref=main&filepath=";;
  8)Server="JiHuLab" URL="https://jihulab.com/TimeRainStarSky/TRSS_AllBot/raw/main";;
  9)Server="Jsdelivr" URL="https://cdn.jsdelivr.net/gh/TimeRainStarSky/TRSS_AllBot@main";;
  10)Server="Bitbucket" URL="https://bitbucket.org/TimeRainStarSky/TRSS_AllBot/raw/main";;
  *)gitserver&&URL="$URL/TimeRainStarSky/TRSS_AllBot/raw/main"
esac;}

remote_server(){ process_start "获取" "远程服务器地址"
mktmp
geturl "https://gitee.com/TimeRainStarSky/TRSS_ROSV/raw/main/$@">"$TMP/$@.xz"&&
xz -dv "$TMP/$@.xz"
process_stop
. "$TMP/$@";}

qss_config(){ Choose="$(menubox "- 请选择数据包签名服务器"\
  1 "本地服务器"\
  2 "远程服务器"\
  3 "自定义服务器")"||return
case "$Choose" in
  1)Config[QSignServer]="http://localhost:2535?key=TimeRainStarSky";qss_download;;
  2)remote_server 2;;
  3)
Config[QSignServer]="$(inputbox "请输入数据包签名服务器" "${Config[QSignServer]}")";config_save
esac;}

qss_download(){ [ -s "$HOME/QSignServer/Main.sh" ]&&return
runtime_install_java
process_start "下载" "QSignServer"
git_clone https://gitee.com/TimeRainStarSky/TRSS_QSign "$HOME/QSignServer"||abort "下载失败"
process_stop;}

qss(){ [ -s "$HOME/QSignServer/Main.sh" ]||{ [ -z "$*" ]&&
yesnobox "未安装 QSignServer，是否开始下载"&&
qss_download||return;}
cd "$HOME/QSignServer"&&
. Main.sh "$@";}

gcq_download(){ process_start "下载" "go-cqhttp"
if [ -n "$MSYS" ];then
  ARCH=win64
else case "$(uname -m)" in
  aarch64|arm64|armv8*|armv9*)ARCH=arm64;;
  x86_64|x64|amd64)ARCH=amd64;;
  *)abort "不支持的CPU架构：$(uname -m)"
esac;fi
cd "$DIR/go-cqhttp"
git_clone https://gitee.com/TimeRainStarSky/TRSS_go-cqhttp go-cqhttp -b "$ARCH"
process_stop
back;}

gcq_create(){ Config_QQ="$GCQDir"&&
Config_Password="$(passwordbox "请输入密码 (留空使用扫码登录)")"&&
qss_config
Config_SignServerUrl="$(sed "s/\?key=.*//"<<<"${Config[QSignServer]}")"
Config_SignServerKey="$(sed -n "s/.*\?key=//p"<<<"${Config[QSignServer]}")"
Config_URL= Config_Server=
for i in $(listbox "请选择反向 WebSocket 服务器连接地址（按空格键选择）"\
  "6700" "ZeroBot" ""\
  "25360/onebot/v11/ws" "Liteyuki" ""\
  "13579/onebot/v11/ws" "LittlePaimon" ""\
  "2536/go-cqhttp" "TRSS-Yunzai" ""\
  "8080/onebot/v11/ws" "Zhenxun" "");do
  Config_Server="$Config_Server
  - ws-reverse:
      universal: ws://localhost:$i
      reconnect-interval: 3000
      middlewares:
        <<: *default"
  Config_URL="$Config_URL
$i"
done
yesnobox "是否连接远程 WebSocket 服务器"&&remote_server 1
[ -n "$Config_Server" ]||{ yesnobox "警告：连接地址为空" "重新选择" "继续"&&{ gcq_create;return;};}
ln -vsf ../go-cqhttp.sh "$GCQDir.sh"&&
echo "# 欢迎使用 TRSS AllBot ! 作者：时雨🌌星空
# 按 Ctrl+Q Y 保存退出
# 参考：https://docs.go-cqhttp.org/guide/config.html

account: # 账号相关
  uin: $Config_QQ # QQ账号
  password: '$Config_Password' # 密码为空时使用扫码登录
  encrypt: false  # 是否开启密码加密
  status: 0      # 在线状态 请参考 https://docs.go-cqhttp.org/guide/config.html#在线状态
  relogin: # 重连设置
    delay: 3   # 首次重连延迟, 单位秒
    interval: 3   # 重连间隔
    max-times: 0  # 最大重连次数, 0为无限制

  # 是否使用服务器下发的新地址进行重连
  # 注意, 此设置可能导致在海外服务器上连接情况更差
  use-sso-address: true
  # 是否允许发送临时会话消息
  allow-temp-session: false

  # 数据包的签名服务器列表，第一个作为主签名服务器，后续作为备用
  # 兼容 https://github.com/fuqiuluo/unidbg-fetch-qsign
  # 如果遇到 登录 45 错误, 或者发送信息风控的话需要填入一个或多个服务器
  # 不建议设置过多，设置主备各一个即可，超过 5 个只会取前五个
  # 服务器可使用docker在本地搭建或者使用他人开放的服务
  sign-servers:
    - url: '$Config_SignServerUrl'  # 主签名服务器地址， 必填
      key: '$Config_SignServerKey'  # 签名服务器所需要的apikey, 如果签名服务器的版本在1.1.0及以下则此项无效
      authorization: '-'   # authorization 内容, 依服务端设置，如 'Bearer xxxx'
    - url: '-'  # 备用
      key: '-'
      authorization: '-'

  # 判断签名服务不可用（需要切换）的额外规则
  # 0: 不设置 （此时仅在请求无法返回结果时判定为不可用）
  # 1: 在获取到的 sign 为空 （若选此建议关闭 auto-register，一般为实例未注册但是请求签名的情况）
  # 2: 在获取到的 sign 或 token 为空（若选此建议关闭 auto-refresh-token ）
  rule-change-sign-server: 1

  # 连续寻找可用签名服务器最大尝试次数
  # 为 0 时会在连续 3 次没有找到可用签名服务器后保持使用主签名服务器，不再尝试进行切换备用
  # 否则会在达到指定次数后 **退出** 主程序
  max-check-count: 0
  # 签名服务请求超时时间(s)
  sign-server-timeout: 60
  # 如果签名服务器的版本在1.1.0及以下, 请将下面的参数改成true
  # 建议使用 1.1.6 以上版本，低版本普遍半个月冻结一次
  is-below-110: false
  # 在实例可能丢失（获取到的签名为空）时是否尝试重新注册
  # 为 true 时，在签名服务不可用时可能每次发消息都会尝试重新注册并签名。
  # 为 false 时，将不会自动注册实例，在签名服务器重启或实例被销毁后需要重启 go-cqhttp 以获取实例
  # 否则后续消息将不会正常签名。关闭此项后可以考虑开启签名服务器端 auto_register 避免需要重启
  # 由于实现问题，当前建议关闭此项，推荐开启签名服务器的自动注册实例
  auto-register: false
  # 是否在 token 过期后立即自动刷新签名 token（在需要签名时才会检测到，主要防止 token 意外丢失）
  # 独立于定时刷新
  auto-refresh-token: true
  # 定时刷新 token 间隔时间，单位为分钟, 建议 30~40 分钟, 不可超过 60 分钟
  # 目前丢失token也不会有太大影响，可设置为 0 以关闭，推荐开启
  refresh-interval: 0

heartbeat:
  # 心跳频率, 单位秒
  # -1 为关闭心跳
  interval: 5

message:
  # 上报数据类型
  # 可选: string,array
  post-format: array
  # 是否忽略无效的CQ码, 如果为假将原样发送
  ignore-invalid-cqcode: false
  # 是否强制分片发送消息
  # 分片发送将会带来更快的速度
  # 但是兼容性会有些问题
  force-fragment: false
  # 是否将url分片发送
  fix-url: false
  # 下载图片等请求网络代理
  proxy-rewrite: ''
  # 是否上报自身消息
  report-self-message: false
  # 移除服务端的Reply附带的At
  remove-reply-at: false
  # 为Reply附加更多信息
  extra-reply-data: false
  # 跳过 Mime 扫描, 忽略错误数据
  skip-mime-scan: false
  # 是否自动转换 WebP 图片
  convert-webp-image: false
  # download 超时时间(s)
  http-timeout: 15

output:
  # 日志等级 trace,debug,info,warn,error
  log-level: warn
  # 日志时效 单位天. 超过这个时间之前的日志将会被自动删除. 设置为 0 表示永久保留.
  log-aging: 15
  # 是否在每次启动时强制创建全新的文件储存日志. 为 false 的情况下将会在上次启动时创建的日志文件续写
  log-force-new: true
  # 是否启用日志颜色
  log-colorful: true
  # 是否启用 DEBUG
  debug: false # 开启调试模式

# 默认中间件锚点
default-middlewares: &default
  # 访问密钥, 强烈推荐在公网的服务器设置
  access-token: ''
  # 事件过滤器文件目录
  filter: ''
  # API限速设置
  # 该设置为全局生效
  # 原 cqhttp 虽然启用了 rate_limit 后缀, 但是基本没插件适配
  # 目前该限速设置为令牌桶算法, 请参考:
  # https://baike.baidu.com/item/%E4%BB%A4%E7%89%8C%E6%A1%B6%E7%AE%97%E6%B3%95/6597000?fr=aladdin
  rate-limit:
    enabled: false # 是否启用限速
    frequency: 1  # 令牌回复频率, 单位秒
    bucket: 1     # 令牌桶大小

database: # 数据库相关设置
  leveldb:
    # 是否启用内置leveldb数据库
    # 启用将会增加10-20MB的内存占用和一定的磁盘空间
    # 关闭将无法使用 撤回 回复 get_msg 等上下文相关功能
    enable: true
  sqlite3:
    # 是否启用内置sqlite3数据库
    # 启用将会增加一定的内存占用和一定的磁盘空间
    # 关闭将无法使用 撤回 回复 get_msg 等上下文相关功能
    enable: false
    cachettl: 3600000000000 # 1h

# 连接服务列表
servers:$Config_Server">config.yml||abort "配置文件写入失败"
msgbox "配置文件生成完成：
QQ号：$Config_QQ
密码：$(echo -n "$Config_Password"|tr -c '' '*')
连接：$Config_URL";}

gcq_fix_version(){ rm -vrf device.json&&
mkdir -vp data/versions&&
echo -n '{
  "apk_id": "com.tencent.mobileqq",
  "app_id": 537118044,
  "sub_app_id": 537118044,
  "app_key": "0S200MNJT807V3GE",
  "sort_version_name": "8.8.88.7083",
  "build_time": 1648004515,
  "apk_sign": "a6b745bf24a2c277527716f6f36eb68d",
  "sdk_version": "6.0.0.2497",
  "sso_version": 19,
  "misc_bitmap": 150470524,
  "main_sig_map": 16724722,
  "sub_sig_map": 66560,
  "dump_time": 1648004515,
  "protocol_type": 1
}'>data/versions/6.json&&
msgbox "修改完成"||abort "修改失败";}

gcq_device(){ Config_Device="$(menubox "- 请选择设备协议"\
  1 "安卓手机"\
  2 "安卓手表"\
  3 "MacOS"\
  4 "企点"\
  5 "iPad"\
  6 "安卓平板"\
  7 "安卓手机 8.8.88")"||return
[ "$Config_Device" = 7 ]&&{ gcq_fix_version;return;}
[ -s device.json ]||{ msgbox "未找到设备文件";return;}
sed -i 's/"protocol": *[0-9]/"protocol":'"$Config_Device/" device.json
depend bat&&
bat --paging never device.json&&
back;}

gcq_menu(){ [ -n "$GCQDir" ]&&cd "$DIR/go-cqhttp/$GCQDir"||return
[ -s config.yml ]||{ gcq_create||return;}
Choose="$(menubox "$(git_logp s ../go-cqhttp)
账号：$GCQDir"\
  1 "打开 go-cqhttp"\
  2 "启动 go-cqhttp"\
  3 "停止 go-cqhttp"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "修改设备协议"\
  7 "QSignServer"\
  8 "查看二维码"\
  9 "文件管理"\
  10 "检查更新"\
  11 "重置项目"\
  12 "新建账号"\
  13 "删除账号"\
  14 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach "$GCQDir" go-cqhttp;;
  2)tmux_start "$GCQDir" go-cqhttp;;
  3)tmux_stop "$GCQDir" go-cqhttp;;
  4)editor config.yml;;
  5)gcq_create;;
  6)gcq_device;;
  7)qss;;
  8)if [ -s qrcode.png ];then depend catimg&&catimg -t qrcode.png>&3&&back;else msgbox "未找到二维码文件";fi;;
  9)file_list;;
  10)cd ../go-cqhttp;git_update;back;;
  11)yesnobox "确认重置项目？"&&{ git -C ../go-cqhttp reset --hard&&rm -vrf data logs&&msgbox "项目重置完成"||abort "项目重置失败";};;
  12)GCQDir="$(inputbox "请输入QQ号")"&&mkdir -vp "$DIR/go-cqhttp/$GCQDir"||return;;
  13)yesnobox "确认删除账号？"&&{ rm -vrf "$DIR/go-cqhttp/$GCQDir"||abort "账号删除失败";return;};;
  14)fg_start "$GCQDir" go-cqhttp;;
  *)return
esac;gcq_menu;}

gcq(){ cd "$DIR/go-cqhttp"&&[ -x go-cqhttp/go-cqhttp ]||{ yesnobox "未安装 go-cqhttp，是否开始下载"&&gcq_download||return;}
GCQDir="$(ls */config.yml|sed "s|/config.yml$||")"
[ -n "$GCQDir" ]||{ GCQDir="$(inputbox "请输入QQ号")"&&mkdir -vp "$GCQDir"||return;}
if [ "$(wc -l<<<"$GCQDir")" != 1 ];then
  Choose="$(eval menubox "'- 请选择账号' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$GCQDir")")"||return
  GCQDir="$(sed -n "${Choose}p"<<<"$GCQDir")"
fi
gcq_menu;}

mcl_download(){ runtime_install_java
echo "
$Y- 正在下载 Mirai Console Loader$O"
time_start
getver_github iTXTech/mirai-console-loader Mirai||return
echo "
  开始下载"
mktmp
geturl "$URL/iTXTech/mirai-console-loader/releases/download/$NEWNAME/mcl-${NEWNAME#*v}.zip">"$TMP/mcl.zip"||abort "下载失败"
unzip -o "$TMP/mcl.zip" mcl.jar -d "$TMP"||abort "解压失败"
[ -s mcl.jar ]&&{ mv -vf mcl.jar mcl.jar.bak||abort "重命名原文件失败";}
mv -vf "$TMP/mcl.jar" .||abort "移动下载文件失败"
echo -n "name=$NEWNAME
version=$NEWVER
md5=$(md5 mcl.jar)">version
echo "
$Y- 正在更新依赖$O
"
java -jar mcl.jar --update-package net.mamoe:mirai-api-http --channel stable-v2 --type plugin&&java -jar mcl.jar -uz||abort "依赖更新失败"
time_stop
msgbox "Mirai Console Loader 下载完成，用时：$TimeSpend";}

mcl_create(){ Config_VerifyKey="$(passwordbox "请输入验证密钥")"&&
Config_QQ="$(inputbox "请输入QQ号")"&&
Config_Password="$(passwordbox "请输入密码")"&&
Config_Device="$(menubox "- 请选择登录设备"\
  "ANDROID_PHONE" "安卓手机"\
  "ANDROID_PAD" "安卓平板"\
  "ANDROID_WATCH" "安卓手表"\
  "MACOS" "MacOS"\
  "IPAD" "iPad")"||return
rm -vrf config
mkdir -vp config/net.mamoe.mirai-api-http&&
echo "# 欢迎使用 TRSS AllBot ! 作者：时雨🌌星空
# 按 Ctrl+Q Y 保存退出
# 参考：https://github.com/project-mirai/mirai-api-http
#       https://sagiri-kawaii.github.io/sagiri-bot/deployment/linux
#       https://amiyabot.com/guide/deploy/console/configure.html
adapters:
  - http
  - ws
debug: false
enableVerify: $([ -n "$Config_VerifyKey" ]&&echo true||echo false)
verifyKey: '$Config_VerifyKey'
singleMode: false
cacheSize: 4096
adapterSettings:
  http:
    host: 0.0.0.0
    port: 23456
    cors: [*]
  ws:
    host: 0.0.0.0
    port: 23456
    reservedSyncId: -1">config/net.mamoe.mirai-api-http/setting.yml&&
mkdir -vp config/Console&&
echo "# 欢迎使用 TRSS AllBot ! 作者：时雨🌌星空
# 按 Ctrl+Q Y 保存退出
# 参考：https://sagiri-kawaii.github.io/sagiri-bot/deployment/linux
accounts:
  -
    account: $Config_QQ
    password:
      kind: PLAIN
      value: '$Config_Password'
    configuration:
      protocol: $Config_Device
      device: device.json
      enable: true
      heartbeatStrategy: STAT_HB">config/Console/AutoLogin.yml||abort "配置文件写入失败"
msgbox "配置文件生成完成：
密钥：$([ -n "$Config_VerifyKey" ]&&echo -n "$Config_VerifyKey"|tr -c '' '*'||echo "关闭")
QQ号：$Config_QQ
密码：$(echo -n "$Config_Password"|tr -c '' '*')
设备：$Config_Device";}

mcl(){ getver Mirai||{ yesnobox "未安装 Mirai，是否开始下载"&&mcl_download&&getver Mirai||return;}
[ -s config/net.mamoe.mirai-api-http/setting.yml ]||{ mcl_create||return;}
Choose="$(menubox "Mirai Console Loader $NAME ($VER)"\
  1 "打开 Mirai"\
  2 "启动 Mirai"\
  3 "停止 Mirai"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "文件管理"\
  7 "检查更新"\
  8 "清除缓存"\
  9 "清除数据"\
  10 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach Mirai;;
  2)tmux_start Mirai;;
  3)tmux_stop Mirai;;
  4)file_list config;;
  5)mcl_create;;
  6)file_list;;
  7)mcl_download;;
  8)yesnobox "确认清除缓存？"&&{ rm -vrf data logs&&msgbox "缓存清除完成"||abort "缓存清除失败";};;
  9)yesnobox "确认清除数据？"&&{ rm -vrf $(ls|rg -v '^(mcl\.jar|version)$')&&java -jar mcl.jar --update-package net.mamoe:mirai-api-http --channel stable-v2 --type plugin&&java -jar mcl.jar -uz&&msgbox "数据清除完成"||abort "数据清除失败";};;
  10)fg_start Mirai;;
  *)return
esac;mcl;}

zbp_download(){ echo "
$Y- 正在下载 ZeroBot-Plugin$O"
time_start
getver_github FloatTech/ZeroBot-Plugin zbp ZeroBot||return
case "$(uname -m)" in
  aarch64|arm64|armv8*|armv9*)ARCH=arm64;;
  aarch*|arm*)ARCH=armv7;;
  x86_64|x64|amd64)ARCH=amd64;;
  x86|i[36]86)ARCH=386;;
  *)abort "不支持的CPU架构：$(uname -m)"
esac
echo "
  开始下载"
mktmp
if [ -n "$MSYS" ];then
  geturl "$URL/FloatTech/ZeroBot-Plugin/releases/download/$NEWNAME/zbp_windows_$ARCH.zip">"$TMP/zbp.zip"||abort "下载失败"
  unzip -o "$TMP/zbp.zip" -d "$TMP"||abort "解压失败"
else
  geturl "$URL/FloatTech/ZeroBot-Plugin/releases/download/$NEWNAME/zbp_linux_$ARCH.tar.gz">"$TMP/zbp.tgz"||abort "下载失败"
  tar -xvzf "$TMP/zbp.tgz" -C "$TMP"||abort "解压失败"
fi
[ -s zbp ]&&{ mv -vf zbp zbp.bak||abort "重命名原文件失败";}
mv -vf "$TMP/zbp" .||abort "移动下载文件失败"
echo -n "name=$NEWNAME
version=$NEWVER
md5=$(md5 zbp)">version
time_stop
msgbox "ZeroBot-Plugin 下载完成，用时：$TimeSpend";}

zbp_create(){ Config_SuperUser="$(inputbox "请输入主人QQ")"&&
Config_NickName="$(inputbox "请输入Bot昵称" 椛椛)"&&
Config_CMDPrefix="$(inputbox "请输入命令前缀" /)"&&
echo '{
  "zero": {
    "nickname": [
      "'"$Config_NickName"'",
      "ATRI",
      "atri",
      "亚托莉",
      "アトリ"
    ],
    "command_prefix": "'"$Config_CMDPrefix"'",
    "super_users": ['"$Config_SuperUser"'],
    "ring_len": 4096,
    "latency": 233000000,
    "max_process_time": 240000000000
  },
  "wss": [
    {
      "Url": "0.0.0.0:6700"
    }
  ]
}'>config.json||abort "配置文件写入失败"
msgbox "配置文件生成完成：
主人QQ：$Config_SuperUser
Bot昵称：$Config_NickName
命令前缀：$Config_CMDPrefix";}

zbp(){ getver zbp ZeroBot||{ yesnobox "未安装 ZeroBot，是否开始下载"&&zbp_download&&getver zbp ZeroBot||return;}
[ -s config.json ]||{ zbp_create||return;}
Choose="$(menubox "ZeroBot-Plugin $NAME ($VER)"\
  1 "打开 ZeroBot"\
  2 "启动 ZeroBot"\
  3 "停止 ZeroBot"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "文件管理"\
  7 "检查更新"\
  8 "清除缓存"\
  9 "清除数据"\
  10 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach zbp ZeroBot;;
  2)tmux_start zbp ZeroBot;;
  3)tmux_stop zbp ZeroBot;;
  4)editor config.json;;
  5)zbp_create;;
  6)file_list;;
  7)zbp_download;;
  8)yesnobox "确认清除缓存？"&&{ rm -vrf data&&msgbox "缓存清除完成"||abort "缓存清除失败";};;
  9)yesnobox "确认清除数据？"&&{ rm -vrf $(ls|rg -v '^(zbp|version)$')&&msgbox "数据清除完成"||abort "数据清除失败";};;
  10)fg_start zbp ZeroBot;;
  *)return
esac;zbp;}

pypi(){ [ -s "${1:-.}/pyproject.toml" ]&&cd "${1:-.}"||return
Choose="$(menubox "- PyPI 软件包管理"\
  1 "启动 Poetry fish"\
  2 "文件管理"\
  3 "列出软件包"\
  4 "更新软件包"\
  5 "安装软件包"\
  6 "卸载软件包"\
  7 "修改镜像源"\
  0 "返回")"
case "$Choose" in
  1)poetry run fish;;
  2)file_list "$([ -n "$MSYS" ]&&cygpath -u "$(poetry env info -p)\\Lib"||echo "$(poetry env info -p)/lib/python"*)/site-packages";;
  3)echo "
$Y- 已安装软件包：$O
"
    poetry show --latest
    pip list
    back;;
  4)process_start "更新" "软件包"
    pip_install $(poetry run pip list --format freeze --disable-pip-version-check|cut -d= -f1)
    process_stop
    back;;
  5)Input="$(inputbox "请输入安装软件包名")"&&{
      process_start "安装" "软件包" "" "：$C$Input"
      pip_install "$Input"
      process_stop
      back
    };;
  6)Input="$(inputbox "请输入卸载软件包名")"&&{
      process_start "卸载" "软件包" "" "：$C$Input"
      poetry run pip uninstall "$Input"
      process_stop
      back
    };;
  7)Input="$(inputbox "请输入镜像源地址")"&&{
      process_start "修改" "镜像源：$Input"
      poetry run pip config set global.index-url "$Input"
      process_stop
      back
    };;
  *)return
esac;pypi;}

nb-cli(){ cd "$NBDir"||return
Choose="$(menubox "- NoneBot2 管理"\
  1 "启动 nb-cli"\
  2 "插件列表"\
  3 "安装插件"\
  4 "更新插件"\
  5 "卸载插件"\
  0 "返回")"
case "$Choose" in
  1)process_start "启动" " nb-cli"
    poetry run nb
    back;;
  2)poetry run nb plugin list|less;;
  3)Input="$(inputbox "请输入安装插件名")"&&{
      process_start "安装" "插件" "" "：$C$Input"
      poetry run nb plugin install "$Input"
      process_stop
      back
    };;
  4)Input="$(inputbox "请输入更新插件名")"&&{
      process_start "更新" "插件" "" "：$C$Input"
      poetry run nb plugin update "$Input"
      process_stop
      back
    };;
  5)Input="$(inputbox "请输入卸载插件名")"&&{
      process_start "卸载" "插件" "" "：$C$Input"
      poetry run nb plugin uninstall "$Input"
      process_stop
      back
    };;
  *)return
esac;nb-cli;}

nb_git_plugin_manager(){ cd "$NBDir/$NBPluginDir"
[ -d "$1" ]&&GitDir="$1"||return
if [ -d "$GitDir/.git" ];then Choose="$(menubox "- Git 插件：$GitDir ($(git_logp cd "$GitDir"))"\
  1 "文件管理"\
  2 "删除插件"\
  3 "更新日志"\
  4 "更新插件"\
  5 "重置插件"\
  0 "返回")"
else Choose="$(menubox "- 插件：$GitDir"\
  1 "文件管理"\
  2 "删除插件"\
  0 "返回")"
fi
case "$Choose" in
  1)file_list "$GitDir";;
  2)yesnobox "确认删除插件？"&&{
    rm -vrf "$GitDir"&&{
      [ -z "$(rg "plugin_dirs =" ../pyproject.toml|rg -m1 "src/$GitDir")" ]||
      sed -i "s|\"src/$GitDir\",||" ../pyproject.toml
    }||abort "插件删除失败";};;
  3)git_log "$GitDir";;
  4)git_pull "$GitDir"
    back;;
  5)yesnobox "确认重置插件？"&&{
      process_start "重置" "插件" "" "：$C$GitDir"
      git -C "$GitDir" reset --hard
      process_stop
      back
    };;
  *)return
esac;nb_git_plugin_manager "$GitDir";}

nb_git_plugin_list(){ cd "$NBDir/$NBPluginDir"||return
GitList="$(ls -AF|sed -n 's|/$||p')"
Choose="$(eval menubox "'- 已安装 Git 插件' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$GitList")")"||return
nb_git_plugin_manager "$(sed -n "${Choose}p"<<<"$GitList")"
nb_git_plugin_list;}

nb_git_plugin_install(){ GitDir="$1";GitURL="$2";shift 2
yesnobox "确认安装插件？
插件名：$GitDir
插件URL：$GitURL"||return
process_start "安装" "插件" "" "：$C$GitDir"
git_clone "$GitURL" "$GitDir" "$@"&&
[ -n "$(rg "plugin_dirs =" ../pyproject.toml|rg -m1 "src/$GitDir")" ]||sed -i "s|plugin_dirs = \[|plugin_dirs = [\"src/$GitDir\",|" ../pyproject.toml
process_stop
if [ -s "$GitDir/pyproject.toml" ];then
  process_start "安装" "依赖" "使用 Poetry "
  poetry run bash -c "cd '$GitDir'&&poetry install"
  process_stop
elif [ -s "$GitDir/requirements.txt" ];then
  process_start "安装" "依赖" "使用 pip "
  mktmp
  sed -E 's/(>|=|~).*//' "$GitDir/requirements.txt">"$TMP/requirements.txt"&&
  pip_install -r "$TMP/requirements.txt"
  process_stop
fi;}

nb_git_plugin_choose(){ cd "$NBDir/$NBPluginDir"&&
Choose="$(menubox "- 请选择插件"\
  1 "GenshinUID"\
  2 "LittlePaimon"\
  0 "自定义")"||return
case "$Choose" in
  1)gitserver&&nb_git_plugin_install GenshinUID "$URL/KimigaiiWuyi/GenshinUID" -b v4-nonebot2;;
  2)nb_git_plugin_install LittlePaimon "https://gitee.com/CherishMoon/LittlePaimon";;
  0)Input="$(inputbox "请输入插件名")"&&InputURL="$(inputbox "请输入插件URL")"&&nb_git_plugin_install "$Input" "$InputURL";;
  *)return
esac&&back;nb_git_plugin_choose;}

nb_git_plugin(){ cd "$NBDir/$NBPluginDir"||return
Choose="$(menubox "- Git 插件管理"\
  1 "管理插件"\
  2 "更新插件"\
  3 "安装插件"\
  0 "返回")"
case "$Choose" in
  1)nb_git_plugin_list;;
  2)process_start "更新" "所有插件" "" "[A";ls -AF|sed -n 's|/$||p'|while read i;do git_pull "$i";done;process_stop;back;;
  3)nb_git_plugin_choose;;
  *)return
esac;nb_git_plugin;}

nb_plugin(){ [ -s pyproject.toml ]||return
NBDir="$PWD"
Choose="$(menubox "- 请选择操作"\
  1 "PyPI 软件包管理"\
  2 "NoneBot2 管理"\
  3 "Git 插件管理"\
  0 "返回")"
case "$Choose" in
  1)pypi;;
  2)nb-cli;;
  3)nb_git_plugin;;
  *)return
esac;cd "$NBDir";nb_plugin;}

ly_download(){ cd "$DIR"
runtime_install_python
process_start "下载" "Liteyuki"
git_clone "https://gitee.com/snowykami/liteyuki-bot" Liteyuki&&
cd Liteyuki&&
process_stop
process_start "安装" "依赖" "使用 Poetry "
poetry_install
process_stop
back;}

ly_create(){ Config_SuperUser="$(inputbox "请输入主人QQ")"&&
Config_NickName="$(inputbox "请输入Bot昵称" 轻雪)"&&
Config_CMDStart="$(inputbox "请输入命令前缀")"&&
Config_CMDSEP="$(inputbox "请输入命令分隔符")"||return
echo 'HOST=0.0.0.0
PORT=25360
SUPERUSERS=['"$Config_SuperUser"']
NICKNAME=["'"$Config_NickName"'"]
COMMAND_START=["'"$Config_CMDStart"'"]
COMMAND_SEP=["'"$Config_CMDSEP"'"]
DEBUG=false
FASTAPI_RELOAD=false'>.env||abort "配置文件写入失败"
msgbox "配置文件生成完成：
主人QQ：$Config_SuperUser
Bot昵称：$Config_NickName
命令前缀：$Config_CMDStart
命令分隔符：$Config_CMDSEP";}

ly_config(){ Choose="$(menubox "- 请选择配置文件"\
  1 "环境配置 .env"\
  2 "项目配置 pyproject.toml"\
  3 "插件配置 src/config")"
case "$Choose" in
  1)editor .env;;
  2)editor pyproject.toml;;
  3)file_list src/config;;
  *)return
esac;ly_config;}

ly(){ cd "$DIR/Liteyuki"
[ -d .git ]||{ yesnobox "未安装 Liteyuki，是否开始下载"&&ly_download||return;}
[ -s .env ]||{ ly_create||return;}
NAME="$(json version_name<src/config/config.json)"
VER="$(git_logp cd)"
Choose="$(menubox "Liteyuki $NAME ($VER)"\
  1 "打开 Liteyuki"\
  2 "启动 Liteyuki"\
  3 "停止 Liteyuki"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "插件管理"\
  7 "文件管理"\
  8 "更新日志"\
  9 "检查更新"\
  10 "重置项目"\
  11 "重新安装"\
  12 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach Liteyuki;;
  2)tmux_start Liteyuki;;
  3)tmux_stop Liteyuki;;
  4)ly_config;;
  5)ly_create;;
  6)NBPluginDir=src;nb_plugin;;
  7)file_list;;
  8)git_log;;
  9)git_update poetry install;back;;
  10)yesnobox "确认重置项目？"&&{ git reset --hard&&msgbox "项目重置完成"||abort "项目重置失败";};;
  11)yesnobox "将会清除所有数据，确认重新安装？"&&ly_download;;
  12)fg_start Liteyuki;;
  *)return
esac;ly;}

lp_download(){ cd "$DIR"
runtime_install_python
process_start "下载" "LittlePaimon"
git_clone "https://gitee.com/CherishMoon/LittlePaimon" LittlePaimon&&
cd LittlePaimon&&
rm -vrf .env.prod
process_stop
process_start "安装" "依赖" "使用 Poetry "
poetry_install
pip_install nb-cli
process_stop
back;}

lp_create(){ Config_SuperUser="$(inputbox "请输入主人QQ")"&&
Config_NickName="$(inputbox "请输入Bot昵称" 派蒙)"&&
Config_CMDStart="$(inputbox "请输入命令前缀")"&&
Config_CMDSEP="$(inputbox "请输入命令分隔符")"||return
echo 'HOST=0.0.0.0
PORT=13579
LOG_LEVEL=INFO
SUPERUSERS=['"$Config_SuperUser"']
NICKNAME=["'"$Config_NickName"'"]
COMMAND_START=["'"$Config_CMDStart"'"]
COMMAND_SEP=["'"$Config_CMDSEP"'"]'>.env.prod||abort "配置文件写入失败"
msgbox "配置文件生成完成：
主人QQ：$Config_SuperUser
Bot昵称：$Config_NickName
命令前缀：$Config_CMDStart
命令分隔符：$Config_CMDSEP";}

lp_config(){ Choose="$(menubox "- 请选择配置文件"\
  1 "环境配置 .env.prod"\
  2 "项目配置 pyproject.toml"\
  3 "插件配置 config")"
case "$Choose" in
  1)editor .env.prod;;
  2)editor pyproject.toml;;
  3)file_list config;;
  *)return
esac;lp_config;}

lp(){ cd "$DIR/LittlePaimon"
[ -d .git ]||{ yesnobox "未安装 LittlePaimon，是否开始下载"&&lp_download||return;}
[ -s .env.prod ]||{ lp_create||return;}
NAME="$(rg -m1 'version =' pyproject.toml|tr -d ' "'|sed "s/version=//")"
VER="$(git_logp cd)"
Choose="$(menubox "LittlePaimon $NAME ($VER)"\
  1 "打开 LittlePaimon"\
  2 "启动 LittlePaimon"\
  3 "停止 LittlePaimon"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "插件管理"\
  7 "文件管理"\
  8 "更新日志"\
  9 "检查更新"\
  10 "重置项目"\
  11 "重新安装"\
  12 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach LittlePaimon;;
  2)tmux_start LittlePaimon;;
  3)tmux_stop LittlePaimon;;
  4)lp_config;;
  5)lp_create;;
  6)NBPluginDir=src;nb_plugin;;
  7)file_list;;
  8)git_log;;
  9)git_update poetry install;back;;
  10)yesnobox "确认重置项目？"&&{ git reset --hard&&rm -vrf .env.prod&&msgbox "项目重置完成"||abort "项目重置失败";};;
  11)yesnobox "将会清除所有数据，确认重新安装？"&&lp_download;;
  12)fg_start LittlePaimon;;
  *)return
esac;lp;}

yz_js_plugin_manager(){ [ -f "$1" ]&&JSFile="$1"||yz_js_plugin_list
Choose="$(menubox "- JS 插件：$JSFile"\
  1 "修改插件"\
  2 "删除插件"\
  3 "导出插件"\
  0 "返回")"
case "$Choose" in
  1)editor "$JSFile";;
  2)yesnobox "确认删除插件？"&&{
      rm -vrf "$JSFile"||abort "插件删除失败"
    };;
  3)Input="$(inputbox "请输入导出路径")"&&{
      process_start "导出" "插件"
      cp -vrf "$JSFile" "$Input"
      process_stop
      back
    };;
  *)return
esac;yz_js_plugin_manager "$JSFile";}

yz_js_plugin_list(){ cd "$YzDir/plugins/example"||return
JSList="$(ls *.js)"
Choose="$(eval menubox "'- 已安装 JS 插件' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$JSList")")"||return
yz_js_plugin_manager "$(sed -n "${Choose}p"<<<"$JSList")"
yz_js_plugin_list;}

yz_js_plugin_create(){ Input="$(inputbox "请输入插件名")"&&{
  editor "$Input.js"&&
  yz_js_plugin_manager "$Input.js"
};}

yz_js_plugin_install(){ if yesnobox "请选择插件类型" "本地插件" "网络插件";then
  Input="$(inputbox "请输入插件路径")"&&{
    if [ -s "$Input" ];then
      process_start "导入" "插件" "" "：$C$Input"
      cp -vrf "$Input" .
      process_stop
      back
    else
      msgbox "错误：插件不存在"
    fi
  }
else
  Input="$(inputbox "请输入插件名")"&&
  InputURL="$(inputbox "请输入插件URL")"&&{
    process_start "下载" "插件" "" "：$C$Input.js"
    mktmp
    geturl "$InputURL">"$TMP/$Input.js"&&
    mv -vf "$TMP/$Input.js" .&&
    process_stop
    back
  }
fi;}

yz_js_plugin(){ cd "$YzDir/plugins/example"||return
Choose="$(menubox "- JS 插件管理"\
  1 "管理插件"\
  2 "新建插件"\
  3 "导入插件"\
  4 "软件包管理"\
  0 "返回")"
case "$Choose" in
  1)yz_js_plugin_list;;
  2)yz_js_plugin_create;;
  3)yz_js_plugin_install;;
  4)[ -s package.json ]||echo '{
  "name": "example",
  "type": "module"
}'>package.json&&
    pnpm_manager .;;
  *)return
esac;yz_js_plugin;}

yz_git_plugin_manager(){ cd "$YzDir/plugins"
[ -d "$1" ]&&GitDir="$1"||return
if [ -d "$GitDir/.git" ];then
  Choose="$(menubox "- Git 插件：$GitDir ($(git_logp cd "$GitDir"))"\
  1 "文件管理"\
  2 "删除插件"\
  3 "软件包管理"\
  4 "更新日志"\
  5 "更新插件"\
  6 "重置插件"\
  0 "返回")"
else
  Choose="$(menubox "- 插件：$GitDir"\
  1 "文件管理"\
  2 "删除插件"\
  3 "软件包管理"\
  0 "返回")"
fi
case "$Choose" in
  1)file_list "$GitDir";;
  2)yesnobox "确认删除插件？"&&{
      rm -vrf "$GitDir"||abort "插件删除失败"
    };;
  3)[ -s "$GitDir/package.json" ]||echo '{
  "name": "'"$GitDir"'",
  "type": "module"
}'>"$GitDir/package.json"&&
    pnpm_manager "$GitDir";;
  4)git_log "$GitDir";;
  5)git_pull "$GitDir"
    back;;
  6)yesnobox "确认重置插件？"&&{
      process_start "重置" "插件" "" "：$C$GitDir"
      git -C "$GitDir" reset --hard
      process_stop
      back
    };;
  *)return
esac;yz_git_plugin_manager "$GitDir";}

yz_git_plugin_list(){ cd "$YzDir/plugins"||return
GitList="$(ls -AF|sed -n 's|/$||p')"
Choose="$(eval menubox "'- 已安装 Git 插件' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$GitList")")"||return
yz_git_plugin_manager "$(sed -n "${Choose}p"<<<"$GitList")"
yz_git_plugin_list;}

yz_git_plugin_install(){ GitDir="$1";GitURL="$2";shift 2
yesnobox "确认安装插件？
插件名：$GitDir
插件URL：$GitURL"||return
process_start "安装" "插件" "" "：$C$GitDir"
git_clone "$GitURL" "$GitDir" "$@"
process_stop
if [ -s "$GitDir/package.json" ];then
  process_start "安装" "依赖" "使用 pnpm "
  cd "$GitDir"&&
  pnpm i
  process_stop
fi;}

yz_py_plugin_install(){ cd "$YzDir/plugins"&&yz_git_plugin_install py-plugin "https://gitee.com/realhuhu/py-plugin"||return
echo "# 欢迎使用 TRSS Yunzai ! 作者：时雨🌌星空
# 按 Ctrl+Q Y 保存退出
# 参考：https://gitee.com/realhuhu/py-plugin
">config.yaml
cat config_default.yaml>>config.yaml
process_start "安装" "依赖" "使用 Poetry "
poetry_install
pip_install nb-cli
process_stop;}

yz_py_plugin_nb(){ Choose="$(menubox "- NoneBot2 插件管理"\
  1 "启动 nb-cli"\
  2 "文件管理"\
  3 "插件列表"\
  4 "更新插件"\
  5 "安装插件"\
  6 "卸载插件"\
  7 "修改镜像源"\
  0 "返回")"
case "$Choose" in
  1)process_start "启动" " nb-cli"
    poetry run nb
    back;;
  2)file_list "$([ -n "$MSYS" ]&&cygpath -u "$(poetry env info -p)\\Lib"||echo "$(poetry env info -p)/lib/python"*)/site-packages";;
  3)poetry run nb plugin list|less;;
  4)process_start "更新" "插件"
    pip_install $(poetry run pip list --disable-pip-version-check|tail -n +3|cut -d ' ' -f1)
    process_stop
    back;;
  5)Input="$(inputbox "请输入安装插件名")"&&{
      process_start "安装" "插件" "" "：$C$Input"
      pip_install "$Input"&&
      rg -m1 " - $Input" config.yaml >/dev/null||
      sed -i "/^plugins:/a\  - $Input" config.yaml
      process_stop
      back
    };;
  6)Input="$(inputbox "请输入卸载插件名")"&&{
      process_start "卸载" "插件" "" "：$C$Input"
      poetry run pip uninstall "$Input"&&
      sed -i "/^ - $Input$/d" config.yaml
      process_stop
      back
    };;
  7)Input="$(inputbox "请输入镜像源地址")"&&{
      process_start "修改" "镜像源" "" "：$C$Input"
      poetry run pip config set global.index-url "$Input"
      process_stop
      back
    };;
  *)return
esac;yz_py_plugin_nb;}

yz_py_plugin_git_manager(){ cd "$YzDir/plugins/py-plugin/plugins"
[ -d "$1" ]&&GitDir="$1"||return
if [ -d "$GitDir/.git" ];then Choose="$(menubox "- Py 插件 Git 插件：$GitDir ($(git_logp cd "$GitDir"))"\
  1 "文件管理"\
  2 "删除插件"\
  3 "更新日志"\
  4 "更新插件"\
  5 "重置插件"\
  0 "返回")"
else Choose="$(menubox "- 插件：$GitDir"\
  1 "文件管理"\
  2 "删除插件"\
  0 "返回")"
fi
case "$Choose" in
  1)file_list "$GitDir";;
  2)yesnobox "确认删除插件？"&&{
      rm -vrf "$GitDir"&&
      sed -i "/^ - $GitDir$/d" ../config.yaml||abort "插件删除失败"
    };;
  3)git_log "$GitDir";;
  4)git_pull "$GitDir"
    back;;
  5)yesnobox "确认重置插件？"&&{
      process_start "重置" "插件" "" "：$C$GitDir"
      git -C "$GitDir" reset --hard
      process_stop
      back
    };;
  *)return
esac;yz_py_plugin_git_manager "$GitDir";}

yz_py_plugin_git_list(){ cd "$YzDir/plugins/py-plugin/plugins"||return
GitList="$(ls -AF|sed -n 's|/$||p')"
Choose="$(eval menubox "'- Py 插件 已安装 Git 插件' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$GitList")")"||return
yz_py_plugin_git_manager "$(sed -n "${Choose}p"<<<"$GitList")"
yz_py_plugin_git_list;}

yz_py_plugin_git_install(){ GitDir="$1";GitURL="$2";shift 2
yesnobox "确认安装插件？
插件名：$GitDir
插件URL：$GitURL"||return
process_start "安装" "插件" "" "：$C$GitDir"
git_clone "$GitURL" "$GitDir" "$@"&&
rg -m1 " - $GitDir" ../config.yaml >/dev/null||
sed -i "/^plugins:/a\  - $GitDir" ../config.yaml
process_stop
if [ -s "$GitDir/pyproject.toml" ];then
  process_start "安装" "依赖" "使用 Poetry "
  poetry run bash -c "cd '$GitDir'&&poetry install"
  process_stop
elif [ -s "$GitDir/requirements.txt" ];then
  process_start "安装" "依赖" "使用 pip "
  mktmp
  sed -E 's/(>|=|~).*//' "$GitDir/requirements.txt">"$TMP/requirements.txt"&&
  pip_install -r "$TMP/requirements.txt"
  process_stop
fi;}

yz_py_plugin_git_choose(){ cd "$YzDir/plugins/py-plugin/plugins"&&
Choose="$(menubox "- 请选择插件"\
  1 "GenshinUID"\
  2 "LittlePaimon"\
  0 "自定义")"||return
case "$Choose" in
  1)gitserver&&yz_py_plugin_git_install GenshinUID "$URL/KimigaiiWuyi/GenshinUID" -b v4-nonebot2&&rm -rf GenshinUID/__init__.py;;
  2)yz_py_plugin_git_install LittlePaimon "https://gitee.com/CherishMoon/LittlePaimon";;
  0)Input="$(inputbox "请输入插件名")"&&InputURL="$(inputbox "请输入插件URL")"&&yz_py_plugin_git_install "$Input" "$InputURL";;
  *)return
esac&&back;yz_py_plugin_git_choose;}

yz_py_plugin_git(){ cd "$YzDir/plugins/py-plugin/plugins"||return
Choose="$(menubox "- Py 插件 Git 插件管理"\
  1 "管理插件"\
  2 "更新插件"\
  3 "安装插件"\
  0 "返回")"
case "$Choose" in
  1)yz_py_plugin_git_list;;
  2)process_start "更新" "所有插件" "" "[A"
    ls -AF|sed -n 's|/$||p'|while read i;do
      git_pull "$i"
    done
    process_stop
    back;;
  3)yz_py_plugin_git_choose;;
  *)return
esac;yz_py_plugin_git;}

yz_py_plugin(){ cd "$YzDir/plugins/py-plugin"||{ yz_py_plugin_install&&back||return;}
Choose="$(menubox "- Py 插件管理"\
  1 "NoneBot2 管理"\
  2 "Git 插件管理"\
  3 "修改配置文件"\
  4 "检查更新"\
  5 "启动 Poetry fish"\
  0 "返回")"
case "$Choose" in
  1)yz_py_plugin_nb;;
  2)yz_py_plugin_git;;
  3)editor config.yaml;;
  4)git_update poetry install
    back;;
  5)poetry run fish;;
  *)return
esac;yz_py_plugin;}

yz_trss_plugin_realesrgan(){ process_start "安装" "图片修复"
poetry_install
git_clone "https://gitee.com/TimeRainStarSky/Real-ESRGAN" Real-ESRGAN&&
cd Real-ESRGAN&&
poetry run python setup.py develop
process_stop;}

yz_trss_plugin_rembg(){ process_start "安装" "图片背景去除"
poetry_install
git_clone "https://gitee.com/TimeRainStarSky/RemBG" RemBG&&
cd RemBG&&
gitserver||return
mktmp
geturl "$URL/TimeRainStarSky/TRSS-Plugin/releases/download/latest/u2net.onnx.xz">"$TMP/u2net.onnx.xz"&&
geturl "$URL/TimeRainStarSky/TRSS-Plugin/releases/download/latest/isnetis.onnx.xz">"$TMP/isnetis.onnx.xz"&&
xz -dv "$TMP/u2net.onnx.xz" "$TMP/isnetis.onnx.xz"&&
mv -vf "$TMP/u2net.onnx" "$TMP/isnetis.onnx" .
process_stop;}

yz_trss_plugin_voice(){ process_start "安装" "语音合成"
poetry_install
git_clone "https://gitee.com/TimeRainStarSky/ChatWaifu" ChatWaifu&&
git_clone "https://gitee.com/TimeRainStarSky/GenshinVoice" GenshinVoice&&
pip_install monotonic-align
process_stop;}

yz_trss_plugin_voice_cn(){ [ -d ChatWaifu ]&&gitserver||return
process_start "安装" "语音合成 汉语模型"
mktmp
geturl "$URL/TimeRainStarSky/TRSS-Plugin/releases/download/latest/ChatWaifuCN.txz">"$TMP/ChatWaifuCN.txz"&&
tar -xvJf "$TMP/ChatWaifuCN.txz" -C ChatWaifu
process_stop;}

yz_trss_plugin_voice_jp(){ [ -d ChatWaifu ]&&gitserver||return
process_start "安装" "语音合成 日语模型"
mktmp
geturl "$URL/TimeRainStarSky/TRSS-Plugin/releases/download/latest/ChatWaifuJP.txz">"$TMP/ChatWaifuJP.txz"&&
tar -xvJf "$TMP/ChatWaifuJP.txz" -C ChatWaifu
process_stop;}

yz_trss_plugin_voice_genshin(){ [ -d GenshinVoice ]&&gitserver||return
process_start "安装" "语音合成 原神模型"
mktmp
geturl "$URL/TimeRainStarSky/TRSS-Plugin/releases/download/latest/G_809000.pth.xz">"$TMP/G_809000.pth.xz"&&
xz -dv "$TMP/G_809000.pth.xz"&&
mv -vf "$TMP/G_809000.pth" GenshinVoice
process_stop;}

yz_trss_plugin(){ cd "$YzDir/plugins/TRSS-Plugin"||{ cd "$YzDir/plugins"&&yz_git_plugin_install TRSS-Plugin "https://Yunzai.TRSS.me"&&back||return;}
Choose="$(menubox "- TRSS 插件管理"\
  1 "修改配置文件"\
  2 "安装 图片修复"\
  3 "安装 图片背景去除"\
  4 "安装 语音合成"\
  5 "安装 语音合成 汉语模型"\
  6 "安装 语音合成 日语模型"\
  7 "安装 语音合成 原神模型"\
  0 "返回")"
case "$Choose" in
  1)editor config.yaml;;
  2)yz_trss_plugin_realesrgan;;
  3)yz_trss_plugin_rembg;;
  4)yz_trss_plugin_voice;;
  5)yz_trss_plugin_voice_cn;;
  6)yz_trss_plugin_voice_jp;;
  7)yz_trss_plugin_voice_genshin;;
  *)return
esac&&back;yz_trss_plugin;}

yz_git_plugin_choose(){ cd "$YzDir/plugins"&&
Choose="$(menubox "- 请选择插件"\
  1 "Atlas                  图鉴插件"\
  2 "suiyue                 碎月插件"\
  3 "Icepray                冰祈插件"\
  4 "l-plugin                  L插件"\
  5 "Tlon-Sky               光遇插件"\
  6 "ap-plugin              绘图插件"\
  7 "FanSky_Qs              繁星插件"\
  8 "ql-plugin              清凉插件"\
  9 "ws-plugin            OneBot插件"\
  10 "lin-plugin               麟插件"\
  11 "phi-plugin              phi插件"\
  12 "zhi-plugin             白纸插件"\
  13 "auto-plugin          自动化插件"\
  14 "k423-plugin            k423插件"\
  15 "miao-plugin            喵喵插件"\
  16 "mora-plugin            摩拉插件"\
  17 "WeLM-plugin            WeLM插件"\
  18 "armoe-plugin         阿尔萌插件"\
  19 "ayaka-plugin           绫华插件"\
  20 "cunyx-plugin         寸幼萱插件"\
  21 "Guoba-Plugin           锅巴插件"\
  22 "sanyi-plugin           三一插件"\
  23 "voice-plugin           语音插件"\
  24 "wenan-plugin           文案插件"\
  25 "yenai-plugin           椰奶插件"\
  26 "expand-plugin          拓展插件"\
  27 "flower-plugin          抽卡插件"\
  28 "hanhan-plugin          憨憨插件"\
  29 "paimon-plugin          派蒙插件"\
  30 "xianyu-plugin          咸鱼插件"\
  31 "XiaoXuePlugin          小雪插件"\
  32 "xiaoye-plugin          小叶插件"\
  33 "xitian-plugin        JS管理插件"\
  34 "y-tian-plugin          阴天插件"\
  35 "avocado-plugin       鳄梨酱插件"\
  36 "chatgpt-plugin      ChatGPT插件"\
  37 "earth-k-plugin         土块插件"\
  38 "hs-qiqi-plugin         枫叶插件"\
  39 "liulian-plugin         榴莲插件"\
  40 "windoge-plugin         风歌插件"\
  41 "xianxin-plugin         闲心插件"\
  42 "xiaofei-plugin         小飞插件"\
  43 "xiaoyue-plugin         小月插件"\
  44 "xiuxian-plugin         修仙插件"\
  45 "zhishui-plugin         止水插件"\
  46 "rconsole-plugin           R插件"\
  47 "StarRail-plugin    星穹铁道插件"\
  48 "recreation-plugin      娱乐插件"\
  49 "yunzai-c-v-plugin    清凉图插件"\
  50 "xiaoyao-cvs-plugin     图鉴插件"\
  51 "achievements-plugin    成就插件"\
  52 "call_of_seven_saints   七圣召唤"\
  53 "ff14-composite-plugin  FF14插件"\
  54 "akasha-terminal-plugin 虚空插件"\
  55 "Jinmaocuicuisha-plugin 脆鲨插件"\
  0 "自定义")"||return
URL="https://gitee.com"
case "$Choose" in
  1)yz_git_plugin_install Atlas "$URL/Nwflower/atlas";;
  2)yz_git_plugin_install suiyue "$URL/Acceleratorsky/suiyue";;
  3)yz_git_plugin_install Icepray "$URL/koinori/Icepray";;
  4)gitserver&&yz_git_plugin_install l-plugin "$URL/liuly0322/l-plugin";;
  5)yz_git_plugin_install Tlon-Sky "$URL/Tloml-Starry/Tlon-Sky";;
  6)yz_git_plugin_install ap-plugin "$URL/yhArcadia/ap-plugin"&&pnpm_add axios;;
  7)yz_git_plugin_install FanSky_Qs "$URL/FanSky_Qs/FanSky_Qs"&&pnpm_add axios markdown-it;;
  8)yz_git_plugin_install ql-plugin "$URL/xwy231321/ql-plugin";;
  9)yz_git_plugin_install ws-plugin "$URL/xiaoye12123/ws-plugin";;
  10)yz_git_plugin_install lin-plugin "$URL/go-farther-and-farther/lin-plugin";;
  11)gitserver&&yz_git_plugin_install phi-plugin "$URL/catrong/phi-plugin";;
  12)yz_git_plugin_install zhi-plugin "$URL/headmastertan/zhi-plugin";;
  13)yz_git_plugin_install auto-plugin "$URL/Nwflower/auto-plugin";;
  14)gitserver&&yz_git_plugin_install k423-plugin "$URL/K423-D/k423-plugin"&&pnpm_add axios btoa canvas;;
  15)yz_git_plugin_install miao-plugin "$URL/yoimiya-kokomi/miao-plugin";;
  16)yz_git_plugin_install mora-plugin "$URL/Rrrrrrray/mora-plugin";;
  17)yz_git_plugin_install WeLM-plugin "$URL/shuciqianye/yunzai-custom-dialogue-welm";;
  18)yz_git_plugin_install armoe-plugin "$URL/armoe-project/armoe-plugin";;
  19)gitserver&&yz_git_plugin_install ayaka-plugin "$URL/lumie-fx/ayaka-plugin";;
  20)yz_git_plugin_install cunyx-plugin "$URL/cunyx/cunyx-plugin";;
  21)yz_git_plugin_install Guoba-Plugin "$URL/guoba-yunzai/guoba-plugin";;
  22)yz_git_plugin_install sanyi-plugin "$URL/ThreeYi/sanyi-plugin";;
  23)gitserver&&yz_git_plugin_install voice-plugin "$URL/yuchiXiong/voice-plugin"&&pnpm_add cheerio;;
  24)yz_git_plugin_install wenan-plugin "$URL/white-night-fox/wenan-plugin";;
  25)yz_git_plugin_install yenai-plugin "$URL/yeyang52/yenai-plugin";;
  26)yz_git_plugin_install expand-plugin "$URL/SmallK111407/expand-plugin";;
  27)yz_git_plugin_install flower-plugin "$URL/Nwflower/flower-plugin";;
  28)yz_git_plugin_install hanhan-plugin "$URL/han-hanz/hanhan-plugin";;
  29)gitserver&&yz_git_plugin_install paimon-plugin "$URL/zlh-debug/paimon-plugin";;
  30)yz_git_plugin_install xianyu-plugin "$URL/suancaixianyu/xianyu-plugin";;
  31)yz_git_plugin_install XiaoXuePlugin "$URL/XueWerY/XiaoXuePlugin";;
  32)yz_git_plugin_install xiaoye-plugin "$URL/xiaoye12123/xiaoye-plugin";;
  33)yz_git_plugin_install xitian-plugin "$URL/XiTianGame/xitian-plugin";;
  34)yz_git_plugin_install y-tian-plugin "$URL/wan13877501248/y-tian-plugin";;
  35)yz_git_plugin_install avocado-plugin "$URL/sean_l/avocado-plugin";;
  36)gitserver&&yz_git_plugin_install chatgpt-plugin "$URL/ikechan8370/chatgpt-plugin";;
  37)yz_git_plugin_install earth-k-plugin "$URL/SmallK111407/earth-k-plugin";;
  38)yz_git_plugin_install hs-qiqi-plugin "$URL/kesally/hs-qiqi-cv-plugin"&&pnpm_add axios;;
  39)yz_git_plugin_install liulian-plugin "$URL/huifeidemangguomao/liulian-plugin"&&pnpm_add axios;;
  40)gitserver&&yz_git_plugin_install windoge-plugin "$URL/gxy12345/windoge-plugin";;
  41)yz_git_plugin_install xianxin-plugin "$URL/xianxincoder/xianxin-plugin"&&pnpm_add axios;;
  42)yz_git_plugin_install xiaofei-plugin "$URL/xfdown/xiaofei-plugin"&&pnpm_add axios;;
  43)yz_git_plugin_install xiaoyue-plugin "$URL/yunxiyuan/xiaoyue-plugin"&&pnpm_add axios;;
  44)yz_git_plugin_install xiuxian@2.0.0 "$URL/three-point-of-water/xiuxian-plugin";;
  45)yz_git_plugin_install zhishui-plugin "$URL/fjcq/zhishui-plugin";;
  46)yz_git_plugin_install rconsole-plugin "$URL/kyrzy0416/rconsole-plugin";;
  47)yz_git_plugin_install StarRail-plugin "$URL/hewang1an/StarRail-plugin";;
  48)gitserver&&yz_git_plugin_install recreation-plugin "$URL/QiuLing0/recreation-plugin";;
  49)yz_git_plugin_install yunzai-c-v-plugin "$URL/xwy231321/yunzai-c-v-plugin";;
  50)yz_git_plugin_install xiaoyao-cvs-plugin "$URL/Ctrlcvs/xiaoyao-cvs-plugin";;
  51)yz_git_plugin_install achievements-plugin "$URL/zolay-poi/achievements-plugin";;
  52)yz_git_plugin_install call_of_seven_saints "$URL/huangshx2001/call_of_seven_saints";;
  53)yz_git_plugin_install ff14-composite-plugin "$URL/jo30k/ff14-composite-plugin";;
  54)yz_git_plugin_install akasha-terminal-plugin "$URL/go-farther-and-farther/akasha-terminal-plugin";;
  55)yz_git_plugin_install Jinmaocuicuisha-plugin "$URL/JMCCS/jinmaocuicuisha";;
  0)Input="$(inputbox "请输入插件名")"&&InputURL="$(inputbox "请输入插件URL")"&&yz_git_plugin_install "$Input" "$InputURL";;
  *)return
esac&&back;yz_git_plugin_choose;}

yz_git_plugin(){ cd "$YzDir/plugins"||return
Choose="$(menubox "- Git 插件管理"\
  1 "管理插件"\
  2 "更新插件"\
  3 "安装插件"\
  4 "Py 插件"\
  5 "TRSS 插件"\
  0 "返回")"
case "$Choose" in
  1)yz_git_plugin_list;;
  2)process_start "更新" "所有插件" "" "[A"
    ls -AF|sed -n 's|/$||p'|while read i;do
      git_pull "$i"
    done
    process_stop
    back;;
  3)yz_git_plugin_choose;;
  4)yz_py_plugin;;
  5)yz_trss_plugin;;
  *)return
esac;yz_git_plugin;}

ac_plugin_manager(){ cd "$DIR/Adachi/src/plugins"
[ -d "$1" ]&&GitDir="$1"||ac_plugin_list
if [ -d "$GitDir/.git" ];then Choose="$(menubox "- Adachi 插件：$GitDir ($(git_logp cd "$GitDir"))"\
  1 "文件管理"\
  2 "删除插件"\
  3 "软件包管理"\
  4 "更新日志"\
  5 "更新插件"\
  6 "重置插件"\
  0 "返回")"
else Choose="$(menubox "- 插件：$GitDir"\
  1 "文件管理"\
  2 "删除插件"\
  3 "软件包管理"\
  0 "返回")"
fi
case "$Choose" in
  1)file_list "$GitDir";;
  2)yesnobox "确认删除插件？"&&{
      rm -vrf "$GitDir"||abort "插件删除失败"
    };;
  3)[ -s "$GitDir/package.json" ]||echo '{
  "name": "'"$GitDir"'",
  "type": "module"
}'>"$GitDir/package.json"&&
    pnpm_manager "$GitDir";;
  4)git_log "$GitDir";;
  5)git_pull "$GitDir"
    back;;
  6)yesnobox "确认重置插件？"&&{
      process_start "重置" "插件" "" "：$C$GitDir"
      git -C "$GitDir" reset --hard
      process_stop
      back
    };;
  *)return
esac;ac_plugin_manager "$GitDir";}

ac_plugin_list(){ cd "$DIR/Adachi/src/plugins"||return
GitList="$(ls -AF|sed -n 's|/$||p')"
Choose="$(eval menubox "'- 已安装 Adachi 插件' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$GitList")")"||return
ac_plugin_manager "$(sed -n "${Choose}p"<<<"$GitList")"
ac_plugin_list;}

ac_plugin_choose(){ cd "$DIR/Adachi/src/plugins"&&
gitserver&&
Choose="$(menubox "- 请选择插件"\
  1 "music                 点歌插件"\
  2 "hot-news              新闻插件"\
  3 "acg_search            以图识番"\
  4 "pic_search            搜图插件"\
  5 "coser-image           米游社Coser"\
  6 "mari-plugin           茉莉插件"\
  7 "setu-plugin           色图插件"\
  8 "group_helper          群助手插件"\
  9 "genshin_sign          米游社签到"\
  10 "genshin_rating        圣遗物评分"\
  11 "genshin_draw_analysis 抽卡分析"\
  0 "自定义")"||return
case "$Choose" in
  1)yz_git_plugin_install music "$URL/SilveryStar/Adachi-Plugin" -b music;;
  2)yz_git_plugin_install hot-news "$URL/BennettChina/hot-news";;
  3)yz_git_plugin_install acg_search "$URL/KallkaGo/acg_search";;
  4)yz_git_plugin_install pic_search "$URL/MarryDream/pic_search";;
  5)yz_git_plugin_install coser-image "$URL/BennettChina/coser-image";;
  6)yz_git_plugin_install mari-plugin "$URL/MarryDream/mari-plugin";;
  7)yz_git_plugin_install setu-plugin "$URL/BennettChina/setu-plugin";;
  8)yz_git_plugin_install group_helper "$URL/BennettChina/group_helper";;
  9)yz_git_plugin_install genshin_sign "$URL/wickedll/genshin_sign";;
  10)yz_git_plugin_install genshin_rating "$URL/wickedll/genshin_rating";;
  11)yz_git_plugin_install genshin_draw_analysis "$URL/wickedll/genshin_draw_analysis"&&pnpm_add exceljs qiniu qrcode;;
  0)Input="$(inputbox "请输入插件名")"&&InputURL="$(inputbox "请输入插件URL")"&&yz_git_plugin_install "$Input" "$InputURL";;
  *)return
esac&&back;ac_plugin_choose;}

ac_plugin(){ cd "$DIR/Adachi/src/plugins"||return
Choose="$(menubox "- Adachi 插件管理"\
  1 "管理插件"\
  2 "更新插件"\
  3 "安装插件"\
  0 "返回")"
case "$Choose" in
  1)ac_plugin_list;;
  2)process_start "更新" "所有插件" "" "[A"
    ls -AF|sed -n 's|/$||p'|while read i;do
      git_pull "$i"
    done
    process_stop
    back;;
  3)ac_plugin_choose;;
  *)return
esac;ac_plugin;}

dragonfly_download(){ echo "
$Y- 正在下载 Dragonfly$O"
time_start
getver_github dragonflydb/dragonfly home/Dragonfly||return
case "$(uname -m)" in
  aarch64|arm64|armv8*|armv9*)ARCH=aarch64;;
  x86_64|x64|amd64)ARCH=x86_64;;
  *)abort "不支持的CPU架构：$(uname -m)"
esac
echo "
  开始下载"
mktmp
geturl "$URL/dragonflydb/dragonfly/releases/download/$NEWNAME/dragonfly-$ARCH.tar.gz">"$TMP/Dragonfly.tgz"||abort "下载失败"
tar -xvzf "$TMP/Dragonfly.tgz" -C "$TMP"||abort "解压失败"
[ -s Dragonfly ]&&{ mv -vf Dragonfly Dragonfly.bak||abort "重命名原文件失败";}
mv -vf "$TMP/dragonfly-$ARCH" Dragonfly||abort "移动下载文件失败"
echo -n "name=$NEWNAME
version=$NEWVER
md5=$(md5 Dragonfly)">version
time_stop
msgbox "Dragonfly 下载完成，用时：$TimeSpend";}

dragonfly(){ [ -n "$MSYS" ]&&{ msgbox "Dragonfly 暂不支持 Windows";return;}
getver home/Dragonfly||{ yesnobox "未安装 Dragonfly，是否开始下载"&&dragonfly_download&&getver home/Dragonfly||return;}
Choose="$(menubox "Dragonfly $NAME ($VER)"\
  1 "文件管理"\
  2 "检查更新"\
  3 "删除 Dragonfly"\
  0 "返回")"
case "$Choose" in
  1)file_list;;
  2)dragonfly_download;;
  3)yesnobox "确认删除 Dragonfly？"&&{ rm -vrf "$HOME/Dragonfly";return;};;
  *)return
esac;dragonfly;}

yz_plugin(){ YzDir="$PWD"
Choose="$(menubox "- 请选择操作"\
  1 "JS 插件管理"\
  2 "Git 插件管理"\
  3 "Dragonfly 数据库"\
  4 "QSignServer"\
  0 "返回")"
case "$Choose" in
  1)yz_js_plugin;;
  2)yz_git_plugin;;
  3)dragonfly;;
  4)qss;;
  *)return
esac;cd "$YzDir";yz_plugin;}

catimg_qrcode(){ QRFile=data/qrcode.png
[ -s "$QRFile" ]||{ QRFile="$(ls data/icqq/*/qrcode.png)"||{ msgbox "未找到二维码文件";return;};}
if [ "$(wc -l<<<"$QRFile")" != 1 ];then
  Choose="$(eval menubox "'- 请选择二维码文件' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$QRFile")")"||return
  QRFile="$(sed -n "${Choose}p"<<<"$QRFile")"
fi
depend catimg&&
catimg -t "$QRFile">&3&&
back;}

fix_version(){ git_update pnpm up icqq@latest&&
Config_Device="$(menubox "- 请选择登录平台"\
  1 "安卓手机"\
  2 "安卓平板"\
  6 "TIM")"&&
sed -i "s/platform: .*/platform: $Config_Device/" "$1"&&
sed -i "/${3:-sign_api_addr}:/d;/ver:/d" "$2"&&
qss_config&&
echo -n "
${3:-sign_api_addr}: ${Config[QSignServer]}">>config/config/bot.yaml&&
rm -vrf data/device.json data/icqq/*/device.json&&
msgbox "修复完成"||abort "修复失败";}

yz_download(){ cd "$DIR"
runtime_install_nodejs
process_start "下载" "Yunzai"
git_clone "https://gitee.com/TimeRainStarSky/Yunzai-Bot" Yunzai&&
git_clone "https://Yunzai.TRSS.me" Yunzai/plugins/TRSS-Plugin
cd Yunzai
process_stop
process_start "安装" "依赖" "使用 pnpm "
pnpm i
process_stop
back;}

yz(){ cd "$DIR/Yunzai"
[ -d .git ]||{ yesnobox "未安装 Yunzai，是否开始下载"&&yz_download||return;}
NAME="$(json version<package.json)"
VER="$(git_logp cd)"
Choose="$(menubox "Le-Yunzai $NAME ($VER)"\
  1 "打开 Yunzai"\
  2 "启动 Yunzai"\
  3 "停止 Yunzai"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "修复禁止登录"\
  7 "查看二维码"\
  8 "插件管理"\
  9 "文件管理"\
  10 "更新日志"\
  11 "检查更新"\
  12 "清除数据"\
  13 "重置项目"\
  14 "重新安装"\
  15 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach Yunzai;;
  2)tmux_start Yunzai;;
  3)redis-cli SHUTDOWN & tmux_stop Yunzai;;
  4)file_list config/config;;
  5)rm -vrf config/config/*&&msgbox "配置文件已删除"||abort "配置文件删除失败";;
  6)git remote set-url origin "https://gitee.com/TimeRainStarSky/Yunzai-Bot"&&fix_version config/config/{qq,bot}.yaml;;
  7)catimg_qrcode;;
  8)yz_plugin;;
  9)file_list;;
  10)git_log;;
  11)git_update pnpm i;back;;
  12)yesnobox "确认清除数据？"&&{ rm -vrf config/config/* data logs&&msgbox "数据清除完成"||abort "数据清除失败";};;
  13)yesnobox "确认重置项目？"&&{ git reset --hard&&msgbox "项目重置完成"||abort "项目重置失败";};;
  14)yesnobox "将会清除所有数据，确认重新安装？"&&yz_download;;
  15)fg_start Yunzai;;
  *)return
esac;yz;}

myz_download(){ cd "$DIR"
runtime_install_nodejs
process_start "下载" "Miao-Yunzai"
git_clone "https://gitee.com/yoimiya-kokomi/Miao-Yunzai" Miao-Yunzai&&
git_clone "https://gitee.com/yoimiya-kokomi/miao-plugin" Miao-Yunzai/plugins/miao-plugin||process_stop
git_clone "https://Yunzai.TRSS.me" Miao-Yunzai/plugins/TRSS-Plugin
cd Miao-Yunzai
process_stop
process_start "安装" "依赖" "使用 pnpm "
pnpm i
process_stop
back;}

myz(){ cd "$DIR/Miao-Yunzai"
[ -d .git ]||{ yesnobox "未安装 Miao-Yunzai，是否开始下载"&&myz_download||return;}
NAME="$(json version<package.json)"
VER="$(git_logp cd)"
Choose="$(menubox "Miao-Yunzai $NAME ($VER)"\
  1 "打开 Miao-Yunzai"\
  2 "启动 Miao-Yunzai"\
  3 "停止 Miao-Yunzai"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "修复禁止登录"\
  7 "查看二维码"\
  8 "插件管理"\
  9 "文件管理"\
  10 "更新日志"\
  11 "检查更新"\
  12 "清除数据"\
  13 "重置项目"\
  14 "重新安装"\
  15 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach Miao-Yunzai;;
  2)tmux_start Miao-Yunzai;;
  3)redis-cli SHUTDOWN & tmux_stop Miao-Yunzai;;
  4)file_list config/config;;
  5)rm -vrf config/config/*&&msgbox "配置文件已删除"||abort "配置文件删除失败";;
  6)fix_version config/config/{qq,bot}.yaml;;
  7)catimg_qrcode;;
  8)yz_plugin;;
  9)file_list;;
  10)git_log;;
  11)git_update pnpm i;back;;
  12)yesnobox "确认清除数据？"&&{ rm -vrf config/config/* data logs&&msgbox "数据清除完成"||abort "数据清除失败";};;
  13)yesnobox "确认重置项目？"&&{ git reset --hard&&msgbox "项目重置完成"||abort "项目重置失败";};;
  14)yesnobox "将会清除所有数据，确认重新安装？"&&myz_download;;
  15)fg_start Miao-Yunzai;;
  *)return
esac;myz;}

tyz_download(){ cd "$DIR"
runtime_install_nodejs
process_start "下载" "TRSS-Yunzai"
git_clone "https://gitee.com/TimeRainStarSky/Yunzai" TRSS-Yunzai&&
git_clone "https://gitee.com/TimeRainStarSky/Yunzai-genshin" TRSS-Yunzai/plugins/genshin&&
git_clone "https://gitee.com/yoimiya-kokomi/miao-plugin" TRSS-Yunzai/plugins/miao-plugin||process_stop
git_clone "https://Yunzai.TRSS.me" TRSS-Yunzai/plugins/TRSS-Plugin
cd TRSS-Yunzai
process_stop
process_start "安装" "依赖" "使用 pnpm "
pnpm i
process_stop
back;}

tyz(){ cd "$DIR/TRSS-Yunzai"
[ -d .git ]||{ yesnobox "未安装 TRSS-Yunzai，是否开始下载"&&tyz_download||return;}
NAME="$(json version<package.json)"
VER="$(git_logp cd)"
Choose="$(menubox "TRSS-Yunzai $NAME ($VER)"\
  1 "打开 TRSS-Yunzai"\
  2 "启动 TRSS-Yunzai"\
  3 "停止 TRSS-Yunzai"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "插件管理"\
  7 "文件管理"\
  8 "更新日志"\
  9 "检查更新"\
  10 "清除数据"\
  11 "重置项目"\
  12 "重新安装"\
  13 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach TRSS-Yunzai;;
  2)tmux_start TRSS-Yunzai;;
  3)redis-cli SHUTDOWN & tmux_stop TRSS-Yunzai;;
  4)file_list config/config;;
  5)rm -vrf config/config/*&&msgbox "配置文件已删除"||abort "配置文件删除失败";;
  6)yz_plugin;;
  7)file_list;;
  8)git_log;;
  9)git_update pnpm i;back;;
  10)yesnobox "确认清除数据？"&&{ rm -vrf config/config/* data logs&&msgbox "数据清除完成"||abort "数据清除失败";};;
  11)yesnobox "确认重置项目？"&&{ git reset --hard&&msgbox "项目重置完成"||abort "项目重置失败";};;
  12)yesnobox "将会清除所有数据，确认重新安装？"&&tyz_download;;
  13)fg_start TRSS-Yunzai;;
  *)return
esac;tyz;}

ac_download(){ cd "$DIR"
runtime_install_nodejs
gitserver||return
process_start "下载" "Adachi"
git_clone "$URL/SilveryStar/Adachi-BOT" Adachi&&
cd Adachi
process_stop
process_start "安装" "依赖" "使用 pnpm "
echo -n "packages:
  - 'src/**'">pnpm-workspace.yaml
pnpm i -w puppeteer@19.2.2 @types/express-serve-static-core
process_stop
back;}

ac_create(){ Config_QQ="$(inputbox "请输入QQ号")"&&
Config_Password="$(passwordbox "请输入密码 (留空使用扫码登录)")"&&
Config_Device="$(menubox "- 请选择登录平台"\
  1 "安卓手机"\
  2 "安卓平板"\
  3 "安卓手表"\
  4 "MacOS"\
  5 "iPad")"&&
Config_SuperUser="$(inputbox "请输入主人QQ")"&&
Config_CMDPrefix="$(inputbox "请输入命令前缀")"||return
[ -n "$Config_Password" ]&&yesnobox "是否启用网页控制台"&&Config_WebConsole=true||Config_WebConsole=false
rm -vrf config
mkdir -vp config
echo "tips: 此文件修改后需重启应用">config/commands.yml||abort "配置文件写入失败"
echo "cookies:
  - 米游社Cookies(允许设置多个)">config/cookies.yml||abort "配置文件写入失败"
echo "tips:
- 欢迎使用 TRSS Yunzai ! 作者：时雨🌌星空
- 按 Ctrl+Q Y 保存退出
- 参考：https://docs.adachi.top/config
qrcode: false
number: $Config_QQ
password: '$Config_Password'
master: $Config_SuperUser
header: '$Config_CMDPrefix'
platform: $Config_Device
atUser: true
atBOT: false
addFriend: true
useWhitelist: false
fuzzyMatch: false
matchPrompt: true
inviteAuth: master
countThreshold: 60
ThresholdInterval: false
groupIntervalTime: 1500
privateIntervalTime: 2000
helpPort: 54919
helpMessageStyle: card
callTimes: 3
logLevel: info
dbPort: 6379
dbPassword: ''
banScreenSwipe:
  enable: false
  limit: 10
  duration: 1800
  prompt: true
  promptMsg: 请不要刷屏哦~
banHeavyAt:
  enable: false
  limit: 10
  duration: 1800
  prompt: true
  promptMsg: 你at太多人了，会被讨厌的哦~
webConsole:
  enable: $Config_WebConsole
  consolePort: 54980
  tcpLoggerPort: 54921
  logHighWaterMark: 64
  jwtSecret: '$(random_string 0-9a-zA-Z 16)'
autoChat:
  tip1: type参数说明：1为青云客，不用配置后面的两个secret，
  tip2: 2为腾讯自然语言处理，需要前往腾讯云开通NLP并获取到你的secret（听说超级智能）
  enable: true
  type: 1
  secretId: ''
  secretKey: ''">config/setting.yml||abort "配置文件写入失败"
msgbox "配置文件生成完成：
QQ号：$Config_QQ
密码：$(echo -n "$Config_Password"|tr -c '' '*')
主人QQ：$Config_SuperUser
命令前缀：$Config_CMDPrefix";}

ac(){ cd "$DIR/Adachi"
[ -d .git ]||{ yesnobox "未安装 Adachi，是否开始下载"&&ac_download||return;}
[ -s config/setting.yml ]||{ ac_create||return;}
NAME="$(json version<package.json)"
VER="$(git_logp cd)"
Choose="$(menubox "Adachi $NAME ($VER)"\
  1 "打开 Adachi"\
  2 "启动 Adachi"\
  3 "停止 Adachi"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "修复禁止登录"\
  7 "查看二维码"\
  8 "插件管理"\
  9 "文件管理"\
  10 "更新日志"\
  11 "检查更新"\
  12 "清除数据"\
  13 "重置项目"\
  14 "重新安装"\
  15 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach Adachi;;
  2)tmux_start Adachi;;
  3)redis-cli SHUTDOWN & tmux_stop Adachi;;
  4)file_list config;;
  5)ac_create;;
  6)fix_version config/setting.yml{,} signApiAddr;;
  7)catimg_qrcode;;
  8)ac_plugin;;
  9)file_list;;
  10)git_log;;
  11)git_update pnpm i -w puppeteer@19.2.2 @types/express-serve-static-core;back;;
  12)yesnobox "确认清除数据？"&&{ rm -vrf data database logs&&msgbox "数据清除完成"||abort "数据清除失败";};;
  13)yesnobox "确认重置项目？"&&{ git reset --hard&&msgbox "项目重置完成"||abort "项目重置失败";};;
  14)yesnobox "将会清除所有数据，确认重新安装？"&&ac_download;;
  15)fg_start Adachi;;
  *)return
esac;ac;}

saya_plugin_manager(){ [ -d "$1" ]&&SayaDir="$1"||saya_plugin_list
Choose="$(menubox "- Saya 插件：$SayaDir"\
  1 "文件管理"\
  2 "删除插件"\
  0 "返回")"
case "$Choose" in
  1)file_list "$SayaDir";;
  2)yesnobox "确认删除插件？"&&{
      rm -vrf "$SayaDir"||abort "插件删除失败"
    };;
  *)return
esac;saya_plugin_manager "$SayaDir";}

saya_plugin_list(){ cd "$DIR/Sagiri/modules/third_party"||return
SayaList="$(ls -AF|sed -n 's|/$||p')"
Choose="$(eval menubox "'- 已安装 Saya 插件' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$SayaList")")"||return
saya_plugin_manager "$(sed -n "${Choose}p"<<<"$SayaList")"
saya_plugin_list;}

saya_plugin_install(){ SayaDir="$1" SayaURL="$2"
yesnobox "确认安装插件？
插件名：$SayaDir
插件URL：$SayaURL"||return
process_start "安装" "插件" "" "：$C$SayaDir"
rm -rf "$SayaDir"||process_stop "删除"
mktmp
geturl "$SayaURL">"$TMP/saya.txz"&&
xz -dcv "$TMP/saya.txz"|tar -xv
process_stop
[ -s "$SayaDir/requirements.txt" ]&&{ process_start "安装" "依赖" "使用 pip "
pip_install -r "$SayaDir/requirements.txt"
process_stop;};}

mockingbird_model_install(){ MBModName="$1" MBModURL="$2"
process_start "安装" "模型" "" "：$C$MBModName"
mktmp
geturl "$MBModURL">"$TMP/mbmod.txz"&&
mkdir -vp "$DIR/Sagiri/resources/mockingbird"&&
xz -dcv "$TMP/mbmod.txz"|tar -xvC "$DIR/Sagiri/resources/mockingbird"
process_stop;}

mockingbird_install(){ Choose="$(menubox "- 请选择安装组件"\
  1 "MockingBird"\
  2 "azusa 模型"\
  3 "tianyi 模型"\
  0 "返回")"
case "$Choose" in
  1)mockingbird_model_install "mockingbird" "$URL/TimeRainStarSky/Sagiri_MockingBird/releases/download/latest/mockingbird.txz";;
  2)mockingbird_model_install "azusa" "$URL/TimeRainStarSky/Sagiri_MockingBird/releases/download/latest/azusa.txz";;
  3)mockingbird_model_install "tianyi" "$URL/TimeRainStarSky/Sagiri_MockingBird/releases/download/latest/tianyi.txz";;
  *)return
esac&&back;mockingbird_install;}

saya_plugin_choose(){ cd "$DIR/Sagiri/modules/third_party"&&
Choose="$(menubox "- 请选择插件"\
  1 "MockingBird"\
  0 "自定义")"||return
case "$Choose" in
  1)gitserver&&mockingbird_install;;
  0)Input="$(inputbox "请输入插件名")"&&InputURL="$(inputbox "请输入插件URL")"&&saya_plugin_install "$Input" "$InputURL"&&back;;
  *)return
esac;saya_plugin_choose;}

saya_plugin(){ cd "$DIR/Sagiri/modules/third_party"||return
Choose="$(menubox "- Saya 插件管理"\
  1 "管理插件"\
  2 "安装插件"\
  0 "返回")"
case "$Choose" in
  1)saya_plugin_list;;
  2)saya_plugin_choose;;
  *)return
esac;saya_plugin;}

si_plugin(){ cd "$DIR/Sagiri"&&[ -s pyproject.toml ]||return
Choose="$(menubox "- 请选择操作"\
  1 "PyPI 软件包管理"\
  2 "Saya 插件管理"\
  0 "返回")"
case "$Choose" in
  1)pypi;;
  2)saya_plugin;;
  *)return
esac;si_plugin;}

si_download(){ cd "$DIR"
runtime_install_python
gitserver||return
process_start "下载" "Sagiri"
git_clone "$URL/SAGIRI-kawaii/sagiri-bot" Sagiri&&
cd Sagiri
process_stop
process_start "安装" "依赖" "使用 Poetry "
poetry_install --all-extras
process_stop
back;}

si(){ cd "$DIR/Sagiri"
[ -d .git ]||{ yesnobox "未安装 Sagiri，是否开始下载"&&si_download||return;}
NAME="$(rg -m1 'version =' pyproject.toml|tr -d ' "'|sed "s/version=//")"
VER="$(git_logp cd)"
Choose="$(menubox "Sagiri $NAME ($VER)"\
  1 "打开 Sagiri"\
  2 "启动 Sagiri"\
  3 "停止 Sagiri"\
  4 "修改配置文件"\
  5 "插件管理"\
  6 "文件管理"\
  7 "更新日志"\
  8 "检查更新"\
  9 "重置项目"\
  10 "重新安装"\
  11 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach Sagiri;;
  2)tmux_start Sagiri;;
  3)tmux_stop Sagiri;;
  4)file_list config;;
  5)si_plugin;;
  6)file_list;;
  7)git_log;;
  8)git_update poetry install --all-extras;back;;
  9)yesnobox "确认重置项目？"&&{ git reset --hard&&msgbox "项目重置完成"||abort "项目重置失败";};;
  10)yesnobox "将会清除所有数据，确认重新安装？"&&si_download;;
  11)fg_start Sagiri;;
  *)return
esac;si;}

ai_plugin(){ cd "$DIR/Amiya"&&[ -s pyproject.toml ]||return
Choose="$(menubox "- 请选择操作"\
  1 "PyPI 软件包管理"\
  0 "返回")"
case "$Choose" in
  1)pypi;;
  *)return
esac;ai_plugin;}

ai_download(){ cd "$DIR"
runtime_install_python
process_start "下载" "Amiya"
gitserver||return
git_clone "$URL/AmiyaBot/Amiya-Bot" Amiya&&
cd Amiya
process_stop
process_start "安装" "依赖" "使用 pip "
echo '[tool.poetry]
name = "Amiya-Bot"
version = "0.1.0"
description = "基于 AmiyaBot 框架的 QQ 聊天机器人"
authors = ["时雨🌌星空 <Time.Rain.Star.Sky@Gmail.com>"]'>pyproject.toml&&
poetry run bash -c "pip config set global.index-url '$PyPIURL'&&pip config set global.extra-index-url '$PyPIURL'&&pip install -U pip&&pip install -Ur requirements.txt&&playwright install chromium"&&
sed -i "s/from collections import/from collections.abc import/" "$([ -n "$MSYS" ]&&cygpath -u "$(poetry env info -p)\\Lib"||echo "$(poetry env info -p)/lib/python"*)/site-packages/attrdict/"*.py&&
process_stop
back
Config_Authkey="$(passwordbox "请输入服务密匙")"&&sed -i "s/127.0.0.1/0.0.0.0/;s/authKey:/authKey: '$Config_Authkey'/" config/server.yaml
msgbox "Amiya 安装完成
服务密匙：$(echo -n "$Config_Authkey"|tr -c '' '*')";}

ai(){ cd "$DIR/Amiya"
[ -d .git ]||{ yesnobox "未安装 Amiya，是否开始下载"&&ai_download||return;}
NAME="$(cat .github/publish.txt)"
VER="$(git_logp cd)"
Choose="$(menubox "Amiya $NAME ($VER)"\
  1 "打开 Amiya"\
  2 "启动 Amiya"\
  3 "停止 Amiya"\
  4 "修改配置文件"\
  5 "插件管理"\
  6 "文件管理"\
  7 "更新日志"\
  8 "检查更新"\
  9 "重置项目"\
  10 "重新安装"\
  11 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach Amiya;;
  2)tmux_start Amiya;;
  3)tmux_stop Amiya;;
  4)file_list config;;
  5)ai_plugin;;
  6)file_list;;
  7)git_log;;
  8)git_update "poetry run bash -c 'pip install -U pip&&pip install -Ur requirements.txt&&playwright install chromium'";back;;
  9)yesnobox "确认重置项目？"&&{ git reset --hard&&msgbox "项目重置完成"||abort "项目重置失败";};;
  10)yesnobox "将会清除所有数据，确认重新安装？"&&ai_download;;
  11)fg_start Amiya;;
  *)return
esac;ai;}

postgresql_install(){ sed -i 's|bind:.*|bind: str = "postgres://zhenxun:TimeRainStarSky@localhost:5432/zhenxun"|g' "$DIR/Zhenxun/configs/config.py"
type pg_ctl psql &>/dev/null||{
if [ -n "$MSYS" ];then
  depend_install postgresql
else
  pacman_Syu postgresql
fi;}
process_start "初始化" "数据库"
if [ -n "$MSYS" ];then
  PGSQLDB=/win/pgsql/data
  rm -rf "$PGSQLDB"&&
  mkdir -vp "$PGSQLDB"&&
  initdb -D "$PGSQLDB"||process_stop
  pg_ctl start -D "$PGSQLDB"&&
  createdb&&
  psql -c "CREATE USER zhenxun WITH PASSWORD 'TimeRainStarSky'"&&
  psql -c "CREATE DATABASE zhenxun OWNER zhenxun"&&
  pg_ctl stop -D "$PGSQLDB"
else
  PGSQLDB=/var/lib/postgres/data
  rm -rf "$PGSQLDB"&&
  mkdir -vp "$PGSQLDB"&&
  chown postgres:postgres "$PGSQLDB"&&
  su - postgres -c "initdb -D '$PGSQLDB'"&&
  mkdir -vp /run/postgresql&&
  chown postgres:postgres /run/postgresql||process_stop
  su - postgres -c "pg_ctl start -D '$PGSQLDB'&&
  psql -c \"CREATE USER zhenxun WITH PASSWORD 'TimeRainStarSky'\"&&
  psql -c 'CREATE DATABASE zhenxun OWNER zhenxun'&&
  pg_ctl stop -D '$PGSQLDB'"
fi||process_stop "创建"
process_stop;}

zx_download(){ cd "$DIR"
runtime_install_python
process_start "下载" "Zhenxun"
gitserver||return
git_clone "$URL/HibiKier/zhenxun_bot" Zhenxun&&
cd Zhenxun&&
rm -vrf .env.dev
process_stop
process_start "安装" "依赖" "使用 Poetry "
poetry add --lock lxml==4.9.3 pyyaml==6.0.1 wordcloud==1.9.2
poetry_install
poetry run playwright install chromium
process_stop
postgresql_install
back;}

zx_create(){ Config_SuperUser="$(inputbox "请输入主人QQ")"&&
Config_NickName="$(inputbox "请输入Bot昵称" 真寻)"&&
Config_CMDStart="$(inputbox "请输入命令前缀")"||return
echo 'HOST=0.0.0.0
PORT=8080
DEBUG=False
SUPERUSERS=['"$Config_SuperUser"']
NICKNAME=["'"$Config_NickName"'","小真寻","绪山真寻","小寻子"]
COMMAND_START=["'"$Config_CMDStart"'"]
SESSION_RUNNING_EXPRESSION="别急呀,小真寻要宕机了!QAQ"
SESSION_EXPIRE_TIMEOUT=30'>.env.dev||abort "配置文件写入失败"
msgbox "配置文件生成完成：
主人QQ：$Config_SuperUser
Bot昵称：$Config_NickName
命令前缀：$Config_CMDStart";}

zx_config(){ Choose="$(menubox "- 请选择配置文件"\
  1 "环境配置 .env.dev"\
  2 "项目配置 pyproject.toml"\
  3 "插件配置 configs")"
case "$Choose" in
  1)editor .env.dev;;
  2)editor pyproject.toml;;
  3)file_list configs;;
  *)return
esac;zx_config;}

zx(){ cd "$DIR/Zhenxun"
[ -d .git ]||{ yesnobox "未安装 Zhenxun，是否开始下载"&&zx_download||return;}
[ -s .env.dev ]||{ zx_create||return;}
NAME="$(cut -d ':' -f2 __version__|tr -d ' ')"
VER="$(git_logp cd)"
Choose="$(menubox "Zhenxun $NAME ($VER)"\
  1 "打开 Zhenxun"\
  2 "启动 Zhenxun"\
  3 "停止 Zhenxun"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "重建数据库"\
  7 "插件管理"\
  8 "文件管理"\
  9 "更新日志"\
  10 "检查更新"\
  11 "重置项目"\
  12 "重新安装"\
  13 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach Zhenxun;;
  2)tmux_start Zhenxun;;
  3)if [ -n "$MSYS" ];then pg_ctl stop -D /win/pgsql/data;else su - postgres -c "pg_ctl stop -D /var/lib/postgres/data";fi;tmux_stop Zhenxun;;
  4)zx_config;;
  5)zx_create;;
  6)postgresql_install&&back;;
  7)NBPluginDir=plugins;nb_plugin;;
  8)file_list;;
  9)git_log;;
  10)git checkout pyproject.toml poetry.lock&&git_update "poetry add --lock lxml==4.9.3 pyyaml==6.0.1 wordcloud==1.9.2&&poetry install&&poetry run playwright install chromium";back;;
  11)yesnobox "确认重置项目？"&&{ git reset --hard&&rm -vrf .env.dev&&msgbox "项目重置完成"||abort "项目重置失败";};;
  12)yesnobox "将会清除所有数据，确认重新安装？"&&zx_download;;
  13)fg_start Zhenxun;;
  *)return
esac;zx;}

zxwebui_download(){ cd "$DIR"
type nginx &>/dev/null||{
if [ -n "$MSYS" ];then
  depend_install nginx
else
  pacman_Syu nginx
fi;}
process_start "下载" "ZxWebUI"
gitserver||return
git_clone "$URL/HibiKier/zhenxun_bot_webui" ZxWebUI&&
cd ZxWebUI
process_stop
back;}

zxwebui_create(){ Config_PORT="$(inputbox "请输入端口" 8081)"||return
if [ -n "$MSYS" ];then
  echo "events {
  worker_connections 1024;
}
http {
  include mime.types;
  default_type application/octet-stream;
  access_log '$(cygpath -w "$DIR/ZxWebUI/access.log")';
  sendfile on;
  server {
    listen $Config_PORT;
    root '$(cygpath -w "$DIR/ZxWebUI/dist")';
  }
}">nginx.conf&&
  ln -vf nginx.conf /win/nginx/conf||abort "配置文件写入失败"
else
  echo "user root;
events {
  worker_connections 1024;
}
http {
  include mime.types;
  default_type application/octet-stream;
  access_log '$DIR/ZxWebUI/access.log';
  sendfile on;
  server {
    listen $Config_PORT;
    root '$DIR/ZxWebUI/dist';
  }
}">nginx.conf&&
  ln -vsf "$DIR/ZxWebUI/nginx.conf" /etc/nginx||abort "配置文件写入失败"
fi
msgbox "配置文件生成完成：
端口：$Config_PORT";}

zxwebui(){ cd "$DIR/ZxWebUI"
[ -d .git ]||{ yesnobox "未安装 ZxWebUI，是否开始下载"&&zxwebui_download||return;}
[ -s nginx.conf ]||{ zxwebui_create||return;}
NAME="$(json version<package.json)"
VER="$(git_logp cd)"
Choose="$(menubox "ZxWebUI $NAME ($VER)"\
  1 "打开 ZxWebUI"\
  2 "启动 ZxWebUI"\
  3 "停止 ZxWebUI"\
  4 "修改配置文件"\
  5 "重建配置文件"\
  6 "文件管理"\
  7 "更新日志"\
  8 "检查更新"\
  9 "重置项目"\
  10 "重新安装"\
  11 "前台启动"\
  0 "返回")"
case "$Choose" in
  1)tmux_attach ZxWebUI;;
  2)tmux_start ZxWebUI;;
  3)nginx -s quit & tmux_stop ZxWebUI;;
  4)editor nginx.conf;;
  5)zxwebui_create;;
  6)file_list;;
  7)git_log;;
  8)git_update;back;;
  9)yesnobox "确认重置项目？"&&{ git reset --hard&&msgbox "项目重置完成"||abort "项目重置失败";};;
  10)yesnobox "将会清除所有数据，确认重新安装？"&&zxwebui_download;;
  11)fg_start ZxWebUI;;
  *)return
esac;zxwebui;}

pnpm_add(){ process_start "安装" "依赖" "使用 pnpm " "：$C$*"
[ -d "$GitDir" ]&&cd "$GitDir"&&{
  [ -s package.json ]||echo '{
  "name": "'"$GitDir"'",
  "type": "module"
}'>package.json
}
pnpm add "$@"
process_stop;}

pnpm_manager(){ [ -s "${1:-.}/package.json" ]&&cd "${1:-.}"||return
Choose="$(menubox "- pnpm 软件包管理：$(json name<package.json)"\
  1 "文件管理"\
  2 "列出软件包"\
  3 "更新软件包"\
  4 "安装软件包"\
  5 "删除软件包"\
  6 "修改镜像源"\
  0 "返回")"
case "$Choose" in
  1)file_list node_modules;;
  2)echo "
$Y- 已安装软件包：$O
"
    pnpm ls
    back;;
  3)process_start "更新" "软件包"
    pnpm up --latest
    process_stop
    back;;
  4)Input="$(inputbox "请输入安装软件包名")"&&{
      process_start "安装" "软件包" "" "：$C$Input"
      pnpm add "$Input"
      process_stop
      back
    };;
  5)Input="$(inputbox "请输入删除软件包名")"&&{
      process_start "删除" "软件包" "" "：$C$Input"
      pnpm rm "$Input"
      process_stop
      back
    };;
  6)Input="$(inputbox "请输入镜像源地址")"&&{
      process_start "修改" "镜像源" "" "：$C$Input"
      pnpm config set registry "$Input"
      process_stop
      back
    };;
  *)return
esac;pnpm_manager;}

pypi_list(){ gaugebox "- 正在扫描 Py 项目"
PyPIList="$(fd -HIt f '^pyproject.toml$'|sed '/^home\/\.cache\//d;s|/pyproject.toml$||')"
gaugebox_stop
[ -n "$PyPIList" ]&&Choose="$(eval menubox "'- 请选择工作空间' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$PyPIList")")"||return
pypi "$(sed -n "${Choose}p"<<<"$PyPIList")"
pypi_list;}

pnpm_list(){ gaugebox "- 正在扫描工作空间"
PMList="$(fd -HIt d '^node_modules$' "$DIR"|sed 's|/node_modules/$||;/\/node_modules\//d')"
gaugebox_stop
[ -n "$PMList" ]&&Choose="$(eval menubox "'- 请选择工作空间' $(n=1;while read i;do echo -n "$n \"$i\" ";((n++));done<<<"$PMList")")"||return
pnpm_manager "$(sed -n "${Choose}p"<<<"$PMList")"
pnpm_list;}

plugin(){ Choose="$(menubox "- 请选择操作"\
  1 "PyPI 软件包管理"\
  2 "pnpm 软件包管理"\
  0 "返回")"
case "$Choose" in
  1)pypi_list;;
  2)pnpm_list;;
  *)return
esac;plugin;}

backup_menu(){ cd "$DIR"
Choose="$(menubox "- 请选择备份项目"\
  1 "go-cqhttp"\
  2 "Mirai"\
  3 "ZeroBot"\
  4 "Liteyuki"\
  5 "LittlePaimon"\
  6 "Yunzai"\
  7 "Miao-Yunzai"\
  8 "TRSS-Yunzai"\
  9 "Adachi"\
  10 "Sagiri"\
  11 "Amiya"\
  12 "Zhenxun"\
  13 "ZxWebUI"\
  14 "home"\
  15 "全部"\
  0 "自定义")"||return
case "$Choose" in
  1)backup_choose go-cqhttp go-cqhttp-data go-cqhttp/config* go-cqhttp/device.json go-cqhttp/session.token go-cqhttp/data*;;
  2)backup_choose Mirai Mirai-data Mirai/config* Mirai/bots Mirai/data*;;
  3)backup_choose ZeroBot ZeroBot-data ZeroBot/config* ZeroBot/data*;;
  4)backup_choose Liteyuki Liteyuki-data Liteyuki/.env* Liteyuki/data*;;
  5)backup_choose LittlePaimon LittlePaimon-data LittlePaimon/.env* LittlePaimon/config* LittlePaimon/data*;;
  6)backup_choose Yunzai Yunzai-data Yunzai/config/config* Yunzai/data*;;
  7)backup_choose Miao-Yunzai Miao-Yunzai-data Miao-Yunzai/config/config* Miao-Yunzai/data*;;
  8)backup_choose TRSS-Yunzai TRSS-Yunzai-data TRSS-Yunzai/config/config* TRSS-Yunzai/data*;;
  9)backup_choose Adachi Adachi-data Adachi/config* Adachi/data*;;
  10)backup_choose Sagiri Sagiri-data Sagiri/config* Sagiri/data*;;
  11)backup_choose Amiya Amiya-data Amiya/config* Amiya/data*;;
  12)backup_choose Zhenxun Zhenxun-data Zhenxun/.env* Zhenxun/config* Zhenxun/data*;;
  13)backup_zstd ZxWebUI;;
  14)backup_zstd home;;
  15)backup_zstd All home Adachi Amiya go-cqhttp Liteyuki LittlePaimon Miao-Yunzai Mirai Sagiri TRSS-Yunzai Yunzai ZeroBot Zhenxun ZxWebUI;;
  0)BackupName="$(inputbox "请输入备份名")"&&BackupDir="$(inputbox "请输入备份路径")"&&backup_zstd "$BackupName" "$BackupDir"||return
esac;back;}

autostart_set(){ rg -m1 "bash '$DIR/AutoStart.sh'" "$OHOME/.profile" &>/dev/null||echo "bash '$DIR/AutoStart.sh'">>"$OHOME/.profile"
echo 'MAIN="$(dirname "$0")/Main.sh"
main(){ bash "$MAIN" "$@";}'>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_Update]}" = 1 ]&&echo "main update all quiet">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_gocqhttp]}" = 1 ]&&echo "main go-cqhttp start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_ZeroBot]}" = 1 ]&&echo "main ZeroBot start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_Liteyuki]}" = 1 ]&&echo "main Liteyuki start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_LittlePaimon]}" = 1 ]&&echo "main LittlePaimon start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_Yunzai]}" = 1 ]&&echo "main Yunzai start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_MiaoYunzai]}" = 1 ]&&echo "main Miao-Yunzai start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_TRSSYunzai]}" = 1 ]&&echo "main TRSS-Yunzai start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_Adachi]}" = 1 ]&&echo "main Adachi start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_Sagiri]}" = 1 ]&&echo "main Sagiri start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_Amiya]}" = 1 ]&&echo "main Amiya start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_Zhenxun]}" = 1 ]&&echo "main Zhenxun start">>"$DIR/AutoStart.sh"
[ "${Config[AutoStart_ZxWebUI]}" = 1 ]&&echo "main ZxWebUI start">>"$DIR/AutoStart.sh"
config_save;}

autostart(){ Choose="$(menubox "- 请选择自启动项目"\
  1 "检查更新     $([ "${Config[AutoStart_Update]}" = 1 ]&&echo "开启"||echo "关闭")"\
  2 "go-cqhttp    $([ "${Config[AutoStart_gocqhttp]}" = 1 ]&&echo "开启"||echo "关闭")"\
  3 "ZeroBot      $([ "${Config[AutoStart_ZeroBot]}" = 1 ]&&echo "开启"||echo "关闭")"\
  4 "Liteyuki     $([ "${Config[AutoStart_Liteyuki]}" = 1 ]&&echo "开启"||echo "关闭")"\
  5 "LittlePaimon $([ "${Config[AutoStart_LittlePaimon]}" = 1 ]&&echo "开启"||echo "关闭")"\
  6 "Yunzai       $([ "${Config[AutoStart_Yunzai]}" = 1 ]&&echo "开启"||echo "关闭")"\
  7 "Miao-Yunzai  $([ "${Config[AutoStart_MiaoYunzai]}" = 1 ]&&echo "开启"||echo "关闭")"\
  8 "TRSS-Yunzai  $([ "${Config[AutoStart_TRSSYunzai]}" = 1 ]&&echo "开启"||echo "关闭")"\
  9 "Adachi       $([ "${Config[AutoStart_Adachi]}" = 1 ]&&echo "开启"||echo "关闭")"\
  10 "Sagiri       $([ "${Config[AutoStart_Sagiri]}" = 1 ]&&echo "开启"||echo "关闭")"\
  11 "Amiya        $([ "${Config[AutoStart_Amiya]}" = 1 ]&&echo "开启"||echo "关闭")"\
  12 "Zhenxun      $([ "${Config[AutoStart_Zhenxun]}" = 1 ]&&echo "开启"||echo "关闭")"\
  13 "ZxWebUI      $([ "${Config[AutoStart_ZxWebUI]}" = 1 ]&&echo "开启"||echo "关闭")")"
case "$Choose" in
  1)[ "${Config[AutoStart_Update]}" = 1 ]&&Config[AutoStart_Update]=||Config[AutoStart_Update]=1;;
  2)[ "${Config[AutoStart_gocqhttp]}" = 1 ]&&Config[AutoStart_gocqhttp]=||Config[AutoStart_gocqhttp]=1;;
  3)[ "${Config[AutoStart_ZeroBot]}" = 1 ]&&Config[AutoStart_ZeroBot]=||Config[AutoStart_ZeroBot]=1;;
  4)[ "${Config[AutoStart_Liteyuki]}" = 1 ]&&Config[AutoStart_Liteyuki]=||Config[AutoStart_Liteyuki]=1;;
  5)[ "${Config[AutoStart_LittlePaimon]}" = 1 ]&&Config[AutoStart_LittlePaimon]=||Config[AutoStart_LittlePaimon]=1;;
  6)[ "${Config[AutoStart_Yunzai]}" = 1 ]&&Config[AutoStart_Yunzai]=||Config[AutoStart_Yunzai]=1;;
  7)[ "${Config[AutoStart_MiaoYunzai]}" = 1 ]&&Config[AutoStart_MiaoYunzai]=||Config[AutoStart_MiaoYunzai]=1;;
  8)[ "${Config[AutoStart_TRSSYunzai]}" = 1 ]&&Config[AutoStart_TRSSYunzai]=||Config[AutoStart_TRSSYunzai]=1;;
  9)[ "${Config[AutoStart_Adachi]}" = 1 ]&&Config[AutoStart_Adachi]=||Config[AutoStart_Adachi]=1;;
  10)[ "${Config[AutoStart_Sagiri]}" = 1 ]&&Config[AutoStart_Sagiri]=||Config[AutoStart_Sagiri]=1;;
  11)[ "${Config[AutoStart_Amiya]}" = 1 ]&&Config[AutoStart_Amiya]=||Config[AutoStart_Amiya]=1;;
  12)[ "${Config[AutoStart_Zhenxun]}" = 1 ]&&Config[AutoStart_Zhenxun]=||Config[AutoStart_Zhenxun]=1;;
  13)[ "${Config[AutoStart_ZxWebUI]}" = 1 ]&&Config[AutoStart_ZxWebUI]=||Config[AutoStart_ZxWebUI]=1;;
  *)return
esac;autostart_set;autostart;}

about(){ echo "
$C- 系统信息：$O
"
fastfetch
type getprop &>/dev/null&&
echo "
  设备代号：$C$(getprop ro.product.device)$O
  设备型号：$C$(getprop ro.product.marketname) ($(getprop ro.product.name))$O
  认证型号：$C$(getprop ro.product.model)$O
  安卓版本：$C$(getprop ro.build.version.release) (SDK $(getprop ro.build.version.sdk))$O
  系统版本：$C$(getprop ro.build.version.incremental) ($(getprop ro.build.display.id))$O
  编译时间：$C$(date -d "@$(getprop ro.build.date.utc)" "+%F %T")$O
  基带版本：$C$(getprop gsm.version.baseband|cut -d "," -f1)$O"
echo "
$C- 关于脚本：$O

  作者：$C时雨🌌星空$O
  爱发电:$C https://afdian.net/a/TimeRainStarSky$O
  Partme:$C https://partme.com/TimeRainStarSky$O
  感谢名单:$C https://github.com/TimeRainStarSky/SponsorList$O

  go-cqhttp:$C https://docs.go-cqhttp.org$O
  Mirai:$C https://mirai.mamoe.net$O
  Mirai Console Loader:$C https://github.com/iTXTech/mirai-console-loader$O

  ZeroBot:$C https://github.com/wdvxdr1123/ZeroBot$O
  ZeroBot-Plugin:$C https://github.com/FloatTech/ZeroBot-Plugin$O

  NoneBot2:$C https://v2.nonebot.dev$O
  Liteyuki:$C https://github.com/snowyfirefly/Liteyuki-Bot$O
  LittlePaimon:$C https://blog.cherishmoon.fun/posts/littlepaimon-nonebot2.html$O
  Zhenxun:$C https://hibikier.github.io/zhenxun_bot$O

  Yunzai:$C https://github.com/Le-niao/Yunzai-Bot$O
  Adachi:$C https://docs.adachi.top$O

  Graia-Ariadne:$C https://graia.readthedocs.io/ariadne$O
  Sagiri:$C https://sagiri-kawaii.github.io/sagiri-bot$O
  Amiya:$C https://amiyabot.com$O

  QQ群号:$C 659945190 1027131254 300714227$O
  GitHub:$C https://github.com/TimeRainStarSky/TRSS_AllBot$O
  Gitee :$C https://gitee.com/TimeRainStarSky/TRSS_AllBot$O
  Agit  :$C https://agit.ai/TimeRainStarSky/TRSS_AllBot$O
  GitLab:$C https://gitlab.com/TimeRainStarSky/TRSS_AllBot$O
  Coding:$C https://trss.coding.net/public/TRSS/AllBot/git$O
  GitCode:$C https://gitcode.net/TimeRainStarSky1/TRSS_AllBot$O
  GitLink:$C https://gitlink.org.cn/TimeRainStarSky/TRSS_AllBot$O
  JiHuLab:$C https://jihulab.com/TimeRainStarSky/TRSS_AllBot$O
  Bitbucket:$C https://bitbucket.org/TimeRainStarSky/TRSS_AllBot$O";}

main(){ cd "$DIR"
Choose="$(menubox "- 请选择操作"\
  1 "go-cqhttp"\
  2 "Mirai"\
  3 "ZeroBot"\
  4 "Liteyuki"\
  5 "LittlePaimon"\
  6 "Le-Yunzai"\
  7 "Miao-Yunzai"\
  8 "TRSS-Yunzai"\
  9 "Adachi"\
  10 "Sagiri"\
  11 "Amiya"\
  12 "Zhenxun"\
  13 "ZxWebUI"\
  14 "插件管理"\
  15 "使用说明"\
  16 "附加功能"\
  17 "关于脚本"\
  18 "检查更新"\
  0 "退出")"
case "$Choose" in
  1)gcq;;
  2)mcl;;
  3)zbp;;
  4)ly;;
  5)lp;;
  6)yz;;
  7)myz;;
  8)tyz;;
  9)ac;;
  10)si;;
  11)ai;;
  12)zx;;
  13)zxwebui;;
  14)plugin;;
  15)manual;back;;
  16)extra;;
  17)about;back;;
  18)update;;
  *)exit 0
esac;main;}

proxy_check

case "$1" in
  g|gcq|go-cqhttp)cd "$DIR/go-cqhttp"&&{ [ -s "$2/config.yml" ]&&{ GCQDir="$2";shift;}||GCQDir="$(ls */config.yml|sed "s|/config.yml$||")"
  for GCQDir in $GCQDir;do cd "$DIR/go-cqhttp/$GCQDir"&&case "$2" in
    a|attach)tmux_attach "$GCQDir" go-cqhttp;;
    s|start)tmux_start_quiet "$GCQDir" go-cqhttp;;
    f|fgstart)fg_start "$GCQDir" go-cqhttp;;
    st|stop)tmux_stop_quiet "$GCQDir" go-cqhttp;;
    c|config)editor config.yml;;
    cr|create)gcq_create;;
    fi|file)file_list;;
    d|download|u|update)gcq_download;;
    *)gcq
  esac;done;};;
  m|mcl|Mirai)cd "$DIR/Mirai"&&case "$2" in
    a|attach)tmux_attach Mirai;;
    s|start)tmux_start_quiet Mirai;;
    f|fgstart)fg_start Mirai;;
    st|stop)tmux_stop_quiet Mirai;;
    c|config)file_list config;;
    cr|create)mcl_create;;
    fi|file)file_list;;
    d|download|u|update)mcl_download;;
    *)mcl
  esac;;
  z|zbp|ZeroBot)cd "$DIR/ZeroBot"&&case "$2" in
    a|attach)tmux_attach zbp ZeroBot;;
    s|start)tmux_start_quiet zbp ZeroBot;;
    f|fgstart)fg_start zbp ZeroBot;;
    st|stop)tmux_stop_quiet zbp ZeroBot;;
    c|config)editor config.json;;
    cr|create)zbp_create;;
    fi|file)file_list;;
    d|download|u|update)zbp_download;;
    *)zbp
  esac;;
  l|ly|Liteyuki)cd "$DIR/Liteyuki"&&case "$2" in
    a|attach)tmux_attach Liteyuki;;
    s|start)tmux_start_quiet Liteyuki;;
    f|fgstart)fg_start Liteyuki;;
    st|stop)tmux_stop_quiet Liteyuki;;
    c|config)ly_config;;
    cr|create)ly_create;;
    p|plugin)NBPluginDir=src;nb_plugin;;
    fi|file)file_list;;
    d|download)ly_download;;
    u|update)git_update poetry install;;
    *)ly
  esac;;
  lp|LittlePaimon)cd "$DIR/LittlePaimon"&&case "$2" in
    a|attach)tmux_attach LittlePaimon;;
    s|start)tmux_start_quiet LittlePaimon;;
    f|fgstart)fg_start LittlePaimon;;
    st|stop)tmux_stop_quiet LittlePaimon;;
    c|config)lp_config;;
    cr|create)lp_create;;
    p|plugin)NBPluginDir=src;nb_plugin;;
    fi|file)file_list;;
    d|download)lp_download;;
    u|update)git_update poetry install;;
    *)lp
  esac;;
  y|yz|Yunzai)cd "$DIR/Yunzai"&&case "$2" in
    a|attach)tmux_attach Yunzai;;
    s|start)tmux_start_quiet Yunzai;;
    f|fgstart)fg_start Yunzai;;
    st|stop)redis-cli SHUTDOWN & tmux_stop_quiet Yunzai;;
    c|config)file_list config/config;;
    p|plugin)yz_plugin;;
    fi|file)file_list;;
    d|download)yz_download;;
    u|update)git_update pnpm i;;
    *)yz
  esac;;
  my|myz|Miao-Yunzai)cd "$DIR/Miao-Yunzai"&&case "$2" in
    a|attach)tmux_attach Miao-Yunzai;;
    s|start)tmux_start_quiet Miao-Yunzai;;
    f|fgstart)fg_start Miao-Yunzai;;
    st|stop)redis-cli SHUTDOWN & tmux_stop_quiet Miao-Yunzai;;
    c|config)file_list config/config;;
    p|plugin)yz_plugin;;
    fi|file)file_list;;
    d|download)myz_download;;
    u|update)git_update pnpm i;;
    *)myz
  esac;;
  ty|tyz|TRSS-Yunzai)cd "$DIR/TRSS-Yunzai"&&case "$2" in
    a|attach)tmux_attach TRSS-Yunzai;;
    s|start)tmux_start_quiet TRSS-Yunzai;;
    f|fgstart)fg_start TRSS-Yunzai;;
    st|stop)redis-cli SHUTDOWN & tmux_stop_quiet TRSS-Yunzai;;
    c|config)file_list config/config;;
    p|plugin)yz_plugin;;
    fi|file)file_list;;
    d|download)tyz_download;;
    u|update)git_update pnpm i;;
    *)tyz
  esac;;
  a|ac|Adachi)cd "$DIR/Adachi"&&case "$2" in
    a|attach)tmux_attach Adachi;;
    s|start)tmux_start_quiet Adachi;;
    f|fgstart)fg_start Adachi;;
    st|stop)redis-cli SHUTDOWN & tmux_stop_quiet Adachi;;
    c|config)file_list config;;
    cr|create)ac_create;;
    p|plugin)ac_plugin;;
    fi|file)file_list;;
    d|download)ac_download;;
    u|update)git_update pnpm i -w puppeteer@19.2.2 @types/express-serve-static-core;;
    *)ac
  esac;;
  s|si|Sagiri)cd "$DIR/Sagiri"&&case "$2" in
    a|attach)tmux_attach Sagiri;;
    s|start)tmux_start_quiet Sagiri;;
    f|fgstart)fg_start Sagiri;;
    st|stop)tmux_stop_quiet Sagiri;;
    c|config)file_list config;;
    p|plugin)si_plugin;;
    fi|file)file_list;;
    d|download)si_download;;
    u|update)git_update poetry install --all-extras;;
    *)si
  esac;;
  a|ai|Amiya)cd "$DIR/Amiya"&&case "$2" in
    a|attach)tmux_attach Amiya;;
    s|start)tmux_start_quiet Amiya;;
    f|fgstart)fg_start Amiya;;
    st|stop)tmux_stop_quiet Amiya;;
    c|config)file_list config;;
    p|plugin)ai_plugin;;
    fi|file)file_list;;
    d|download)ai_download;;
    u|update)git_update "poetry run bash -c 'pip install -U pip&&pip install -Ur requirements.txt&&playwright install chromium'";;
    *)ai
  esac;;
  z|zx|Zhenxun)cd "$DIR/Zhenxun"&&case "$2" in
    a|attach)tmux_attach Zhenxun;;
    s|start)tmux_start_quiet Zhenxun;;
    f|fgstart)fg_start Zhenxun;;
    st|stop)if [ -n "$MSYS" ];then pg_ctl stop -D /win/pgsql/data;else su - postgres -c "pg_ctl stop -D /var/lib/postgres/data";fi;tmux_stop_quiet Zhenxun;;
    c|config)zx_config;;
    cr|create)zx_create;;
    p|plugin)NBPluginDir=plugins;nb_plugin;;
    fi|file)file_list;;
    d|download)zx_download;;
    u|update)git checkout pyproject.toml poetry.lock&&git_update "poetry add --lock lxml==4.9.3 pyyaml==6.0.1 wordcloud==1.9.2&&poetry install&&poetry run playwright install chromium";;
    *)zx
  esac;;
  w|ZxWebUI)cd "$DIR/ZxWebUI"&&case "$2" in
    a|attach)tmux_attach ZxWebUI;;
    s|start)tmux_start_quiet ZxWebUI;;
    f|fgstart)fg_start ZxWebUI;;
    st|stop)nginx -s quit & tmux_stop_quiet ZxWebUI;;
    c|config)editor nginx.conf;;
    cr|create)zxwebui_create;;
    fi|file)file_list;;
    d|download)zxwebui_download;;
    u|update)git_update;;
    *)zxwebui
  esac;;
  qss)shift;qss "$@";;
  p|plugin)plugin;;
  f|file)file_list "$2";;
  manual)manual;;
  e|extra)shift;extra "$@";;
  a|about)about;;
  u|update)shift;update "$@";;
  c|cmd)shift;debug_cmd "$@";;
  docker)msgbox "提示：按 Ctrl+P+Q 退出容器";;
  *)depend_check;update_check;main
esac