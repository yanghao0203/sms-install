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
CURRENT_TIME=`date +20%y.%m.%d_%H:%M:%S`
VCPE_HOME=/home/vcpe-basic
PACKAGE_HOME=/home/FlexBS-vCPE-US-v1.0.x
JAVA_VERSION=
old_password=
new_password=
isCluster=n
prifix=`ip r sh | grep default | awk '{print $3}' | awk -F. '{print $1"."$2"."$3}'`
LOCALIP=`ip add sh | grep $prifix | awk '{print $2}' | awk -F/ '{print $1}'`
VCPE_IP=$LOCALIP
FLEXINC_IP=$LOCALIP
FLEXINC_IP1=$LOCALIP
FLEXINC_IP2=`echo $FLEXINC_IP1 | awk -F. '{print $1"."$2"."$3"."($4+1)}'`
FLEXINC_IP3=`echo $FLEXINC_IP1 | awk -F. '{print $1"."$2"."$3"."($4+2)}'`
FTP_IP=$LOCALIP
FTP_PORT=21
FTP_USER=certus
FTP_PASSWD=certus123
VCPE_DBNAME=db_flex_so

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
        setenforce 0
        sed -i s/^SELINUX=.*/SELINUX=disabled/g /etc/sysconfig/selinux
        yum install -y  vim autoconf net-tools unzip ntp expect libaio >> $VCPE_HOME/install-$CURRENT_TIME.log 2>&1
        #time zone change
        #Pacific
        cp /usr/share/zoneinfo/US/Pacific /etc/localtime
        service ntpd start
        hwclock -w
        systemctl enable ntpd.service
}

function sms_init {
        #firewall
        firewall-cmd --zone=public --add-port=6633/tcp --permanent
        firewall-cmd --zone=public --add-port=6653/tcp --permanent
        firewall-cmd --zone=public --add-port=6640/tcp --permanent
        firewall-cmd --zone=public --add-port=8181/tcp --permanent
        firewall-cmd --zone=public --add-port=9876/tcp --permanent
        firewall-cmd --zone=public --add-port=8300/tcp --permanent
        firewall-cmd --zone=public --add-port=3838/tcp --permanent
        firewall-cmd --reload
        #hostname
        hostnamectl set-hostname flexsms
        echo "127.0.0.1   flexsms" >> /etc/hosts
}

function  mano_init {
        #firewall
        firewall-cmd --zone=public --add-port=8080/tcp --permanent
        firewall-cmd --reload
        #hostname
        hostnamectl set-hostname flexsynth
        echo "127.0.0.1   flexsynth" >> /etc/hosts
}

function ftp_install {
        ftp_version=`rpm -qa|grep vsftpd | awk -F- '{print $2}'`
        if [ -z $ftp_version ];then
          yum install -y vsftpd
          sed -i '/^anonymous_enable=YES/a\anonymous_enable=NO' /etc/vsftpd/vsftpd.conf
          sed -i '/^chroot_local_user=YES/a\chroot_local_user=YES' /etc/vsftpd/vsftpd.conf
          sed -i '$a\allow_writeable_chroot=YES' /etc/vsftpd/vsftpd.conf
          service vsftpd restart
          chkconfig vsftpd on

          useradd -d /var/ftp/$FTP_USER -s /sbin/nologin $FTP_USER
          /usr/bin/expect >> $VCPE_HOME/install-$CURRENT_TIME.log 2>&1 <<EOF
set time 1
spawn passwd $FTP_USER
expect  "New password:"
send "$FTP_PASSWD\r"
expect  "Retype new password:"
send "$FTP_PASSWD\r"
EOF
          chown -R $FTP_USER.$FTP_USER /var/ftp/$FTP_USER
         else
           echo "FTP server is alreay installed."
         fi
}

#java install
function java8_install {
        echo "Installing java package...."
        java_version=`java -version 2>&1 |awk 'NR==1{ gsub(/"/,""); print $3 }'`

        if [ "$java_version"x = "1.8.0_77"x ]; then
           echo "java_version "$java_version
        else
           sed -i '/JAVA_HOME/d' /etc/profile
           sed -i '/JRE_HOME/d' /etc/profile
           sed -i '/CLASSPATH/d' /etc/profile
           sed -i '/export PATH/d' /etc/profile
           [ ! -d "/usr/lib/jvm" ] && mkdir /usr/lib/jvm
           cp $VCPE_HOME/jdk1.8.0_77.tar.gz /usr/lib/jvm
           cd /usr/lib/jvm
           rm -rf jdk1.8.0_77
           rm -rf java-8-openjdk-amd64
           mkdir jdk1.8.0_77
           tar zxf jdk1.8.0_77.tar.gz
           ln -s  jdk1.8.0_77 java-8-openjdk-amd64
           echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> /etc/profile
           echo 'export JRE_HOME=$JAVA_HOME/jre' >> /etc/profile
           echo 'export CLASSPATH=.:$CLASSPATH:$JAVA_HOME/lib:$JRE_HOME/lib' >> /etc/profile
           echo 'export PATH=$PATH:$JAVA_HOME/bin:$JRE_HOME/bin' >> /etc/profile
           /bin/sh /etc/profile
           echo "Done."
        fi

}

function java7_install {
        echo "Installing java package...."
        java_version=`java -version 2>&1 |awk 'NR==1{ gsub(/"/,""); print $3 }'`

        if [ "$java_version"x = "1.7.0_75"x ]; then
           echo "java_version "$java_version
        else
           sed -i '/JAVA_HOME/d' /etc/profile
           sed -i '/JRE_HOME/d' /etc/profile
           sed -i '/CLASSPATH/d' /etc/profile
           sed -i '/export PATH/d' /etc/profile
           cp $VCPE_HOME/jdk-7u75-linux-x64.tar.gz /usr/local
           cd /usr/local
           rm -rf jdk1.7.0_75
           tar zxf jdk-7u75-linux-x64.tar.gz
           echo 'export JAVA_HOME=/usr/local/jdk1.7.0_75' >> /etc/profile
           echo 'export CLASSPATH==.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar' >> /etc/profile
           echo 'export PATH==$PATH:$JAVA_HOME/bin' >> /etc/profile
           /bin/sh /etc/profile
           echo "Done."
        fi
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
                echo "Installing MySQL package..."
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
                     rpm -ivh $VCPE_HOME/MySQL-client-*.rpm  >> $VCPE_HOME/install-$CURRENT_TIME.log 2>&1
                     rpm -ivh $VCPE_HOME/MySQL-server-*.rpm  >> $VCPE_HOME/install-$CURRENT_TIME.log 2>&1
                     rpm -ivh $VCPE_HOME/MySQL-devel-*.rpm  >> $VCPE_HOME/install-$CURRENT_TIME.log 2>&1
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
        old_password=`sed -n '/password/h;${x;p}' /root/.mysql_secret | awk  '{print $18}'`
        if [ -f /etc/my.cnf ] ; then
          echo "MySQL initialization is already done."
        else
          cp  /usr/share/mysql/my-default.cnf  /etc/my.cnf
          echo "#skip-grant-tables" >> /etc/my.cnf
          service mysql start
          echo -n "Pls input the password of root:[default:123456]"
          read passwd
          if [ -z $passwd ] ;then
             new_password=123456
           else
             new_password=$passwd
          fi

          /usr/bin/expect >> $VCPE_HOME/install-$CURRENT_TIME.log 2>&1 <<EOF
set time 1
spawn mysql -uroot -p$old_password
expect {
"mysql>" {send "SET PASSWORD=PASSWORD('$new_password');\r";}
}
expect "*#"                                                                                                                                                              expect "*#"
send "quit"
EOF

          mysql -uroot -p$new_password <<EOF
use mysql;
update user set password=password('$new_password') where user='root';
GRANT ALL ON *.* TO 'root'@'%' IDENTIFIED BY '$new_password';
flush privileges;
quit
EOF
          chkconfig mysql on
          echo "Done."
        fi
}
#Apache tomcat8 installation
function tomcat8_install {
      echo "Installing Tomcat Apache package...."
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
Environment='JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64'
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

function tomcat7_install {
      echo "Installing Tomcat Apache package...."
      if [ -d /usr/local/apache-tomcat-7.0.65 ] ;then
        echo "Apache Tomcat is already installed."
      elif [ -f $VCPE_HOME/apache-tomcat-7.0.65.tar.gz ] ; then
        tar -zxf $VCPE_HOME/apache-tomcat-7.0.65.tar.gz -C /usr/local
        sed -i '/^PRGDIR/a\\CATALINA_OPTS="$CATALINA_OPTS -server -Xmx2048m -XX:MaxPermSize=512m "' /usr/local/apache-tomcat-7.0.65/bin/catalina.sh
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
Description=Tomcat7
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
Environment='JAVA_HOME=/usr/local/jdk1.7.0_75/'
Environment='CATALINA_PID=/usr/local/apache-tomcat-7.0.65/bin/tomcat.pid'
Environment='CATALINA_HOME=/usr/local/apache-tomcat-7.0.65/'
Environment='CATALINA_BASE=/usr/local/apache-tomcat-7.0.65/'


WorkingDirectory=/usr/local/apache-tomcat-7.0.65/

ExecStart=/usr/local/apache-tomcat-7.0.65/bin/startup.sh
ExecStop=/bin/kill -s QUIT $MAINPID
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOF

      systemctl enable tomcat.service
      fi
}

#sms depoly
function flexsms_install {

        echo "FlexSMS depolyment..."
        system_init
        sms_init
        java8_install
        mysql_install
        tomcat8_install

        while true ;
        do
          i=1
          SMS_VERSION=()
          echo "SMS version list:"
          for SMS_PACKAGE in $(find $PACKAGE_HOME -name FlexSMS* -exec basename {} \; )
          do
            if [ -z $SMS_PACKAGE ]; then
              echo "FlexSMS package can't be found.The installation will be exit."
            else
              echo "[$i] : $SMS_PACKAGE"
              SMS_VERSION[$i]=$SMS_PACKAGE
              i=`expr $i + 1`
            fi
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
             mysql -uroot -p$new_password -e"create database db_flex_so;"
             rm -rf $PACKAGE_HOME/$SMS_PACKAGE/DB/sms-db.sql
             cd $PACKAGE_HOME/$SMS_PACKAGE/DB ;ls db* > $PACKAGE_HOME/$SMS_PACKAGE/DB/sms-db.sql
             sed -i s/db_/source\ db_/g $PACKAGE_HOME/$SMS_PACKAGE/DB/sms-db.sql
             #cat $SMS_HOME/sms-db.sql
             cd $PACKAGE_HOME/$SMS_PACKAGE/DB ; mysql -uroot -p$new_password  -Ddb_flex_os_poc -e"source sms-db.sql;"
             echo "manage-web depolyment..."
             [ ! -d /usr/local/apache-tomcat8/backup ] && mkdir /usr/local/apache-tomcat8/backup
             cp /usr/local/apache-tomcat8/webapps/*.war /usr/local/apache-tomcat8/backup/
             cp $PACKAGE_HOME/$SMS_PACKAGE/*.war /usr/local/apache-tomcat8/webapps
             systemctl start tomcat.service
             echo "FlexSMS project configuration."
             echo "Pls wait for the FlexSMS project to start..."
             while [ ! -d /usr/local/apache-tomcat8/webapps/vcpe-connector ] || [ ! -d /usr/local/apache-tomcat8/webapps/vcpe-manage-web ] ;do
                echo -n "..."
                sleep 5
             done
             echo ""
             echo -n "Pls input the onos ip address:[default:$FLEXINC_IP]"
             read ip
             if [ -z $ip ];then
               ip=$FLEXINC_IP
             else
               judge_ip $ip
               j=`echo $?`
               until [ "$j" -eq 0 ];do
                echo -e "\033[31m you input error IP：$ip ====>>>>\033[0m"
                echo  "example "192.168.1.1""
                break
              done
             fi
             sed -i "s/onos.invoke.address=.*/onos.invoke.address=\"http:\/\/$ip:8181\/onos\/vcpena\"/g" /usr/local/apache-tomcat8/webapps/vcpe-connector/WEB-INF/classes/config.properties
             sed -i "s/ftp.ip=.*/ftp.ip=\"$FTP_IP\"/g" /usr/local/apache-tomcat8/webapps/vcpe-connector/WEB-INF/classes/config.properties
             sed -i "s/ftp.user=.*/ftp.user=\"$FTP_USER\"/g" /usr/local/apache-tomcat8/webapps/vcpe-connector/WEB-INF/classes/config.properties
             sed -i "s/ftp.password=.*/ftp.password=\"$FTP_PASSWD\"/g" /usr/local/apache-tomcat8/webapps/vcpe-connector/WEB-INF/classes/config.properties
             sed -i  's/\.\.\/logs/'${TOMCAT_HOME//\//\\/}'\/logs/' /usr/local/apache-tomcat8/webapps/vcpe-connector/WEB-INF/classes/log4j.xml
             sed -i '/jdbc.url/s/\([0-9]\{1,3\}.\)\{3\}[0-9]\{1,3\}/127.0.0.1/g' /usr/local/apache-tomcat8/webapps/vcpe-manage-web/WEB-INF/classes/jdbc.properties
             sed -i  's/\.\.\/logs/'${TOMCAT_HOME//\//\\/}'\/logs/' /usr/local/apache-tomcat8/webapps/vcpe-manage-web/WEB-INF/classes/log4j.xml
             systemctl restart tomcat.service
             echo "Done."
             break
          fi
        done
}

function flexsynth_install {
  #statements
  echo "FlexSYNTH depolyment..."
  system_init
  mano_init
  java7_install
  mysql_install
  tomcat7_install

  while true :
  do
    i=1
    MANO_VERSION=()
    echo "Mano version list:"
    for MANO_PACKAGE in $(find $PACKAGE_HOME -name FlexSYNTH* -exec basename {} \;)
    do
      if [ -z $MANO_PACKAGE ]; then
        echo "FlexSYNTH package can't be found.The installation will quit."
      else
        echo "[$i] : $MANO_PACKAGE"
        SMS_VERSION[$i]=$MANO_PACKAGE
        i=`expr $i + 1`
      fi
    done
    echo -n "Pls choose mano version:"
    read version
    if [ -z $version ] || [ $version -ge $i ] ;then
      echo "Pls input the correct version number!"
      continue
     else
       SMS_PACKAGE=${MANO_VERSION[$version]}
       echo $MANO_PACKAGE

       echo "database import..."
       rm -rf $PACKAGE_HOME/$MANO_PACKAGE/sql/sms-db.sql
       cd $PACKAGE_HOME/$MANO_PACKAGE/sql ;ls db* > $PACKAGE_HOME/$MANO_PACKAGE/sql/sms-db.sql
       sed -i s/db/source\ db/g $PACKAGE_HOME/$MANO_PACKAGE/sql/sms-db.sql
       #cat $SMS_HOME/sms-db.sql
       cd $PACKAGE_HOME/$MANO_PACKAGE/sql ; mysql -uroot -p$new_password -e"source sms-db.sql;"
       echo "Mano-web depolyment..."
       [ ! -d /usr/local/apache-tomcat-7.0.65/backup ] && mkdir /usr/local/apache-tomcat-7.0.65/backup
       cp /usr/local/apache-tomcat-7.0.65/webapps/*.war* /usr/local/apache-tomcat-7.0.65/backup/
       cp $PACKAGE_HOME/$MANO_PACKAGE/deploy/*.war /usr/local/apache-tomcat-7.0.65/webapps
       echo -n "Use windriver or openstack?[default:windriver]:"
       read type
       if [ -z $type ] || [ x$type = x"windriver" ] ; then
           cp $PACKAGE_HOME/$MANO_PACKAGE/deploy/mano-vim.war-1512 /usr/local/apache-tomcat-7.0.65/webapps/mano-vim.war
       else
           cp $PACKAGE_HOME/$MANO_PACKAGE/deploy/mano-vim.war-m /usr/local/apache-tomcat-7.0.65/webapps/mano-vim.war
       fi
       systemctl start tomcat.service
       echo "FlexSYNTH project configuration."
       echo "Pls wait for the FlexSYNTH project to start..."
       while [ ! /usr/local/apache-tomcat-7.0.65/webapps/mano ] || [ ! -d /usr/local/apache-tomcat-7.0.65/webapps/mano-vim ] || [ ! /usr/local/apache-tomcat-7.0.65/webapps/mano-nfvo ] || [ ! /usr/local/apache-tomcat-7.0.65/webapps/mano-vnfm ] ;do
          echo -n "..."
          sleep 5
       done
       #mano
       ##gui.properties
#       echo ""
#       echo -n "Use windriver or other alarm data[default:windriver]:"
#       read type
#       if [ -z $type ] || [ x$type = x"windriver" ] ; then
#         sed -i "s/^Alarm_Page_Switch.*/Alarm_Page_Switch\ =\ 1/g" /usr/local/apache-tomcat-7.0.65/webapps/mano/WEB-INF/classes/gui.properties
#       else
#         sed -i "s/^Alarm_Page_Switch.*/Alarm_Page_Switch\ =\ 0/g" /usr/local/apache-tomcat-7.0.65/webapps/mano/WEB-INF/classes/gui.properties
#         sed -i "s/^AlarmPlatform_X=.*/AlarmPlatform_X=1/g" /usr/local/apache-tomcat-7.0.65/webapps/mano/WEB-INF/classes/gui.properties
#       fi
       ##stream-config.properties
       sed -i "s/^STREAM_FILE_LOCAL_REPOSITORY=.*/STREAM_FILE_LOCAL_REPOSITORY=\/usr\/local\/apache-tomcat-7.0.65\/webapps\/uploadpath/g" /usr/local/apache-tomcat-7.0.65/webapps/mano/WEB-INF/classes/stream-config.properties
       #mano-vnfm
       ##mano-common.properties

       #mano-nfvo
       ##mano-common.properties
       sed -i "s/^VNFD_SWITCH.*/VNFD_SWITCH=2/g" /usr/local/apache-tomcat-7.0.65/webapps/mano-nfvo/WEB-INF/classes/mano-common.properties
       sed -i "s/^CONFIGS_SWITCH.*/CONFIGS_SWITCH\ =\ 1/g" /usr/local/apache-tomcat-7.0.65/webapps/mano-nfvo/WEB-INF/classes/mano-common.properties
       #oam_physical_network

       #mano-vim
       ##
       #sed -i "s/^PROVIDER_SWITCH.*/PROVIDER_SWITCH\ =\ 2/g" /usr/local/apache-tomcat-7.0.65/webapps/mano-vim/WEB-INF/classes/mano-vim.properties
       sed -i '/\#PROVIDER_SWITCH/a\PROVIDER_SWITCH\ =\ 2' /usr/local/apache-tomcat-7.0.65/webapps/mano-vim/WEB-INF/classes/mano-vim.properties
       sed -i "s/^PHYSICAL_NETWOR_SWITCH.*/PHYSICAL_NETWOR_SWITCH\ =\ 2/g" /usr/local/apache-tomcat-7.0.65/webapps/mano-vim/WEB-INF/classes/mano-vim.properties
       service tomcat restart
       echo "Done."
       break
    fi
  done
}
#flexinc depolyment
function flexinc_install {
        system_init
        echo "FlexINC depolyment..."

        while :
        do
          i=1
          ONOS_VERSION=()
          echo "flexinc version list:"
          for ONOS_PACKAGE in $(find $PACKAGE_HOME -name FlexINC* -exec basename {} \;)
          do
            if [ -z $ONOS_PACKAGE ]; then
                echo "FlexINC package can't be found.The installation will quit."
            else
              echo "[$i] : $ONOS_PACKAGE"
              ONOS_VERSION[$i]=$ONOS_PACKAGE
              i=`expr $i + 1`
            fi
          done
          rm -rf /opt/.flexinc-config
          touch /opt/.flexinc-config
          echo -n "Pls choose flexinc version:"
          read version
          if [ -z $version ] || [ $version -ge $i ] ;then
            echo "Pls input the correct  number!"
            continue
           else
             ONOS_PACKAGE=${ONOS_VERSION[$version]}
             echo "FLEXINC_NAME=$ONOS_PACKAGE" >> /opt/.flexinc-config
             break
          fi
        done


        echo -n "the cluster scene:n/y[default:n]"
        read scene
        while true ; do
          if [ x"$scene" = x"y" ] ;then
            #sed -i s/isCluster=.*/isCluster=$scene/g $ONOS_HOME/flexinc-run
            echo "isCluster=$scene" >> /opt/.flexinc-config
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
                  echo -e "\033[31m You enter error IP：${ip_array[$a]} ====>>>>\033[0m"
                  echo  "example "192.168.1.1""
                  break
                done
                b=$[a + 1]
                #sed -i s/FLEXINC_IP$b=.*/FLEXINC_IP$b=${ip_array[$a]}/g $ONOS_HOME/flexinc-run
                echo "FLEXINC_IP$b=${ip_array[$a]}" >> /opt/.flexinc-config
              done
              break 2
            done

          elif [ x"$scene" = x"n" ] || [ -z $scene ] ; then
            scene=n
            #sed -i s/isCluster=.*/isCluster=$scene/g $ONOS_HOME/flexinc-run
            echo "isCluster=$scene" >> /opt/.flexinc-config
            while true ; do
              echo -n "Config flexinc ip[default:$FLEXINC_IP]:"
              read ipnew
              if [ -z $ipnew ];then
                  #sed -i s/FLEXINC_IP=.*/FLEXINC_IP=$FLEXINC_IP/g $ONOS_HOME/flexinc-run
                  echo "FLEXINC_IP=$FLEXINC_IP" >> /opt/.flexinc-config
              else
                judge_ip “${ipnew}”
                i=`echo $?`
                until [ "$i" -eq 0 ];do
                  echo -e "\033[31m You enter error IP：${ipnew} ====>>>>\033[0m"
                  echo  "example “192.168.1.1”"
                  break
                done
                echo "FLEXINC_IP=$ipnew" >> /opt/.flexinc-config
              fi
             break 2
           done
          else
            echo "Pls input correct value."
            continue
          fi
        done
        echo "FLEXINC_USER=root" >> /opt/.flexinc-config
        echo "PROJECT=flexgw" >> /opt/.flexinc-config

        #STB_WEB_URL
        echo "Config STB_WEB_URL..."
        while true ; do
          echo -n "Pls enter the ip of vcpe[default:$VCPE_IP]:"
          read ipnew
          if [ -z $ipnew ];then
              #sed -i s/FLEXINC_IP=.*/FLEXINC_IP=$FLEXINC_IP/g $ONOS_HOME/flexinc-run
              echo "STB_WEB_URL=http://$VCPE_IP:3838/vcpe-manage-web/vcpe" >> /opt/.flexinc-config
          else
            judge_ip “${ipnew}”
            i=`echo $?`
            until [ "$i" -eq 0 ];do
              echo -e "\033[31m you input error IP：${ipnew} ====>>>>\033[0m"
              echo  "example “192.168.1.1”"
              break
            done
            echo "STB_WEB_URL=http://$ipnew:3838/vcpe-manage-web/vcpe" >> /opt/.flexinc-config
          fi
         break
       done

        echo "NETCONFSERVER_USER=foo" >> /opt/.flexinc-config
        echo "NETCONFSERVER_PASSWORD=bar" >> /opt/.flexinc-config

        #sed -i "s/STB_WEB_URL=.*/STB_WEB_URL=\"http:\/\/$VCPE_IP:3838\/vcpe-manage-web\/vcpe\"/g" $ONOS_HOME/flexinc-run
        #sed -i "/STB_WEB_URL/s/[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*/$VCPE_IP/;s/vcpe/gw/" $ONOS_HOME/flexinc-run
        chmod a+x $PACKAGE_HOME/$ONOS_PACKAGE/DB/flexinc-setup
        cp $PACKAGE_HOME/$ONOS_PACKAGE/DB/flexinc-setup /opt
        cp $PACKAGE_HOME/$ONOS_PACKAGE/deploy/* /opt

        #cd /opt ; ./flexinc-run install FlexINC_*.tar.gz
        #cd /opt ; ./flexincsh
        echo "..."
        cd /opt
        /usr/bin/expect >> $VCPE_HOME/install-$CURRENT_TIME.log 2>&1 <<EOF
#        /usr/bin/expect  <<EOF
set timeout 120
spawn ./flexinc-setup
expect  "help):"
send "1\r"
expect  "project:"
send "1\r"
expect "Web URL"
send "\r"
expect "Netconf server user name"
send "\r"
expect "password"
send "\r"
expect "Local node IP"
send "\r"
expect "Local node user name"
send "\r"
expect "Cluster"
send "n\r"
expect "tarball:"
send "1\r"
expect "Is this configs correct?"
send "y\r"
expect "/root/.ssh/id_rsa"
send "\r"
expect "empty for no passphrase"
send "\r"
expect "Enter same passphrase again"
send "\r"
expect "want to continue connecting (yes/no)?"
send "yes\r"
expect "'s password:"
send "123456\r"
expect "help):"
send "q\r"
EOF

        echo "/opt/flexinc/bin/flexinc-run start" >> /etc/rc.local
        chmod a+x /etc/rc.d/rc.local
        echo "Done"

}

touch /home/install-$CURRENT_TIME.log
logfile=install-$CURRENT_TIME.log

echo -n "The VCPE directory is [default:$VCPE_HOME]:"
read vcpe_home
if [ -z $vcpe_home ];then
  if [ -d $VCPE_HOME ]; then
    echo "Installation begin..."
  else
    cd /home ; tar -zxvf vcpe-basic.tar.gz
  fi
else
  if [ -d $vcpe_home ];then
    VCPE_HOME=$vcpe_home
  else
   echo "The directory $VCPE_HOME can not be found,The installation will be exit."
   exit 1
  fi
fi

echo -n "The package directory is [default:$PACKAGE_HOME]:"
read package_home
if [ -z $package_home ];then
  if [ -d $PACKAGE_HOME ]; then
    echo "Installation begin..."
  else
    echo "The directory $PACKAGE_HOME can not be found,The installation will be exit."
    exit 1
  fi
else
  if [ -d $package_home ];then
    PACKAGE_HOME=$package_home
  else
   echo "The directory  $PACKAGE_HOME can not be found,The installation will be exit."
   exit 1
  fi
fi

while true ; do
  read -p "Deploy options:[FlexSYNTH:m FlexSMS:s FlexINC:f or QUIT:q]" OK
  case ${OK} in
      m)
      flexsynth_install
      ;;
      s)
      flexsms_install
      ftp_install
      ;;
      f)
      flexinc_install
      ;;
      q)
      break ;;
      *)
      echo "Pls enter "m" for FlexSYNTH,"s" for FlexSMS,"f" for FlexINC,"q" for QUIT."
      continue
      ;;
  esac
done
