#!/bin/bash

REDMINE_HOME=/var/www/redmine
REDMINE_DUMP_DIR=/home/ec2-user/dump/redmine
CURRENT_DUMP_LINK=current.db.gz

# per official backup guidelines at
# http://www.redmine.org/projects/redmine/wiki/RedmineInstall#Backups

log() {
    echo `date '+%Y-%m-%d %H:%M:%S'` - $@
}

updateSymlink() {
    # drop the dump if it mathces the previous one
    if [ -L "$CURRENT_DUMP_LINK" ] ; then
        oldDumpSum=`gunzip -c "$CURRENT_DUMP_LINK" | sha256sum - | cut -f 1 -d ' '`
        newDumpSum=`gunzip -c "$DB_DUMP_FILE" | sha256sum - | cut -f 1 -d ' '`
        if [ $oldDumpSum = $newDumpSum ] ; then
            rm "$DB_DUMP_FILE"
            log "RedMine DB dump: $DB_DUMP_FILE was dropped as it matched $CURRENT_DUMP_LINK"
            return 0
        fi
    fi

    if [ -e "$CURRENT_DUMP_LINK" -a ! -L "$CURRENT_DUMP_LINK" ] ; then
        log "RedMine DB dump - warning: $CURRENT_DUMP_LINK exists, but is not a symlink"
        return 1
    fi

    ln -sf "$DB_DUMP_FILE" "$CURRENT_DUMP_LINK"

    return $?
}

dumpDb() {
    DB_DUMP_DIR="${DUMP_DIR}/db"
    mkdir -p "$DB_DUMP_DIR"
    DB_DUMP_PATH="${DB_DUMP_DIR}/${DB_DUMP_FILE}"

    pg_dump -U redmine redmine | gzip -9 > "$DB_DUMP_PATH" && {
        log "RedMine DB dump: successfully dumped to $DB_DUMP_PATH"

        pushd "$DB_DUMP_DIR" > /dev/null
        updateSymlink
        popd > /dev/null

        return 0
    } || {
        log "RedMine DB dump: failed"
    }
    return 1
}

dumpFiles() {
    rsync -a files "${DUMP_DIR}" && {
        log "RedMine files dump: successfully dumped to ${DUMP_DIR}/files"
        return 0
    } || {
        log "RedMine files dump: failed"
    }
    return $?
}


#
# main
#

log "--- started ---"

pushd "$REDMINE_HOME" > /dev/null

DUMP_DATE_TIME=`date '+%Y-%m-%dT%H:%M:%S'`
DB_DUMP_FILE="${DUMP_DATE_TIME}.db.gz"
DUMP_DIR=$REDMINE_DUMP_DIR

dumpDb && dumpFiles && {
    log "Redmine: dumped successfully on ${DUMP_DATE_TIME}"
} || {
    log "Redmine: failed to dump on ${DUMP_DATE_TIME}"
}

popd > /dev/null

log "--- finished ---"
