#!/bin/sh

# ----------------------------------------------------------------------
# Snapshot integration script to signal the snapshot is done
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
TRACEFILE=/local/backup/log/trace.log

# --- End Configuration ---

# Internal variables
DOMBACK_STATUS_FILE=$DOMINO_DATA_PATH/dominobackup_snapshot.lck

tracefile()
{
  if [ -z "$TRACEFILE" ]; then return 0; fi
  echo "[$(date '+%F %T')] $@" >> $TRACEFILE
}

echo DONE > $DOMBACK_STATUS_FILE

echo [$(date '+%F %T')] Snapshot done

tracefile "STATUS: [$SNAPSHOT_STATUS] [$0]"

exit 0
