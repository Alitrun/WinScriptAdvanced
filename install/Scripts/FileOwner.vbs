'================================================= 
' Script for WinScriptAdv content plugin

' Returns the owner of a file \ folder
'================================================= 

content = Result 

Function Result 
	On Error Resume Next 
	Dim wmiSecSettings 
	Dim wmiSecurityDescriptor 

	Dim FOResult 
	Dim wmiOwner 

	Set wmiSecSettings = GetObject ("winmgmts:Win32_LogicalFileSecuritySetting.path='" & filename & "'") 

	FOResult = wmiSecSettings.GetSecurityDescriptor(wmiSecurityDescriptor) 
	Set wmiOwner = wmiSecurityDescriptor.Owner 

	If Err.Number <> 0 Then 
		Result = "Can't get file owner. Error: " & Err.Description 
	Else 
		Result = wmiOwner.Domain & "\" & wmiOwner.Name 
	End If 
End Function