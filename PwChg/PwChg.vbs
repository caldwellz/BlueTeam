' ****************************************************
' *       Quick 'N Dirty Mass Password Changer       *
' *         Copyright (C) 2017 Zach Caldwell         *
' ****************************************************
' * This Source Code Form is subject to the terms of *
' * the Mozilla Public License, v. 2.0. If a copy of *
' * the MPL was not distributed with this file, You  *
' * can obtain one at http://mozilla.org/MPL/2.0/.   *
' ****************************************************

' Declare settings
strPassword = ""
strDomain = ""
Const strExclusionsList = "pwExclusions.txt"
Const logChanges = True		' Turn this off in actual competition to leave a tiny bit less info lying around ;)
Const useExclusions = True
Const askPassword = True	' Ask for these by default, both for security and to avoid being labeled 'preconfigured software'
Const askDomain = True
Const setDomainPws = True
Const setLocalPws = True

On Error Resume Next
Const OpenForReading = 1, OpenForWriting = 2, OpenForAppending = 8
Set objFSO = CreateObject("Scripting.FileSystemObject")

' Open log file and write header
Set objLog = Nothing
If logChanges Then
	Set objLog = objFSO.OpenTextFile("PwChgLog.txt", OpenForAppending, True)
	objDateTime = Now
	sTimeStamp = Right("0" & Hour(objDateTime), 2) & ":" & Right("0" & Minute(objDateTime), 2) & ":" & Right("0" & Second(objDateTime), 2)
	objLog.WriteLine sTimeStamp & " -- Password Changer Starting"
End If


' Load exclusions list
Set objExclusionList = CreateObject("Scripting.Dictionary")
If useExclusions Then
	Set objExclusionListFile = objFSO.OpenTextFile(strExclusionsList, OpenForReading)
	Do While Not objExclusionListFile.AtEndOfStream
		objExclusionList(LCase(objExclusionListFile.ReadLine)) = True
	Loop
	objExclusionListFile.Close
	If logChanges Then objLog.WriteLine "- Loaded exclusions list"
End If


' Ask for password and domain
If askPassword Then
	strPassword = InputBox("Enter password: ")
End If

If askDomain Then
	strDomain = InputBox("Enter domain: ")
End If


' Reset local machine passwords
If setLocalPws Then
	If logChanges Then objLog.WriteLine "- Changing local machine passwords. Users:"
	Set objMachine = GetObject("WinNT://.")
	For Each objItem in objMachine
		If objItem.Class = "User" Then
			If Not objExclusionList.Exists(LCase(objItem.Name))
				objItem.SetPassword(strPassword)
				If logChanges Then objLog.WriteLine "./" & objItem.Name
			End If
		End If
	Next
End If


' Reset domain passwords
If setDomainPws Then
	If logChanges Then objLog.WriteLine "- Changing passwords on domain '" & strDomain & "'. Users:"
	Set objDomain = GetObject("WinNT://" & strDomain)
	For Each objItem in objDomain
		If objItem.Class = "User" Then
			If Not objExclusionList.Exists(LCase(objItem.Name))
				objItem.SetPassword(strPassword)
				If logChanges Then objLog.WriteLine strDomain & "/" & objItem.Name
			End If
		End If
	Next
End If


' Clean up and close
If logChanges Then
	objLog.WriteLine "- Finished!"
	objLog.Close
End If
WScript.Echo "Finished changing passwords!"
