#!/bin/bash
# Copyright (c) 2009 & onwards. MapR Tech, Inc., All rights reserved

INSTALL_DIR=${MAPR_HOME:=/opt/mapr}
ROLES="${INSTALL_DIR}/roles"
ZK_INSTALL_DIR="${INSTALL_DIR}/zookeeper"
logFile="${INSTALL_DIR}/logs/configure.log"
# MapR config files
mfsConf="${INSTALL_DIR}/conf/mfs.conf"
cldbConf="${INSTALL_DIR}/conf/cldb.conf"
cldbLog4j="${INSTALL_DIR}/conf/log4j.cldb.properties"
uiConf="${INSTALL_DIR}/conf/web.conf"
wardenConf="${INSTALL_DIR}/conf/warden.conf"
nfsConf="${INSTALL_DIR}/conf/nfsserver.conf"
clusterConf="${INSTALL_DIR}/conf/mapr-clusters.conf"
drillBase="${INSTALL_DIR}/drill"
hadoopBase="${INSTALL_DIR}/hadoop"
hbaseBase="${INSTALL_DIR}/hbase"
DBConf="${INSTALL_DIR}/conf/db.conf"
hibernateConf="${INSTALL_DIR}/conf/hibernate.cfg.xml"
DAEMON_CONF="${INSTALL_DIR}/conf/daemon.conf"
cldbKey="${INSTALL_DIR}/conf/cldb.key"
serverTkt="${INSTALL_DIR}/conf/maprserverticket"
maprCli="${INSTALL_DIR}/bin/maprcli"
manageSslKeys="${INSTALL_DIR}/server/manageSSLKeys.sh"
hmrConf=

oldConf="${INSTALL_DIR}/conf/conf.old"
oldWardenConf="${oldConf}/warden.conf"
oldClusterConf="${oldConf}/mapr-clusters.conf"
oldDBConf="${oldConf}/db.conf"
oldHibernateConf="${oldConf}/hibernate.cfg.xml"

# Non-mapr config files - depends on node roles

# Variables
diskList="" # The diskList passed in by -D
diskFile="" # The disk file used for disksetup. Generate from diskList or specified by -F
diskOpts="F"
dbConnect=
dbUser=
dbPassword=
dbSchema=
hadoop=2
hadoopVersionExplicit=""
buildOozie=""
# Resource Manager IP
rm_ip=
hs_ip=

# Set by setHadoopVersion in configure-common.sh
hadoopVersion=

# Set by setHadoopConfDir in configure-common.sh
hadoopConfDir=

cldbNodesList=""
zkNodesList=""
zkClientPort=
clusterName="my.cluster.com"
cldbPort=
roles=""
ZK_INTERNAL_BASE=""
ZK_SERVERS=""
space=" "
zkNodesCount=0
localKvStorePort=5660
jtPort=9001
cldbDefaultPort=7222
cldbJmxRemotePort=7220
zkDefaultPort=5181
takenPorts="7221 5660"
isOnlyRoles=0
# Calculated later
currentIP=

nfsNodeOn=0
fsNodeOn=0
cldbNodeOn=0
ttNodeOn=0
oozieNodeOn=0
drillBitsNodeOn=0
hbRsNodeOn=0
hbMsNodeOn=0
hbINodeOn=0
jtNodeOn=0
wsNodeOn=0
zkNodeOn=0
jmRoleOn=0
impalaServerRoleOn=0
clientOnly=0
force=0
isMyCluster=1
genKeys=0
noCerts=0
certDomain=""
isDB=1
setDB=0
autoStart=1
sysChk=
promptStyle="p"
verboseOn=0
isMemAllocationChanged=0
dontChangeSecurityPermissionsOn=0

runDiskSetup=0 # Boolean to run disksetup or not (will not run if diskList and diskFile are not defined). If 1, disksetup will run
removeDiskListFile=0 # Boolean to remove disk file if the one being used is the auto generated one. Default will not remove
rebuildOozie=false

isSecure=
cldbHttpsPort=""
cldbPrincipal=""
kerberosEnable=0


# Function that returns 0 if ip addr command is available or 1 to use ifconfig
function GetIpAddrMethod() {
ip addr &> /dev/null

if [ "$?" == "0" ]; then
    echo "0"
else
    echo "1"
fi
}

function SetCurrentIP() {
# Check if ip addr command exists
if [ "$(GetIpAddrMethod)" == "0" ]; then
    currentIP=$(ip addr | grep 'inet ' | sed -e 's/^.*inet //' -e 's/[\/ ].*//' -e '/127.0.0.1/d' | head -1)
else
    # Use ifconfig
    currentIP=$(ifconfig | grep 'inet addr:'  | sed -e 's/^.*inet addr://' -e 's/ .*//' -e '/127.0.0.1/d' | head -1)
fi

}

# Function to start zookeeper and warden
function StartCluster() {
    # Check if autostart flag is given. If not, then return and print message to let user know to start their cluster
    if [ $autoStart -ne 1 ]; then
        if [ $clientOnly -eq 0 -a "${isOnlyRoles:-}" -eq 0 ]; then
            logInfo "Node not starting automatically."
            if [ $zkNodeOn -ne 0 ]; then
                echo "Run \"service mapr-zookeeper start\" in order to start the zookeeper node and then run \"service mapr-warden start\" in order to start this node"
            else
                echo "Run \"service mapr-warden start\" in order to start this node"
            fi
        fi
        return;
    fi
    if [ ! -f /opt/mapr/conf/disktab ]; then
        if [ $clientOnly -eq 0 ]; then
            logInfo "No /opt/mapr/conf/disktab file, not starting cluster automatically"
            logInfo "Run /opt/mapr/server/disksetup manually"
            return;
        fi
    fi

    # Check if zookeeper exists and not running
    if [ $zkNodeOn -ne 0 ]; then
        if [ `/etc/init.d/mapr-zookeeper status 2> /dev/null | grep "not running" | wc -l` -ne 0 ]; then
            # Start zookeeper
            echo "Zookeeper found on this node, and it is not running. Starting Zookeeper"
            service mapr-zookeeper start
            logInfo "Zookeeper started."

            # Add mapr-zookeeper to inittab
            # Check if mapr-zookeeper already respawning in inittab
            if [ `grep ":respawn:/etc/init.d/mapr-zookeeper" /etc/inittab 2> /dev/null | wc -l` -eq 0 ]; then
                echo "Zookeeper respawn not found in inittab. Adding entry."
                # Iterate through letters and integers to find an ID
                stop_iter=0
                for letter in {a..z}; do
                    for integer in {1..9}; do
                        # Verify that the given ID does not exist in inittab already
                        if [ `grep "^$letter$integer:" /etc/inittab 2> /dev/null | wc -l` -eq 0 ]; then
                            # Add new id and mapr-zookeeper start in inittab
                            echo "Creating zookeeper respawn in inittab with ID of \"$letter$integer\""
                            logInfo "Adding \"$letter$integer:234:respawn:/etc/init.d/mapr-zookeeper\" to \"/etc/inittab\""
                            echo "# Added from configure.sh: respawn mapr-zookeeper" >> /etc/inittab
                            echo "$letter$integer:234:respawn:/etc/init.d/mapr-zookeeper" >> /etc/inittab
                            stop_iter=1
                            break
                        fi
                    done
                    if [ $stop_iter -eq 1 ]; then
                        break
                    fi
                done
            fi


        else
            logInfo "Zookeeper found and already running. Not starting zookeeper."
        fi
    fi
    # Check if warden is not running (assumed warden is always installed)
    if [ `/etc/init.d/mapr-warden status 2> /dev/null | grep "WARDEN running as proces" | wc -l` -eq 0 ]; then
        echo "Warden is not running. Starting mapr-warden. Warden will then start all other configured services on this node"
        service mapr-warden start
        logInfo "Warden started."

        # Add mapr-warden to inittab
        # Check if mapr-warden already respawning in inittab
        if [ `grep ":respawn:/etc/init.d/mapr-warden" /etc/inittab 2> /dev/null | wc -l` -eq 0 ]; then
            echo "Warden respawn not found in inittab. Adding entry."
            # Iterate through letters and integers to find an ID
            stop_iter=0
            for letter in {a..z}; do
                for integer in {1..9}; do
                    # Verify that the given ID does not exist in inittab already
                    if [ `grep "^$letter$integer:" /etc/inittab 2> /dev/null | wc -l` -eq 0 ]; then
                        # Add new id and mapr-warden start in inittab
                        echo "Creating warden respawn in inittab with ID of \"$letter$integer\""
                        logInfo "Adding \"$letter$integer:234:respawn:/etc/init.d/mapr-warden\" to \"/etc/inittab\""
                        echo "# Added from configure.sh: respawn mapr-warden" >> /etc/inittab
                        echo "$letter$integer:234:respawn:/etc/init.d/mapr-warden" >> /etc/inittab
                        stop_iter=1
                        break
                    fi
                done
                if [ $stop_iter -eq 1 ]; then
                    break
                fi
            done
        fi

        WEB_SERVER_HOST="{webserver host name}"

        for service in $(ls "$ROLES"); do
            if [ $service == "kvstore" ]; then
                echo "... Starting fileserver"
            else
                if [ $service == "webserver" ]; then
                    WEB_SERVER_HOST=`hostname`
                fi
                # Do not show zookeeper role
                if [ $service != "zookeeper" ]; then
                    echo "... Starting $service"
                fi
            fi
        done


        echo "To further manage the system, use \"maprcli\", or connect browser to https://${WEB_SERVER_HOST}:8443/"
        echo "To stop and start this node, use \"service mapr-warden stop/start\""
    else
        logInfo "Warden is already running. Not starting warden."
    fi

}
function ConfigureSysChecks() {

if [ "$sysChk" == "n" ]; then
    # Do not add sys checks if user specified n
    logInfo "Removing system checks"
    ${MAPR_HOME}/support/tools/syscheck/syscheck.sh uninstall -u ${MAPR_USER} all >> $logFile
    return
fi



# Check if user specified y to enable system checks
if [ "$sysChk" != "y" ]; then
    # Return early and do not add system checks
    return
fi

logInfo "Adding system checks to run every minute"
${MAPR_HOME}/support/tools/syscheck/syscheck.sh install -u ${MAPR_USER} all >> $logFile
}

function SortList() {
    eval $1=`echo ${!1} | tr , "\n" | sort | tr "\n" , | sed 's@,$@@'`
}

# Function to setup disks
# Uses diskList or diskFile variables (which are populated by user parameters -D and -F respectively)
function SetupDisksFile() {
    # The current disk file to use. 
    if [ ! -z $diskList ]; then
        # Disk list specified by user (-D)
        diskFile="/tmp/$$-disklist.txt"
        logInfo "Generating disklist file at: $diskFile with the following disks $diskList"
        runDiskSetup=1
        IFS=',' read -ra ADDR <<< "$diskList"
        for i in "${ADDR[@]}"; do
            echo $i >> $diskFile
        done
        # Remove disk file. Disk file is auto generated
        removeDiskListFile=1
    fi
    if [ ! -z $diskFile ]; then
        # Disk file specified by user (-F)
        logInfo "Using disklist file $diskFile"
        runDiskSetup=1
    fi
}

# Function to actually perform the disksetup
# Uses $diskFileto pass to disksetup
function RunDiskSetup() {
    ret=0
    if [ $runDiskSetup -ne 0 ]; then
        # Run disk setup
        logInfo "Running disksetup: \"/opt/mapr/server/disksetup -$diskOpts $diskFile\""
        # Run with options
        /opt/mapr/server/disksetup -$diskOpts $diskFile
        ret=$?
        # Run cleanup automatically
        CleanupDiskFile
    else 
        # Disksetup not run
        logInfo "Disksetup NOT run (-F or -D options not provided). Please run /opt/mapr/server/disksetup manually"
    fi
    return $ret
}

# Does cleanup on disk file if it was generated by configure.sh
# Checks $removeDiskListFile to not be 0 to remove disk file
function CleanupDiskFile() {
    if [ $removeDiskListFile -ne 0 ]; then
        # Remove temp file
        logInfo "Removing temporary disklist file: $diskFile"
        rm $diskFile
    fi
}

# Does a check of the given directory
# Verifies that the argument passed in has more than 1GB disk space
function CheckDiskSpace() {
    mem=`df -Pm $1 | tail -1 | awk '{print $4}'`
    requiredMem=1024
    logInfo "Checking if Diskspace is on \"$1\" is greater than $requiredMem MB"
    if [ $mem -lt $requiredMem ]; then
        echo "Not enough disk space on \"$1\". Required disk space is at least $requiredMem MB and \"$1\" has only $mem MB";
        PromptUserOnError
    else
        logInfo "Diskspace on \"$1\" is $mem MB. Passed."
    fi
}

# Does a check on each disk listed in the given diskFile
function CheckDiskFile() {
    # Only run check if diskFile is set
    # Checks for disk parameters should have been done already
    if [ ! -z $diskFile ]; then
        if [ ! -f $diskFile ]; then
            logErr "DiskList file \"$diskFile\" does not exist!"
            echo "Error: disklist file \"$diskFile\" does not exist"
            ExitSingleInstance 1
        fi
        # Failure variable. If 1 then there is a failure
        fail=0
        # Iterate through each disk (each one separated by space or newline)
        while IFS=' ' read -ra ADDR; do
            for disk in "${ADDR[@]}"; do
                # Check if disk exists
                logInfo "Checking if \"$disk\" exists"
                diskExists=`fdisk -l $disk 2>&1 | wc -l`
                if [ $diskExists -lt 1 ]; then
                    fail=1
                    echo "$disk does not exist"
                    logErr "\"$disk\" not found!"
                fi
                # Check if disk is in disktab if it exist
                if [ -f /opt/mapr/conf/disktab ]; then
                    if [ `grep "^$disk " /opt/mapr/conf/disktab | wc -l` -ne 0 ]; then
                        echo "$disk is already being used on node. (Entity exists in \"/opt/mapr/conf/disktab\")"
                        logErr "$disk is already being used on node. (Entity exists in \"/opt/mapr/conf/disktab\")"
                        ExitSingleInstance 1
                    fi
                fi
            done
        done < $diskFile
        if [ $fail -ne 0 ]; then
            PromptUserOnError
        else
            logInfo "All disks exist."
        fi
    fi
}

# Check if the ram on the given machine is greater than 4GB
function CheckMem() {
    # Get ram amount
    memKb=$(expr `cat /proc/meminfo | grep "MemTotal" | awk '{print $2}'` / 1024)
    if [ "x${memNeeded}" = "x" ]; then
      memNeeded=1900
    fi
    tmpWardenConf="/tmp/warden.conf"
    logInfo "Checking if system has at least $memNeeded MB of memory."
    if [ $memKb -lt $memNeeded ]; then
        echo "Not enough memory. System only has $memKb MB. Required memory is $memNeeded MB"
        PromptUserOnError
        # If code reached this point, then user pressed yes. Add enable overcommit to warden.conf
        if [ -f $wardenConf ]; then
            if [ `grep "enable\.overcommit=" $wardenConf | wc -l` -eq 0 ]; then
                cat $wardenConf > $tmpWardenConf
                echo "enable.overcommit=true" >> $tmpWardenConf;
                echo "1"
                mv $tmpWardenConf $wardenConf
            fi
        fi
    else
        logInfo "System has enough memory: $memKb MB"
    fi
}




function ConfigureRoles() {
  ConfigureHadoop
  UpdateFileClientConfig
  if [ "x$zkNodesList" != "x" ]; then
    ConfigureZKRole
  fi
  ConfigureCLDBRole
  ConfigureNFSRole
  ConfigureWSRole

  ConfigureJTRole
  ConfigureTTRole

  ConfigureDrillBitsRole
  ConfigureHBMRole
  ConfigureHBRRole
  ConfigureHBIRole
  ConfigureJMRole
  ConfigureOozieRole

  if [ $clientOnly -eq 0 -a -f $wardenConf ]; then
    UpdateWardenConfig
  fi
}

function ValidateSecurityArgsAndFiles() {
  if [ "${isSecure:-}" != "true" -o $clientOnly -eq 1 ] ; then
    return 0
  fi
  
  if [ "$genKeys" -eq 1 -a "$cldbNodeOn" -ne 1 ]; then
    logErr "ERROR: -genkeys should be run on first cldb node only"
    echo "ERROR: -genkeys should be run on first cldb node only"
    return 1
  fi

  if [ "$genKeys" -eq 1 ]; then
    if [ -f $cldbKey ]; then
      logErr "ERROR: cldb key file '$cldbKey' is already available."
      echo "ERROR: cldb key file '$cldbKey' is already available."
      return 1
    fi
    
    if [ -f $serverTkt ]; then
      logErr "ERROR: server ticket file '$serverTkt' is already available."
      echo "ERROR: server ticket file '$serverTkt' is already available."
      return 1
    fi
  else 
    #security is on, but not generating keys, confirm there
    if [ "$cldbNodeOn" -eq 1 -a ! -f $cldbKey ]; then
      logErr "ERROR: cldb key file '$cldbKey' is not available."
      echo "ERROR: cldb key file '$cldbKey' is not available."
      return 1
    fi
 
    if [ ! -f $serverTkt ]; then
      logErr "ERROR: server ticket file '$serverTkt' is not available."
      echo "ERROR: server ticket file '$serverTkt' is not available."
      return 1
    fi

    ConfirmSslKeys
    if [ $? -ne 0 ]; then
       return 1
    fi
  fi
  return 0
}

function ConfigureJMRole() {
  if [ "$jmRoleOn" -ne 1 ]; then
    logInfo "Skipping Job Management Role configuration... Metrics not found"
    return
  fi

  ConfigureJMHadoopProperties "${INSTALL_DIR}/conf/hadoop-metrics.properties"

  # need to update db.conf and if webserver role on then hibernate.cfg.xml
  # substitute corresponding params in those 3 files
  if [ ! -f "$DBConf" ]; then
    echo "ERROR: Can not find $dbConf file. Data will not be collected correctly from this node"
    logErr " Can not find $dbConf file. Data will not be collected correctly from this node"
    return 1
  fi
  now=`date +%Y-%m-%d.%H-%M`
  # save copy of db.conf and proceed
  cp -Rp $DBConf "$oldDBConf"."$now"
  if [ "$dbConnect"x != "x" ]; then
    grep "db.url=" $DBConf > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
      # insert
      logInfo "Adding \"db.url=$dbConnect\" to \"$DBConf\""
      echo "db.url=$dbConnect" >> $DBConf
    else 
      # update
      sed -i -e 's/db.url=.*$/db.url='$dbConnect'/g' $DBConf
    fi
  else
      dbUrl=`grep "^db.url=" "${DBConf:-}" | cut -d = -f 2 2> /dev/null`
      if [ -z "${dbUrl:-}" ]; then
          echo "WARN: as mapr-metrics package is installed and no DB connect URL is specified. Data may not be flowing to DB from this node"
          logErr " as mapr-metrics package is installed and no DB connect URL is specified. Data may not be flowing to DB from this node"
      fi
  fi

  if [ "$dbUser"x != "x" ]; then
    grep "db.user=" $DBConf > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
      # insert
      logInfo "Adding \"db.user=$dbUser\" to \"$DBConf\""
      echo "db.user=$dbUser" >> $DBConf
    else
      #update
      sed -i -e 's/db.user=.*$/db.user='$dbUser'/g' $DBConf
    fi
  fi
  if [ "$dbPassword"x != "x" ]; then
    grep "db.passwd=" $DBConf > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
      # insert
      logInfo "Adding \"db.passwd=$dbPassword\" to \"$DBConf\""
      echo "db.passwd=$dbPassword" >> $DBConf
    else
      # update
      sed -i -e 's/db.passwd=.*$/db.passwd='$dbPassword'/g' $DBConf
    fi
  fi
  if [ "$dbSchema"x != "x" ]; then
    grep "db.schema=" $DBConf > /dev/null 2>&1
    if [ "$?" -ne 0 ]; then
      # insert
      logInfo "Adding \"db.schema=$dbSchema\" to \"$DBConf\""
      echo "db.schema=$dbSchema" >> $DBConf
    else
      # update
      sed -i -e 's/db.schema=.*$/db.schema='$dbSchema'/g' $DBConf
    fi
  fi

  grep "db.driverclass=" $DBConf > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    #insert
    logInfo "Adding \"db.driverclass=com.mysql.jdbc.Driver\" to \"$DBConf\""
    echo "db.driverclass=com.mysql.jdbc.Driver" >> $DBConf
  else
    #update
    sed -i -e 's/db.driverclass=.*$/db.driverclass=com.mysql.jdbc.Driver/g' $DBConf
  fi

  if [ "$wsNodeOn" -eq 1 ]; then
    cp -Rp $hibernateConf "$oldHibernateConf"."$now"
    # this is webserver configured node. Need to configure hibernate.cfg.xml
    if [ "$dbConnect"x != "x" ]; then
      sed -i -e 's/jdbc:mysql:\/\/.*[0-9]\//jdbc:mysql:\/\/'$dbConnect'\//' $hibernateConf 
    fi
    if [ "$dbUser"x != "x" ]; then
      sed -i -e 's/"connection.username">.*</"connection.username">'$dbUser'</' $hibernateConf 
    fi
    if [ "$dbPassword"x != "x" ]; then
      sed -i -e 's/"connection.password">.*</"connection.password">'$dbPassword'</' $hibernateConf
    fi
    if [ "$dbSchema"x != "x" -a "$dbConnect"x != "x" ];then
      sed -i -e 's/'$dbConnect'\/.*<\/property>/'$dbConnect'\/'$dbSchema'<\/property>/' $hibernateConf
    fi
  fi

	ConfigureRunUserForJM $MAPR_USER
}

function ConfigureZKRole() {
  if [ "$zkNodeOn" -ne 1 ]; then
     logInfo "Skipping ZooKeeper Role configuration... Not found"
     return
  fi 
  # Redo myid and zoo.cfg with passed set of zk nodes
  # pending verification that changing number in "myid" won't screw things around

  # this sets zk_config
  GetZKConfigPath
  now=`date +%Y-%m-%d.%H-%M`
  nowPerm="$now"
  if [ -f "$zk_config" ]; then
     cp -Rp "$zk_config" "$zk_config"."$nowPerm"     
     cat "$zk_config" | sed '/^server\.[0-9]\+=/d' > "$zk_config"$$
     mv "$zk_config"$$ "$zk_config"
  fi
  
  dataDir=`cat $zk_config | grep "dataDir" | sed 's/dataDir=//'`
  clientPort=`cat $zk_config | grep "clientPort" | sed 's/clientPort=//'`
  if [ "$zkNodesCount" -gt 1 ]; then
    k=0
    isCurrentZK=0
    for i in `echo $ZK_INTERNAL_BASE`
    do
      zkServer=`echo $i | awk -F":" '{print $1}'`
      zkPort=`echo $i | awk -F":" '{print $2}'`
      ZK_SERVER=`echo server.`
      ZK_SERVER="$ZK_SERVER""$k"`echo =`
      ZK_SERVER="$ZK_SERVER""$zkServer"`echo :2888:3888`
      echo $ZK_SERVER >> $zk_config
      # find who I am here
      isItMe $zkServer
      if [ "$?" == "0" ]; then
        isCurrentZK=1
        # produce myid
        echo $k > $dataDir"/myid"
        if [ "$clientPort" != "$zkPort" ]; then
          sed -i -e 's/clientPort=.*/clientPort='$zkPort'/' $zk_config
        fi
      fi   
      k=`expr $k + 1`
    done
    if [ "$isCurrentZK" == "0" ]; then
      echo "ERROR: Cannot find matching ZK node IP based on provided input: " $zkNodesList
      echo "ERROR: mapr-zookeeper was installed on the current node, but was not included in "
      echo "ERROR: the list of zookeeper nodes. To continuse, either include the current node"
      echo "ERROR: in the -Z list option or uninstall the mapr-zookeeper package."

      logErr "Cannot find matching ZK node IP based on provided input: " $zkNodesList
      logErr "mapr-zookeeper was installed on the current node, but was not included in "
      logErr "the list of zookeeper nodes. To continuse, either include the current node"
      logErr "in the -Z list option or uninstall the mapr-zookeeper package."

      # restore original file
      cp -Rp "$zk_config"."$nowPerm" "$zk_config"
      ExitSingleInstance 1
    fi
  else
    # if there was myid file from before - we are reducing numbr of zks - need to remove it
    if [ -f "${dataDir}"/myid ]; then
      rm "${dataDir}"/myid 
    fi
    zkPort=`echo $ZK_INTERNAL_BASE | awk -F":" '{print $2}'`
    if [ "$clientPort" != "$zkPort" ]; then
      sed -i -e 's/clientPort=.*/clientPort='$zkPort'/' $zk_config
    fi
  fi

  grep "superUser=" $zk_config > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    #insert
    echo "superUser=$MAPR_USER" >> $zk_config
  else
    sed -i -e 's/superUser=.*$/superUser='$MAPR_USER'/g' $zk_config
  fi

  # deal with security setting
  if [ "${isSecure:-}" = "true" ]; then
    # set authMech=MAPR-SECURITY
    grep "^authMech=" $zk_config > /dev/null 2>&1
    if [ "$?" -eq 0 ]; then
      sed -i -e 's/authMech=.*$/authMech=MAPR-SECURITY/g' $zk_config
    fi 
  else
    # set authMech=SIMPLE-SECURITY
    grep "^authMech=" $zk_config > /dev/null 2>&1
    if [ "$?" -eq 0 ]; then
      sed -i -e 's/authMech=.*$/authMech=SIMPLE-SECURITY/g' $zk_config
    fi
  fi
  ConfigureRunUserForZKRole
}

function isItMe() {
  # check hostname, hostname -f, ip addr

  hostOut=$(gethostip -d $1)
  if [ $? -eq 0 ]; then
      toGrepFor=$hostOut
  else
      toGrepFor=$1
  fi

  if [ "$(GetIpAddrMethod)" == "0" ]; then
      ip addr | grep 'inet ' | tr -s ' ' | cut -d' ' -f3 | cut -d'/' -f1 | grep -w $toGrepFor > /dev/null 2>&1
  else
      ifconfig  | grep -w "inet" | tr -s ' ' | cut -d' ' -f3 | cut -d: -f2 | grep -w $toGrepFor > /dev/null 2>&1
  fi

  if [ "$?" -eq 0 ]; then
     return 0
  fi
  hostname --fqdn | grep $1 > /dev/null 2>&1
  return $?
}

function UpdateAuditLogger() {
  if [ -f "$cldbLog4j" ]; then
    grep "cldb.audit.logger" $cldbLog4j > /dev/null 2>&1

    if [ "$?" -ne 0 ]; then
      # audit information is not present in cldb log4j
      echo "" >> $cldbLog4j
      echo "# CLDB audit logging" >> $cldbLog4j
      echo "cldb.audit.logger=INFO,CADRFA" >> $cldbLog4j
      echo "cldb.audit.file=/tmp/cldbaudit.log.json" >> $cldbLog4j
      echo "log4j.appender.CADRFA=org.apache.log4j.MaprfsDailyRollingUTCAppender" >> $cldbLog4j
      echo "log4j.appender.CADRFA.Append=true" >> $cldbLog4j
      echo "log4j.appender.CADRFA.File=\${cldb.audit.file}" >> $cldbLog4j
      echo "log4j.appender.CADRFA.layout=com.mapr.log4j.NoFormatLayout" >> $cldbLog4j
      echo "log4j.category.AuditLogger=\${cldb.audit.logger}" >> $cldbLog4j
      echo "log4j.additivity.AuditLogger=false" >> $cldbLog4j
    fi
  fi
}

function ConstructMapRClustersConfFile() {
  if [ -f "$clusterConf" ]; then
     # file exists - need add there
     # first save copy
     now=`date +%Y-%m-%d.%H-%M`
     cp -Rp "$clusterConf" "$oldClusterConf"."$now"
  else
    touch $clusterConf
  fi
  chmod go+r $clusterConf

  cluster="${clusterName} secure=${isSecure}"
  if [ "$kerberosEnable" -eq 1 ]; then
    cluster="${cluster} kerberosEnable=true"
  fi
  if [ x"${cldbPrincipal}" != x"" ]; then
    cluster="${cluster} cldbPrincipal=${cldbPrincipal}"
  fi
  if [ x"${cldbHttpsPort}" != x"" ]; then
    cluster="${cluster} cldbHttpsPort=${cldbHttpsPort}"
  fi

  arr=$(echo $cldbNodesList | tr "," " ")
  logInfo "Contructing ClusterConfFile: cldb node list: ${arr[@]}"
  for i in $arr
  do 
    cluster="${cluster} ${i}"
  done
    cat $clusterConf | grep "^\<${clusterName}\>" > /dev/null 2>&1
    if [ $? == 0 ]; then
       # file exists, default line exists, replace it
       sed -i -e "s%^\<${clusterName}\>.*$%${cluster}%" $clusterConf
    else 
       logInfo "Adding \"${cluster}\" to \"$clusterConf\""
       echo "${cluster}" >> $clusterConf
    fi
  clusterLine=$(grep -n "^\<${clusterName}\>" ${clusterConf} | cut -d: -f1)
  if [ -n $clusterLine -a $clusterLine -gt 1 ]; then
    isMyCluster=0
  fi

  logInfo "Contructing ClusterConfFile: Done"
}

function GenerateCldbKey() {
  logInfo "Generating cldb key"
  $maprCli security genkey -keyfile $cldbKey 2>> $logFile
  if [ "$?" -ne 0 ]; then
    logErr "ERROR: could not generate cldb key $cldbKey."
    echo "ERROR: could not generate cldb key $cldbKey. See log file for more details."
    return 1
  fi
  chmod 600 $cldbKey
  chown $MAPR_USER:$MAPR_GROUP $cldbKey
}

function GenerateServerTicket() {
  logInfo "Generating server ticket"
  uid=`id -u $MAPR_USER`
  gid=`id -g $MAPR_USER`
  $maprCli security genticket -inkeyfile $cldbKey -ticketfile $serverTkt -cluster $clusterName -maprusername $MAPR_USER -mapruid $uid -maprgid $gid 2>> $logFile
  if [ "$?" -ne 0 ]; then
    logErr "ERROR: could not generate server key $serverTkt"
    echo "ERROR: could not generate server key $serverTkt. See log file for more details"
    return 1
  fi
  chmod 600 $serverTkt
  chown $MAPR_USER:$MAPR_GROUP $serverTkt
}

function ConfirmSslKeys() {
  if [ ! -r ${INSTALL_DIR}/conf/ssl_keystore ]; then
    logErr "ERROR: Required ssl_keystore not present. Please copy from first CLDB. "
    echo "ERROR: Required ssl_keystore not present. Please copy from first CLDB. "
    return 1 
  fi

  if [ ! -r ${INSTALL_DIR}/conf/ssl_truststore ]; then
    logErr "ERROR: Required ssl_truststore not present. Please copy from first CLDB. "
    echo "ERROR: Required ssl_truststore not present. Please copy from first CLDB. "
    return 1 
  fi
}


#Generate needed keys. These are used by all of the Web UIs when security is
#enabled. The MCS uses these keys with or without security.

function GenerateSslKeys() {
  if [ "$noCerts" -ne 0 ]; then
      echo "Certificates in ssl_keystore and ssl_truststore not generated. You must provide."
      logInfo "Certificates in ssl_keystore and ssl_truststore not generated. You must provide."
     return 0
  fi

  logInfo "Generating ssl keys"
  
  if [ x"$certDomain" != x"" ]; then
    certArg="-d $certDomain"
  fi

  $manageSslKeys create -N $clusterName $certArg -ug $MAPR_USER:$MAPR_GROUP 2>> $logFile
  if [ "$?" -ne 0 ]; then
    logErr "ERROR: could not generate ssl keys "
    echo "ERROR: could not generate ssl keys. See log file for more details"
    return 1
  fi
  logInfo "SSL keys succefully generated"
}

function ConfigureCLDBRole() {
   if [ "$cldbNodeOn" -ne 1 ]; then
     logInfo "Skipping CLDB Role configuration... Not found"
     return
  fi
  
  if [ "$genKeys" -eq 1 ]; then
    GenerateCldbKey
    if [ "$?" -ne 0 ]; then
      ExitSingleInstance 1 
    fi
    logInfo "cldb key $cldbKey is succefully generated"

    GenerateServerTicket
    if [ "$?" -ne 0 ]; then
      ExitSingleInstance 1 
    fi
    logInfo "server ticket $serverTkt is succefully generated"

    if [ "$noCerts" -ne 1 ]; then
      GenerateSslKeys
      if [ "$?" -ne 0 ]; then
        ExitSingleInstance 1 
      fi
    fi 
   
  fi

   localKvStoreIpPort=${currentIP}:${localKvStorePort}
   cldb_zk_servers="cldb.zookeeper.servers"
  sed -i -e 's/^.*'${cldb_zk_servers}'=.*/'${cldb_zk_servers}'='$zkNodesList'/g' $cldbConf

  cldb_kvstore_local="cldb.kvstore.local"
  sed -i -e 's/^.*'${cldb_kvstore_local}'=.*/'${cldb_kvstore_local}'='${localKvStoreIpPort}'/g' $cldbConf

  cldb_port="cldb.port"
  sed -i -e 's/^.*'${cldb_port}'=.*/'${cldb_port}'='${cldbPort}'/g' $cldbConf

  hadoop_version="hadoop.version"
  sed -i -e 's/^.*'${hadoop_version}'=.*/'${hadoop_version}'='${hadoopVersion}'/g' $cldbConf

  cldb_remote_jmx_port="cldb.jmxremote.port"
  sed -i -e 's/^.*'${cldb_remote_jmx_port}'=.*/'${cldb_remote_jmx_port}'='${cldbJmxRemotePort}'/g' $cldbConf

  mfs_cache_lru_sizes="mfs.cache.lru.sizes"
  if [ "$isDB" == "1" ]; then
    mfs_lru_default_sizes="inode:3:meta:6:small:27:dir:6:db:20:valc:3"
    mfs_lru_sizes_for_cldb="inode:10:meta:10:dir:30:small:10:db:15:valc:3"
  else
    mfs_lru_default_sizes="inode:3:meta:6:small:27:dir:6:db:0:valc:0"
    mfs_lru_sizes_for_cldb="inode:10:meta:10:dir:40:small:15:db:0:valc:0"
  fi
  grep "^\s*${mfs_cache_lru_sizes}=" $mfsConf > /dev/null 2>&1
  if [ $? == 0 ]; then
      sed -i -e 's/^\s*'${mfs_cache_lru_sizes}'=.*/'${mfs_cache_lru_sizes}'='${mfs_lru_sizes_for_cldb}'/g' $mfsConf
  else
    logInfo "Adding: \"${mfs_cache_lru_sizes}=${mfs_lru_sizes_for_cldb}\" to \"$mfsConf\""
    echo "${mfs_cache_lru_sizes}=${mfs_lru_sizes_for_cldb}" >> $mfsConf
  fi

  grep "^\s*#\s*${mfs_cache_lru_sizes}=" $mfsConf > /dev/null 2>&1
  if [ $? == 0 ]; then
      # Use double quotes instead of single quotes to handle # symbol in the regex
      sed -i -e "s/^\s*#\s*${mfs_cache_lru_sizes}=.*/#${mfs_cache_lru_sizes}=${mfs_lru_default_sizes}/g" $mfsConf
  else
    logInfo "Adding: \"#${mfs_cache_lru_sizes}=${mfs_lru_default_sizes}\" to \"$mfsConf\""
    echo "#${mfs_cache_lru_sizes}=${mfs_lru_default_sizes}" >> $mfsConf
  fi
  
  mfs_is_virtual_machine="mfs.on.virtual.machine"
  grep "${mfs_is_virtual_machine}=" $mfsConf > /dev/null 2>&1
  if [ $? == 0 ]; then
    sed -i -e 's/^.*'$mfs_is_virtual_machine'=.*/'$mfs_is_virtual_machine'='$isVM'/g' $mfsConf
  else
    logInfo "Adding: \"$mfs_is_virtual_machine=$isVM\" to \"$mfsConf\""
    echo "$mfs_is_virtual_machine=$isVM" >> $mfsConf
  fi
  
  local maprLoginConf=${INSTALL_DIR}/conf/mapr.login.conf
  if [ -f ${maprLoginConf} ]; then
    grep "SUBSTITUTE_CLUSTER_NAME_HERE" ${maprLoginConf} > /dev/null 2>&1
    if [ $? == 0 ]; then
      sed -i -e 's/SUBSTITUTE_CLUSTER_NAME_HERE/'${clusterName}'/g' $maprLoginConf
    fi
    if [ "${cldbPrincipal}" != "" -a $isOnlyRoles -ne 1 ]; then
      grep "principal=\"mapr/" ${maprLoginConf} > /dev/null 2>&1
      if [ $? == 0 ]; then
        sed -i -e 's/principal=\"mapr\/.*/principal=\"mapr\/'${cldbPrincipal}'\"/g' $maprLoginConf
      fi
    fi
  fi
}

function ConfigureNFSRole() {
   if [ "$nfsNodeOn" -ne 1 ]; then
      logInfo "Skipping NFS Role configuration... Not found"
      return
   fi
   # Check if nfs exists and is running
   if [ -f /etc/init.d/nfs ]; then
       # Check if nfs is running
       if [ `ps -e | grep -w nfsd | wc -l` -ne 0 ]; then
           echo "NFS is running and mapr-nfs is configured for this node. Stopping NFS."
           # Stop NFS
           /etc/init.d/nfs stop
       fi
   fi

   # configure mapr user only for nfs client mode.
   if [ $clientOnly -eq 1 ]; then
     ConfigMaprUser
   fi

   # nothing to configure
}

function ConfigureWSRole() {
  if [ $clientOnly -eq 0 -a $dontChangeSecurityPermissionsOn -eq 0 ]; then
    ConfigureRunUserForWS
  fi

  local maprLoginConf=${INSTALL_DIR}/conf/mapr.login.conf
  if [ $clientOnly -eq 0 -a -f ${maprLoginConf} ]; then
    grep "SUBSTITUTE_FQDN_HERE" ${maprLoginConf} > /dev/null 2>&1
    if [ $? == 0 ]; then
      hostname=$(hostname --fqdn)
      if [ $? -eq 0 ]; then
        sed -i -e 's/SUBSTITUTE_FQDN_HERE/'${hostname}'/g' $maprLoginConf
      fi
    fi
  fi

  if [ "$wsNodeOn" -ne 1 ]; then
     logInfo "Skipping Webserver Role configuration... Not found"
     return
  fi
  logInfo "Configuring Webserver"

  if [ "${isSecure:-}" != "true" ] ; then
  #generate key & trust store since MCS needs even without security
    if [ ! -f ${INSTALL_DIR}/conf/ssl_keystore ]; then
      GenerateSslKeys
      if [ "$?" -ne 0 ]; then
         ExitSingleInstance 1 
      fi
    fi
  fi 


   zk_key="zkconnect"
   sed -i -e 's/'${zk_key}'=.*/'${zk_key}'='$zkNodesList'/g' $uiConf
   cldb_port="cldb.port"
   sed -i -e 's/^.*'${cldb_port}'=.*/'${cldb_port}'='${cldbPort}'/g' $uiConf
}

function ConfigureHadoop() {
  HADOOP_DIR="${hadoopBase}/hadoop-${hadoopVersion}"
  if [ ! -d $HADOOP_DIR ]; then
    logInfo "Skipping Hadoop configuration... Not found"
    return
  fi

  ConfigureOozie

  HADOOP_CONF_DIR="${HADOOP_DIR}/conf"

  ConfigureRunUserForHadoop $MAPR_USER

  hConf="${hadoopConfDir}/hadoop-site.xml"
  if [ "$ver" == "0.18.3" ]; then
    hcoreConf=$hConf
    hmrConf=$hConf
  else
    hcoreConf="${hadoopConfDir}/core-site.xml"
    hmrConf="${hadoopConfDir}/mapred-site.xml"
  fi
}

# Sets up symlinks, updates configuration files. This is different from
# ConfigureHadoop. It needs to be run only when the user wants to specify
# a new Hadoop version to be configured. It is not needed when roles are
# refreshed.
function ConfigureHadoopDir() {
  ConfigureHadoopMain "$hadoop" "$hadoopVersion"
}


checkBuildOozieWar() {

  if [ -d "${INSTALL_DIR}/oozie" ]; then
    oozieVersion=$(cat ${INSTALL_DIR}/oozie/oozieversion)
    if [ -f "${INSTALL_DIR}/oozie/oozie-${oozieVersion}/logs/hadoop_version.log" ]; then
      oozieHadoopVersion=$(cat ${INSTALL_DIR}/oozie/oozie-${oozieVersion}/logs/hadoop_version.log)
      if [ "${oozieHadoopVersion}" != "${hadoopVersion}" ]; then
        buildOozie="true"
      fi
    fi
  fi
}
# If Oozie has been installed, then for each
# installation of Oozie, recreate the oozie.war
# file with the new mapr-core jars.
ConfigureOozie() {
  if [ -d  "${INSTALL_DIR}/oozie" -a ${rebuildOozie} = false ]; then
    for oozieDir in $(dir -d1 ${INSTALL_DIR}/oozie/oozie-* | tr '\n' ' '); do
      # Construct the oozie-setup command.
      cmd="$oozieDir/bin/oozie-setup.sh -hadoop "$hadoopVersion" "${hadoopBase}/hadoop-${hadoopVersion}""

      # Rebuild the oozie war with the current hadoop jars. 
      $cmd
    done
    rebuildOozie=true
  fi
}

function UpdateFileClientConfig() {
 
  logInfo "Updating file client config"
    #edit core-site.xml file to make file clients default to <cldb-ip>
  key="<name>fs.default.name<\/name>"
  value="maprfs\:\/\/\/"
  sed -i -e '/'"$key"'/{
    N
    s/\('"$key"' *\n* *<value>\)\(.*\)\(<\/value>\)/\1'"$value"'\3/
  }' "$hcoreConf"

  # tell mapreduce to use maprfs
  key="<name>mapreduce.use.maprfs<\/name>"
  value="true"
  sed -i -e '/'"$key"'/{
    N
    s/\('"$key"' *\n* *<value>\)\(.*\)\(<\/value>\)/\1'"$value"'\3/
  }' "$hmrConf"

  if [ "$hadoopVersion" == "trunk" ]; then
    key="<name>mapreduce.jobtracker.address<\/name>"
  else
    key="<name>mapred.job.tracker<\/name>"
  fi
  value="maprfs\:\/\/\/"
  sed -i -e '/'"$key"'/{
    N
    s/\('"$key"' *\n* *<value>\)\(.*\)\(<\/value>\)/\1'"$value"'\3/
  }' "$hmrConf"

}

function ConfigureJTRole() {
  if [ "$jtNodeOn" -ne 1 ]; then
    logInfo "Skipping Job Tracker Role configuration... Not found"
    return
  fi

  # configure hadoop stuff
  logInfo "Configuring Hadoop"
  ConfigureHadoop
  
  logInfo "Updating JT config"
  
  UpdateFileClientConfig 

  ConfigureJMHadoopProperties "${hadoopConfDir}/hadoop-metrics.properties"

}

function ConfigureOozieRole() {

  checkBuildOozieWar
  #configure oozie
  if [ "${hadoopVersionExplicit}" != "" -o "${buildOozie}" == "true" ];then
    ConfigureOozie
  fi

  if [ "$oozieNodeOn" -ne 1 ];then
     logInfo "Skipping Oozie Role configuration... Not found"
     return
  fi
  if [ -f "${INSTALL_DIR}/oozie/oozieversion" ]; then
    oozieVersion=$(cat "${INSTALL_DIR}/oozie/oozieversion")
  else
    oozieVersion=$(ls -lt ${INSTALL_DIR}/oozie | grep "oozie-" | head -1 | sed 's/^.*oozie-//' | awk '{print $1}')
  fi
  
  OOZIE_DIR="${INSTALL_DIR}/oozie/oozie-${oozieVersion}"

  logInfo "Configuring Oozie role"
  ConfigureRunUserForOozieRole
}

function ConfigureTTRole() {
  if [ "$ttNodeOn" -ne 1 ];then
     logInfo "Skipping TaskTracker Role configuration... Not found"
     return
  fi

  logInfo "Configuring TaskTracker role"
  # configure hadoop stuff
  ConfigureHadoop
  ConfigureRunUserForTTRole

  UpdateFileClientConfig

}

function ConfigureDrillBitsRole() {
  if [ "$drillBitsNodeOn" -ne 1 ]; then
    logInfo "Skipping Drill Bits Role configuration... Not found"
    return
  fi
  logInfo "Configuring Drill Bits Role"
  if [ -f "${drillBase}/drillversion" ]; then
    ver=$(cat "${drillBase}/drillversion")
  else
    ver=`ls -t ${drillBase} | sed 's/^.*drill-//' | head -1 | awk '{print $1}'`
  fi
  DRILL_BASE_DIR=${drillBase}/drill-${ver}

  ConfigureRunUserForDrill $DRILL_BASE_DIR $MAPR_USER

  DRILL_CONF_DIR=${DRILL_BASE_DIR}/conf
  drillConf="${DRILL_CONF_DIR}/drill-override.conf"

  oldClusterId="drillbits1"
  oldZkConnect="localhost:2181"

  newClusterId="${clusterName}-drillbits"

  sed -i -e "s/$oldClusterId/$newClusterId/g" $drillConf
  sed -i -e "s/$oldZkConnect/$zkNodesList/g" $drillConf
  
  drillEnv="${DRILL_CONF_DIR}/drill-env.sh"
  drillEnvExistingExport=`grep "export HADOOP_HOME" ${drillEnv}`
  if [ -z "$drillEnvExistingExport" ]; then
    echo "" >> $drillEnv
    echo "export HADOOP_HOME=/opt/mapr/hadoop/hadoop-${hadoopVersion}" >> $drillEnv
  else
    sed -i -e "s/^export HADOOP_HOME=.*/export HADOOP_HOME=\/opt\/mapr\/hadoop\/hadoop-${hadoopVersion}/g" $drillEnv
  fi
}

function ConfigureHBase() {
  logInfo "Configuring Hbase"

  # change hadoop-env.sh to set HBASE_PID dir
  if [ -f "${hbaseBase}/hbaseversion" ]; then
    ver=$(cat "${hbaseBase}/hbaseversion")
  else 
    ver=`ls -lt ${hbaseBase} | sed 's/^.*hbase-//' | head -1 | awk '{print $1}'`
  fi
  HBASE_BASE_DIR=${hbaseBase}/hbase-${ver}

  # Bug 13243 Hbase has been compiled with new hdfs 2 jars. Will now•
  # switch between hadoop2 jars and normal jars
  for JAR in `find "$HBASE_BASE_DIR" -iname "*jar.hadoop2"`; do
      logInfo "Renaming ${JAR:-} to ${JAR%\.*}"
      mv -f "${JAR:-}" ${JAR%\.*}
  done

  # Bug 12676: HBase releases 0.94.1 through 0.94.9 have older version
  # of Zookeeper JARs which conflicts with the one in MapR release v3.1
  for TO_FIX_VERSION in "0.94.1" "0.94.3" "0.94.5" "0.94.9" ; do
    if [ "${TO_FIX_VERSION}" == "${ver}" ]; then
      if [ -d ${HBASE_BASE_DIR}/lib ] ; then
        for ZK_JAR in $(find ${HBASE_BASE_DIR}/lib -regextype posix-extended -regex ".*zookeeper-.*\.jar" -print 2> /dev/null); do
          logInfo "Removing $ZK_JAR"
          rm -f "$ZK_JAR"
        done
      fi
    fi
  done

  ConfigureRunUserForHbase $HBASE_BASE_DIR $MAPR_USER

  HBASE_CONF_DIR=${HBASE_BASE_DIR}/conf
  hbaseEnv="${HBASE_CONF_DIR}/hbase-env.sh"
  hbasePidDir="HBASE_PID_DIR"
  escapedInstallDir=$(echo ${INSTALL_DIR} | sed 's/\//\\\//g')
  sed -i -e 's/^.*'${hbasePidDir}'=.*/export '${hbasePidDir}'='${escapedInstallDir}'\/pid/g' $hbaseEnv

  # Configure hbase-site.xml
  hbaseConf="${HBASE_CONF_DIR}/hbase-site.xml"
  zooname="<name>hbase.cluster.distributed<\/name>"
  sed -i -e '/'"$zooname"'/{
  N
  s/^.*$/'"$zooname"'\n<value>true<\/value>/
  }' ${hbaseConf}

  zkIPs=`echo ${ZK_SERVERS} | tr " " ","`
  zkPort=`echo ${zkNodesList} | sed 's/^.*://g'`

  zooaddress="<name>hbase.zookeeper.quorum<\/name>"
  sed -i -e '/'"$zooaddress"'/{
  N
  s/^.*$/'"$zooaddress"'\n<value>'"$zkIPs"'<\/value>/
  }' ${hbaseConf}

  zooport="<name>hbase.zookeeper.property.clientPort<\/name>"
  sed -i -e '/'"$zooport"'/{
  N
  s/^.*$/'"$zooport"'\n<value>'"$zkPort"'<\/value>/
  }' ${hbaseConf}

}
function ConfigureHBMRole() {
  if [ "$hbMsNodeOn" -ne 1 ]; then
    logInfo "Skipping Hbase Master Role configuration... Not found"
    return
  fi
  logInfo "Configuring Hbase Master Role"
  ConfigureHBase

  if [ "$ttNodeOn" -ne 1 -a "$jtNodeOn" -ne 1 ]; then
    # Need to configure Hadoop as well
    ConfigureHadoop
    UpdateFileClientConfig
  fi
}

function ConfigureHBIRole() {
  if [ "$hbINodeOn" -ne 1 ]; then
    logInfo "Skipping Hbase Client Role configuration... Not found"
    return
  fi
  logInfo "Configuring Hbase Client Role"
  ConfigureHBase

  if [ "$ttNodeOn" -ne 1 -a "$jtNodeOn" -ne 1 ]; then
    # Need to configure Hadoop as well
    ConfigureHadoop
    UpdateFileClientConfig
  fi
}


function ConfigureHBRRole() {
  if [ "$hbRsNodeOn" -ne 1 ]; then
    logInfo "Skipping Hbase RS Role configuration... Not found"
    return
  fi
  logInfo "Configuring Hbase RS Role"
  ConfigureHBase

  if [ "$ttNodeOn" -ne 1 -a "$jtNodeOn" -ne 1 ]; then
    # Need to configure Hadoop as well
    ConfigureHadoop
    UpdateFileClientConfig
  fi
}

function ConfigureJMHadoopProperties() {
  file=$1
  grep "maprmepredvariant.class" $file > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    # insert record
    echo "maprmepredvariant.class=com.mapr.job.mngmnt.hadoop.metrics.MaprRPCContext" >> $file
  else
   # update record
   sed -i -e 's/^maprmepredvariant.class=.*$/maprmepredvariant.class=com.mapr.job.mngmnt.hadoop.metrics.MaprRPCContext/g' $file
  fi

  grep "maprmepredvariant.period" $file > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    # insert record
    echo "maprmepredvariant.period=10" >> $file
  fi

  grep "maprmapred.class" $file > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    # insert record
    echo "maprmapred.class=com.mapr.job.mngmnt.hadoop.metrics.MaprRPCContextFinal" >> $file
  else
   # update record
   sed -i -e 's/^maprmapred.class=.*$/maprmapred.class=com.mapr.job.mngmnt.hadoop.metrics.MaprRPCContextFinal/g' $file
  fi

  grep "maprmapred.period" $file > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    # insert record
    echo "maprmapred.period=10" >> $file
  fi

  
}
function UpdateWardenConfig() {

  ConfigureJMHadoopProperties "${INSTALL_DIR}/conf/hadoop-metrics.properties"
  tmpWardenConf="/tmp/warden.conf"
  logInfo "Updating Warden config"
  now=`date +%Y-%m-%d.%H-%M`
  RPCON=true
  services=`cat ${INSTALL_DIR}/conf/warden.conf | grep "services=" | sed 's/services=//'`
  if [ "$services"x != x ]; then
    # services string is NOT empty
    # save copy of warden.conf and proceed
    cp -Rp $wardenConf "$oldWardenConf"."$now"
  fi
  # copy the warden conf file to a temporary file and make all changes in the temporary file
  cat $wardenConf > $tmpWardenConf
  cldbport_key="cldb.port"
  sed -i -e 's/'${cldbport_key}'=.*/'${cldbport_key}'='${cldbPort}'/g' $tmpWardenConf

  zk_key="zookeeper.servers"
  sed -i -e 's/'${zk_key}'=.*/'${zk_key}'='$zkNodesList'/g' $tmpWardenConf
### Following will need to be set per service based on IPs particular service can be started on
  sed -i -e '1,$s/\:127\.0\.0\.1/\:'$currentIP'/g' $tmpWardenConf

  # remove all services
  svc_key="services"
  sed -i -e 's/'${svc_key}'=.*/'${svc_key}'=/g' $tmpWardenConf
  hostStatsAdded=0

  grep "rpc.drop=" $wardenConf > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    #insert
    logInfo "Adding \"rpc.drop=false\" to \"$wardenConf\""
    echo "rpc.drop=false" >> $tmpWardenConf
  else
    sed -i -e 's/rpc.drop=.*$/rpc.drop=false/g' $tmpWardenConf
  fi
  # following are only insert, do not update as it might be
  # different port
  grep "hs.port=" $wardenConf > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    #insert
    logInfo "Adding \"hs.port=1111\" to \"$wardenConf\""
    echo "hs.port=1111" >> $tmpWardenConf
  fi
  grep "hs.host=" $wardenConf > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    #insert
    logInfo "Adding \"hs.host=localhost\" to \"$wardenConf\""
    echo "hs.host=localhost" >> $tmpWardenConf
  fi

  if [ "$fsNodeOn" == "1" -a "$cldbNodeOn" != "1" ]; then
    fs_svc="fileserver:all;hoststats:all:fileserver"
    sed -i -e 's/'${svc_key}'=/'${svc_key}'='$fs_svc';/g' $tmpWardenConf
    hostStatsAdded=1
  fi
  if [ "$cldbNodeOn" == "1" ]; then
    cldb_svc="kvstore:all;cldb:all:kvstore;hoststats:all:kvstore"
    sed -i -e 's/'${svc_key}'=/'${svc_key}'='$cldb_svc';/g' $tmpWardenConf
    hostStatsAdded=1
  fi
  if [ "$nfsNodeOn" == "1" ]; then
    if [ "$cldbNodeOn" != "1" ]; then
        if [ "$fsNodeOn" == "1" ]; then
           nfs_svc="nfs:all:fileserver"
           hostStatsAdded=1
        else
           nfs_svc="nfs:all:cldb;hoststats:all:nfs"
           RPCON=false
           hostStatsAdded=1
        fi
    else 
        nfs_svc="nfs:all:cldb"
    fi
    sed -i -e 's/'${svc_key}'=/'${svc_key}'='$nfs_svc';/g' $tmpWardenConf
  fi
  if [ "$hbRsNodeOn" == "1" ]; then
    hbrs_svc="hbregionserver:all:hbmaster"
    sed -i -e 's/'${svc_key}'=/'${svc_key}'='$hbrs_svc';/g' $tmpWardenConf
  fi
  if [ "$hbMsNodeOn" == "1" ]; then
    hbms_svc="hbmaster:all:cldb"
    sed -i -e 's/'${svc_key}'=/'${svc_key}'='$hbms_svc';/g' $tmpWardenConf
  fi
  if [ "$ttNodeOn" == "1" ]; then
    tt_svc="tasktracker:all:jobtracker"
    sed -i -e 's/'${svc_key}'=/'${svc_key}'='$tt_svc';/g' $tmpWardenConf
  fi
  if [ "$jtNodeOn" == "1" ]; then
    jt_svc="jobtracker:1:cldb"
    sed -i -e 's/'${svc_key}'=/'${svc_key}'='$jt_svc';/g' $tmpWardenConf
  fi
  if [ "$wsNodeOn" == "1" ]; then
    ws_svc="webserver:all:cldb" 
    sed -i -e 's/'${svc_key}'=/'${svc_key}'='$ws_svc';/g' $tmpWardenConf
  fi
  sed -i -e '/^services=/s/;$//' $tmpWardenConf

  grep "hs.rpcon=" $wardenConf > /dev/null 2>&1
  if [ "$?" -ne 0 ]; then
    #insert if not there
    logInfo "Adding \"hs.rpcon=$RPCON\" to \"$wardenConf\""
    echo "hs.rpcon=$RPCON" >> $tmpWardenConf
  else
    # Otherwise change the rpc value to false (this is only true if node is NFS only)
    sed -i -e "s/hs.rpcon=.*/hs.rpcon=$RPCON/g" $tmpWardenConf
  fi


  # try to see if we have following scenarios:
  # fileserver, TT, HBR
  # or fileserver, HBR
  # and modify memory settings based on it
  sed -i -e 's/^#service.command.mfs.heapsize.percent=/service.command.mfs.heapsize.percent=/g' $tmpWardenConf
  mfsMemoryPercentString=$(grep "service.command.mfs.heapsize.percent" $tmpWardenConf)
  if [ $? -eq 0 ]; then
    mfsMemoryPercent=$(echo $mfsMemoryPercentString | sed 's/service.command.mfs.heapsize.percent=//')
    if [ "$isDB" == "1" -a $mfsMemoryPercent -lt 35 ]; then
      sed -i -e 's/^.*service.command.mfs.heapsize.percent=.*/service.command.mfs.heapsize.percent=35/g' $tmpWardenConf
      isMemAllocationChanged=1
      grep "isDB=" $wardenConf > /dev/null 2>&1
      if [ "$?" -ne 0 ]; then
        #insert
        logInfo "Adding \"isDB=true\" to \"$wardenConf\""
        echo "isDB=true" >> $tmpWardenConf
      else 
        #update
        sed -i -e 's/^isDB=.*/isDB=true/g' $tmpWardenConf
      fi
    elif [ "$isDB" == "0" -a $mfsMemoryPercent -eq 35 ]; then
      sed -i -e 's/^.*service.command.mfs.heapsize.percent=.*/service.command.mfs.heapsize.percent=25/g' $tmpWardenConf
      isMemAllocationChanged=1
      grep "isDB=" $wardenConf > /dev/null 2>&1
      if [ "$?" -ne 0 ]; then
        #insert
        logInfo "Adding \"isDB=false\" to \"$wardenConf\""
        echo "isDB=false" >> $tmpWardenConf
      else
        #update
        sed -i -e 's/^isDB=.*/isDB=false/g' $tmpWardenConf
      fi
    elif [ "$isDB" == "0" -a $mfsMemoryPercent -eq 35 ]; then
      sed -i -e 's/^.*service.command.mfs.heapsize.percent=.*/service.command.mfs.heapsize.percent=25/g' $wardenConf
      isMemAllocationChanged=1
      grep "isDB=" $wardenConf > /dev/null 2>&1
      if [ "$?" -ne 0 ]; then
        #insert
        logInfo "Adding \"isDB=false\" to \"$wardenConf\""
        echo "isDB=false" >> $wardenConf
      else
        #update
        sed -i -e 's/^isDB=.*/isDB=false/g' $wardenConf
      fi
    fi
    if [ $isOnlyRoles -eq 1 -a $isMemAllocationChanged -eq 1 ]; then
      echo "MFS memory allocation has been changed. Please restart warden for changes to take effect"
    fi
    if [ $isOnlyRoles -eq 1 -a $isMemAllocationChanged -eq 1 ]; then
      echo "MFS memory allocation has been changed. Please restart warden for changes to take effect"
    fi
  fi
  if [ "$cldbNodeOn" != "1" -a "$hbMsNodeOn" != "1" -a "$jtNodeOn" != "1" -a "$wsNodeOn" != "1" -a "$impalaServerRoleOn" != 1 ]; then
    if [ "$fsNodeOn" == "1" ]; then
      if [ "$hbRsNodeOn" == "1" ]; then
        if [ "$ttNodeOn" == "1" ]; then
          sed -i -e 's/^.*service.command.mfs.heapsize.percent=.*/service.command.mfs.heapsize.percent=42/g' $tmpWardenConf
          sed -i -e 's/^service.command.mfs.heapsize.min=.*/service.command.mfs.heapsize.min=512/g' $tmpWardenConf
        else
          sed -i -e 's/^service.command.mfs.heapsize.percent=/#service.command.mfs.heapsize.percent=/g' $tmpWardenConf
          sed -i -e 's/^service.command.mfs.heapsize.min=.*/service.command.mfs.heapsize.min=512/g' $tmpWardenConf
        fi
      else
        if [ "$ttNodeOn" == "1" ]; then
          if [ "$isDB" == "1" ]; then
            sed -i -e 's/^.*service.command.mfs.heapsize.percent=42.*/service.command.mfs.heapsize.percent=35/g' $tmpWardenConf
          else
            sed -i -e 's/^.*service.command.mfs.heapsize.percent=42.*/service.command.mfs.heapsize.percent=20/g' $tmpWardenConf
          fi
        else
          # just single mfs
          sed -i -e 's/^service.command.mfs.heapsize.percent=/#service.command.mfs.heapsize.percent=/g' $tmpWardenConf
        fi
      fi
    fi
  fi
  if [ "$wsNodeOn" == "1" -a "$jmRoleOn" == "1" ]; then
    # adjust memory for webserver for JM usage
    memoryPercentString=$(grep "service.command.webserver.heapsize.percent" $wardenConf)
    if [ $? -eq 0 ]; then
       memoryPercent=$(echo $memoryPercentString | sed 's/service.command.webserver.heapsize.percent=//')
       if [ $memoryPercent -le 3 ]; then
         # increase it to at least 10
         sed -i -e 's/^service.command.webserver.heapsize.percent=.*/service.command.webserver.heapsize.percent=10/g' $tmpWardenConf
       fi
    else
      # no memory settings for webserver found
      logInfo "Adding \"service.command.webserver.heapsize.percent=10\" to \"$wardenConf\""
      echo "service.command.webserver.heapsize.percent=10" >> $tmpWardenConf
    fi
    memoryMaxString=$(grep "service.command.webserver.heapsize.max" $wardenConf)
    if [ $? -eq 0 ]; then
       memoryMax=$(echo $memoryMaxString | sed 's/service.command.webserver.heapsize.max=//')
       if [ $memoryMax -le 750 ]; then
         #increase it to 4 GB
         sed -i -e 's/^service.command.webserver.heapsize.max=.*/service.command.webserver.heapsize.max=4000/g' $tmpWardenConf
       fi
    else
      # no max memory setting found
      logInfo "Adding \"service.command.webserver.heapsize.max=4000\" to \"$wardenConf\""
      echo "service.command.webserver.heapsize.max=4000" >> $tmpWardenConf
    fi
  fi
  #move the temporary warden conf file to warden.conf
  mv $tmpWardenConf $wardenConf
}

function getIpAddress() {
 # don't try to check IPs, as of recent Aaron's request (BUG 3438)
 # if in the future it will be decided otherwise just comment out next IF statement
 # we are checking based on regex for ip and ipv6
 isIp=$(echo $1 | sed "s/[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}.[0-9]\{1,3\}//" | sed "s/[0-9a-fA-F]\{1,4\}\(:[0-9a-fA-F]\{0,4\}\)\{0,7\}\(\/[0-9]\{0,3\}\)\{0,1\}//")
 if [ "$isIp"x = "x" ]; then
    # it matched regex, so it is IP, just return it
    echo $1
    return
 fi
 hostOut=$(gethostip -d $1)
 if [ $? -eq 0 ]; then
    echo $hostOut
    return
 fi
 echo "ERROR: invalid(unresolvable) host provided: $1"
 logErr "invalid(unresolvable) host provided: $1" 
 ExitSingleInstance 1
}

function usage() {
	echo ""
	echo "configure.sh is a tool to configure nodes in a MapR cluster and is"
	echo "run on all nodes"
	echo ""
	echo "Usage: "
	echo ""
	echo "configure.sh  -C cldb_list  -Z zookeeper_list  [args]"
	echo "configure.sh  -C cldb_list -M cldb_mh_list [-M cldb_mh_list ...] -Z zookeeper_list  [args]"
	echo "configure.sh  client_only_mode  [refresh_roles] [args]"
	echo "configure.sh  refresh_roles  [client_only_mode] [args]"
	echo ""
	echo "Options:"
	echo ""
	echo "cldb_list        : hostname[:port_no] [,hostname[:port_no] ...]"
        echo "                   a list of CLDB nodes which this machine should use "
        echo "                   to connect to the MapR cluster, "
        echo "                   use this option only when CLDB servers have "
        echo "                   a single IP/hostname assigned to them "
        echo "cldb_mh_list     : nodeBeth0[:port_no][,[nodeBeth1[:port_no] ...]"
        echo "                   a list of hostnames/IP addresses "
        echo "                   which this machine should use to connect "
        echo "                   to a specific CLDB server in the MapR cluster, "
        echo "                   use this option to specify each CLDB server "
        echo "                   which is assigned more than one hostname/IP address "
        echo ""
	echo "zookeeper_list   : hostname[:port_no] [,hostname[:port_no] ...]"
	echo "client_only_mode : -c -C cldb_list [-Z zookeeper_list]"
	echo "refresh_roles    : -R [-C cldb_list] [-Z zookeeper_list]"
        echo ""
	echo "args is a combination of   :"
        echo "    -D <disk_list> -         Specify the list of disks"
        echo "                             to add to this cluster."
        echo "                             (IE /dev/sdb,/deb/sdc)."
        echo "                             All disks will be added"
        echo "                             as separate disks."
        echo "                             In order to specify"
        echo "                             raid disks, create a disklist"
        echo "                             file and use the -F option"
        echo "                             This option cannot be used"
        echo "                             together with -F"
        echo "                             default: None"
        echo "    -F <disk_file> -         Specify a disklist file to be used"
        echo "                             to add all the disks to the cluster."
        echo "                             Disks should be listed on a separate"
        echo "                             line in order to be added as separate"
        echo "                             disks, or together on one line to be"
        echo "                             treated as raid disks. This option"
        echo "                             cannot be used together with -D"
        echo "                             default: None"
        echo "    -disk-opts <FGMW:X>     - The options to pass to "
        echo "                             /opt/mapr/server/disksetup"
        echo "                             (See the help options for more"
        echo "                             information)"
        echo "                             default: F"
	echo "    -N  <cluster_name>     - name of the cluster"
	echo "                             default: \"my.cluster.com\""
	echo "    -d  <hostname:port_no> - address of the database to connect to"
	echo "                             default: None"
	echo "    -du <username>         - user account to use to connect to the database"
	echo "                             default: None"
	echo "    -dp <password>         - password of the database user account"
	echo "                             default: None"
	echo "    -ds <schema>           - database schema to be used"
	echo "                             default: metrics"
	echo "    -u  <username>         - user name to run the mapr services"
        echo "                             on the node. This can also be specified"
        echo "                             using \${MAPR_USER}. Deafult is \"mapr\""
	echo "    -g  <groupname>        - group name which is the default group of "
        echo "                             \${MAPR_USER} who runs mapr services"
	echo "    --create-user | -a     - create the local user \${MAPR_USER} with"
        echo "                             which the mapr services run"
	echo "    -U  <uid>              - user id to use if unix account \${MAPR_USER}"
	echo "                             has to be created. corresponds to -u/--uid"
	echo "                             option of \"useradd\" command in unix"
	echo "                             default: picked by the operating system"
	echo "    -G  <gid>              - group name or the number to use if unix account"
	echo "                             \${MAPR_USER} has to be created. corresponds to"
	echo "                             -g/--gid option of \"useradd\" command in unix"
	echo "                             default: picked by the operating system"
	echo "    -J  <port_no>          - cldb jmx port number"
	echo "                             default: 7220"
	echo "    -H  <port_no>          - cldb https port number"
	echo "                             default: 7443"
	echo "    -L  <logfile_name>     - alternative to the default log file"
	echo "                             default: ${MAPR_HOME}/logs/configure.log"
        echo "    -v                     - verbose: display all verbose messages"
	echo "    -f                     - configure the node without the check of system"
	echo "                             configuration"
        echo "    -M7                    - configure mfs memory for M7 usage"
        echo "    -syschk <y|n>          - configure system checks to be enabled or disabled"
        echo "                             y in order to enable system checks. n in order to disable"
        echo "    -noDB                  - configure mfs for non M7 usage"
        echo "    -no-autostart            - do not autostart the cluster"
        echo "                             (IE does not start mapr-warden)"
        echo "                             In order to start your cluster"
        echo "                             with this option make sure you run"
        echo "                             \"service mapr-warden start\""
        echo "    -on-prompt-cont <y|n>  - Change the stype of prompts. \"y\" will evaluate"
        echo "                             all warning messages to \"yes\". "
        echo "                             \"n\" will evaluate all messages to"
        echo "                             \"no\". \"p\" will cause all warning"
        echo "                             messages to ask the user whether to"
        echo "                             proceed or not"
        echo "                             default: p"
        echo ""
        echo "    -genkeys               - generate needs keys and certificates for first CLDB node"
        echo "    -certdomain <domain>   - override default DNS domain for generated SSL wild card certificates"
        echo "    -nocerts               - do not generate certificates even if -genkeys specified"
        echo "    -no-auto-permission-update - do not update the system security permissions automatically"
        echo "                             Warn: Features like WebServer might not work properly"
        echo "                             default: disabled"
        echo "    -S | -secure           - secure cluster"
	echo "                             default: non-secure"
        echo "    -unsecure              - non-secure cluster"
	echo "                             default: non-secure"
        echo "    -K | -kerberosEnable   - Enable kerberos"
	echo "                             default: disabled"
	echo "    -P \"<cldbPrincipal>\"   - cldb Principal, please use Quotes around Principal"
        echo "    --isvm                 - Specifies virtual machine setup. Required when configure.sh is "
        echo "                             run on a virtual machine. Option should only be used on nodes"
        echo "                             that have CLDB role."
	echo "    -RM <ip or hostname>   - Resource Manager IP or hostname"
	echo "    -HS <ip or hostname>   - History Server IP or hostname. If this option is not specified,
					   it will default to the Resource Manager hostname provided with -RM.
					   If -RM is also not specified, -HS will default to 0.0.0.0
					   If multiple RM addresses are specified via the -RM option, -HS is required"
        echo ""
	echo ""
	echo "Environment Variables:"
	echo ""
	echo "MAPR_USER: the user for whom the node is configured"
	echo "           default: \"mapr\"."
	echo "           The user account is created if it does not exist"
	echo "MAPR_HOME: root directory of installation and configuration info"
	echo "           default: /opt/mapr"
	echo ""
} 

#########################################################################
# ConfigureImpersonation                                                #
#   Create the directory and file that is used to determine which users #
#   can perform impersonation.  If there is a file named as the user    #
#   name, the user is allowed to do impersonation.  For example, for    #
#   user 'foo', the user is allowed to do impersonation if the file     #
#   $MAPR_HOME/proxy/foo exists                                         #
#                                                                       #
#   The requrement is that the directory $MAPR_HOME/proxy be owned by   #
#   owned by root, with group $MAPR_GROUP, and that the only write      #
#   access is by the owner, i.e. root                                   #
#                                                                       #
#   The directory cannot be a symbolic link                             #
#########################################################################
function ConfigureImpersonation () {
  proxyDir="${INSTALL_DIR}/conf/proxy"
  maprFile="$proxyDir/$MAPR_USER"
  rootFile="$proxyDir/root"
  
  # If the proxy directory does not exist, create it and set 
  # owner/permissions
  if [ ! -e $proxyDir ]; then 
    # We need to be root to do this
    CheckForRoot
    mkdir $proxyDir

  fi
  chown root:$MAPR_GROUP $proxyDir
  chmod 755 $proxyDir

  # If the proxy file does not exist for MAPR_USER, create
  if [ ! -e $maprFile ]; then
    # We need to be root to do this
    CheckForRoot
    touch $maprFile
  fi
  
  # If the proxy file does not exist for MAPR_USER, create
  if [ ! -e $rootFile ]; then
    # We need to be root to do this
    CheckForRoot
    touch $rootFile
  fi
}

################
#  main        #
################
SetCurrentIP

installDir=${INSTALL_DIR}
SERVER_DIR=${installDir}/server
logFile="${INSTALL_DIR}/logs/configure.log"

# check for input params: list of cldbs and list of zk

if [ $# -eq 0 ]; then
  usage
  exit 1
fi

cmdLine="$0 $@"
configUser=0
configGroup=0
isVM=0;
setVM=0
prereq_opt=
index=0

# create conf.old directory
if [ ! -e "$oldConf" ]; then
  mkdir $oldConf
  chmod 755 $oldConf
  echo "create $oldConf"
fi

while [ $# -gt 0 ]
do
  case "$1" in
  -C) shift
      cldbNodesList=$1
      while [ '-' != "${2:0:1}" ]; do
          if [ -z $2 ]; then
              break
          fi
          cldbNodesList=$cldbNodesList,$2
          shift
      done
      SortList cldbNodesList;;
  -M) shift
      cldbNodesListExt[$index]=$1
      index=`expr $index + 1`;;
  -c) clientOnly=1
      autoStart=0
      prereq_opt=${prereq_opt}" -isClient";;
  -Z) shift;
      zkNodesList=$1
      while [ '-' != "${2:0:1}" ]; do
          if [ -z $2 ]; then
              break
          fi
          zkNodesList=$zkNodesList,$2
          shift
      done
      SortList zkNodesList;;
  -L) shift;
      logFile=$1;;
  -N) shift;
      if [[ "$1"  == *" "* ]]; then
          echo "ERROR: -N option error: cluster name cannot contain spaces."
          exit 1
      fi
      if [ -z $1 ]; then
          echo "ERROR: -N option error: cluster name cannot be blank."
          exit 1
      fi
      clusterName=$1;;
  -F) shift
      diskFile=$1;;
  -D) shift
      diskList=$1
      while [ '-' != "${2:0:1}" ]; do
          if [ -z $2 ]; then
              break
          fi
         diskList=$diskList,$2
          shift
      done;;
  -disk-opts) shift
      diskOpts=$1;;
  -J) shift;
      cldbJmxRemotePort=$1;;
  -g) shift;
      configGroup=1
      MAPR_GROUP=$1;;
  -u) shift;
      configUser=1
      MAPR_USER=$1;;
  -a) CREATE_USER=1;;
  --create-user) CREATE_USER=1;;
  -G) shift;
      maprGroupId=$1;;
  -U) shift;
      maprUserId=$1;;
  -R) autoStart=0
  	  isOnlyRoles=1;;
  -d) shift;
      dbConnect=$1;;
 -du) shift;
      dbUser=$1;;
 -dp) shift;
      dbPassword=$1;;
 -ds) shift;
      dbSchema=$1;;
  --isvm) setVM=1
      isVM=1;;
  --novm) setVM=1
      isVM=0;;
  -f) force=1;;
  -genkeys) genKeys=1;;
  -nocerts) noCerts=1;;
  -certdomain) shift;
      certDomain=$1;;
  -M7) setDB=1 
      isDB=1;;
  -noDB) setDB=1
      isDB=0;;
  -v) verboseOn=1;;
  -no-autostart) autoStart=0;;
  -on-prompt-cont) shift
      promptStyle=$1;;
  -S) isSecure="true";;
  -secure) isSecure="true";;
  -syschk) shift
      sysChk=${1,,};;
  -unsecure) isSecure="false";;
  -K) kerberosEnable=1;;
  -kerberosEnable) kerberosEnable=1;;
  -no-auto-permission-update) 
      echo "Warn: The option -no-auto-permission-update is for advanced user, some of the features like WebServer might not work properly"
      dontChangeSecurityPermissionsOn=1;;
  -H) shift;
      cldbHttpsPort=$1;;
  -P) shift;
      cldbPrincipal="$1";;
  -RM) shift;
      rm_ip="$1"
      SortList rm_ip;;
  -HS) shift;
      hs_ip="$1";;
  -*) usage;
      echo "ERROR: Unrecognized option: " $1;
      exit 1;;
   *) echo "ERROR: Unrecognized parameter: " $1;
      exit 1;;  # terminate while loop
  esac
  shift
done

# Change the permissions
touch $logFile;
chmod 600 $logFile;

if [ $clientOnly -eq 1 ]; then
  # in some cases where we dont install the pkg (Mac shipped as
  # a zip file) create the required directories
  mkdir -p ${INSTALL_DIR}
  mkdir -p ${INSTALL_DIR}/logs
  mkdir -p ${INSTALL_DIR}/conf
fi

# PLEASE DO NOT MOVE prerequisitecheck.sh below sourcing of scripts-common.sh
# as it is screwing up logging
LogFile_=${logFile} #save the logile name
if [ $force -eq 0 ]; then
  . ${SERVER_DIR}/prerequisitecheck.sh $prereq_opt

  # reset the logFile Name: prerequisitecheck.sh changes the logFile var
  # and the logErr() functions use $logFile
  logFile=${LogFile_}
fi

if [ $isOnlyRoles -ne 1 ]; then
  if [ "x$cldbNodesList" == "x" ]; then
    if [ $index -lt 1 ]; then
    # <MAPR_ERROR>
    # cldb list was not provided.
    # </MAPR_ERROR>
    echo "ERROR: No cldb nodes list was provided. Exiting"
    logErr "No cldb nodes list was provided. Exiting"
    exit 1
    fi
  fi
fi

if [ ! -d ${SERVER_DIR} ]; then
  installDir=`dirname "$0"` # will be extracted_dir/server
  SERVER_DIR=${installDir}
  installDir=${installDir}/.. # go back to extracted_dir
fi

if [ ! -d ${hadoopBase} ]; then
  # Mac: use the extracted_dir
  hadoopBase=${installDir}/hadoop
fi

. ${SERVER_DIR}/scripts-common.sh
. ${SERVER_DIR}/configure-common.sh
. ${SERVER_DIR}/configure-hadoop.sh

if [ -z "$hadoop" ]; then
  echo "Using default hadoop: $default_hadoop"
  hadoop=$default_hadoop
fi

# check if this is a HA configuration
if [ ! -z "$rm_ip" ]; then
  IsRMHAConfiguration $rm_ip
  if [ $? -eq 0 -a -z "$hs_ip" ]; then
    echo "No IP/hostname provided for History Server (-HS option). Exiting.."
    exit 1
  fi
fi

# This requires sourcing configure-common.sh
setHadoopVersion "$hadoop"
if [ $? == 1 ]; then
  exit 1;
fi

setHadoopConfDir "$hadoop" "${hadoopBase}/hadoop-${hadoopVersion}"
if [ $? == 1 ]; then
  exit 1;
fi

#Always configure hadoop dir
ConfigureHadoopDir

if [ $clientOnly -eq 0 ]; then
  CheckForRoot;  #if its not root then exit
else
  # Mac clients dont need to be installed as root. So for clients
  # CheckForRoot only if the INSTALL_DIR is not writeable
  if [ ! -w ${INSTALL_DIR} ]; then
    CheckForRoot;
  fi
fi

CheckForSingleInstance;  #check for single instance of the script

if [ $clientOnly -eq 1 ]; then
  # client_only_mode doesn't support either of -D and -F
  if [ ! -z $diskList ]; then
    logErr "Cannot specify both -D and -c options. Exiting"
    echo "ERROR: Cannot specify both -D and -c options. Exiting"
    exit 1
  fi

  if [ ! -z $diskFile ]; then
    logErr "Cannot specify both -F and -c options. Exiting"
    echo "ERROR: Cannot specify both -F and -c options. Exiting"
    exit 1
  fi
fi

if [ $index -gt 0 ]; then
  # deal with additional, maybe multihomed cldbs
  for cldb in "${cldbNodesListExt[@]}"; do
     arr1=$(echo $cldb | tr "," ";")
     if [ "x$cldbNodesList" == "x" ]; then
        cldbNodesList="${arr1}"
     else
        cldbNodesList="${cldbNodesList},${arr1}"   
     fi
  done
fi

if [ "x$cldbNodesList" == "x" ]; then
  # we could be here only if isOnlyRoles is set
  # let's recreate CLDB list from mapr-clusters.conf
  if [ -f $clusterConf -a -s $clusterConf ]; then
    # read first line
    firstLine=$(cat $clusterConf | sed '/^\s*$/d' | sed '/^\s*#.*/d' | head -1)
    cldbNodesList=$(echo $firstLine | sed 's/\s*\S*,/ /g' | tr -s '[\t ]' "," | cut -d, -f2-)
  else
  # <MAPR_ERROR>
  # cldb list was not provided.
  # </MAPR_ERROR>
  echo "ERROR: File $clusterConf is invalid. Use -C parameter to provide list of cldb nodes. Exiting"
  logErr "File $clusterConf is invalid. Use -C parameter to provide list of cldb nodes. Exiting"
  ExitSingleInstance 1
  fi
fi

# check cldbNodeList for formatting
arr=$(echo $cldbNodesList | tr "," " ")
cldbNodeListTemp=
for x in $arr
do
  # deal with ";"
  arr0=$(echo $x | tr ";" " ")
  cldbNodeListTempInt=
  for y in $arr0; 
  do
    arr1=$(echo $y | tr ":" " ")
    tokens=`echo $arr1 | wc -w`
    if [ "$tokens" -ne 2 ]; then
      if [ "$tokens" -eq 1 ]; then
        # have to use default port
        logInfo "Using $cldbDefaultPort port for CLDB $y"
        if [ "$cldbNodeListTempInt"z = "z" ]; then
          cldbNodeListTempInt="${arr1}:${cldbDefaultPort}"
        else
          cldbNodeListTempInt="${cldbNodeListTempInt};${arr1}:${cldbDefaultPort}"
        fi
      else
        # <MAPR_ERROR>
        # cldb list is not in syntax.
        # </MAPR_ERROR>
        echo "ERROR: CLDB list should be in format: host[:port],host[:port]"
        logErr "CLDB list should be in format: host[:port],host[:port]"
        ExitSingleInstance 1
      fi
    else
      if [ "$cldbNodeListTempInt"z = "z" ]; then
        cldbNodeListTempInt="${y}"
      else
        cldbNodeListTempInt="${cldbNodeListTempInt};${y}"
      fi
    fi
  done
  if [ "$cldbNodeListTemp"z = "z" ]; then
	cldbNodeListTemp="${cldbNodeListTempInt}"
  else
    cldbNodeListTemp="${cldbNodeListTemp},${cldbNodeListTempInt}"
  fi
done

# non-uniform cldb ports not allowed
cldbNodesList=$cldbNodeListTemp
tempArr=$(echo $cldbNodesList | tr "," "\n" | tr ";" "\n" | awk -F ":" '{print $2}')
isFirst=
for x in $tempArr
do
  if [ "$isFirst"a != "a" ]; then
    if [ $isFirst != $x ]; then
      # ports are not the same
      # report an error
      echo "ERROR: CLDB Ports should be the same for all CLDBs"
      logErr "CLDB Ports should be the same for all CLDBs"
      ExitSingleInstance 1
    fi
  fi
  isFirst=$x
done

# reserved cldb ports not allowed
cldbPort=$(echo $cldbNodesList | sed "s/^.*://g")
echo $takenPorts | grep $cldbPort > /dev/null 2>&1
if [ $? == "0" ]; then
  echo "ERROR: Can not use reserved ports: " $takenPorts
  logErr "Can not use reserved ports: " $takenPorts
  ExitSingleInstance 1
fi

# localhost loopback IP discouraged
echo $cldbNodesList | grep "127.0.0.1:" > /dev/null 2>&1
if [ $? == "0" ]; then
  echo "WARN: Use of 127.0.0.1 can lead to unpredictable results. Please use different IP address if possible."
  logWarn "Use of 127.0.0.1 can lead to unpredictable results. Please use different IP address if possible."
  # exit 1
fi

# build zk nodes list from roles-only command
if [ $isOnlyRoles -eq 1 -a "x$zkNodesList" == "x" ]; then
  # get ZK credentials from warden.conf
  zkLine=$(grep zookeeper.servers $wardenConf)
  if [ $? -ne 0 ]; then
     # <MAPR_ERROR>
     # ZooKeeper list list was not provided.
     # </MAPR_ERROR>
     echo "ERROR: Zookeeper nodes list is not available. Please use -C and -Z parameters to configure the node. Exiting"
     logErr "Zookeeper nodes list is not available. Please use -C and -Z parameters to configure the node. Exiting"
     ExitSingleInstance 1
  fi
  zkNodesList=$(echo $zkLine | sed 's/zookeeper.servers=//')
fi

# No need for zookeper in client-only installs: it gets invoked with
# configure.sh -c -C cldbip
if [ $clientOnly -eq 0 -a "x$zkNodesList" == "x" ]; then
  # <MAPR_ERROR>
  # ZooKeeper list list was not provided.
  # </MAPR_ERROR>
  echo "ERROR: No Zookeeper nodes list was provided. Exiting"
  logErr "No Zookeeper nodes list was provided. Exiting"
  ExitSingleInstance 1
fi

# need to check for formatting
arr=$(echo $zkNodesList | tr "," " ")
zkNodesCount=`echo $arr | wc -w`
zkNodeListTemp=

for x in $arr
do 
  arr1=$(echo $x | tr ":" " ")
  tokens=`echo $arr1 | wc -w`
  if [ "$tokens" -ne 2 ];  then
    if [ "$tokens" -eq 1 ]; then
      # have to use default port
      logInfo "Using $zkDefaultPort port for ZooKeeper $x"
      arr1=$arr1$space$zkDefaultPort
      if [ "$zkNodeListTemp"z = "z" ]; then
        zkNodeListTemp="${x}:${zkDefaultPort}"
      else 
        zkNodeListTemp="${zkNodeListTemp},${x}:${zkDefaultPort}"
      fi
      ZK_INTERNAL_BASE="${ZK_INTERNAL_BASE} ${x}:${zkDefaultPort}" 
    else
      # <MAPR_ERROR>
      # Zk node list is not in syntax.
      # </MAPR_ERROR>
      echo "ERROR: ZK nodes list should be in format: host[:port],host[:port]"
      logErr "ZK nodes list should be in format: host[:port],host[:port]"
      ExitSingleInstance 1
    fi
  else
    if [ "$zkNodeListTemp"z = "z" ]; then
      zkNodeListTemp="${x}"
    else
      zkNodeListTemp="${zkNodeListTemp},${x}"
    fi
    ZK_INTERNAL_BASE=$ZK_INTERNAL_BASE$space$x 
  fi
  zkServer=`echo $arr1 | awk '{print $1}'`
  zkResult=$(getIpAddress $zkServer)
  if [ $? -ne 0 ]; then
     echo "WARN: invalid(unresolvable) Zookeeper host/ip provided: $zkServer"
     logErr "WARN: invalid(unresolvable) Zookeeper host/ip provided: $zkServer"
  fi
  zkPort=`echo $arr1 | awk '{print $2}'`
  ZK_SERVERS=$ZK_SERVERS$space$zkServer 
done
  
# non-uniform zk ports not allowed
zkNodesList=$zkNodeListTemp
tempArr=$(echo $zkNodesList | tr "," "\n" | awk -F ":" '{print $2}')
isFirst=
for x in $tempArr
do
  if [ "$isFirst"a != "a" ]; then
    if [ $isFirst != $x ]; then
      # ports are not the same
      # report an error
      echo "ERROR: ZK client Ports should be the same for all Zookeepers"
      logErr "ZK client Ports should be the same for all Zookeepers"
      ExitSingleInstance 1
    fi
  fi
  isFirst=$x
done

# reserved zk ports not allowed
zkClientPort=$(echo $zkNodesList | sed "s/^.*://g")
echo $takenPorts | grep $zkClientPort > /dev/null 2>&1
if [ $? == "0" ]; then
  echo "ERROR: Can not use reserved ports: " $takenPorts
  logErr "Can not use reserved ports: " $takenPorts
  ExitSingleInstance 1
fi

# cldb and zk port conflicts not allowed
if [ "$cldbPort" == "$zkClientPort" ]; then
  echo "ERROR: CLDB and Zookeeper ports can not be the same: " $cldbPort $zkClientPort
  logErr "CLDB and Zookeeper ports can not be the same: " $cldbPort $zkClientPort
  ExitSingleInstance 1
fi

# localhost loopback IP discouraged
echo $zkNodesList | grep "127.0.0.1:" > /dev/null 2>&1
if [ $? == "0" ]; then
  echo "WARN: Use of 127.0.0.1 can lead to unpredictable results. Please use different IP address if possible."
  logWarn "Use of 127.0.0.1 can lead to unpredicatable results. Please use different IP address if possible."
  # exit 1
fi

# Check memory on disk if greater than 1G
# Only run check if on non client and force is 0 and if it's not -R
if [ $force -eq 0 ]; then
    if [ $clientOnly -eq 0 -a "${isOnlyRoles:-}" -eq 0 ]; then
        CheckDiskSpace "/opt"
        CheckDiskSpace "/tmp"
        CheckMem
    fi
fi


# Check if both -D and -F options are passed to configure.sh. If so, then stop running
if [ ! -z $diskList ]; then
    if [ ! -z $diskFile ]; then
        logErr "Cannot specify both -D and -F options."
        echo "Cannot specify both -D and -F options."
        ExitSingleInstance 1
    fi
fi

# Setup the disk file to be used
SetupDisksFile
# Check if disks exist
CheckDiskFile


# Only display if -R option is not given
if [ $isOnlyRoles -ne 1 ]; then
    echo "CLDB node list: $cldbNodesList"
    echo "Zookeeper node list: $zkNodesList"
fi

logInfo ""
logInfo "Node install STARTED"
logInfo "-----------------------"
logInfo "CMD: $cmdLine"


# Set is secure to true or false if it doesn't exist
# This is done in order to cause the rest of the code to execute as secure=true or secure=false (so even for roles refresh it runs properly)
# Check if clusterConf exists
if [ -f "$clusterConf" ]; then
    # Then see if the user did not specify secure or unsecure
    if [ -z "${isSecure:-}" ]; then
      # Set isSecure to clusterConf secure value
      if [ "${isOnlyRoles:-}" -eq 1 ]; then
        #Set isSecure from default cluster, if "-R" is used
        theLine=$(cat $clusterConf | sed '/^\s*$/d' | sed '/^\s*#.*/d' | head -1)
      else
        # Do it only for the matching clusterName, in case of multiple clusters
        theLine=`cat $clusterConf | grep "^${clusterName}\>"`
      fi
      isSecure=`echo $theLine | grep -o "secure=.*" | cut -d= -f2 | cut -d' ' -f1`
    fi
fi
# Set isSecure to false if cluster.conf does not have it, or if it doesn't exist
[ -z "${isSecure:-}" ] && isSecure="false"

grep "isDB=" $wardenConf > /dev/null 2>&1
if [ $? -eq 0 -a $setDB -eq 0 ]; then
    dbVal=$(awk -F = '$1 == "isDB" { print $2 }' "$wardenConf")
    if [ "$dbVal" == "true" ]; then
        isDB=1
    else
        isDB=0
    fi
fi

grep "mfs.on.virtual.machine=" $mfsConf > /dev/null 2>&1
if [ $? -eq 0 -a "$setVM" -eq 0 ]; then
    isVM=$(awk -F = '$1 == "mfs.on.virtual.machine" { print $2 }' "$mfsConf")
fi

logInfo "Cluster run as secure=$isSecure"

if [ $isOnlyRoles -ne 1 ]; then
  ConstructMapRClustersConfFile
fi

if [ $isOnlyRoles -ne 0 ]; then
  UpdateAuditLogger
fi

if [ $isMyCluster -ne 1 ]; then
  echo "As cluster provided as input: $clusterName is not current cluster. Only $clusterConf will be updated"
  logInfo "As cluster provided as input: $clusterName is not current cluster. Only $clusterConf will be updated"
  ExitSingleInstance 0
fi

# if -u options is not specified and there is no daemon.conf, then
# set default user to run services as "mapr", the user should be created
# before running configure.sh unless "--create-user" option is being used
if [ $configUser -ne 1 ]; then
  if [ $configGroup -eq 1 ]; then
    echo "ERROR: -g option should be used along with -u."
    exit 1
  fi
fi

if [ -e $DAEMON_CONF ]; then
    MAPR_USER=$( awk -F = '$1 == "mapr.daemon.user" { print $2 }' $DAEMON_CONF)
    MAPR_GROUP=$( awk -F = '$1 == "mapr.daemon.group" { print $2 }' $DAEMON_CONF)
fi

# Set mapr user if MAPR_USER is blank
[ -z $MAPR_USER ] && MAPR_USER="mapr"

if [ $clientOnly -eq 0 ]; then
  # Always run to Config Mapr User to set permissions of Maprexecute
  ConfigMaprUser
  ConfigureWardenToRunAsMaprUser
  ConfigureYarnLinuxContainerExecutor
fi
if [ ! -z $rm_ip ]; then
  ConfigureYarnServices "$rm_ip" "$hs_ip"
elif [ $isOnlyRoles -ne 1 ]; then
  # No -RM provided and no -R. Configure MapR-HA for RM.
  ConfigureYarnServices "" "$hs_ip"
fi

ReadRoles
ValidateSecurityArgsAndFiles
if [ "$?" -eq 1 ]; then
  ExitSingleInstance 1
fi

ConfigureRoles
ConfigureHive
ConfigureImpersonation

RunDiskSetup

StartCluster
ConfigureSysChecks



logInfo ""
logInfo "Node install FINISHED"
logInfo "-----------------------"
ExitSingleInstance 0
