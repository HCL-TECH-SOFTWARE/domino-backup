@echo off

REM  ----------------------------------------------------------------------
REM  Veeam integration script to trigger Domino Backup to bring all databases into backup mode (called by pree-freeze.cmd)
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

set LOTUS=C:\Program Files\HCL\Domino
set LOTUS=c:\domino
set DOMINO_DATA_PATH=e:\notesdata

set TIMEOUT=120
set DOMBACK_STATUS_FILE=%DOMINO_DATA_PATH%\dominobackup_snapshot.lck

set LOGFILE=c:\log\backup_domino_snapshot.log
REM SET LOGFILE=nul

set TRACEFILE=c:\log\backup_tracefile.log

REM SET TRACEFILE=nul

REM  --- End Configuration ---


if not exist "%DOMINO_DATA_PATH%\names.nsf" (
  echo [%DATE% %TIME%] Cannot access data directory [%DOMINO_DATA_PATH%] >> %LOGFILE%
  exit /b 1
)

set SNAPSHOT_STATUS=
if exist %DOMBACK_STATUS_FILE% set /p SNAPSHOT_STATUS=<%DOMBACK_STATUS_FILE%
echo [%DATE% %TIME%] STATUS: [%SNAPSHOT_STATUS%] [%0] >> %TRACEFILE%

echo REQUESTED> %DOMBACK_STATUS_FILE%

echo [%DATE% %TIME%] Snapshot requested >> %LOGFILE%

set CURRENT_DIR=%CD%
cd /D %DOMINO_DATA_PATH%
%LOTUS%\nserver.exe -c "load backup -s"
cd /D %CURRENT_DIR%

set /a count = 1

:LOOP

  set SNAPSHOT_STATUS=
  if exist %DOMBACK_STATUS_FILE% set /p SNAPSHOT_STATUS=<%DOMBACK_STATUS_FILE%
  echo [%DATE% %TIME%] STATUS: [%SNAPSHOT_STATUS%] [%0] >> %TRACEFILE%

  if "%SNAPSHOT_STATUS%" == "DOMINO-DONE" (
    echo Snapshot successfully started after %count% seconds
	echo [%DATE% %TIME%] Snapshot started after %count% seconds >> %LOGFILE%
    exit /b 0
  )

  if %count% geq %TIMEOUT% (
    echo [%DATE% %TIME%] Cannot start snapshot on Domino server - Timeout rearched >> %LOGFILE%
    exit /b 1
  )

  set /a count += 1
  timeout /T 1 /NOBREAK > nul

goto LOOP

exit /b 0
