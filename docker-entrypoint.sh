#! /usr/bin/env sh

# Where are we going to mount the remote bucket resource in our container.
DEST=${AWS_S3_MOUNT:-/opt/geesefs/bucket}

# Check variables and defaults
if [ -z "${AWS_S3_ACCESS_KEY_ID}" -a -z "${AWS_S3_SECRET_ACCESS_KEY}" -a -z "${AWS_S3_SECRET_ACCESS_KEY_FILE}" -a -z "${AWS_S3_AUTHFILE}" ]; then
    echo "You need to provide some credentials!!"
    exit
fi
if [ -z "${AWS_S3_BUCKET}" ]; then
    echo "No bucket name provided!"
    exit
fi
if [ -z "${AWS_S3_URL}" ]; then
    AWS_S3_URL="https://storage.yandexcloud.net"
fi

if [ -n "${AWS_S3_SECRET_ACCESS_KEY_FILE}" ]; then
    AWS_S3_SECRET_ACCESS_KEY=$(read ${AWS_S3_SECRET_ACCESS_KEY_FILE})
fi

# Create or use authorisation file
if [ -z "${AWS_S3_AUTHFILE}" ]; then
    AWS_S3_AUTHFILE=/opt/geesefs/passwd-geesefs
    echo "[default]" > ${AWS_S3_AUTHFILE}
    echo "aws_access_key_id = ${AWS_S3_ACCESS_KEY_ID}" >> ${AWS_S3_AUTHFILE}
    echo "aws_secret_access_key = ${AWS_S3_SECRET_ACCESS_KEY}" >> ${AWS_S3_AUTHFILE}
    chmod 600 ${AWS_S3_AUTHFILE}
fi

# forget about the password once done (this will have proper effects when the
# PASSWORD_FILE-version of the setting is used)
if [ -n "${AWS_S3_SECRET_ACCESS_KEY}" ]; then
    unset AWS_S3_SECRET_ACCESS_KEY
fi

# Create destination directory if it does not exist.
if [ ! -d $DEST ]; then
    mkdir -p $DEST
fi

GROUP_NAME=$(getent group "${GID}" | cut -d":" -f1)

# Add a group
if [ $GID -gt 0 -a -z "${GROUP_NAME}" ]; then
    addgroup -g $GID -S $GID
    GROUP_NAME=$GID
fi

# Add a user
if [ $UID -gt 0 ]; then
    adduser -u $UID -D -G $GROUP_NAME $UID
    RUN_AS=$UID
    chown $UID:$GID $AWS_S3_MOUNT
    chown $UID:$GID ${AWS_S3_AUTHFILE}
    chown $UID:$GID /opt/geesefs
    chown $UID:$GID /dev/stderr
fi

# Debug options
DEBUG_OPTS=
if [ $GEESEFS_DEBUG = "1" ]; then
    DEBUG_OPTS="--debug --debug_fuse --debug_s3"
fi

# Additional geesefs options
if [ -n "$GEESEFS_ARGS" ]; then
    GEESEFS_ARGS="-o $GEESEFS_ARGS"
fi

# Mount and verify that something is present. davfs2 always creates a lost+found
# sub-directory, so we can use the presence of some file/dir as a marker to
# detect that mounting was a success. Execute the command on success.

su - $RUN_AS -c "geesefs $DEBUG_OPTS ${GEESEFS_ARGS} \
    --log-file stderr \
    --shared-config=${AWS_S3_AUTHFILE} \
    --endpoint ${AWS_S3_URL} \
    --uid=$UID \
    --gid=$GID \
    ${AWS_S3_BUCKET} ${AWS_S3_MOUNT}"

# geesefs can claim to have a mount even though it didn't succeed.
# Doing an operation actually forces it to detect that and remove the mount.
ls "${AWS_S3_MOUNT}"

mounted=$(mount | grep fuse.geesefs | grep "${AWS_S3_MOUNT}")
if [ -n "${mounted}" ]; then
    echo "Mounted bucket ${AWS_S3_BUCKET} onto ${AWS_S3_MOUNT}"
    exec "$@"
else
    echo "Mount failure"
fi
