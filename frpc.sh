#!/usr/bin/env bash

SCRIPT=$(basename "$0")
VERSION="1.0"
NAME="frpc"
FRPC_WORKDIR=/opt/frp
FRPC_BIN=$FRPC_WORKDIR/frpc
FRPC_CONFIG_DIR=$FRPC_WORKDIR/conf
FRPC_CONFIG_FRPC_INI=$FRPC_CONFIG_DIR/frpc.ini
FRPC_SERVICE_FILE=/etc/systemd/system/frpc.service
FRPC_SERVICE_EXEC_START="$FRPC_BIN --config_dir $FRPC_CONFIG_DIR"
FRPC_BIN_FILE_URL=https://raw.githubusercontent.com/billcoding/frpc-command-toolset/main/frpc.tar

INSTALL=false
UNINSTALL=false
COMMON=false
START=false
STOP=false
RESTART=false
STATUS=false
ENABLE=false
DISABLE=false
LOGS=false
LIST=false
ADD=false
UPDATE=false
REMOVE=false
FLUSH=false
VER=false
FVER=false

INSTALL_SERVER_ADDR=127.0.0.1
INSTALL_SERVER_PORT=7000
INSTALL_TLS_ENABLE=false
INSTALL_TOKEN=""

UNINSTALL_REMOVE=false

COMMON_SERVER_ADDR=""
COMMON_SERVER_PORT=""

LOGS_LINE=100

FVER_SHOW_PATH=false

FRPC_PROXY_NAME=""
FRPC_PROXY_TYPE=""
FRPC_PROXY_LOCAL_IP=""
FRPC_PROXY_LOCAL_PORT=""
FRPC_PROXY_REMOTE_PORT=""

MAIN_DESC="The frpc command toolset."
INSTALL_DESC="Install $NAME to your system."
UNINSTALL_DESC="Uninstall $NAME from your system."
COMMON_DESC="Change $NAME common configuration."
START_DESC="Start $NAME service."
STOP_DESC="Stop $NAME service."
RESTART_DESC="Restart $NAME service."
STATUS_DESC="Show $NAME service status."
LOGS_DESC="Show $NAME service logs."
ENABLE_DESC="Enable $NAME service."
DISABLE_DESC="Disable $NAME service."
LIST_DESC="List all the $NAME proxy."
ADD_DESC="Add one $NAME proxy."
UPDATE_DESC="Update one $NAME proxy."
REMOVE_DESC="Remove one $NAME proxy."
FLUSH_DESC="Flush all $NAME proxy."
VER_DESC="Show toolset version."
FVER_DESC="Show $NAME version."
HELP_DESC="Show help message."

function show_help(){
  cat <<EOF
$MAIN_DESC

Usage:
  $SCRIPT <COMMAND>

Examples:
  $SCRIPT install
  $SCRIPT remove
  $SCRIPT list
  $SCRIPT flush

Commands:
  i,  install               $INSTALL_DESC
  un, uninstall             $UNINSTALL_DESC
  c,  common                $COMMON_DESC
  st, start                 $START_DESC
  sp, stop                  $STOP_DESC
  rt, restart               $RESTART_DESC
  ss, status                $STATUS_DESC
  ls, logs                  $LOGS_DESC
  e,  enable                $ENABLE_DESC
  d,  disable               $DISABLE_DESC
  l,  list                  $LIST_DESC
  a,  add                   $ADD_DESC
  u,  update                $UPDATE_DESC
  r,  remove                $REMOVE_DESC
  f,  flush                 $FLUSH_DESC
  -v, v, ver                $VER_DESC
  -fv, fv, fver             $FVER_DESC
  -h, --help, h, help       $HELP_DESC
EOF
}

function show_install_help(){
  cat <<EOF
$INSTALL_DESC

Usage: 
  $SCRIPT i       <OPTIONS>
  $SCRIPT install <OPTIONS>
 
Examples:
  $SCRIPT install -a $INSTALL_SERVER_ADDR -p $INSTALL_SERVER_PORT -t sometoken
  $SCRIPT install --server-addr $INSTALL_SERVER_ADDR --server-port $INSTALL_SERVER_PORT --token sometoken

Options:
  -a, --server-addr        Frps server addr (default: $INSTALL_SERVER_ADDR).
  -p, --server-port        Frps server port (default: $INSTALL_SERVER_PORT).
  -t, --token              Frps server token.
  -h, --help               Show this help message.
EOF
}

function disable_selinux(){
  SES=$(sestatus |grep 'SELinux status:'| awk -F: '{print $2}'|sed 's/ //g')
  if [ "$SES" = "enabled" ];then
    sudo setenforce 0
    cat>/etc/selinux/config<<EOF
SELINUX=disabled
SELINUXTYPE=targeted
EOF
  fi
}

function install_pkg_tar(){
  if ! which tar > /dev/null; then yum install -y tar; fi
}

function install_pkg_systemd(){
  if ! which systemctl > /dev/null; then yum install -y systemd; fi
}

function change_common_process(){
  for ff in $(ls $FRPC_CONFIG_DIR|grep '\.ini$');do
      file=$FRPC_CONFIG_DIR/$ff
      if [ -n "$INSTALL_SERVER_ADDR" ]; then sed -i "s/^ *server_addr *=.*$/server_addr = $INSTALL_SERVER_ADDR/g" $file;fi
      if [ -n "$INSTALL_SERVER_PORT" ]; then sed -i "s/^ *server_port *=.*$/server_port = $INSTALL_SERVER_PORT/g" $file;fi
      if [ -n "$INSTALL_TOKEN" ]; then sed -i "s/^ *token *=.*$/token = $INSTALL_TOKEN/g" $file;fi
  done
}

function install_process(){
  disable_selinux
  install_pkg_tar
  install_pkg_systemd
  frpcFile=/tmp/frpc.tar
  if [ ! -f "$frpcFile"  ]; then
    curl -L -o $frpcFile $FRPC_BIN_FILE_URL
  fi
  tar xvf $frpcFile -C /tmp
  mkdir -p $FRPC_WORKDIR $FRPC_CONFIG_DIR
  mv /tmp/frpc $FRPC_WORKDIR
  chmod +x $FRPC_BIN
  cat>$FRPC_CONFIG_FRPC_INI<<EOF
[common]
server_addr = $INSTALL_SERVER_ADDR
server_port = $INSTALL_SERVER_PORT
tls_enable = $INSTALL_TLS_ENABLE
EOF

  if [ -n "$INSTALL_TOKEN" ];then
    echo "token = $INSTALL_TOKEN" >> $FRPC_CONFIG_FRPC_INI
  fi

  cat>$FRPC_SERVICE_FILE<<EOF
[Unit]
Description=Frp Server Service
After=network-online.target syslog.target
Wants=network-online.target

[Service]
Type=simple
Restart=on-failure
RestartSec=3s
ExecStart=$FRPC_SERVICE_EXEC_START

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload

  systemctl enable $NAME

  for ff in $(ls $FRPC_CONFIG_DIR|grep '\.ini$');do
      file=$FRPC_CONFIG_DIR/$ff
      sed -i "s/^ *server_addr *=.*$/server_addr = $INSTALL_SERVER_ADDR/g" $file
      sed -i "s/^ *server_port *=.*$/server_port = $INSTALL_SERVER_PORT/g" $file
      sed -i "s/^ *token *=.*$/token = $INSTALL_TOKEN/g" $file
  done

  systemctl restart $NAME
}

function show_common_help(){
  cat <<EOF
$COMMON_DESC

Usage: 
  $SCRIPT c       <OPTIONS>
  $SCRIPT common  <OPTIONS>
 
Examples:
  $SCRIPT common -a $INSTALL_SERVER_ADDR -p $INSTALL_SERVER_PORT -t sometoken
  $SCRIPT common --server-addr $INSTALL_SERVER_ADDR --server-port $INSTALL_SERVER_PORT --token sometoken

Options:
  -a, --server-addr        Frps server addr.
  -p, --server-port        Frps server port.
  -t, --token              Frps server token.
  -h, --help               Show this help message.
EOF
}

function common_process(){
  check_install
  for ff in $(ls $FRPC_CONFIG_DIR|grep '\.ini$');do
      file=$FRPC_CONFIG_DIR/$ff
      if [ -n "$COMMON_SERVER_ADDR" ]; then sed -i "s/^ *server_addr *=.*$/server_addr = $COMMON_SERVER_ADDR/g" $file;fi
      if [ -n "$COMMON_SERVER_PORT" ]; then sed -i "s/^ *server_port *=.*$/server_port = $COMMON_SERVER_PORT/g" $file;fi
      if [ -n "$INSTALL_TOKEN" ]; then sed -i "s/^ *token *=.*$/token = $INSTALL_TOKEN/g" $file;fi
  done
  systemctl restart $NAME
}

function show_uninstall_help(){
  cat <<EOF
$UNINSTALL_DESC

Usage:
  $SCRIPT un        <OPTIONS>
  $SCRIPT uninstall <OPTIONS>

Examples:
  $SCRIPT uninstall
  $SCRIPT uninstall --remove

Options:
  -r, --remove             Remove all files.
  -h, --help               Show this help message.
EOF
}

function uninstall_process(){
  systemctl stop $NAME
  systemctl disable $NAME
  systemctl disable $NAME
  if $UNINSTALL_REMOVE; then
    rm -rf FRPC_SERVICE_FILE $FRPC_WORKDIR
  fi
}

function show_start_help(){
  cat <<EOF
$START_DESC

Usage: 
  $SCRIPT st    <OPTIONS>
  $SCRIPT start <OPTIONS>

Examples:
  $SCRIPT start

Options:
  -h, --help               Show this help message.
EOF
}

function start_process(){
  systemctl start $NAME
}

function show_stop_help(){
  cat <<EOF
$STOP_DESC

Usage:
  $SCRIPT sp   <OPTIONS>
  $SCRIPT stop <OPTIONS>

Examples:
  $SCRIPT stop

Options:
  -h, --help               Show this help message.
EOF
}

function stop_process(){
  systemctl stop $NAME
}

function show_restart_help(){
  cat <<EOF
$RESTART_DESC

Usage:
  $SCRIPT rt      <OPTIONS>
  $SCRIPT restart <OPTIONS>

Examples:
  $SCRIPT restart

Options:
  -h, --help               Show this help message.
EOF
}

function restart_process(){
  systemctl restart $NAME
}

function show_status_help(){
  cat <<EOF
$STATUS_DESC

Usage:
  $SCRIPT ss     <OPTIONS>
  $SCRIPT status <OPTIONS>

Examples:
  $SCRIPT status

Options:
  -h, --help               Show this help message.
EOF
}

function status_process(){
  systemctl status $NAME -l --no-pager
}

function show_enable_help(){
  cat <<EOF
$ENABLE_DESC

Usage: 
  $SCRIPT ee     <OPTIONS>
  $SCRIPT enable <OPTIONS>

Examples:
  $SCRIPT enable

Options:
  -h, --help               Show this help message.
EOF
}

function enable_process(){
  systemctl enable $NAME
}

function show_disable_help(){
  cat <<EOF
$DISABLE_DESC

Usage:
  $SCRIPT de      <OPTIONS>
  $SCRIPT disable <OPTIONS>

Examples:
  $SCRIPT disable

Options:
  -h, --help               Show this help message.
EOF
}

function disable_process(){
  systemctl disable $NAME
}

function show_logs_help(){
  cat <<EOF
$LOGS_DESC

Usage:
  $SCRIPT ls      <OPTIONS>
  $SCRIPT logs    <OPTIONS>

Examples:
  $SCRIPT logs
  $SCRIPT logs -n 20

Options:
  -n, --line               Show some lines (default: $LOGS_LINE).
  -h, --help               Show this help message.
EOF
}

function logs_process(){
  if [ -n "$LOGS_LINE" ]; then LOGS_LINE=100;fi
  journalctl -u $NAME -n $LOGS_LINE --no-pager -e
}

function check_install(){
  if [ ! -f "$FRPC_BIN" ];then
    echo "Please install $NAME first."
    exit 1
  fi
}

function show_list_help(){
  cat <<EOF
$LIST_DESC

Usage:
  $SCRIPT l    <OPTIONS>
  $SCRIPT list <OPTIONS>

Examples:
  $SCRIPT list

Options:
  -h, --help               Show this help message.
EOF
}

function list_process(){
  check_install
  printf "%s\n" "common configuration"
  printf "%s\n" "------------------------------------------------------"
  printf "%-15s %-12s %-12s %-20s\n" "server_addr" "server_port" "tls_enable" "token"
  printf "%s\n" "------------------------------------------------------"
  server_addr=$(grep 'server_addr *= *' $FRPC_CONFIG_FRPC_INI|awk -F= '{print $2}'|sed 's/ //g')
  server_port=$(grep 'server_port *= *' $FRPC_CONFIG_FRPC_INI|awk -F= '{print $2}'|sed 's/ //g')
  tls_enable=$(grep 'tls_enable *= *' $FRPC_CONFIG_FRPC_INI|awk -F= '{print $2}'|sed 's/ //g')
  token=$(grep 'token *= *' $FRPC_CONFIG_FRPC_INI|awk -F= '{print $2}'|sed 's/ //g')
  printf "%-15s %-12s %-12s %-20s\n" $server_addr $server_port $tls_enable $token

  printf "\n\n"

  printf "%s\n" "proxy configuration"
  printf "%s\n" "------------------------------------------------------"
  printf "%-6s %-6s %-15s %-12s %-12s\n" "name" "type" "local_ip" "local_port" "remote_port"
  printf "%s\n" "------------------------------------------------------"
  for ff in $(ls $FRPC_CONFIG_DIR|grep '\.ini$');do
    file=$FRPC_CONFIG_DIR/$ff
    name=$(basename $file .ini)
    if [ ! "$name" = "frpc" ]; then
      type=$(grep 'type *= *' $file|awk -F= '{print $2}'|sed 's/ //g')
      local_ip=$(grep 'local_ip *= *' $file|awk -F= '{print $2}'|sed 's/ //g')
      local_port=$(grep 'local_port *= *' $file|awk -F= '{print $2}'|sed 's/ //g')
      remote_port=$(grep 'remote_port *= *' $file|awk -F= '{print $2}'|sed 's/ //g')
      printf "%-6s %-6s %-15s %-12s %-12s\n" $name $type $local_ip $local_port $remote_port
    fi
  done
}

function show_add_help(){
 cat <<EOF
$ADD_DESC

Usage: 
  $SCRIPT a   <OPTIONS>
  $SCRIPT add <OPTIONS>

Examples:
  $SCRIPT add --name ssh --type tcp --local-ip 172.0.0.1 --local-port 22 --remote-port 60022
  $SCRIPT add --name web --type http --local-ip 172.100.100.10 --local-port 8080 --remote-port 60080

Options:
  --name                   Proxy name.
  --type                   Proxy type (default: tcp).
  --local-ip               Proxy local ip (default: 127.0.0.1).
  --local-port             Proxy local port.
  --remote-port            Proxy remote port.
  -h, --help               Show this help message.
EOF
}

function add_process(){
  check_install
  if [ -z "$FRPC_PROXY_NAME" ]; then echo "Please provide proxy name.";exit 1;fi
  if [ -z "$FRPC_PROXY_LOCAL_PORT" ]; then echo "Please provide proxy local_port.";exit 1;fi
  if [ -z "$FRPC_PROXY_REMOTE_PORT" ]; then echo "Please provide proxy remote_port.";exit 1;fi

  if [ -z "$FRPC_PROXY_TYPE" ]; then FRPC_PROXY_TYPE="tcp";fi
  if [ -z "$FRPC_PROXY_LOCAL_IP" ]; then FRPC_PROXY_LOCAL_IP="127.0.0.1";fi

  confFile=$FRPC_CONFIG_DIR/$FRPC_PROXY_NAME.ini
  if [ -f "$confFile" ]; then
    echo "Proxy was already exists."
    exit 1
  fi
  cat $FRPC_CONFIG_FRPC_INI>$confFile
  cat>>$confFile<<EOF
[$FRPC_PROXY_NAME]
type = $FRPC_PROXY_TYPE
local_ip = $FRPC_PROXY_LOCAL_IP
local_port = $FRPC_PROXY_LOCAL_PORT
remote_port = $FRPC_PROXY_REMOTE_PORT
EOF

  restart_process
}

function show_update_help(){
  cat <<EOF
$UPDATE_DESC

Usage:
  $SCRIPT u      <OPTIONS>
  $SCRIPT update <OPTIONS>

Examples:
  $SCRIPT update --name ssh --local-port 8081 --remote-port 50022
  $SCRIPT update --name web --local-ip 127.0.0.1 --remote-port 50080

Options:
  --name                   Proxy name.
  --type                   Proxy type.
  --local-ip               Proxy local ip.
  --local-port             Proxy local port.
  --remote-port            Proxy remote port.
  -h, --help               Show this help message.
EOF
}

function update_process(){
  check_install
  if [ -z "$FRPC_PROXY_NAME" ]; then echo "Please provide proxy name.";exit 1;fi

  confFile=$FRPC_CONFIG_DIR/$FRPC_PROXY_NAME.ini
  if [ ! -f "$confFile" ]; then
    echo "Proxy was not exists."
    exit 1
  fi

  if [ -n "$FRPC_PROXY_TYPE" ]; then
    sed -i "s/^ *type *=.*$/type = $FRPC_PROXY_TYPE/g" $confFile
  fi
  if [ -n "$FRPC_PROXY_LOCAL_IP" ]; then
    sed -i "s/^ *local_ip *=.*$/local_ip = $FRPC_PROXY_LOCAL_IP/g" $confFile
  fi
  if [ -n "$FRPC_PROXY_LOCAL_PORT" ]; then
    sed -i "s/^ *local_port *=.*$/local_port = $FRPC_PROXY_LOCAL_PORT/g" $confFile
  fi
  if [ -n "$FRPC_PROXY_REMOTE_PORT" ]; then
    sed -i "s/^ *remote_port *=.*$/remote_port = $FRPC_PROXY_REMOTE_PORT/g" $confFile
  fi

  restart_process
}

function show_remove_help(){
  cat <<EOF
$REMOVE_DESC

Usage: 
  $SCRIPT r      <OPTIONS>
  $SCRIPT remove <OPTIONS>

Examples:
  $SCRIPT remove --name web

Options:
  --name                   Proxy name.
  -h, --help               Show this help message.
EOF
}

function remove_process(){
  check_install
  if [ -z "$FRPC_PROXY_NAME" ]; then echo "Please provide proxy name.";exit 1;fi
  confFile=$FRPC_CONFIG_DIR/$FRPC_PROXY_NAME.ini
  if [ ! -f "$confFile" ]; then echo "Proxy was not exists.";exit 1;fi
  rm -rf $confFile
  restart_process
}

function show_flush_help(){
  cat <<EOF
$FLUSH_DESC

Usage: 
  $SCRIPT f     <OPTIONS>
  $SCRIPT flush <OPTIONS>

Examples:
  $SCRIPT flush

Options:
  -h, --help               Show this help message.
EOF
}

function flush_process(){
  check_install
  find $FRPC_CONFIG_DIR -type f ! -name "frpc.ini" -delete
  restart_process
}

function show_ver_help(){
  cat <<EOF
$VER_DESC

Usage: 
  $SCRIPT v   <OPTIONS>
  $SCRIPT ver <OPTIONS>

Examples:
  $SCRIPT ver

Options:
  -h, --help               Show this help message.
EOF
}

function ver_process(){
  printf "%s\n" $VERSION
}

function show_fver_help(){
  cat <<EOF
$FVER_DESC

Usage: 
  $SCRIPT fv   <OPTIONS>
  $SCRIPT fver <OPTIONS>

Examples:
  $SCRIPT fver

Options:
  --show-path              Show $NAME bin path.
  -h, --help               Show this help message.
EOF
}

function fver_process(){
  check_install
  if $FVER_SHOW_PATH; then
    printf "%s\n" $FRPC_BIN 
  fi
  printf "%s\n" $($FRPC_BIN --version)
}

function help_process(){
  if $INSTALL; then show_install_help
  elif $UNINSTALL; then show_uninstall_help
  elif $COMMON; then show_common_help
  elif $START; then show_start_help
  elif $STOP; then show_stop_help
  elif $RESTART; then show_restart_help
  elif $STATUS; then show_status_help
  elif $ENABLE; then show_enable_help
  elif $DISABLE; then show_disable_help
  elif $LOGS; then show_logs_help
  elif $LIST; then show_list_help
  elif $ADD; then show_add_help
  elif $UPDATE; then show_update_help
  elif $REMOVE; then show_remove_help
  elif $FLUSH; then show_flush_help
  elif $VER; then show_ver_help
  elif $FVER; then show_fver_help
  else show_help;
  fi;
}

function process(){
  if $INSTALL; then install_process
  elif $UNINSTALL; then uninstall_process
  elif $COMMON; then common_process
  elif $START; then start_process
  elif $STOP; then stop_process
  elif $RESTART; then restart_process
  elif $STATUS; then status_process
  elif $ENABLE; then enable_process
  elif $DISABLE; then disable_process
  elif $LOGS; then logs_process
  elif $LIST; then list_process
  elif $ADD; then add_process
  elif $UPDATE; then update_process
  elif $REMOVE; then remove_process
  elif $FLUSH; then flush_process
  elif $VER; then ver_process
  elif $FVER; then fver_process
  fi
}

function main() {
  [ -z "$1" ] && show_help && exit 0

  while [[ $# -gt 0 ]]; do
    case $1 in
      -h|--help|h|help)
        help_process;exit 0;;
      i|install)
        INSTALL=true;shift;;
      un|uninstall)
        UNINSTALL=true;shift;;
      c|common)
        COMMON=true;shift;;
      st|start)
        START=true;shift;;
      sp|stop)
        STOP=true;shift;;
      rt|restart)
        RESTART=true;shift;;
      ss|status)
        STATUS=true;shift;;
      ee|enable)
        ENABLE=true;shift;;
      de|disable)
        DISABLE=true;shift;;
      ls|logs)
        LOGS=true;shift;;
      l|list)
        LIST=true;shift;;
      a|add)
        ADD=true;shift;;
      u|update)
        UPDATE=true;shift;;
      r|remove)
        REMOVE=true;shift;;
      f|flush)
        FLUSH=true;shift;;
      -v|v|ver)
        VER=true;shift;;
      -fv|fv|fver)
        FVER=true;shift;;

      -a|--server-addr)
        if [ -n "$2" ]; then INSTALL_SERVER_ADDR=$2;COMMON_SERVER_ADDR=$2;shift 2;else shift;fi;;
      -p|--server-port)
        if [ -n "$2" ]; then INSTALL_SERVER_PORT=$2;COMMON_SERVER_PORT=$2;shift 2;else shift;fi;;
      -t|--token)
        if [ -n "$2" ]; then INSTALL_TOKEN=$2;shift 2;else shift;fi;;
      
      -r|--remove)
        UNINSTALL_REMOVE=true;shift;;

      -n|--line)
        if [ -n "$2" ]; then LOGS_LINE=$2;shift 2;else shift;fi;;

      --name)
        if [ -n "$2" ]; then FRPC_PROXY_NAME=$2;shift 2;else shift;fi;;
      --type)
        if [ -n "$2" ]; then FRPC_PROXY_TYPE=$2;shift 2;else shift;fi;;
      --local-ip)
        if [ -n "$2" ]; then FRPC_PROXY_LOCAL_IP=$2;shift 2;else shift;fi;;
      --local-port)
        if [ -n "$2" ]; then FRPC_PROXY_LOCAL_PORT=$2;shift 2;else shift;fi;;
      --remote-port)
        if [ -n "$2" ]; then FRPC_PROXY_REMOTE_PORT=$2;shift 2;else shift;fi;;
      
      --show-path)
        FVER_SHOW_PATH=true;shift;;
      
      *)
        echo "Invalid command: $1";exit 1;;
    esac
  done

  process
}

main "$@"
