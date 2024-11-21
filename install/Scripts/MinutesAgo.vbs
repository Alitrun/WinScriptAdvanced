'============================================================================== 
'Script for WinScriptAdv content plugin
'
'Columns Returns the difference in minutes between the current date and the date of folder\file: 
'   content  - Created Date;
'   content1 - Modified Date
'   content2 - Accessed Date
'============================================================================== 
Const UseFolderRecursion = False  
'============================================================================== 
Set FSO  = CreateObject("Scripting.FileSystemObject") 
content  = Result(filename, 1) & " min ago"
content1 = Result(filename, 2) & " min ago"
content2 = Result(filename, 3) & " min ago"
Set FSO  = Nothing 

Function Result(pPath, pMode) 
	Dim Diff, F 
	If FSO.FolderExists(pPath) Then 
		Result = GetDiff(FSO.GetFolder(pPath), pMode) 
		With FSO.GetFolder(pPath) 
		For Each F In .Files 
			Diff = Result(F, pMode) 
			If Diff < Result Then Result = Diff 
			Next 
			If UseFolderRecursion Then 
				For Each F In .SubFolders 
					Diff = Result(F, pMode) 
					If Diff < Result Then Result = Diff 
					Next 
				End If 
			End With 
		ElseIf FSO.FileExists(pPath) Then 
			Result = GetDiff(FSO.GetFile(pPath), pMode) 
		End If 
	End Function 

	Function GetDiff(pObj, pMode) 
		Dim lDate 
		With pObj 
		Select Case pMode 
			Case 1 lDate = .DateCreated 
			Case 2 lDate = .DateLastModified 
			Case 3 lDate = .DateLastAccessed 
		End Select 
	End With 
	GetDiff = DateDiff("n", lDate, Now) 
End Function