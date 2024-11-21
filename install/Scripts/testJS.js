//js script test 
var oFS   = new ActiveXObject( "Scripting.FileSystemObject" );
var oFile = oFS.OpenTextFile( filename, 1);

var ss = oFile.ReadLine();
oFile.Close();
content = ss;