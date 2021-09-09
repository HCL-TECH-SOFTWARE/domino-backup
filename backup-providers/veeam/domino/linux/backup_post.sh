#!/bin/sh

# ----------------------------------------------------------------------
# Domino Backup Snapshot Script to finalize the snapshot backup operation
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

# --- End Configuration ---


# Internal variables
DOMBACK_STATUS_FILE=$DOMINO_DATA_PATH/dominobackup_snapshot.lck


echo "--- POST BACKUP ---"
echo "PhysicalFileName : $1"
echo "FileName         : $2"
echo "BackupReference  : $3"
echo "BackupNode       : $4"
echo "BackupName       : $5"
echo "BackupMode       : $6"
echo "BackupStartDT    : $7"
echo "BackupTargetDir  : $8"
echo "RestoreFileName  : $9"

if [ -e "$DOMBACK_STATUS_FILE" ]; then
  rm -f "$DOMBACK_STATUS_FILE"
fi

echo Return: PROCESSED

exit 0
