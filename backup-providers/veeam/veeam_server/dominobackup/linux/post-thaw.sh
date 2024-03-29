#!/bin/sh

# ----------------------------------------------------------------------
# Domino Linux Veeam post thaw script
# Last updated: 22.10.2021
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

# This script is uploaded to the Domino on Linux server by Veeam.
# It is executed and the server to unfreeze Domino databases after snapshot.
# This script is the integration script on the Veeam side to call the actual scripts
# which are located on the Domino on Linux server in /opt/hcl/domino/backup/veeam.

SCRIPT_NAME=/opt/hcl/domino/backup/veeam/backup_domino_snapshot_done.sh
TRACEFILE=/tmp/dominoveeam_trace.log

echo "[$(date '+%F %T')] Veeam script [$0] executed" >> $TRACEFILE 2>&1
echo "[$(date '+%F %T')] [$0] running [$SCRIPT_NAME]" >> $TRACEFILE 2>&1

$SCRIPT_NAME >> $TRACEFILE 2>&1

RET=$?
echo "[$(date '+%F %T')] [$0] STATUS returned: [$RET]" >> $TRACEFILE 2>&1

exit $RET

