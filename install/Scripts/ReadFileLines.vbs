'VBscript for Total Commander with WinScriptAdv content plugin  
'     Plugin Download: http://www.totalcmd.net/plugring/script_wdx.html 
'     Plugin Usage:    http://www.ghisler.ch/board/viewtopic.php?p=206065 

' Purpose of this script: 
'   get line content from current file, from pos1 till pos2 
'   for to use this info with renaming tool or for user columns 
''''''''''''''''''''''''''''''''''''''''''''''''''''''''' 
'code init, don't modify: 
Set fso = CreateObject("Scripting.FileSystemObject") 
Set oTextStream = fso.OpenTextFile(filename) 
''''''''''''''''''''''''''''''''''''''''''''''''''''''''' 

'//  User settings, modify this as you need: 

' Get content from Line L, StartPossition S, till EndPossition E 
' Syntax: GetContent( Line, Startpos, Endpos ) 

content = GetContent(1,1,4) 
content1 = GetContent(2,1,4) 
content2 = GetContent(3,1,4)  
content3 = GetContent(4,1,4) 
'content4 = GetContent(4,1,4)  
'content5 = GetContent(1,10,25) 
'content6 = GetContent(6,1,15) 
'content7 = GetContent(3,30,34) 
'content8 = GetContent(2,8,9) 
'content9 = GetContent(1,1,4) 

''''''''''''''''''''''''''''''''''''''''''''''''''''''''' 
'// VBS code: 
'don't edit code below if you don't know what you do: 
Function GetContent(vL, vS, vE) 
	Index = 0 
	Do while not oTextStream.AtEndOfStream 
		Index = Index + 1 
		s = oTextStream.ReadLine() 
		s = trim(s) 
		If (Index = vL) Then 
			If (s <> "") Then 
				vString = Mid(s, vS,  vE - vS + 1) 
				If vString > ""  Then 
					GetContent = RemoveInvalidChars(vString) 
				Else 
					GetContent = "(nothing found)" 
				End If 
			Else 
				GetContent = "(line was empty)" 
			End If 
			Exit Do 
		End If 
	Loop 
End Function 

Function RemoveInvalidChars(str) 
	RemoveInvalidChars = str 
	MyArray = Array("<", ">", "|", "/", "*", "\", "?", ":", """") 
	For X = 0 To UBound(MyArray) 
		'RemoveInvalidChars: 
		'RemoveInvalidChars = Replace(RemoveInvalidChars, MyArray(X), "", 1) 

		'exchange InvalidChars by an underscore: 
		RemoveInvalidChars = Replace(RemoveInvalidChars, MyArray(X), "_", 1) 
	Next 
End Function 

oTextStream.Close 
Set oTextStream = nothing 
Set fso = nothing