@echo off

REM  ----------------------------------------------------------------------
REM  Domino snapshot backup script to finalize snapshot backup operation
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

REM  --- End Configuration ---


echo:
echo --- BACKUP POST ---
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
echo:

echo Return: PROCESSED 
exit /b 0
