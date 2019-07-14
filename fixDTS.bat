rem mkv2vob program was used to convert videos with DTS to play in PS3. These files do not play in devices other than PS3. 
rem This program will undo the changes done and convert to mkv which all modern players can play. This fixes only files with DTS identified by LPCM.
@echo off

rem source root directory under which affected mpg files are found. The program will recursively search under this directory
rem This directory should end with \
SET SOURCEROOT=D:\VIDEO\

rem if a file is fixed, the original file is backed up in this directory
rem this directory cannot be a sub directory of SOURCEROOT
rem This directory should end with \
SET BACKUPROOT=D:\backup\

rem if a subdirectory under the source root only should be processed, set this directory, otherwise you can leave it empty. This will help to test before you process whole library.
rem This directory should end with \
SET SOURCESUBDIR=xxx\yyy\
rem SET SOURCESUBDIR=    to process all files

rem this is a temp folder in which various file processing are done
SET WORKDIR=C:\Users\temp\dtsprocess\

rem you need to download these applications and update the correct path here
set TSMUXER=C:\Users\xxx\tsmuxer\tsMuxeR.exe
set EAC3TO=C:\Users\xxx\eac3to334-UsEac3to129\eac3to.exe
set MKVMERGE=C:\Users\xxx\mkvtoolnix\mkvmerge
set TSREMUX=C:\Users\xxx\TsRemux0212.exe

rem ###############  Do NOT Update after this line #################

if not exist "%SOURCEROOT%%SOURCESUBDIR%" (
   echo Folder does not exist "%SOURCEROOT%%SOURCESUBDIR%"
   exit /B
)
   
cd /D %SOURCEROOT%%SOURCESUBDIR%

rem find all mpg files
for /r %%a in (*.mpg) do (

echo processing file "%%a" ...

rem In network drives, sometimes this helps to wake up drive
if not exist %%a (
 echo file not acessible, waiting
 TIMEOUT 10
 if not exist %%a (
   echo file still not found
 )
)

setlocal ENABLEDELAYEDEXPANSION

rem check if file already processed
set backupDir=%%~dpa
set backupDir=!backupDir:%SOURCEROOT%=%BACKUPROOT%!
set backupFile=!backupDir!%%~na.mpg
echo !backupFile!

if exist "!backupFile!" (
  echo file already processed    
) else (

rem if ac3 track found, then no need to convert
echo %TSMUXER% "%%a"
%TSMUXER% "%%a" > "%WORKDIR%media.txt"

for /f "tokens=3 delims= " %%G in (%WORKDIR%media.txt) do (
  if "%%G" == "AC3" (
    echo AC3 found skipping
    set ac3Found=true
  )
)

if NOT "!ac3Found!" == "true" (

echo dts found
rem pause
rem exit /B

rem remux the file
%TSREMUX% "%%a" "%WORKDIR%%%~na.m2ts"

if not exist "%WORKDIR%%%~na.m2ts" (
    echo Error creating "%WORKDIR%%%~na.m2ts" , skipping
) else (
   
   
rem get track info
echo %TSMUXER% "%WORKDIR%%%~na.m2ts"
%TSMUXER% "%WORKDIR%%%~na.m2ts" > "%WORKDIR%media.txt"

set /a x=0

rem extract track number, track type from media info
for /f "tokens=3 delims= " %%G in (%WORKDIR%media.txt) do (
  set mediaInfo[!x!]=%%G
  set /a "x+=1"
  rem echo !x!
  rem call echo %%mediaInfo[!x!]%%
)

rem echo xx !mediaInfo[1]!
rem echo xx !mediaInfo[3]!
rem echo xx !mediaInfo[5]!
rem echo xx !mediaInfo[7]!


rem create meta file
@echo MUXOPT --demux > %WORKDIR%yourscript.meta
@echo !mediaInfo[3]!, "%WORKDIR%%%~na.m2ts", insertSEI, contSPS, track=!mediaInfo[1]! >> %WORKDIR%yourscript.meta
@echo !mediaInfo[7]!, "%WORKDIR%%%~na.m2ts", track=!mediaInfo[5]!  >> %WORKDIR%yourscript.meta

rem extract video and audio from source
@call %TSMUXER% %WORKDIR%yourscript.meta %WORKDIR%

cd /D %WORKDIR%

for /r %%b in (*.264) do (
set videoFile=%%~nb
rem echo !videoFile!
)
echo Found !videoFile!

for /r %%b in (*.wav) do (
set audioFile=%%~nb
rem echo !audioFile!
)
echo Found !audioFile!

rem if dts track found, then it will be a wav file. Fix, dts only. Others do not need any fix
IF NOT "!audioFile!" == "" (

   @call %EAC3TO% "%WORKDIR%!audioFile!.wav"  "%WORKDIR%!audioFile!.dts"
	
   @call %MKVMERGE% -o "%WORKDIR%%%~na.mkv" "%WORKDIR%!videoFile!.264" "%WORKDIR%!audioFile!.dts"
   echo moving mkv file to destination
   move "%WORKDIR%%%~na.mkv" "%%~da%%~pa%%~na.mkv"

   if not exist "!backupDir!" (
      md "!backupDir!"
   )
    
   echo move "%%a" "!backupDir!"
   move "%%a" "!backupDir!"

) ELSE (
  echo Skipping file since AC3
)

rem m2ts failed
)

rem ac3 found
)

rem backup file exists
)

rem cleanup working dir
del /F /Q %WORKDIR%*.*

echo COMPLETED file "%%a"  ###########################

endlocal
)
