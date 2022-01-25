exit_script() {
    SIGNAL=$1
    echo "Caught $SIGNAL! Unmounting ${DEST}..."
    fusermount -uz ${DEST}
    geesefs=$(ps -o pid= -o comm= | grep geesefs | sed -E 's/\s*(\d+)\s+.*/\1/g')
    if [ -n "$geesefs" ]; then
        echo "Forwarding $SIGNAL to $geesefs"
        kill -$SIGNAL $geesefs
    fi
    trap - $SIGNAL # clear the trap
    exit $?
}

trap "exit_script INT" INT
trap "exit_script TERM" TERM
