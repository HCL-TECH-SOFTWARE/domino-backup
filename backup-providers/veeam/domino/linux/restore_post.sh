#!/bin/sh

# ----------------------------------------------------------------------
# Domino Veeam backup post script to unmount backups 
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


# --- Begin Configuration ---

# Veeam server ssh connection
VEEAM_SERVER_SSH=notes@192.168.1.1

# Timeout for SSH connection
TIMEOUT=60

# --- End Configuration ---


# Internal variables
SSH_CMD=ssh

# Restore mount path where Veeam mounts restores as a start point to search
VEEAM_RESTORE_BASE_PATH=/tmp


echo "Unmounting snaphots"
timeout $TIMEOUT $SSH_CMD $VEEAM_SERVER_SSH unmount 2>&1


echo "Return: PROCESSED ($TARGET)"

# echo "Return: ERROR - Cannot unmount backups"

exit 0

