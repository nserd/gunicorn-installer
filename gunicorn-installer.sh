#!/bin/bash

function usage {
    echo -e "${cCyn}Gunicorn Installer${cEnd}"
    echo "Installs the WSGI-server, adds a unit file and configures the rotation of the logs."
    echo "Supports VestaCP."
    echo
    echo -e "  Usage: gunicorn-installer.sh [${cMgn}options${cEnd}] <project-dir>"
    echo
    echo -e "  Options: ${cMgn}--web-user -w${cEnd}    Web User"
    echo -e "           ${cMgn}--venv     -v${cEnd}    Path to virtual enviroment"
    echo -e "           ${cMgn}--help     -h${cEnd}    Print this text"
    echo
    echo "  Default values: Web user           - www-data or admin (VestaCP)"
    echo "                  Virtual enviroment - create/use venv in project directory"
}

function init-color-vars {
    cMgn="\033[35m" # magenta
    cRed="\033[31m" # red
    cYel="\033[33m" # yellow
    cCyn="\033[36m" # cyan

    cEnd="\033[0m"
}

function print-error {
    echo -e "${cRed}Error:${cEnd} $1"
}

function empty-option-check {
    [ -z "$2" ] && echo -e "Data is not specified in the parameter (${cMgn}$1${cEnd})" && exit 1
}

function delete-last-slash {
    local string="$1"
    if echo $string | grep "/$" > /dev/null 2>&1; then string=${string::-1}; fi

    echo $string
}

function get-web-user {
    [ -n "$VESTA" ] && echo "admin" || echo "www-data"
}

function arg-handler {
    local lastArg="${!#}"

    while [ -n "$1" ]
    do
        case $1 in
            --web-user|-w) [ "$2" != "$lastArg" ] && webUser=$2; empty-option-check "--web-user|-w" $webUser
                shift;;
            --venv|-v)     [ "$2" != "$lastArg" ] && venv=`delete-last-slash $2`; empty-option-check "--venv|-v" $venv
                shift;;
            --help|-h) usage;
                exit 0;;
            $lastArg) projectDir=`delete-last-slash $1`
                break;;
            *) echo "\"$1\" is not a option."
                exit 1;;
        esac
        shift
    done

    projectName=`echo $projectDir | awk -F '/' '{print $NF}'`
}

function check-vars {
    if [ -z "$projectDir" ]
    then
        echo -e "Project directiory not specified. Use: gunicorn-installer.sh ${cMgn}--help${cEnd}"
        exit 1
    fi
    
    if ! echo $projectDir | grep "^/" > /dev/null 2>&1
    then
        print-error "You must specify the absolute path to the project directory."
        exit 1
    fi

    if ! echo $venv | grep "^/" > /dev/null 2>&1 && [ -n "$venv" ]
    then
        print-error "You must specify the absolute path to the enviroment."
        exit 1
    fi

    [ -z "$webUser" ] && webUser=`get-web-user`
    [ -z "$venv" ] && venv="$projectDir/venv"
    ! [ -d "$projectDir" ] && print-error "Project directory not found." && exit 1
}

function check-python {
    if [ `for i in $(echo $PATH | tr ':' '\n'); do [ -d $i ] && ls $i | grep "^python" | grep -v "-"; done | wc -l` -eq 0 ]
    then
        print-error "Python interpreter  not found."
        echo -e "Install python before run this script or enter path to virual enviroment using ${cMgn}-v${cEnd} option."
        exit 1
    fi
}

function get-python {
    echo "List of available python interpreters:"
    echo
    for i in `echo $PATH | tr ':' '\n'`
    do
        [ -d $i ] && ls $i | grep "^python" | grep -v "-"
    done | sort | uniq
    echo

    while [ -z $python ]
    do
        read -p "Enter an interpreter from the list: "

        if which $REPLY > /dev/null 2>&1
        then python="$REPLY"
        else echo "Interpreter not found."
        fi
    done
}

function get-python-venv {
    if ! [ -f $venv/bin/python ]
    then
        if ls $venv/bin | grep "^python" > /dev/null 2>&1
        then
            echo -e "${cYel}Python interpreter not found in virtual environment${cEnd} ($venv/bin/python)"
            echo "Available interpreters:"
            echo
            ls $venv/bin | grep "^python"
            echo
            while [ -z "$python" ]
            do
                read -p "Enter an interpreter from the list: "
                if ls $venv/bin | grep "^python" | grep "^$REPLY$" > /dev/null 2>&1
                then
                    python="$REPLY"
                else
                    echo "Incorrect input."
                fi
            done
        else
            print-error "Python interpreter not found in virtual environment ($venv/bin/python)"
            exit 1
        fi
    else
        python="$venv/bin/python"
    fi
}

function replace-venv-paths {
    currentPath="`head -1 $venv/bin/* 2>/dev/null | grep -a "^#!" | grep "python" | sed 's\#!\\\g' | sed 's#/bin.*##' | head -1`"
    actualPath="$venv"

    if [ "$actualPath" != "$currentPath" ]
    then
	echo -e "${cYel}Enviroment scripts has old paths. Replace with actual.${cEnd}"
	echo "    Current path: $currentPath"
	echo "    Actual path:  $venv"
	echo
	grep -Rl "$currentPath" $venv/bin | xargs sed -i "s#$currentPath#$actualPath#g"
    fi
}

function install-modules {
    if ! $python -m pip --version > /dev/null 2>&1
    then
        print-error "PIP module not found. Install module for `$python -V 2>&1`."
        echo "This commands may be helpful:"
	echo
        [ "$distr" == "ubuntu/debian" ] && echo -e "  apt install python-pip\n  apt install python3-pip\n"
        [ "$distr" == "centos" ] && echo -e "  yum install python-pip\n  yum install python3-pip\n"	
        exit 1
    fi

    if [ "$distr" == "ubuntu/debian" ] && [ `apt list --installed $python-venv 2>/dev/null | wc -l` -eq 1 ]
    then
        apt install -y $python-venv
        [ $? -ne 0 ] && print-error "Failed to install module venv." && exit 1
    fi

    if [ "$distr" == "centos" ] && [ `yum list installed $python-virtualenv 2>/dev/null | wc -l` -eq 1 ]
    then
        yum install -y $python-virtualenv
        [ $? -ne 0 ] && print-error "Failed to install module venv." && exit 1
    fi
}

function install-gunicorn {
    if ! [ -f $venv/bin/gunicorn ]
    then
        echo -e "${cYel}Gunicorn not found in virtual enviroment.${cEnd} Installing"
        $python -m pip install gunicorn

        [ $? -ne 0 ] && print-error "Failed to install gunicorn." && exit 1
    fi
}

function create-venv {
    echo -e "Creating virtual enviroment -> $venv"
 
    if [ "$distr" == "ubuntu/debian" ]; then $python -m venv $venv; fi 
    if [ "$distr" == "centos" ]; then $python -m virtualenv $venv; fi
    
    [ $? -ne 0 ] && print-error "Failed to create virual enviroment." && exit 1
}

function create-unit {
    local unitFile="/etc/systemd/system/gunicorn@$projectName.service"

    if [ -f $unitFile ]
    then
        read -p "Service gunicorn@$projectName exist. Do you want to recreate it? [y/n]: " answer
        [ "$answer" != "y" ] && echo -e "${cYel}Installation cancelled.${cEnd}" && exit 0
    fi

    >$unitFile

    echo "[Unit]" >> $unitFile
    echo "Description=Gunicorn [$projectName] daemon" >> $unitFile
    echo "After=network.target" >> $unitFile
    echo >> $unitFile
    echo "[Service]" >> $unitFile
    echo "User=$webUser" >> $unitFile
    echo "Group=$webUser" >> $unitFile
    echo "WorkingDirectory=$projectDir" >> $unitFile
    echo "ExecStart=$venv/bin/gunicorn --workers 3 " \
                                       "--bind unix:/var/run/gunicorn/$projectName.sock " \
                                       "--access-logfile $accessLog " \
                                       "--error-logfile $errorLog " \
                                       "$projectName.wsgi:application" >> $unitFile
    echo >> $unitFile
    echo "[Install]" >> $unitFile
    echo "WantedBy=multi-user.target" >> $unitFile

    echo -e "Service ${cMgn}gunicorn@$projectName${cEnd} created."
}

function add-template {
    templateName="gunicorn_$projectName"
    templatesPath="/usr/local/vesta/data/templates/web/nginx"

    if [ -f `dirname $0`/vesta-gunicorn.tpl ] || [ -f `dirname $0`/vesta-gunicorn.stpl ]
    then
        echo "Adding template \"$templateName\" for VestaCP"
        sed "s#__projectName__#$projectName#g" `dirname $0`/vesta-gunicorn.tpl  > $templatesPath/$templateName.tpl
        sed "s#__projectName__#$projectName#g" `dirname $0`/vesta-gunicorn.stpl > $templatesPath/$templateName.stpl
    fi
}

function add-logrotate {
    local rotateFile="/etc/logrotate.d/gunicorn_moryak.site"

    accessLog="/var/log/gunicorn/$projectName/access.log"
    errorLog="/var/log/gunicorn/$projectName/error.log"

    mkdir -p /var/log/gunicorn/$projectName

    >$rotateFile

    echo "$accessLog $errorLog {" >> $rotateFile
    echo "  missingok" >> $rotateFile
    echo "  notifempty" >> $rotateFile
    echo "  daily" >> $rotateFile
    echo "  rotate 30" >> $rotateFile
    echo "  compress" >> $rotateFile
    echo "  dateext" >> $rotateFile
    echo "  dateformat .%Y-%m-%d" >> $rotateFile
    echo "}" >> $rotateFile

    chown -R $webUser:$webUser /var/log/gunicorn
}

function print-completion-message {
    echo
    echo -e "${cCyn}Installation completed!${cEnd}"
    echo " * Check command output:"
    echo "       systemctl status gunicorn@$projectName"

    if [ -n "$VESTA" ]
    then
        if [ -f $templatesPath/$templateName.tpl ] && [ -f $templatesPath/$templateName.stpl ]
        then
            echo " * New VestaCP template has been created. To apply it, run command:"
            echo "       v-change-web-domain-proxy-tpl $webUser <domain> $templateName"
        else
            echo -e " * ${cYel}VestaCP template was not created${cEnd} (missing template files in the script folder)"
        fi
    else
        echo " * Socket:"
        echo "       /var/run/gunicorn/$projectName.sock"
    fi

    echo " * Log files:"
    echo "       Access logs    $accessLog"
    echo "       Error logs     $errorLog"
    echo
}

function create-socket-dir {
    local confString="d /var/run/gunicorn 0755 $webUser $webUser -"
    
    ! [ -f /usr/lib/tmpfiles.d/gunicorn.conf ] && echo "$confString" > /usr/lib/tmpfiles.d/gunicorn.conf
    mkdir -p /var/run/gunicorn && chown $webUser:$webUser /var/run/gunicorn
}

function get-distribution {
    [ `cat /etc/*-release | egrep -ic "ubuntu|debian"` -ne 0 ] && echo "ubuntu/debian"
    [ `cat /etc/*-release | grep -ic centos` -ne 0 ] && echo "centos"
}

init-color-vars
arg-handler "$@"
check-vars

distr=`get-distribution`
[ -z "$distr" ] && print-error "Distribution not supported." && exit 1

echo "Start installation ... "

if [ -d $venv ]
then
    get-python-venv
    replace-venv-paths
else
    echo -e "${cYel}Virtual enviroment not found.${cEnd} To create new enviroment specify python interpreter."
    check-python
    get-python
    install-modules
    create-venv
    get-python-venv
fi

install-gunicorn
add-logrotate
create-socket-dir
create-unit

systemctl enable gunicorn@$projectName
systemctl restart gunicorn@$projectName

[ -n "$VESTA" ] && add-template

print-completion-message