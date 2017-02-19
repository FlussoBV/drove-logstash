#!/usr/bin/env bash

LOGNAME=DROVE-LOG
PREFIX=drove
ES_IMAGE=elasticsearch:2.4
ES_SERVICE=${PREFIX}-es
LS_IMAGE=caladreas/logstash
LS_SERVICE=${PREFIX}-ls
KIBANA_IMAGE=kibana:4.6
KIBANA_SERVICE=${PREFIX}-kibana
LOGSPOUT_SERVICE=${PREFIX}-spout
LOGSPOUT_IMAGE=gliderlabs/logspout
NETWORK=drove
STACK=drove-log

EXISTING=`docker service ls | grep -c $ES_SERVICE`
if [ $EXISTING -gt 0 ]
then
    echo "[${LOGNAME}] service $ES_SERVICE already exists"
else
    echo "[${LOGNAME}] service $ES_SERVICE does not exist, creating"
    docker service create \
        --name ${ES_SERVICE} \
        --network ${NETWORK} \
        --publish 9200:9200 \
        --label com.docker.stack.namespace=$STACK \
        --container-label com.docker.stack.namespace=$STACK \
        ${ES_IMAGE}
fi

EXISTING=`docker service ls | grep -c $LS_SERVICE`
if [ $EXISTING -gt 0 ]
then
    echo "[${LOGNAME}] service $LS_SERVICE already exists"
else
    echo "[${LOGNAME}] service $LS_SERVICE does not exist, creating"
    docker service create \
        --name ${LS_SERVICE} \
        --network ${NETWORK} \
        -e LOGSPOUT=ignore \
        --label com.docker.stack.namespace=$STACK \
        --container-label com.docker.stack.namespace=$STACK \
        ${LS_IMAGE} logstash -f /conf/logstash.conf
fi

EXISTING=`docker service ls | grep -c $KIBANA_SERVICE`
if [ $EXISTING -gt 0 ]
then
    echo "[${LOGNAME}] service $KIBANA_SERVICE already exists"
else
    echo "[${LOGNAME}] service $KIBANA_SERVICE does not exist, creating"
    docker service create \
        --name ${KIBANA_SERVICE} \
        --network ${NETWORK} \
        -e ELASTICSEARCH_URL=http://${ES_SERVICE}:9200 \
        --reserve-memory 50m \
        --publish 5601:5601 \
        --label com.docker.stack.namespace=$STACK \
        --container-label com.docker.stack.namespace=$STACK \
        ${KIBANA_IMAGE}
fi

EXISTING=`docker service ls | grep -c $LOGSPOUT_SERVICE`
if [ $EXISTING -gt 0 ]
then
    echo "[${LOGNAME}] service $LOGSPOUT_SERVICE already exists"
else
    echo "[${LOGNAME}] service $LOGSPOUT_SERVICE does not exist, creating"
    docker service create \
        --name ${LOGSPOUT_SERVICE} \
        --network ${NETWORK} \
        --mode global \
        --mount "type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock" \
        -e SYSLOG_FORMAT=rfc3164 \
        --label com.docker.stack.namespace=$STACK \
        --container-label com.docker.stack.namespace=$STACK \
        ${LOGSPOUT_IMAGE} syslog://${LS_SERVICE}:51415
fi