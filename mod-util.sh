##########################################################################################
#
# Terminal Utility Functions
# by veez21
#
##########################################################################################

# Versions
MODUTILVER=v2.6.1
MODUTILVCODE=261

# Check A/B slot
if [ -d /system_root ]; then
  isABDevice=true
  SYSTEM=/system_root/system
  SYSTEM2=/system
  CACHELOC=/data/cache
else
  isABDevice=false
  SYSTEM=/system
  SYSTEM2=/system
  CACHELOC=/cache
fi
[ -z "$isABDevice" ] && { echo "Something went wrong!"; exit 1; }

#=========================== Set Busybox up
# set_busybox <busybox binary>
# alias busybox applets
setup_busybox() {
  if [ -d /sbin/.magisk/busybox ]; then
    PATH="/sbin/.magisk/busybox:$PATH"
  else
    echo "Busybox not detected";
    exit 1;
  fi
}


[ -n "$ANDROID_SOCKET_adbd" ] && alias clear='echo'

#=========================== Default Functions and Variables

# Set perm
set_perm() {
  chown $2:$3 $1 || return 1
  chmod $4 $1 || return 1
  (if [ -z $5 ]; then
    case $1 in
      *"system/vendor/app/"*) chcon 'u:object_r:vendor_app_file:s0' $1;;
      *"system/vendor/etc/"*) chcon 'u:object_r:vendor_configs_file:s0' $1;;
      *"system/vendor/overlay/"*) chcon 'u:object_r:vendor_overlay_file:s0' $1;;
      *"system/vendor/"*) chcon 'u:object_r:vendor_file:s0' $1;;
      *) chcon 'u:object_r:system_file:s0' $1;;
    esac
  else
    chcon $5 $1
  fi) || return 1
}

# Set perm recursive
set_perm_recursive() {
  find $1 -type d 2>/dev/null | while read dir; do
    set_perm $dir $2 $3 $4 $6
  done
  find $1 -type f -o -type l 2>/dev/null | while read file; do
    set_perm $file $2 $3 $5 $6
  done
}

# Mktouch
mktouch() {
  mkdir -p ${1%/*} 2>/dev/null
  [ -z $2 ] && touch $1 || echo $2 > $1
  chmod 644 $1
}

# Grep prop
grep_prop() {
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES='/system/build.prop'
  sed -n "$REGEX" $FILES 2>/dev/null | head -n 1
}

# Is mounted
is_mounted() {
  grep -q " $(readlink -f $1) " /proc/mounts 2>/dev/null
  return $?
}

# Abort
abort() {
  echo "$1"
  exit 1
}

device_info() {
  ABI=$(getprop ro.product.cpu.abi | cut -d'-' -f1)
  ARCH=''
  if [ "$ABI" == "armeabi" ]; then 
    ARCH=arm;
  elif [ "$ABI" == "x86" ]; then 
    ARCH=x86;
  elif [ "$ABI" == "arm64" ]; then 
    ARCH=arm64;
  elif [ "$ABI" == "x86_64" ]; then 
    ARCH=x64; 
  fi;
echo $ARCH
}

# Version Number
VER=$(grep_prop version $MODDIR/module.prop)
# Version Code
REL=$(grep_prop versionCode $MODDIR/module.prop)
# Author
AUTHOR=$(grep_prop author $MODDIR/module.prop)
# Mod Name/Title
MODTITLE=$(grep_prop name $MODDIR/module.prop)

# Colors
G='\e[01;32m'		# GREEN TEXT
R='\e[01;31m'		# RED TEXT
Y='\e[01;33m'		# YELLOW TEXT
B='\e[01;34m'		# BLUE TEXT
V='\e[01;35m'		# VIOLET TEXT
Bl='\e[01;30m'		# BLACK TEXT
C='\e[01;36m'		# CYAN TEXT
W='\e[01;37m'		# WHITE TEXT
BGBL='\e[1;30;47m'	# Background W Text Bl
N='\e[0m'			# How to use (example): echo "${G}example${N}"
loadBar=' '			# Load UI
# Remove color codes if -nc or in ADB Shell
[ -n "$1" -a "$1" == "-nc" ] && shift && NC=true
[ "$NC" -o -n "$ANDROID_SOCKET_adbd" ] && {
  G=''; R=''; Y=''; B=''; V=''; Bl=''; C=''; W=''; N=''; BGBL=''; loadBar='=';
}

# No. of characters in $MODTITLE, $VER, and $REL
character_no=$(echo "$MODTITLE $VER $REL" | wc -c)

# Divider
div="${Bl}$(printf '%*s' "${character_no}" '' | tr " " "=")${N}"

# title_div [-c] <title>
# based on $div with <title>
title_div() {
  [ "$1" == "-c" ] && local character_no=$2 && shift 2
  [ -z "$1" ] && { local message=; no=0; } || { local message="$@ "; local no=$(echo "$@" | wc -c); }
  [ $character_no -gt $no ] && local extdiv=$((character_no-no)) || { echo "Invalid!"; return; }
  echo "${W}$message${N}${Bl}$(printf '%*s' "$extdiv" '' | tr " " "=")${N}"
}

# set_file_prop <property> <value> <prop.file>
set_file_prop() {
  if [ -f "$3" ]; then
    if grep -q "$1=" "$3"; then
      sed -i "s/${1}=.*/${1}=${2}/g" "$3"
    else
      echo "$1=$2" >> "$3"
    fi
  else
    echo "$3 doesn't exist!"
  fi
}

# https://github.com/fearside/ProgressBar
# ProgressBar <progress> <total>
ProgressBar() {
# Determine Screen Size
  if [[ "$COLUMNS" -le "57" ]]; then
    local var1=2
	local var2=20
  else
    local var1=4
    local var2=40
  fi
# Process data
  local _progress=$(((${1}*100/${2}*100)/100))
  local _done=$(((${_progress}*${var1})/10))
  local _left=$((${var2}-$_done))
# Build progressbar string lengths
  local _done=$(printf "%${_done}s")
  local _left=$(printf "%${_left}s")

# Build progressbar strings and print the ProgressBar line
printf "\rProgress : ${BGBL}|${N}${_done// /${BGBL}$loadBar${N}}${_left// / }${BGBL}|${N} ${_progress}%%"
}

#https://github.com/fearside/SimpleProgressSpinner
# Spinner <message>
Spinner() {

# Choose which character to show.
case ${_indicator} in
  "|") _indicator="/";;
  "/") _indicator="-";;
  "-") _indicator="\\";;
  "\\") _indicator="|";;
  # Initiate spinner character
  *) _indicator="\\";;
esac

# Print simple progress spinner
printf "\r${@} [${_indicator}]"
}

# cmd & spinner <message>
e_spinner() {
  PID=$!
  h=0; anim='-\|/';
  while [ -d /proc/$PID ]; do
    h=$(((h+1)%4))
    sleep 0.02
    printf "\r${@} [${anim:$h:1}]"
  done
}

# test_connection
# tests if there's internet connection
test_connection() {
  (
  if ping -q -c 1 -W 1 google.com >/dev/null 2>&1; then
    true
  elif ping -q -c 1 -W 1 baidu.com >/dev/null 2>&1; then
    true
  else
    false
  fi & e_spinner "Testing internet connection"
  ) && echo " - OK" || { echo " - Error"; false; }
}


# Log files will be uploaded to termbin.com
# Logs included: VERLOG LOG oldVERLOG oldLOG
# upload_logs() {
#   $BBok && {
#     test_connection || exit
#     echo "Uploading logs"
#     [ -s $VERLOG ] && verUp=$(cat $VERLOG | nc termbin.com 9999) || verUp=none
#     [ -s $oldVERLOG ] && oldverUp=$(cat $oldVERLOG | nc termbin.com 9999) || oldverUp=none
#     [ -s $LOG ] && logUp=$(cat $LOG | nc termbin.com 9999) || logUp=none
#     [ -s $oldLOG ] && oldlogUp=$(cat $oldLOG | nc termbin.com 9999) || oldlogUp=none
#     [ -s $stdoutLOG ] && stdoutUp=$(cat $stdoutLOG | nc termbin.com 9999) || stdoutUp=none
#     [ -s $oldstdoutLOG ] && oldstdoutUp=$(cat $oldstdoutLOG | nc termbin.com 9999) || oldstdoutUp=none
#     echo -n "Link: "
#     echo "$MODEL ($DEVICE) API $API\n$ROM\n$ID\n
#     O_Verbose: $oldverUp
#     Verbose:   $verUp

#     O_STDOUT:  $oldstdoutUp
#     STDOUT:    $stdoutUp

#     O_Log: $oldlogUp
#     Log:   $logUp" | nc termbin.com 9999
#   } || echo "Busybox not found!"
#   exit
# }

# Print Random
# Prints a message at random
# CHANCES - no. of chances <integer>
# TARGET - target value out of CHANCES <integer>
prandom() {
  local CHANCES=2
  local TARGET=2
  [ "$1" ==  "-c" ] && { local CHANCES=$2; local TARGET=$3; shift 3; }
  [ "$((RANDOM%CHANCES+1))" -eq "$TARGET" ] && echo "$@"
}

# Print Center
# Prints text in the center of terminal
pcenter() {
  local CHAR=$(printf "$@" | sed 's|\\e[[0-9;]*m||g' | wc -m)
  local hfCOLUMN=$((COLUMNS/2))
  local hfCHAR=$((CHAR/2))
  local indent=$((hfCOLUMN-hfCHAR))
  echo "$(printf '%*s' "${indent}" '') $@"
}

# Heading
mod_head() {
  clear
  echo "$div"
  echo "${W}$MODTITLE $VER${N}(${Bl}$REL${N})"
  echo "by ${W}$AUTHOR${N}"
  echo "$div"
  echo "${W}$_bbname${N}"
  echo "${Bl}$_bb${N}"
  echo "$div"
  [ -s $LOG ] && echo "Enter ${W}logs${N} to upload logs" && echo $div
}
