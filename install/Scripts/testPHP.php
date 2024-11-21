<?php
// Script for WinScriptAdv content plugin
// PHP script test  

//$filename = 'd:\qwe.txt'; // Uncomment this if you need to test your script with php.exe in cmd.exe console 


$f = fopen($filename, 'r');

// read first line of file:
$content = fgets($f); 

// Read second line:
$content1 = fgets($f);
fclose($f);
?>