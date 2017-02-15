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
yum install -y  vim autoconf net-tools > /dev/null

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

echo "sms depolyment..."
#database import
cd $SMS_HOME ;ls db_vcpe_manage* > $SMS_HOME/sms-db.sql
sed -i s/db_vcpe/source\ db_vcpe/g $SMS_HOME/sms-db.sql
#cat $SMS_HOME/sms-db.sql
cd $SMS_HOME ; mysql -uroot -p$password -e"source sms-db.sql;"

#vcpe-manage-web depolyment

#flexinc depolyment
