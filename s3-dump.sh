#! /bin/bash

. "/home/ec2-user/.config/aws/credentials.dump.sh"
. "`dirname $0`/common.sh"

AWS_REGION="us-west-1"
DB_DUMP_DIR="${REDMINE_DUMP_DIR}/db"
TO_S3_TEMP_DIR="to-s3"
S3_DUMP_DIR="s3://tiptoes/dump/redmine"

log "--- started ---"

pushd "${DB_DUMP_DIR}" > /dev/null

if [ ! -L "$CURRENT_DUMP_LINK" ] ; then
    log "${DB_DUMP_DIR}/$CURRENT_DUMP_LINK does not exist or is not a symlink"
    popd > /dev/null
    exit 1
fi

currentDump=`readlink ${CURRENT_DUMP_LINK}`
s3DumpDir=`echo $currentDump | sed 's/^\([0-9-]+\)T.\+\.db\.gz$/\1/'`
if [ "${s3DumpDir}" = "${currentDump}" ] ; then
    log "DB dump pattern was not found"
    s3DumpDir="`date '+%Y-%m-%d'`"
fi
popd > /dev/null

log "Will dump $s3DumpDir"

pushd "${REDMINE_DUMP_DIR}" > /dev/null
s3DumpDirPath="$TO_S3_TEMP_DIR/$s3DumpDir"
mkdir -p "$s3DumpDirPath"
fullDumpFilename="${s3DumpDirPath}/files.tar.bz2"

log "Copying db dump"
cp "${DB_DUMP_DIR}/${currentDump}" "${s3DumpDirPath}/db.gz"

log "Archiving files"
tar -cjf "${fullDumpFilename}" files

log "Dumping to S3"
aws s3 cp --recursive ${s3DumpDirPath} ${S3_DUMP_DIR}/${s3DumpDir} --region=$AWS_REGION
res=$?

log "Removing `pwd`/$TO_S3_TEMP_DIR"
rm -fr "$TO_S3_TEMP_DIR"
popd > /dev/null

[ $res -eq 0 ] && \
    log "${s3DumpDir} has been successfully dumped to ${S3_DUMP_DIR}" || \
    log "failed to dump ${s3DumpDir} to ${S3_DUMP_DIR}"

log "--- finished ---"
