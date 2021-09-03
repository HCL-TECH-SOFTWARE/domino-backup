#!/bin/sh

# ----------------------------------------------------------------------
# Domino Snapshot Backup Script
# ----------------------------------------------------------------------

# Copyright 2021 HCL America, Inc.
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
# ----------------------------------------------------------------------


# --- Begin Configuration ---

# Domino data directory
DOMINO_DATA_PATH=/local/notesdata

# Log and trace files
LOGFILE=/local/backup/log/backup_snapshot_start.log
TRACEFILE=/local/backup/log/trace.log

# --- End Configuration ---


# Internal variables
DOMBACK_STATUS_FILE=$DOMINO_DATA_PATH/dominobackup_snapshot.lck
DOMBACK_TAG_FILE=$DOMINO_DATA_PATH/dominobackup_$7.tag


logfile()
{
  if [ -z "$LOGFILE" ]; then return 0; fi
  echo "$@" >> $LOGFILE
}

tracefile()
{
  if [ -z "$TRACEFILE" ]; then return 0; fi
  echo "[$(date '+%F %T')] $@" >> $TRACEFILE
}

write_backup_trace_tags()
{
  local count=0

  while [ $count -lt 60 ];
  do
    DATE_TAG=$(date '+%F %T' |tr ' ' '_' | tr ':' '_')
    echo $DATE_TAG > ${DOMINO_DATA_PATH}/${DATE_TAG}.${count}.trace
    sleep 1
    count=$(expr $count + 1)
  done

}

logfile "[$(date '+%F %T')] --- BACKUP SNAPSHOT START ---"

logfile "--- RESTORE DB ---"
logfile "PhysicalFileName : $1"
logfile "FileName         : $2"
logfile "BackupReference  : $3"
logfile "BackupNode       : $4"
logfile "BackupName       : $5"
logfile "BackupMode       : $6"
logfile "BackupStartDT    : $7"
logfile "BackupTargetDir  : $8"
logfile "Status File      : $DOMBACK_STATUS_FILE"
logfile "Tag File         : $DOMBACK_TAG_FILE"

SNAPSHOT_STATUS=
if [ -e "$DOMBACK_STATUS_FILE" ]; then
  SNAPSHOT_STATUS=$(head -1 $DOMBACK_STATUS_FILE)
fi

logfile "SNAPSHOT_STATUS : $SNAPSHOT_STATUS"

tracefile "STATUS: [$SNAPSHOT_STATUS] [$0]"

if [ "$SNAPSHOT_STATUS" = "REQUESTED" ]; then

  logfile "writing [$7] into [$DOMBACK_TAG_FILE]"
  echo $7 > $DOMBACK_TAG_FILE

  DATE_TAG=$(date '+%F %T' |tr ' ' '_' | tr ':' '_')
  echo $7 > $DOMINO_DATA_PATH/$DATE_TAG.trace

  # make sure all dirty buffers have been written and the file-system contains all data for the snapshot 
  sync
  sleep 2

  logfile "------------------------------------------------------"
  ls -l $DOMINO_DATA_PATH/*.tag >> $LOGFILE
  ls -l $DOMINO_DATA_PATH/*.trace >> $LOGFILE
  ls -l $DOMINO_DATA_PATH/*.nsf >> $LOGFILE
  logfile "------------------------------------------------------"

  echo DOMINO-DONE > $DOMBACK_STATUS_FILE
  logfile "[$(date '+%F %T')] Domino done"
  echo "Return: PROCESSED - Snapshot successfully started"
  exit 0

else

  echo "Return: ERROR - No backup pending"
  exit 1
fi
