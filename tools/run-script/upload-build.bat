@echo off

set SCRIPT_FILE="ftp-script.txt"
del %SCRIPT_FILE% 2>NUL

echo open www.haxenme.org>> %SCRIPT_FILE%
echo %1>> %SCRIPT_FILE%
echo %2>> %SCRIPT_FILE%
echo binary>> %SCRIPT_FILE%
echo put ndll\%3 /public_html/haxenme/builds/ndll/%3>> %SCRIPT_FILE%
echo bye>> %SCRIPT_FILE%

@echo on

ftp -s:%SCRIPT_FILE% 

@del %SCRIPT_FILE% 2>NUL