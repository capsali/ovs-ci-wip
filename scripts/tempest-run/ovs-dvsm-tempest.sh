#!/bin/bash

function exec_with_retry () {
    local max_retries=$1
    local interval=${2}
    local cmd=${@:3}
 
    local counter=0
    while [ $counter -lt $max_retries ]; do
        local exit_code=0
        eval $cmd || exit_code=$?
        if [ $exit_code -eq 0 ]; then
            return 0
        fi
        let counter=counter+1
 
        if [ -n "$interval" ]; then
            sleep $interval
        fi
    done
    return $exit_code
}
 
set -x
set +e

DEPLOYER_PATH="/home/ubuntu/deployer"
BUNDLE_LOCATION=$(mktemp)


eval "cat <<EOF
$(<${WORKSPACE}/ovs-ci-wip/templates/ovs/bundle.template)
EOF
" >> $BUNDLE_LOCATION

cat $BUNDLE_LOCATION

$DEPLOYER_PATH/deployer.py  --clouds-and-credentials $DEPLOYER_PATH/ci-cl-creds.yaml deploy --template $BUNDLE_LOCATION --max-unit-retries 5 --timeout 7200 --search-string $UUID
build_exit_code=$?

source $WORKSPACE/nodes
    
exec_with_retry 5 2 ssh -tt -o 'PasswordAuthentication=no' -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -i /home/ubuntu/.local/share/juju/ssh/juju_id_rsa ubuntu@$DEVSTACK \
    "git clone https://github.com/capsali/common-ci-wip.git /home/ubuntu/common-ci"
clone_exit_code=$?

exec_with_retry 5 2 ssh -tt -o 'PasswordAuthentication=no' -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -i /home/ubuntu/.local/share/juju/ssh/juju_id_rsa ubuntu@$DEVSTACK \
    "git -C /home/ubuntu/common-ci checkout no-zuul"
checkout_exit_code=$?

	
if [[ $build_exit_code -eq 0 ]]; then
	#run tempest
	
    exec_with_retry 5 2 ssh -tt -o 'PasswordAuthentication=no' -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -i /home/ubuntu/.local/share/juju/ssh/juju_id_rsa ubuntu@$DEVSTACK \
        "mkdir -p /home/ubuntu/tempest"
	ssh -tt -o 'PasswordAuthentication=no' -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -i /home/ubuntu/.local/share/juju/ssh/juju_id_rsa ubuntu@$DEVSTACK \
       "/home/ubuntu/common-ci/devstack/bin/run-all-tests.sh --include-file /home/ubuntu/common-ci/devstack/tests/$project/included_tests.txt \
       --exclude-file /home/ubuntu/common-ci/devstack/tests/$project/excluded_tests.txt --isolated-file /home/ubuntu/common-ci/devstack/tests/$project/isolated_tests.txt \
       --tests-dir /opt/stack/tempest --parallel-tests 10 --max-attempts 2"
	tests_exit_code=$?
	
    exec_with_retry 5 2 ssh -tt -o 'PasswordAuthentication=no' -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -i /home/ubuntu/.local/share/juju/ssh/juju_id_rsa ubuntu@$DEVSTACK \
        "/home/ubuntu/devstack/unstack.sh"
fi 


######################### Collect logs #########################
LOG_DIR="logs/$commitID"
mkdir -p "$LOG_DIR"

ssh -tt -o 'PasswordAuthentication=no' -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -i /home/ubuntu/.local/share/juju/ssh/juju_id_rsa ubuntu@$DEVSTACK \
    "sudo /home/ubuntu/common-ci/infra/logs/collect-logs.sh"

scp -o 'PasswordAuthentication=no' -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -i /home/ubuntu/.local/share/juju/ssh/juju_id_rsa \
ubuntu@$DEVSTACK:/home/ubuntu/aggregate.tar.gz $LOG_DIR/aggregate.tar.gz

tar -zxf $LOG_DIR/aggregate.tar.gz -C $LOG_DIR/
rm $LOG_DIR/aggregate.tar.gz

source $WORKSPACE/common-ci-wip/infra/logs/utils.sh

for hv in $(echo $HYPERV | tr "," "\n"); do
    HV_LOGS=$LOG_DIR/hyperv-logs/$hv
    HV_CONFS=$LOG_DIR/hyperv-config/$hv
    mkdir -p $HV_LOGS
    mkdir -p $HV_CONFS

    get_win_files $hv "\openstack\log" $HV_LOGS
    get_win_files $hv "\openstack\etc" $HV_CONFS
    get_win_files $hv "\juju\log" $HV_LOGS
    
    run_wsman_cmd $hv 'systeminfo' > $HV_LOGS/systeminfo.log
    run_wsman_cmd $hv 'wmic qfe list' > $HV_LOGS/windows-hotfixes.log
    run_wsman_cmd $hv 'c:\python27\scripts\pip freeze' > $HV_LOGS/pip-freeze.log
    run_wsman_cmd $hv 'ipconfig /all' > $HV_LOGS/ipconfig.log
    run_wsman_cmd $hv 'sc qc nova-compute' > $HV_LOGS/nova-compute-service.log
    run_wsman_cmd $hv 'sc qc neutron-openvswitch-agent' > $HV_LOGS/neutron-openvswitch-agent-service.log
    
    run_wsman_ps $hv 'get-netadapter ^| Select-object *' > $HV_LOGS/get-netadapter.log
    run_wsman_ps $hv 'get-vmswitch ^| Select-object *' > $HV_LOGS/get-vmswitch.log
    run_wsman_ps $hv 'get-WmiObject win32_logicaldisk ^| Select-object *' > $HV_LOGS/disk-free.log
    run_wsman_ps $hv 'get-netfirewallprofile ^| Select-Object *' > $HV_LOGS/firewall.log
    
    run_wsman_ps $hv 'get-process ^| Select-Object *' > $HV_LOGS/get-process.log
    run_wsman_ps $hv 'get-service ^| Select-Object *' > $HV_LOGS/get-service.log 
done

find $LOG_DIR -name "*.log" -exec gzip {} \;

gzip -f -c $JENKINS_HOME/jobs/$JOB_NAME/builds/$BUILD_ID/log > $LOG_DIR/console.log.gz

tar -zcf $LOG_DIR/aggregate.tar.gz $LOG_DIR

#swift -A http://10.255.244.20:8080/auth/v1.0 -U logs:root -K ubuntu upload $project $ZUUL_CHANGE

#rm -rf $ZUUL_CHANGE
##############################################

if [[ $build_exit_code -ne 0 ]]; then
	echo "CI Error while deploying environment"
	exit 1
fi
 
if [[ $clone_exit_code -ne 0 ]]; then
	echo "CI Error while cloning the scripts repository"
	exit 1
fi

if [[ $checkout_exit_code -ne 0 ]]; then
	echo "CI Error while checking out the scripts repository"
	exit 1
fi

if [[ $tests_exit_code -ne 0 ]]; then
	echo "Tempest tests execution finished with a failure status"
	exit 1
fi 

if [ "$DEBUG" != "YES" ]; then
    #destroy charms, services and used nodes.
    $DEPLOYER_PATH/deployer.py  --clouds-and-credentials $DEPLOYER_PATH/ci-cl-creds.yaml --search-string $UUID
fi

exit 0