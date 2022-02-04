@echo off

REM  ----------------------------------------------------------------------
REM  Domino snapshot delta file prune script
REM  Last updated: 02.02.2022
REM  ----------------------------------------------------------------------
REM  
REM  Copyright 2022 HCL America, Inc.
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

set TARGET=%~8/%~4/%~6/%~7

echo:
echo [%DATE% %TIME%] --- PRUNE SNAPSHOT ---
echo PhysicalFileName  : %1
echo FileName          : %2
echo BackupReference   : %3
echo BackupNode        : %4
echo BackupName        : %5
echo BackupMode        : %6
echo BackupStartDT     : %7
echo BackupTargetDir   : %8
echo TARGET            : %TARGET%
echo All Paramters     : %*
echo:

if not exist "%TARGET%" (
  echo Return: PROCESSED (%TARGET%)
  exit /b 0
)

REM Delete delta files first
for /f "delims=" %%i in ('dir /s /b %TARGET%\*.DELETA') do echo "%%i"

REM Delete empty directories
for /f "delims=" %%i in ('dir /s /b /ad %TARGET% ^| sort /r') do echo "%%i"

echo Return: PROCESSED (%TARGET%)
exit /b 0

