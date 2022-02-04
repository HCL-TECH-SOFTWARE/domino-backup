#!/bin/sh

# ----------------------------------------------------------------------
# Domino snapshot delta file prune script
# Last updated: 02.02.2022
# ----------------------------------------------------------------------

# Copyright 2022 HCL America, Inc.
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


log()
{
  #echo $@ >> /tmp/prune.log
  echo $@
}


TARGET=$8/$4/$6/$7

log "[$(date '+%F %T')] --- PRUNE SNAPSHOT ---"
log "PhysicalFileName : $1"
log "FileName         : $2"
log "BackupReference  : $3"
log "BackupNode       : $4"
log "BackupName       : $5"
log "BackupMode       : $6"
log "BackupStartDT    : $7"
log "BackupTargetDir  : $8"
log "TARGET           : $TARGET"


prune_delta_files()
{
  if [ -z "$TARGET" ]; then
    log "no directory name!"
    return 0
  fi

  if [ ! -e "$TARGET" ]; then
    log "directory not found!"
    return 0
  fi

  # Delete delta files first
  find "$TARGET" -type f -name "*.DELTA" -delete

  # Delete empty directories
  find "$TARGET" -type d -empty -delete
}

prune_delta_files

echo "Return: PROCESSED($TARGET)"
exit 1

