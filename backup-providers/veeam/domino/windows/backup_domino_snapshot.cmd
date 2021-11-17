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
set DOMINO_DATA_PATH=e:\notesdata

set TIMEOUT=120
set DOMBACK_STATUS_FILE=%DOMINO_DATA_PATH%\dominobackup_snapshot.lck

REM Use psexec Microsoft Systinternals helper tool to start processes via system account
REM See https://docs.microsoft.com/en-us/sysinternals/downloads/psexec for details

REM set PSEXEC_BIN=
set PSEXEC_BIN=c:\psexec.exe

set LOGFILE=nul
REM set LOGFILE=c:\log\backup_domino_snapshot.log

set TRACEFILE=nul
REM set TRACEFILE=c:\log\backup_tracefile.log

REM  --- End Configuration ---


REM Sanity check if data directory exists
if not exist "%DOMINO_DATA_PATH%\names.nsf" (
  echo [%DATE% %TIME%] Cannot access data directory [%DOMINO_DATA_PATH%] >> %LOGFILE%
  exit /b 1
)


REM Check if Domino server is running. Backup is always started in server context and should not run if the server is stopped.
tasklist /fi "imagename eq nserver.exe" /fo csv | findstr /i nserver.exe >nul 2>nul

if "%errorlevel%"=="0" (

  echo [%DATE% %TIME%] Domino server is running >> %LOGFILE%

) else (

  echo [%DATE% %TIME%] Domino server is not running - No nserver.exe process found >> %LOGFILE%
  exit /b 1

)

set SNAPSHOT_STATUS=
if exist %DOMBACK_STATUS_FILE% set /p SNAPSHOT_STATUS=<%DOMBACK_STATUS_FILE%
echo [%DATE% %TIME%] STATUS: [%SNAPSHOT_STATUS%] [%0] >> %TRACEFILE%

echo REQUESTED> %DOMBACK_STATUS_FILE%

echo [%DATE% %TIME%] Snapshot requested >> %LOGFILE%


REM Start backup operation via load command invokes the backup task in server context

if "%PSEXEC_BIN%"=="" (

  cd /D %DOMINO_DATA_PATH%

  "%LOTUS%\nserver.exe" -c "load backup -s"

) else (

  REM Run operation as system account and don't wait for termination
   echo "-- Before PSEXEC launching backup servertask --"
  %PSEXEC_BIN% -w %DOMINO_DATA_PATH% -d -s "%LOTUS%\nserver.exe" -c "load backup -s"
   echo "-- After PSEXEC launching backup server task --"

)

REM Wait for snapshot completed by checking the status file


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
  REM wait for 1 second -- timeout command cannot be used in background. ping is a well known workaround
  ping -n 2 -w 1 127.0.0.1 > nul

goto LOOP

exit /b 0
