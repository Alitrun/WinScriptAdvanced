# Script for WinScriptAdv content plugin
# PowerShell script test

$file = new-object System.IO.StreamReader($filename)
$content = $file.ReadLine()
$content1 = $file.ReadLine()
$file.close()