; Script for WinScriptAdv content plugin
; AutoHotkey script test 

#NoTrayIcon  
; No tray icon when AutoHotKey.exe is running with this script - because it blinks

FileReadLine, content, %filename%, 1 
FileReadLine, content1, %filename%, 2 