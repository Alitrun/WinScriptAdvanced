'signatur.vbs by ricobautsch 

'Script for WinScriptAdv
' 
'This script returns the first 10 bytes in the file as text or hex-representation. 
'Could be usefull for example to search for files with a specified signatur 

const bHex = True 
const nCharCnt = 10 

Set fso = CreateObject("Scripting.FileSystemObject") 
Set oTextStream = fso.OpenTextFile(filename) 

If not oTextStream.AtEndOfStream Then 
  content_str = oTextStream.Read(nCharCnt) 
   
  If bHex Then 
    For i=1 To Len(content_str) 
      If content <> "" Then 
        content = content & " " 
      End If 
       
      hex_value = Hex(Asc(Mid(content_str,i,1))) 
       
      content = content & string(2 - len(hex_value), "0") 
      content = content & hex_value 
    Next 
  Else 
    content = content_str 
  End If 
End If 

oTextStream.Close