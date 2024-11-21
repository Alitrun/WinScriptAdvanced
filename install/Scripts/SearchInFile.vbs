'Script for WinScriptAdv content plugin

'Script author: Petr Judl 
'Searches inside of a file and looks for a value specified by regular expression 

Set fso = CreateObject("Scripting.FileSystemObject") 
Set oTextStream = fso.OpenTextFile(filename) 
Set objRegEx = New RegExp 

With objRegEx 
' This property defines the regular expression or search pattern string that is to be matched during the search 
.Pattern    = "8\d{7}" 
'or Pattern    = "MyWords"
.Global     = False ' False signifies that a search should only find the first occurrence of a match 
.IgnoreCase = False ' False signifies that a search should be case-sensitive 
End With 

' set how long string should be read 
' (e.g. if you know the searched string can only be at the beginning of the file, there is no need to read the whole file) 
If not oTextStream.AtEndOfStream Then sText = oTextStream.Read(210) 

Set Matches = objRegEx.Execute(sText) 

'set Match = Matches(0) 
If Matches.Count > 0 Then 
	content = Matches(0).Value 
Else 
	content = "" ' fill whatever you need to return if the searched value was not found 
End If 

oTextStream.Close