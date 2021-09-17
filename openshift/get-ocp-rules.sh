#!/bin/sh -x
#
# Obtain prepared prometheus rules yaml files from openshift cluster
# and optionally (--prov) copy them to zal pod, then run zal prov
#

# OC: could also be kubectl?
OC=${OC:-oc}
# ZAL_JSON: location of raw json file to write configmap contents to
ZAL_JSON="${ZAL_JSON:-configmap--rules.json}"
# ZAL_NAMESPACE: the namespace where zal is deployed
ZAL_NAMESPACE=${ZAL_NAMESPACE:-zal}
# ZAL_LOCAL_ALERTS_DIR: directory on local filesystem containing .yml alert files
ZAL_LOCAL_ALERTS_DIR=${ZAL_LOCAL_ALERTS_DIR:-alerts}
###### Variables below this line only used for '--prov' mode.
# ZAL_REMOTE_ALERTS_DIR: directory on remote (pod) filesystem to upload .yml alert files to
ZAL_REMOTE_ALERTS_DIR=${ZAL_REMOTE_ALERTS_DIR:-/tmp/alerts}
# ZAL_ZABBIX_USERNAME: username to access zabbix api
ZAL_ZABBIX_USERNAME=${ZAL_ZABBIX_USERNAME:-zal}
# ZAL_ZABBIX_PASSWORD: password to access zabbix api
ZAL_ZABBIX_PASSWORD=${ZAL_ZABBIX_PASSWORD:-you_need_to_set_a_password_in_your_environment}
# ZAL_ZABBIX_JSONRPC_URL: url of zabbix + api_jsonrpc.php
ZAL_ZABBIX_JSONRPC_URL=${ZAL_ZABBIX_JSONRPC_URL:-http://localhost/api_jsonrpc.php}

########################################

if [ ! -e "${ZAL_JSON}" ]; then
    ${OC} get configmaps -n openshift-monitoring prometheus-k8s-rulefiles-0 -o json >"${ZAL_LOCAL_ALERTS_DIR}/${ZAL_JSON}"
fi
# So.. unpack them (ugh-ly but functional!)
for key in $(jq -r '.data|keys[] as $k | $k' "${ZAL_LOCAL_ALERTS_DIR}/${ZAL_JSON}"); do
    jq -r ".data.\"${key}\"" "${ZAL_LOCAL_ALERTS_DIR}/${ZAL_JSON}" >"${ZAL_LOCAL_ALERTS_DIR}/${key}"
done

if [ "$1" = "--prov" ]; then
    # Get first relevant zal pod
    zal_pod=$(${OC} get pods -l name=zal --no-headers -o name | head -1 | awk -F/ '{print $2}')
    ${OC} exec "${zal_pod}" -- mkdir -p "${ZAL_REMOTE_ALERTS_DIR}/"
    ${OC} rsync "${ZAL_LOCAL_ALERTS_DIR}" "${zal_pod}:${ZAL_REMOTE_ALERTS_DIR}/../"

    ${OC} exec "${zal_pod}" -- \
        /usr/bin/zal prov \
            --log.level=debug \
            --config-path=/etc/zal/prov-config.yml \
            --user="${ZAL_ZABBIX_USERNAME}" \
            --password="${ZAL_ZABBIX_PASSWORD}" \
            --url="${ZAL_ZABBIX_JSONRPC_URL}"
fi
