#!/bin/bash
#if [ -f install.config ];then
#   source install.config
#else
#  touch install.config
#  echo "VCPE_HOME=/home/vcpe" >> install.config
#  echo "SMS_HOME=$VCPE_HOME/sms" >> install.config
#  echo "JAVA_VERSION=java-1.8.0-openjdk" >> install.config
#  echo "password=123456" >> install.config
#  source install.config
#fi
CURRENT_TIME=`date +20%y%m%d_%H%M%S`
VCPE_HOME=/home/vcpe
SMS_HOME=$VCPE_HOME/SMS
ONOS_HOME=$VCPE_HOME/ONOS
JAVA_VERSION=java-1.8.0-openjdk
old_password=
new_password=123456
isCluster=n
prifix=`ip r sh | grep default | awk '{print $3}' | awk -F. '{print $1"."$2"."$3}'`
LOCALIP=`ip add sh | grep $prifix | awk '{print $2}' | awk -F/ '{print $1}'`
VCPE_IP=$LOCALIP
FLEXINC_IP=$LOCALIP
FLEXINC_IP1=$LOCALIP
FLEXINC_IP2=`echo $LOCALIP | awk -F. '{print $1"."$2"."$3"."($4+1)}'`
FLEXINC_IP3=`echo $LOCALIP | awk -F. '{print $1"."$2"."$3"."($4+2)}'`

function judge_ip(){

        local $1 2>/dev/null
        TMP_TXT=/tmp/iptmp.txt
        echo $1 > ${TMP_TXT}
        IPADDR=`grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' ${TMP_TXT}`

        if [ ! -z "${IPADDR}" ];then
                local j=0;

                for ((i=1;i<=4;i++))
                do
                        local IP_NUM=`echo "${IPADDR}" |awk -F. "{print $"$i"}"`

                        if [ "${IP_NUM}" -ge 0 -a "${IP_NUM}" -le 255 ];then
                                ((j++));
                        else
                                return 1
                        fi
                done

                if [ "$j" -eq 4 ];then

            read -n 1 -p "The IP you enter is${IPADDR},sure：Y|y；Re-enter：R|r：" OK
            case ${OK} in
                Y|y) return 0;;
                R|r) return 1;;
                *) return 1;;
            esac
                else
                        return 1
                fi
        else
                return 1
        fi
}

#Initialization
function  system_init {
        echo "System initialization....."
        echo "nameserver 114.114.114.114" >> /etc/resolv.conf
        echo "nameserver 8.8.8.8" >> /etc/resolv.conf
        iptables -F
        setenforce 0
        sed -i s/^SELINUX=.*/SELINUX=disable/g /etc/sysconfig/selinux
        yum install -y  vim autoconf net-tools unzip  expect  >> install-$CURRENT_TIME.log 2>&1
}
#java install
function java_install {
        echo "Installing java package....[default:$JAVA_VERSION]"
        yum install -y $JAVA_VERSION 2>& 1 >> install-$CURRENT_TIME.log
        echo "Done."
}

#Mysql installation
function mysql_install {
        mariadb_package=`rpm -qa|grep mariadb`
        if [ -z $mariadb_package ] ; then
           echo "No mariadb package"
         else
           rpm -e $mariadb_package --nodeps
        fi
           rpm=`rpm -qa|grep MySQL-server`
           if [ $rpm ] ; then
              echo "MySQL is already installed."
           elif [ -f $VCPE_HOME/MySQL-*.tar ] ; then
                echo "Installing MySQL package....[default:MySQL-5.6.35-1.el6.x86_64.rpm-bundle.tar]"
                while :
                do
                  i=1
                  MYSQL_PACKAGE=()
                  echo "MySQL packages list:"
                  for MYSQL_VERSION in $(ls $VCPE_HOME/MySQL-*.tar)
                  do
                      echo "[$i] : $MYSQL_VERSION"
                      MYSQL_PACKAGE[$i]=$MYSQL_VERSION
                      i=`expr $i + 1`
                  done
                  echo -n "Pls choose mysql version:"
                  read version
                  if [ -z $version ] || [ $version -ge $i ] ;then
                    echo "Pls input the correct version number!"
                    continue
                   else
                     MYSQL_VERSION=${MYSQL_PACKAGE[$version]}
        #             echo $MYSQL_VERSION
                     tar -xf $MYSQL_VERSION -C $VCPE_HOME
                     echo "mysql-server and mysql-client is installing..."
                     rpm -ivh $VCPE_HOME/MySQL-client-*.rpm  >> install-$CURRENT_TIME.log 2>&1
                     rpm -ivh $VCPE_HOME/MySQL-server-*.rpm  >> install-$CURRENT_TIME.log 2>&1
                     rm -rf $VCPE_HOME/MySQL-*.rpm
                     echo "Done."
                     break
                  fi
                done
           else
             echo "None MySQL package found，This installation will be exit."
             exit 1
           fi

        echo "MySQL Initialization..."
        old_password=`sed -n '/password/h;${x;p}' .mysql_secret | awk  '{print $18}'`
        if [ -f /etc/my.cnf ] ; then
          echo "MySQL initialization is already done."
        else
          cp  /usr/share/mysql/my-default.cnf  /etc/my.cnf
          echo "#skip-grant-tables" >> /etc/my.cnf
          service mysql restart
          echo -n "Pls input the password of root:[default:123456]"
          read passwd
          if [ -z $passwd ] ;then
             new_password=123456
           else
             new_password=$passwd
          fi
          /usr/bin/expect >> install-$CURRENT_TIME.log 2>&1 <<EOF
set time 1
spawn mysql -uroot -p$old_password
expect {
"mysql>" {send "SET PASSWORD=PASSWORD('$new_password');\r";}
}
expect "*#"                                                                                                                                                              expect "*#"
send "quit;"
EOF

          mysql -uroot -p$newpassword >> install-$CURRENT_TIME.log 2>&1 <<EOF
use mysql;
update user set password=password('$newpassword') where user='root';
update user set host='%' where host='localhost';
GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY 'root' WITH GRANT OPTION;
flush privileges;
quit;
EOF

          echo "Done."
        fi
}
#Apache tomcat8 installation
function tomcat_install {
      echo "Installing Tomcat Apache package....[default:apache-tomcat8.tar.gz]"
      if [ -d /usr/local/apache-tomcat8 ] ;then
        echo "Apache Tomcat is already installed."
      elif [ -f $VCPE_HOME/apache-tomcat8.tar.gz ] ; then
        tar -zxf $VCPE_HOME/apache-tomcat8.tar.gz -C /usr/local
        echo "Done."
      else
        echo "Tomcat package can not be found，This installation will be exit."
        exit 1
      fi
      #auto boot config
      if [ -f /usr/lib/systemd/system/tomcat.service ] ;then
        echo "Apache tomcat auto-starting  is already configed. "
      else
        touch /usr/lib/systemd/system/tomcat.service
        cat >>/usr/lib/systemd/system/tomcat.service<<EOF
[Unit]
Description=Tomcat8
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
Environment='CATALINA_PID=/usr/local/apache-tomcat8/bin/tomcat.pid'
Environment='CATALINA_HOME=/usr/local/apache-tomcat8/'
Environment='CATALINA_BASE=/usr/local/apache-tomcat8/'


WorkingDirectory=/usr/local/apache-tomcat8/

ExecStart=/usr/local/apache-tomcat8/bin/startup.sh
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

      systemctl enable tomcat.service
      fi
}

#sms depoly
function sms_install {
        system_init
        java_install
        mysql_install
        tomcat_install
        echo "SMS depolyment..."
        echo -n "The VCPE package directory is [default:/home/vcpe]:"
        read vcpe_home
        if [ -z $vcpe_home ];then
          if [ -d $VCPE_HOME ]; then
            echo "Installation begin..."
          else
            echo "The directory can not be found,This installation will be exit."
            exit 1
          fi
        else
          if [ -d $vcpe_home ];then
            VCPE_HOME=$vcpe_home
          else
           echo "The directory can not be found,This installation will be exit."
           exit 1
          fi
        fi

        echo -n "The sms package directory is [default:/home/vcpe/SMS]:"
        read sms_home
        if [ -z $sms_home ];then
          if [ -d $SMS_HOME ]; then
            echo "Installation begin..."
          else
            echo "The directory can not be found,This installation will be exit."
            exit 1
          fi
        else
          if [ -d $SMS_HOME ];then
            SMS_HOME=$sms_home
          else
           echo "The directory can not be found,This installation will be exit."
           exit 1
          fi
        fi
        while :
        do
          i=1
          SMS_VERSION=()
          echo "SMS version list:"
          for SMS_PACKAGE in $(ls $SMS_HOME )
          do
              echo "[$i] : $SMS_PACKAGE"
              SMS_VERSION[$i]=$SMS_PACKAGE
              i=`expr $i + 1`
          done
          echo -n "Pls choose sms version:"
          read version
          if [ -z $version ] || [ $version -ge $i ] ;then
            echo "Pls input the correct version number!"
            continue
           else
             SMS_PACKAGE=${SMS_VERSION[$version]}
             echo $SMS_PACKAGE

             echo "database import..."
             rm -rf $SMS_HOME/$SMS_PACKAGE/sms-db.sql
             cd $SMS_HOME/$SMS_PACKAGE ;ls db* > $SMS_HOME/$SMS_PACKAGE/sms-db.sql
             sed -i s/db_/source\ db_/g $SMS_HOME/$SMS_PACKAGE/sms-db.sql
             #cat $SMS_HOME/sms-db.sql
             cd $SMS_HOME/$SMS_PACKAGE ; mysql -uroot -p$new_password -e"source sms-db.sql;"
             echo "vcpe-manage-web depolyment..."
             mkdir /usr/local/apache-tomcat8/backup
             cp /usr/local/apache-tomcat8/webapps/*.war /usr/local/apache-tomcat8/backup/
             cp $SMS_HOME/$SMS_PACKAGE/*.war /usr/local/apache-tomcat8/webapps
             systemctl start tomcat.service
             echo "Done."
             break
          fi
        done
}

function mano_install {
  #statements
  system_init
  java_install
  mysql_install
  tomcat_install
  
}
#flexinc depolyment
function flexinc_install {
        system_init
        echo "ONOS depolyment..."
        echo -n "The ONOS package directory is [default:/home/vcpe/ONOS]:"
        read onos_home
        if [ -z $onos_home ];then
          if [ -d $ONOS_HOME ]; then
            echo "Installation begin..."
          else
            echo "The directory can not be found,This installation will be exit."
            exit 1
          fi
        else
          if [ -d $onos_home ];then
            ONOS_HOME=$onos_home
          else
           echo "The directory can not be found,This installation will be exit."
           exit 1
          fi
        fi

        echo -n "the cluster scene:n/y[default:n]"
        read scene
        while true ; do
          if [ x"$scene" = x"y" ] ;then
            sed -i s/isCluster=.*/isCluster=$scene/g $ONOS_HOME/flexinc-run
            while true ; do
              echo -n "ifconfig cluster network card ips:[default:$FLEXINC_IP1,$FLEXINC_IP2,$FLEXINC_IP3]"
              read ips
              if [ -z $ips ];then
                ip_array=($FLEXINC_IP1 $FLEXINC_IP2 $FLEXINC_IP3)
              else
                ip_array=()
                ip_array[0]=`echo $ips | awk -F',' '{print  $1}'`
                ip_array[1]=`echo $ips | awk -F',' '{print  $2}'`
                ip_array[2]=`echo $ips | awk -F',' '{print  $3}'`
              fi
              for ((a=0;<3;a++)) ;do
                judge_ip "${ip_array[$a]}"
                j=`echo $?`
                until [ "$j" -eq 0 ];do
                  echo -e "\033[31m you input error IP：${ip_array[$a]} ====>>>>\033[0m"
                  echo  "example "192.168.1.1""
                  break
                done
                b=$[a + 1]
                sed -i s/FLEXINC_IP$b=.*/FLEXINC_IP$b=${ip_array[$a]}/g $ONOS_HOME/flexinc-run
              done
              break 2
            done

          elif [ x"$scene" = x"n" ] || [ -z $scene ] ; then
            sed -i s/isCluster=.*/isCluster=$scene/g $ONOS_HOME/flexinc-run
            while true ; do
              echo -n "ifconfig network card ip:[default:$FLEXINC_IP]"
              read ipnew
              if [ -z $ipnew ];then
                  sed -i s/FLEXINC_IP=.*/FLEXINC_IP=$FLEXINC_IP/g $ONOS_HOME/flexinc-run
              else
                judge_ip “${ipnew}”
                i=`echo $?`
                until [ "$i" -eq 0 ];do
                  echo -e "\033[31m you input error IP：${ipnew} ====>>>>\033[0m"
                  echo  "example “192.168.1.1”"
                  break
                done
                sed -i s/FLEXINC_IP=.*/FLEXINC_IP=$ipnew/g $ONOS_HOME/flexinc-run
              fi
             break 2
           done
          else
            echo "Pls input correct value."
            continue
          fi
        done

        #STB_WEB_URL
        sed -i "s/STB_WEB_URL=.*/STB_WEB_URL=\"http:\/\/$VCPE_IP:3838\/vcpe-manage-web\/gw\"/g" $ONOS_HOME/flexinc-run

        chmod a+x $ONOS_HOME/flexinc-run
        cp $ONOS_HOME/* /opt

        #cd /opt ; ./flexinc-run install FlexINC_*.tar.gz
        while :
        do
          i=1
          ONOS_VERSION=()
          echo "onos version list:"
          for ONOS_PACKAGE in $( ls /opt |grep FlexINC-.*.tar.gz)
          do
              echo "[$i] : $ONOS_PACKAGE"
              ONOS_VERSION[$i]=$ONOS_PACKAGE
              i=`expr $i + 1`
          done
          echo -n "Pls choose sms version:"
          read version
          if [ -z $version ] || [ $version -ge $i ] ;then
            echo "Pls input the correct version number!"
            continue
           else
             ONOS_PACKAGE=${ONOS_VERSION[$version]}
             echo $ONOS_PACKAGE
             echo "vcpe-manage-web depolyment..."
             cd /opt ; ./flexinc-run install $ONOS_PACKAGE
             echo "Done."
             break
          fi
        done

        source /etc/profile

        cd /opt ; ./flexinc-run restart
}

touch install-$CURRENT_TIME.log
