@echo off

REM  ----------------------------------------------------------------------
REM  Veeam integration script to signal the snapshot is done (called by post-thaw.cmd)
REM  Last updated: 12.11.2021
REM  ----------------------------------------------------------------------
REM  
REM  Copyright 2021 HCL America, Inc.
REM  
REM  Licensed to the Apache Software Foundation (ASF) under one
REM  or more contributor license agreements.  See the NOTICE file
REM  distributed with this work for additional information
REM  regarding copyright ownership.  The ASF licenses this file
REM  to you under the Apache License, Version 2.0 (the
REM  "License"); you may not use this file except in compliance
REM  with the License.  You may obtain a copy of the License at
REM  
REM    http://www.apache.org/licenses/LICENSE-2.0
REM  
REM  Unless required by applicable law or agreed to in writing,
REM  software distributed under the License is distributed on an
REM  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
REM  KIND, either express or implied.  See the License for the
REM  specific language governing permissions and limitations
REM  under the License.
REM  ----------------------------------------------------------------------

REM  --- Begin Configuration ---

set DOMINO_DATA_PATH=e:\notesdata
set DOMBACK_STATUS_FILE=%DOMINO_DATA_PATH%\dominobackup_snapshot.lck

set LOGFILE=nul
REM set LOGFILE=c:\log\backup_domino_snapshot_done.log


REM  --- End Configuration ---

REM Sanity check if data directory exists
if not exist "%DOMINO_DATA_PATH%\names.nsf" (
  echo [%DATE% %TIME%] Cannot access data directory [%DOMINO_DATA_PATH%] >> %LOGFILE%
  exit /b 1
)

echo DONE> %DOMBACK_STATUS_FILE%

echo "[%DATE% %TIME%] Snapshot done" >> %LOGFILE%

exit /b 0
