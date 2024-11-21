' Script for WinScriptAdv content plugin
' 
' showing day of week for the modified file date 
' (W) StatusQuo 2009 

boAbbreviate = 1 

Dim fs, f 
Dim sDate, sDowNumOnly, sDowOnly, sDatePlusWeekDay, sTimeOnly, sDateOnly 
Set fs = CreateObject("Scripting.FileSystemObject") 
Set f  = fs.GetFile(filename) 
sDate  = f.DateLastModified 
If (Len(sDate) < 12) then      ' "dd.mm.yy " / "dd.mm.yyyy " 
	sTimeNullAdd = " 00:00:00"   ' add time, if it's missing because of zero value 
' Else 
' sTimeNullAdd = "" 
End If 
sDateStr = sDate & sTimeNullAdd 

sDowOnly         = WeekDayName(WeekDay(sDate, vbMonday), boAbbreviate, vbMonday) 
sDowNumOnly      = WeekDay(sDate, vbMonday) & "_" & sDowOnly 
'sDatePlusWeekDay = sDateStr & ", " & sDowOnly 
'sTimeOnly        = Right(sDateStr, 8) 
'sDateOnly        = Left(sDateStr, Len(sDateStr) - 9) 

content = sDowNumOnly      ' number + day-of-week only 
'content1= sDowOnly         ' day-of-week only 
'content2= sTimeOnly 
'content3= sDateOnly 
'content4= sDatePlusWeekDay ' date plus day-of-week 