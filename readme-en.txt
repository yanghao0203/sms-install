OS Required：centos7-mini
Dependent packages：
1.vcpe-basic.tar.gz, Please put this package to /home.Download dir(jumpserver:netelastic.duckdns.org):/home/netelastic/packages/FlexCPE/vCPE/vcpe-basic.tar.gz
2.VCPE integrated version package,like FlexBS-vCPE-US-v1.0.4，please put this package to /home

Preinstall configuration:
the version package path:
PACKAGE_HOME=/home/FlexBS-vCPE-US-v1.0.x

The rest of the configuration can be done during script execution.

The script contains steps：
1.System initialization: host name configuration, firewall configuration, timezone and NTP configuration, the system depends on the package installation.
2.Component deployment: mano and vcpe dependency package installation, mysql initialization, project configuration file interactive configuration.
3.Flexinc Installation: Initialize the configuration file generation, automate the installation.
4.Auto-start configuration of tomcat,mysql and flexinc.
