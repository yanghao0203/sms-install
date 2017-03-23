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
VCPE_HOME=/home/vcpe
SMS_HOME=$VCPE_HOME/SMS
ONOS_HOME=$VCPE_HOME/ONOS
MANO_HOME=$VCPE_HOME/MANO
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
        yum install -y  vim autoconf net-tools unzip ntp expect libaio >> install-$CURRENT_TIME.log 2>&1
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
          /usr/bin/expect >> install-$CURRENT_TIME.log 2>&1 <<EOF
set time 1
spawn passwd $FTP_USER
expect  "password:"
send "$FTP_PASSWD\r"
expect  "password:"
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
           sh /etc/profile
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
           sh /etc/profile
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
                     rpm -ivh $VCPE_HOME/MySQL-devel-*.rpm  >> install-$CURRENT_TIME.log 2>&1
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

          /usr/bin/expect >> install-$CURRENT_TIME.log 2>&1 <<EOF
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
function sms_install {

        echo "SMS depolyment..."
        echo -n "The VCPE package directory is [default:/home/vcpe]:"
        read vcpe_home
        if [ -z $vcpe_home ];then
          if [ -d $VCPE_HOME ]; then
            echo "Installation begin..."
          else
            echo "The directory $VCPE_HOME can not be found,This installation will be exit."
            exit 1
          fi
        else
          if [ -d $vcpe_home ];then
            VCPE_HOME=$vcpe_home
          else
           echo "The directory $VCPE_HOME can not be found,This installation will be exit."
           exit 1
          fi
        fi
        system_init
        java8_install
        mysql_install
        tomcat8_install
        echo -n "The sms package directory is [default:/home/vcpe/SMS]:"
        read sms_home
        if [ -z $sms_home ];then
          if [ -d $SMS_HOME ]; then
            echo "Installation begin..."
          else
            echo "The directory $SMS_HOME can not be found,This installation will be exit."
            exit 1
          fi
        else
          if [ -d $SMS_HOME ];then
            SMS_HOME=$sms_home
          else
           echo "The directory  $SMS_HOME can not be found,This installation will be exit."
           exit 1
          fi
        fi
        while :
        do
          i=1
          SMS_VERSION=()
          echo "SMS version list:"
          for SMS_PACKAGE in $(ls $SMS_HOME  )
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
             rm -rf $SMS_HOME/$SMS_PACKAGE/DB/sms-db.sql
             cd $SMS_HOME/$SMS_PACKAGE/DB ;ls db* > $SMS_HOME/$SMS_PACKAGE/DB/sms-db.sql
             sed -i s/db_/source\ db_/g $SMS_HOME/$SMS_PACKAGE/DB/sms-db.sql
             #cat $SMS_HOME/sms-db.sql
             cd $SMS_HOME/$SMS_PACKAGE/DB ; mysql -uroot -p$new_password -e"source sms-db.sql;"
             echo "manage-web depolyment..."
             [ ! -d /usr/local/apache-tomcat8/backup ] && mkdir /usr/local/apache-tomcat8/backup
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
  echo "MANO depolyment..."
  echo -n "The vcpe package directory is [default:/home/vcpe]:"
  read vcpe_home
  if [ -z $vcpe_home ];then
    if [ -d $VCPE_HOME ]; then
      echo "Installation begin..."
    else
      echo "The directory $VCPE_HOME can not be found,This installation will be exit."
      exit 1
    fi
  else
    if [ -d $vcpe_home ];then
      VCPE_HOME=$vcpe_home
    else
     echo "The directory $VCPE_HOME can not be found,This installation will be exit."
     exit 1
    fi
  fi
  system_init
  java7_install
  mysql_install
  tomcat7_install
  echo -n "The mano package directory is [default:/home/vcpe/MANO]:"
  read mano_home
  if [ -z $mano_home ];then
    if [ -d $MANO_HOME ]; then
      echo "Installation begin..."
    else
      echo "The directory can not be found,This installation will be exit."
      exit 1
    fi
  else
    if [ -d $MANO_HOME ];then
      MANO_HOME=$mano_home
    else
     echo "The directory can not be found,This installation will be exit."
     exit 1
    fi
  fi
  while true :
  do
    i=1
    MANO_VERSION=()
    echo "Mano version list:"
    for MANO_PACKAGE in $(ls $MANO_HOME )
    do
        echo "[$i] : $MANO_PACKAGE"
        SMS_VERSION[$i]=$MANO_PACKAGE
        i=`expr $i + 1`
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
       rm -rf $MANO_HOME/$MANO_PACKAGE/sql/sms-db.sql
       cd $MANO_HOME/$MANO_PACKAGE/sql ;ls db* > $MANO_HOME/$MANO_PACKAGE/sql/sms-db.sql
       sed -i s/db/source\ db/g $MANO_HOME/$MANO_PACKAGE/sql/sms-db.sql
       #cat $SMS_HOME/sms-db.sql
       cd $MANO_HOME/$MANO_PACKAGE/sql ; mysql -uroot -p$new_password -e"source sms-db.sql;"
       echo "Mano-web depolyment..."
       [ ! -d /usr/local/apache-tomcat-7.0.65/backup ] && mkdir /usr/local/apache-tomcat-7.0.65/backup
       cp /usr/local/apache-tomcat-7.0.65/webapps/*.war* /usr/local/apache-tomcat-7.0.65/backup/
       cp $MANO_HOME/$MANO_PACKAGE/deploy/*.war /usr/local/apache-tomcat-7.0.65/webapps
       echo -n "Use windriver or openstack?[default:windriver]:"
       read type
       if [ -z $type ] || [ x$type = x"windriver" ] ; then
           cp $MANO_HOME/$MANO_PACKAGE/deploy/mano-vim.war-1512 /usr/local/apache-tomcat-7.0.65/webapps/mano-vim.war
       else
           cp $MANO_HOME/$MANO_PACKAGE/deploy/mano-vim.war-m /usr/local/apache-tomcat-7.0.65/webapps/mano-vim.war
       fi
       systemctl start tomcat.service
       echo "Done."
       break
    fi
  done
}
#flexinc depolyment
function flexinc_install {
        system_init
        echo "Flexinc depolyment..."
        echo -n "The flexinc package directory is [default:/home/vcpe/ONOS]:"
        read onos_home
        if [ -z $onos_home ];then
          if [ -d $ONOS_HOME ]; then
            echo "Installation begin..."
          else
            echo "The directory $ONOS_HOME can not be found,This installation will be exit."
            exit 1
          fi
        else
          if [ -d $onos_home ];then
            ONOS_HOME=$onos_home
          else
           echo "The directory  $ONOS_HOME can not be found,This installation will be exit."
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
            scene=n
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
        sed -i "s/STB_WEB_URL=.*/STB_WEB_URL=\"http:\/\/$VCPE_IP:3838\/gw-manage-web\/gw\"/g" $ONOS_HOME/flexinc-run
        #sed -i "/STB_WEB_URL/s/[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*\.[1-9][0-9]*/$VCPE_IP/;s/vcpe/gw/" $ONOS_HOME/flexinc-run
        chmod a+x $ONOS_HOME/flexinc-run
        cp $ONOS_HOME/* /opt

        #cd /opt ; ./flexinc-run install FlexINC_*.tar.gz
        while :
        do
          i=1
          ONOS_VERSION=()
          echo "flexinc version list:"
          for ONOS_PACKAGE in $( ls /opt |grep FlexINC-.*.tar.gz)
          do
              echo "[$i] : $ONOS_PACKAGE"
              ONOS_VERSION[$i]=$ONOS_PACKAGE
              i=`expr $i + 1`
          done
          echo -n "Pls choose flexinc version:"
          read version
          if [ -z $version ] || [ $version -ge $i ] ;then
            echo "Pls input the correct version number!"
            continue
           else
             ONOS_PACKAGE=${ONOS_VERSION[$version]}
             echo $ONOS_PACKAGE
             cd /opt ; ./flexinc-run install $ONOS_PACKAGE
             echo "Done."
             break
          fi
        done
        cd /opt ; ./flexinc-run start
}

touch install-$CURRENT_TIME.log

while true ; do
  read -p "Deploy options:[MANO:m or SMS:s or QUIT:q]" OK
  case ${OK} in
      m)
      mano_install
      ;;
      s)
      sms_install
      ftp_install
      ;;
#      f)
#      flexinc_install
#      ;;
      q)
      break ;;
      *)
      echo "Pls enter "m" for MANO,"s" for SMS,"q" for QUIT."
      continue
      ;;
  esac
done
