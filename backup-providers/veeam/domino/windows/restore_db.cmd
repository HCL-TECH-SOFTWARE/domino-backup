@echo off

REM  ----------------------------------------------------------------------
REM  Domino Veeam database and *.DELTA file restore script
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

set VEEAM_SERVER_SSH=notes@192.168.1.1
set VEEAM_RESTORE_BASE_PATH=c:\VeeamFLR

REM  --- End Configuration ---

REM Change Code Page to UTF-8
chcp 65001

set TARGET=%~9
set FILE_EXT=%~x9

REM Unique tag used to verify/identify the backup when mounted
set DOMBACK_TAG_FILE=dominobackup_%~7.tag

echo:
echo [%DATE% %TIME%] --- RESTORE DB from SNAPSHOT ---
echo PhysicalFileName  : %1
echo FileName          : %2
echo BackupReference   : %3
echo BackupNode        : %4
echo BackupName        : %5
echo BackupMode        : %6
echo BackupStartDT     : %7
echo BackupTargetDir   : %8
echo RestoreFileName   : %9
echo All Paramters     : %*
echo:

REM Delta files are restored from a different location

if "%FILE_EXT%"==".DELTA" (
  echo Found DELTA Extension

  set SOURCE=%~8/%~4/%~6/%~7/%~2
  echo SOURCE: [%SOURCE%]

  if not "%SOURCE%" == "" (
	echo xcopy /Y "%SOURCE%" "%TARGET%*"
	xcopy /Y "%SOURCE%" "%TARGET%*" 2>&1
  )
  
  goto :DONE
)

echo "Restore operations from snapshot"

REM Ensure the restore requestalways uses a .DAD extension 

if "%FILE_EXT%"==".DAD" (
  echo Already has .DAD extension
) else (
  echo Appending missing .DAD extension
  set TARGET=%TARGET%.DAD
)

REM Search mounted directories for backup tag file to verify the right mount and get the Domino data directory

set FOUND_FILE_PATH=
set FOUND_NOTESDATA=

echo Searching for backup tag before mounting [%DOMBACK_TAG_FILE%]
  
REM Search the restore location for the tag file and terminate when found the first hit

for /r "%VEEAM_RESTORE_BASE_PATH%" %%a in (%DOMBACK_TAG_FILE%) DO (
  if exist "%%~fa" (
    set FOUND_FILE_PATH=%%~fa
    set FOUND_NOTESDATA=%%~dpa
    goto :EXIT_FOR
  )
)

REM If not found mount the right snapshot

echo:
echo [%DATE% %TIME%] ----- Begin Mounting snaphot ----- 
ssh %VEEAM_SERVER_SSH% mount %7 2>&1
echo [%DATE% %TIME%] ----- End Mounting snaphot ----- 
echo:

REM search the restore location for the tag file and terminate when found the first hit

echo Searching for backup tag after mounting [%DOMBACK_TAG_FILE%]
  
for /r "%VEEAM_RESTORE_BASE_PATH%" %%a in (%DOMBACK_TAG_FILE%) DO (
  if exist "%%~fa" (
    set FOUND_FILE_PATH=%%~fa
    set FOUND_NOTESDATA=%%~dpa
    goto :EXIT_FOR
  )
)

:EXIT_FOR

echo:
echo ----- Search Results ----- 
echo TARGET            : %TARGET%
echo FOUND_FILE_PATH   : [%FOUND_FILE_PATH%]
echo FOUND_NOTESDATA   : [%FOUND_NOTESDATA%]
echo ----- Search Results ----- 
echo:

if not "%FOUND_NOTESDATA%" == "" (
  set SOURCE=%FOUND_NOTESDATA%%~2
)
 
echo SOURCE: [%SOURCE%]

REM copy the file from mount always needs to use xcopy with a trailing * to ensure the target is always assumed as a file not directory

if not "%SOURCE%" == "" (
  echo xcopy /Y "%SOURCE%" "%TARGET%*"
  xcopy /Y "%SOURCE%" "%TARGET%*" 2>&1
)


:DONE

echo:

if exist "%TARGET%" (
  echo Return: PROCESSED (%TARGET%)
  exit /b 0
)

echo "Return: ERROR - Cannot copy file"

echo [%DATE% %TIME%] --- RESTORE DB from SNAPSHOT completed ---
echo:

exit /b 1
