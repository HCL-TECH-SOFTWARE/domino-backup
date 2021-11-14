@echo off

REM  ----------------------------------------------------------------------
REM  Domino Veeam Integration snapshot backup scrip
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

set TRACEFILE=c:\log\backup_tracefile.log
REM SET TRACEFILE=nul

REM  --- End Configuration ---


set DOMBACK_STATUS_FILE=%DOMINO_DATA_PATH%\dominobackup_snapshot.lck
set DOMBACK_TAG_FILE=%DOMINO_DATA_PATH%\dominobackup_%~7.tag

echo:
echo [%DATE% %TIME%] --- BACKUP SNAPSHOT START ---
echo PhysicalFileName : %1
echo FileName         : %2
echo BackupReference  : %3
echo BackupNode       : %4
echo BackupName       : %5
echo BackupMode       : %6
echo BackupStartDT    : %7
echo BackupTargetDir  : %8
echo RetentionDays    : %9
echo All Paramters    : %*

echo NotesDataDir     : %DOMINO_DATA_PATH%
echo Status File      : %DOMBACK_STATUS_FILE%
echo Tag File         : %DOMBACK_TAG_FILE%
echo:

if not exist "%DOMINO_DATA_PATH%\names.nsf" (
  echo [%DATE% %TIME%] Cannot access data directory [%DOMINO_DATA_PATH%]
  exit /b 1
)

set SNAPSHOT_STATUS=
if exist %DOMBACK_STATUS_FILE% set /p SNAPSHOT_STATUS=<%DOMBACK_STATUS_FILE%
echo [%DATE% %TIME%] STATUS: [%SNAPSHOT_STATUS%] [%0] >> %TRACEFILE%

if "%SNAPSHOT_STATUS%" == "REQUESTED" (

  echo %~7> %DOMBACK_TAG_FILE%
  echo DOMINO-DONE> %DOMBACK_STATUS_FILE%
  echo [%DATE% %TIME%] Domino done
  echo Return: PROCESSED - Snapshot successfully started
  exit /b 0

) else (

  echo Return: ERROR - No backup pending
  exit /b 1
)
