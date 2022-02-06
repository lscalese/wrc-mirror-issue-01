ARG IMAGE=store/intersystems/irishealth:2019.3.0.308.0-community
ARG IMAGE=store/intersystems/iris-community:2019.3.0.309.0
ARG IMAGE=store/intersystems/iris-community:2019.4.0.379.0
ARG IMAGE=store/intersystems/iris-community:2020.1.0.199.0
ARG IMAGE=intersystemsdc/iris-community:2019.4.0.383.0-zpm
ARG IMAGE=store/intersystems/iris-community:2020.1.0.199.0
ARG IMAGE=intersystemsdc/iris-community:2020.1.0.209.0-zpm
ARG IMAGE=intersystemsdc/iris-community:2020.2.0.196.0-zpm
FROM $IMAGE

USER root

WORKDIR /opt/irisapp
RUN chown ${ISC_PACKAGE_MGRUSER}:${ISC_PACKAGE_IRISGROUP} /opt/irisapp
COPY irissession.sh /
RUN chmod +x /irissession.sh 

USER irisowner

COPY  Installer.cls .
COPY  %REST.Parameter.cls .
COPY  src src
SHELL ["/irissession.sh"]

RUN \
  Set ns = $namespace \
  zn "%SYS" \
  Set irislibdir = "/usr/irissys/mgr/irislib/" \
  Set db=##Class(SYS.Database).%OpenId(irislibdir) \
  Set db.ReadOnly = 0 \
  Do db.%Save() \
  Kill db \
  Set sc = $SYSTEM.OBJ.Load("%REST.Parameter.cls", "ck") \
  Write "Install fix REST ",$SYSTEM.Status.GetOneErrorText(sc) \
  Set db=##Class(SYS.Database).%OpenId(irislibdir) \
  Set db.ReadOnly = 1 \
  Do db.%Save() \
  zn ns \
  do $SYSTEM.OBJ.Load("Installer.cls", "ck") \
  set sc = ##class(App.Installer).setup() 
# bringing the standard shell back
SHELL ["/bin/bash", "-c"]