#! /usr/bin/env sh

DEST=${AWS_S3_MOUNT:-/opt/geesefs/bucket}
. trap.sh

tail -f /dev/null
