@echo off

REM  ----------------------------------------------------------------------
REM  Domino Snapshot Backup Script
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

set TIMEOUT=120
set DOMBACK_STATUS_FILE=%DOMINO_DATA_PATH%\dominobackup_snapshot.lck
set DOMBACK_TAG_FILE=%DOMINO_DATA_PATH%\dominobackup_%~7.tag

set TRACEFILE=nul
REM set TRACEFILE=c:\log\backup_tracefile.log


REM  --- End Configuration ---


if not exist "%DOMINO_DATA_PATH%\names.nsf" (
  echo [%DATE% %TIME%] Cannot access data directory [%DOMINO_DATA_PATH%]
  exit /b 1
)

set SNAPSHOT_STATUS=
if exist %DOMBACK_STATUS_FILE% set /p SNAPSHOT_STATUS=<%DOMBACK_STATUS_FILE%
echo [%DATE% %TIME%] STATUS: [%SNAPSHOT_STATUS%] [%0] >> %TRACEFILE%
echo [%DATE% %TIME%] Waiting until snapshot status created - Status: [%SNAPSHOT_STATUS%]

set /a count = 1

:LOOP

  set SNAPSHOT_STATUS=
  if exist %DOMBACK_STATUS_FILE% set /p SNAPSHOT_STATUS=<%DOMBACK_STATUS_FILE%
  echo [%DATE% %TIME%] STATUS: [%SNAPSHOT_STATUS%] [%0] >> %TRACEFILE%
  echo [%DATE% %TIME%] STATUS: [%SNAPSHOT_STATUS%] COUNT [%count%]

  if "%SNAPSHOT_STATUS%" == "DONE" (

    del /Q %DOMBACK_TAG_FILE%
    echo Return: PROCESSED - Snapshot Done in %count% seconds
	echo [%DATE% %TIME%] Snapshot created after %count% seconds
    echo [%DATE% %TIME%] FINAL SNAPSHOT_STATUS: [%SNAPSHOT_STATUS%]
    exit /b 0
  )

  if %count% geq %TIMEOUT% (
    del /Q %DOMBACK_TAG_FILE%
    echo [%DATE% %TIME%] Return: ERROR - No Snapshot status. Timeout rearched after %TIMEOUT% seconds
    exit /b 1
  )

  set /a count += 1
  REM wait for 1 second -- timeout command cannot be used in background. ping is a well known workaround
  ping -n 2 -w 1 127.0.0.1 > nul

  echo [%DATE% %TIME%] TEST3


goto LOOP

  echo [%DATE% %TIME%] TEST4

del /Q %DOMBACK_TAG_FILE%
echo Return: ERROR - Unexpected snapshot status
exit /b 0
