#!/bin/sh

# ----------------------------------------------------------------------
# Domino Backup Snaphot trigger script to bring all databases into backup mode
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

# Domino Binary directory
LOTUS=/opt/hcl/domino

# Domino data directory
DOMINO_DATA_PATH=/local/notesdata

# Domino user
DOMINO_USER=notes

# Timeout to bring databases into backup mode
TIMEOUT=120

# Log and trace files
TRACEFILE=/tmp/dominoveeam_trace.log

# --- End Configuration ---


# Internal variables
DOMBACK_STATUS_FILE=$DOMINO_DATA_PATH/dominobackup_snapshot.lck

tracefile()
{
  if [ -z "$TRACEFILE" ]; then return 0; fi
  echo "[$(date '+%F %T')] $@" >> $TRACEFILE
}

SNAPSHOT_STATUS=
if [ -e "$DOMBACK_STATUS_FILE" ]; then
  SNAPSHOT_STATUS=$(head -1 $DOMBACK_STATUS_FILE)
fi

tracefile "STATUS: [$SNAPSHOT_STATUS] [$0]"

echo REQUESTED > $DOMBACK_STATUS_FILE
tracefile "NewStatus: REQUESTED"
echo [$(date '+%F %T')] Snapshot requested

# Remember current directory
CURRENT_DIR=$(pwd)
cd $DOMINO_DATA_PATH

if [ "$LOGNAME" = "root" ]; then
  su - $DOMINO_USER -c "cd $DOMINO_DATA_PATH; $LOTUS/bin/server -c 'load backup -s'"
else
  $LOTUS/bin/server -c 'load backup -s'
fi

# Switch back to original path
cd $CURRENT_DIR

# Now wait for Domino Backup to return that all databases are in backup mode

count=0
while true
do
  SNAPSHOT_STATUS=
  if [ -e "$DOMBACK_STATUS_FILE" ]; then
    SNAPSHOT_STATUS=$(head -1 $DOMBACK_STATUS_FILE)
  fi

  tracefile "STATUS: [$SNAPSHOT_STATUS] [$0]"

  if [ "$SNAPSHOT_STATUS" = "DOMINO-DONE" ]; then
    tracefile "Snapshot successfully started after $count seconds"
    echo "[$(date '+%F %T')] Snapshot started after $count seconds"
    exit 0
  fi

  if [ $count -ge $TIMEOUT ]; then
    tracefile "ERROR: Cannot start snapshot on Domino server - Timeout reached"
    exit 1
  fi

  sleep 1
  count=$(expr $count + 1)
done

exit 0
