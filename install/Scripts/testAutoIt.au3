; Script for WinScriptAdv content plugin
; AutoIt script test 

#NoTrayIcon
#include <WinAPIFiles.au3>

Local $hFileOpen = FileOpen($filename, $FO_READ)

; Read the fist line of the file
Local $content = FileReadLine($hFileOpen, 1)

; Read the second line of the file
Local $content1 = FileReadLine($hFileOpen, 2)

FileClose($hFileOpen)
