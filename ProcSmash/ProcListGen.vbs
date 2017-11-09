' ****************************************************
' *  ProcListGen: Dumps running process list into a  *
' *   file intended to be fed into the ProcSmasher   *
' *         Copyright (C) 2017 Zach Caldwell         *
' ****************************************************
' * This Source Code Form is subject to the terms of *
' * the Mozilla Public License, v. 2.0. If a copy of *
' * the MPL was not distributed with this file, You  *
' * can obtain one at http://mozilla.org/MPL/2.0/.   *
' ****************************************************


' Declare configurable variables
sProcListFile = "approvedList.txt"
sComputerName = "."
sProcQuery = "SELECT * FROM Win32_Process"


' Open process list file
Dim objFSO, objFile, strLine
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objFile = objFSO.OpenTextFile(sProcListFile, 2, True)


' Query processes and make a unique list using a Dictionary
Set objWMIService = GetObject("winmgmts:\\" & sComputerName & "\root\cimv2")
Set procList = objWMIService.ExecQuery(sProcQuery)
Set objDict = CreateObject("Scripting.Dictionary")
For Each objItem In procList
	If Not IsNull(objItem.ExecutablePath) Then
		If Not objDict.Exists(objItem.ExecutablePath) Then objDict(objItem.ExecutablePath) = 0
	End If
Next


' In VB neither dictionaries nor arrays have sorting methods, so use a crude algorithm instead
Dim aSortingArray()
ReDim aSortingArray(objDict.Count - 1)	' first Dim only allows a constant integer for size specification
nCount = 0
sSortKey = objDict.Keys()(0)
While Not IsNull(sSortKey)
	For Each sKey In objDict.Keys()
		If strComp(sSortKey, sKey) > 0 Then sSortKey = sKey
	Next

	aSortingArray(nCount) = sSortKey
	nCount = nCount + 1
	objDict.Remove(sSortKey)
	If objDict.Count > 0 Then
		sSortKey = objDict.Keys()(0)
	Else
		sSortKey = null
	End If
Wend


' Write the sorted list
For Each sExecPath In aSortingArray
	objFile.WriteLine sExecPath
Next


' Clean up and end
objFile.Close
WScript.Echo "Process listing finished."
