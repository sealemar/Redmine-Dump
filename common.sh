#!/bin/bash

. ${HOME}/.config/aws/credentials.dump.sh

REDMINE_DUMP_DIR=/home/ec2-user/dump/redmine
CURRENT_DUMP_LINK=current.db.gz

log() {
    echo `date '+%Y-%m-%d %H:%M:%S'` `basename $0` - $@
}
