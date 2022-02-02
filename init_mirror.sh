#!/bin/bash

# Mirror configuration file in json config-api format for the master node.
MASTER_CONFIG=/opt/demo/mirror-master.json

# The mirror name...
MIRROR_NAME=DEMO

# Mirror Member list.
MIRROR_MEMBERS=BACKUP,REPORT

# PKI Server host:port (PKI Server is installed on master instance)
PKISERVER=master:52773

# Performed on the master.
# Configure Public Key Infrastructure Server on this instance and generate certificate in order to configure a mirror using SSL.
#   See article https://community.intersystems.com/post/creating-ssl-enabled-mirror-intersystems-iris-using-public-key-infrastructure-pki
#   and the related tools https://openexchange.intersystems.com/package/PKI-Script
# Load the mirror configuration using config-api with /opt/demo/simple-config.json file.
# Start a Job to auto-accept other members named "backup" and "report" to join the mirror (avoid manuel validation in portal management).
master() {
iris session $ISC_PACKAGE_INSTANCENAME -U %SYS <<- END
Do ##class(lscalese.pki.Utils).MirrorMaster(,"",,,,"${MIRROR_MEMBERS}")
Set sc = ##class(Api.Config.Services.Loader).Load("${MASTER_CONFIG}")
Set ^log.mirrorconfig(\$i(^log.mirrorconfig)) = \$SYSTEM.Status.GetOneErrorText(sc)
Hang 2
Halt
END
}

master

exit 0