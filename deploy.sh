#!/bin/bash

CLUSTERNAME="dcvdemo"
S3_BUCKETNAME="devin-hpcscripts1234"
# TODO: fix security group to have open https/http ports
SECURITYGROUP_RSW="sg-0ebc93e160de95498"
SUBNETID="subnet-05b2495f54b720cd4"
REGION="us-east-2"
KEY="devin.pastoor"
CERT="~/.ssh/devin.pastoor.pem"

cat scripts/aliases.tmpl | sed "s#CERT#${CERT}#" > scripts/aliases.sh
aws s3 cp scripts/ s3://${S3_BUCKETNAME} --recursive --exclude security-group.sh --exclude *.tmpl --exclude aliases.sh 

# cat config/cluster-config-wb.tmpl | \
# 	sed "s#S3_BUCKETNAME#${S3_BUCKETNAME}#g" | \
#         sed "s#SECURITYGROUP_RSW#${SECURITYGROUP_RSW}#g" | \
#         sed "s#SUBNETID#${SUBNETID}#g" | \
#         sed "s#REGION#${REGION}#g" | \
#         sed "s#KEY#${KEY}#g"  \
# 	> config/cluster-config-wb.yaml
pcluster create-cluster --cluster-name="$CLUSTERNAME" --cluster-config=config/cluster-config-wb.yaml --rollback-on-failure false 

