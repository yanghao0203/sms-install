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
VCPE_HOME=/home/vcpe
SMS_HOME=$VCPE_HOME/sms
JAVA_VERSION=java-1.8.0-openjdk
password=123456

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
#Initialization
#echo "nameserver 8.8.8.8" >> /etc/resolv.conf
yum install -y  vim autoconf net-tools unzip > /dev/null

#java install
echo "Installing java package....[default:$JAVA_VERSION]"
yum install -y $JAVA_VERSION > /dev/null
echo "Done."

#Mysql installation
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
             echo $MYSQL_VERSION
             tar -xf $MYSQL_VERSION -C $VCPE_HOME
             rpm -ivh $VCPE_HOME/MySQL-client-*.rpm
             rpm -ivh $VCPE_HOME/MySQL-server-*.rpm
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
if [ -f /etc/my.cnf ] ; then
  echo "MySQL initialization is already done."
else
  cp  /usr/share/mysql/my-default.cnf  /etc/my.cnf
  /bin/mysql_install_db > /dev/null
  echo "skip-grant-tables" >> /etc/my.cnf
  service mysql restart
  echo -n "Pls input the password of root:[default:123456]"
  read passwd
  if [ -z $passwd ] ;then
     password=123456
   else
    password=$passwd
  fi
  mysql -uroot -e"update mysql.user set mysql.user.password=password('$password'),mysql.user.password_expired='Y' where mysql.user.user='root';"
  sed -i s/skip-grant-tables/\#skip-grant-tables/g /etc/my.cnf
  service mysql restart
  #mysql -uroot -p$password -e"SET PASSWORD = PASSWORD('$password');"
#  mysql -uroot -p$password  <<EOF 2>/dev/null
#    SET PASSWORD = PASSWORD('$password');
#EOF
  echo "Done."
fi

#Apache tomcat8 installation
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
Description=Tomcat7
After=syslog.target network.target remote-fs.target nss-lookup.target

[Service]
Type=forking
#Environment='JAVA_HOME=/usr/local/jdk1.7.0_75/'
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

echo "sms depolyment..."

echo -n "The sms package directory is [default:/home/vcpe/sms]:"
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
  for SMS_PACKAGE in $(ls $SMS_HOME)
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
     cd $SMS_HOME/$SMS_PACKAGE ;ls db_vcpe_manage* > $SMS_HOME/$SMS_PACKAGE/sms-db.sql
     sed -i s/db_vcpe/source\ db_vcpe/g $SMS_HOME/$SMS_PACKAGE/sms-db.sql
     #cat $SMS_HOME/sms-db.sql
     cd $SMS_HOME/$SMS_PACKAGE ; mysql -uroot -p$password -e"source sms-db.sql;"
     echo "vcpe-manage-web depolyment..."
     mkdir /usr/local/apache-tomcat8/backup
     cp /usr/local/apache-tomcat8/webapps/vcpe* /usr/local/apache-tomcat8/backup/
     cp $SMS_HOME/$SMS_PACKAGE/vcpe-*.war /usr/local/apache-tomcat8/webapps
     systemctl start tomcat.service
     echo "Done."
     break
  fi
done
#start apache tomcat8...


#flexinc depolyment
