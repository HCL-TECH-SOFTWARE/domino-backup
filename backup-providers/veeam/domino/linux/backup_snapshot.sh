#!/bin/sh

# ----------------------------------------------------------------------
# Domino Snapshot Backup Script
# Last updated: 21.10.2021
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

# Timeout to wait for the snapshot to be created
TIMEOUT=120

# Log and trace files
TRACEFILE=/tmp/dominoveeam_trace.log

# --- End Configuration ---


# Internal variables
DOMBACK_STATUS_FILE=$DOMINO_DATA_PATH/dominobackup_snapshot.lck
DOMBACK_TAG_FILE=$DOMINO_DATA_PATH/dominobackup_$7.tag


tracefile()
{
  if [ -z "$TRACEFILE" ]; then return 0; fi
  echo "[$(date '+%F %T')] $@" >> $TRACEFILE
}

SNAPSHOT_STATUS=
if [ -e "$DOMBACK_STATUS_FILE" ]; then
  SNAPSHOT_STATUS=$(head -1 $DOMBACK_STATUS_FILE)
fi


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

remove_tag_file()
{
  if [ -e "$DOMBACK_TAG_FILE" ]; then
    rm -f "$DOMBACK_TAG_FILE"
    echo "Removed tag file [$DOMBACK_TAG_FILE]"
  fi
}


tracefile "STATUS: [$SNAPSHOT_STATUS] [$0]"
tracefile "Waiting until snapshot status created - Status: [$SNAPSHOT_STATUS]"

count=0
while true
do
  SNAPSHOT_STATUS=
  if [ -e "$DOMBACK_STATUS_FILE" ]; then
    SNAPSHOT_STATUS=$(head -1 $DOMBACK_STATUS_FILE)
  fi

  tracefile "STATUS: [$SNAPSHOT_STATUS] [$0]"

  if [ "$SNAPSHOT_STATUS" = "DONE" ]; then

	remove_tag_file

    tracefile "Snapshot created after $count seconds"
    tracefile "FINAL SNAPSHOT_STATUS: [$SNAPSHOT_STATUS]"

    echo "Return: PROCESSED - Snapshot Done in $count seconds"
    echo "[$(date '+%F %T')] Snapshot created after $count seconds"
    echo "[$(date '+%F %T')] FINAL SNAPSHOT_STATUS: [$SNAPSHOT_STATUS]"

    exit 0
  fi

  if [ $count -ge $TIMEOUT ]; then

	remove_tag_file

    echo "Return: ERROR - No Snapshot status. Timeout reached"
    tracefile "Return: ERROR - No Snapshot status. Timeout reached"
    exit 1
  fi

  sleep 1
  count=$(expr $count + 1)
done

remove_tag_file

echo Return: ERROR
tracefile "ERROR returned"

exit 0
