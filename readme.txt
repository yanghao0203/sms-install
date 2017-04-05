系统要求：centos7-mini
依赖包：
1.vcpe-basic.tar.gz, 需要放入/home目录,下载位置:172.16.137.206:/home
2.vcpe各组件集成版本包，如FlexBS-vCPE-US-v1.0.4，放置入/home目录

安装前配置脚本中版本包路径：
PACKAGE_HOME=/home/FlexBS-vCPE-US-v1.0.x
其余配置均可在脚本执行过程中完成。

脚本主要包含如下步骤：
    1.系统初始化：主机名配置、防火墙配置、时区与NTP配置、系统依赖包安装
    2.组件部署：mano和vcpe依赖包安装、mysql初始化、项目配置文件交互式配置
    3.flexinc安装：初始化配置文件生成，自动化安装
    4.开机自启动：tomcat、mysql、flexinc
