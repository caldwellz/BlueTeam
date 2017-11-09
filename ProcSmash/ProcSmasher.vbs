' ****************************************************
' *    ProcSmasher: A silly and hackish (but open    *
' *       source!) process monitor for Windoze       *
' *         Copyright (C) 2017 Zach Caldwell         *
' ****************************************************
' * This Source Code Form is subject to the terms of *
' * the Mozilla Public License, v. 2.0. If a copy of *
' * the MPL was not distributed with this file, You  *
' * can obtain one at http://mozilla.org/MPL/2.0/.   *
' ****************************************************
' Credits also go to the Internet of course (Stack Exchange specifically) for providing the gist of the important bits.


' First, declare major variables
sComputerName = "."
sProcQuery = "SELECT Name, ExecutablePath, CommandLine FROM Win32_Process"
sApprovedList = "approvedList.txt"
sLogFile = "smashLog.txt"
iSleepTime = 250	' 250ms a.k.a. a quarter second
Dim procList
Set objWMIService = GetObject("winmgmts:\\" & sComputerName & "\root\cimv2")


' Read approved process list and open log file
Const OpenForReading = 1, OpenForWriting = 2, OpenForAppending = 8
Dim objFSO, objApprovedListFile
Set objApprovedList = CreateObject("Scripting.Dictionary")
Set objFSO = CreateObject("Scripting.FileSystemObject")
Set objApprovedListFile = objFSO.OpenTextFile(sApprovedList, OpenForReading)
Do While Not objApprovedListFile.AtEndOfStream
	objApprovedList(LCase(objApprovedListFile.ReadLine)) = True
Loop
objApprovedListFile.Close
Set objLogFile = objFSO.OpenTextFile(sLogFile, OpenForAppending, True)


' Start main scan/kill loop
WScript.Echo "Log and approved list opened successfully; starting monitoring."
counter = 0
Do
	Set procList = objWMIService.ExecQuery(sProcQuery)
	objDateTime = Now
	For Each objProcess In procList
		If (Not IsNull(objProcess.ExecutablePath)) And (Not objApprovedList.Exists(LCase(objProcess.ExecutablePath))) Then
			objProcess.Terminate()
			sTimeStamp = Right("0" & Hour(objDateTime), 2) & ":" & Right("0" & Minute(objDateTime), 2) & ":" & Right("0" & Second(objDateTime), 2)
			objLogFile.WriteLine sTimeStamp & " -- [Process Name:" & objProcess.Name & ", CmdLine:" & objProcess.CommandLine & ", ExecPath:" & objProcess.ExecutablePath & "]"
		End If
	Next

	' For testing, make the script exit after roughly 10 seconds (40 rounds of at least 250ms (or whatever iSleepTime is) each due to the Sleep below)
	' Comment these lines out to disable auto-exit
'	counter = counter + 1
'	If counter >= 40 Then
'		WScript.Echo "Terminator finished test round; exiting. Comment out test code block and restart script to run continually."
'		WScript.Sleep(2000)
'		Exit Do
'	End If

	objLogFile.Close	' Close and reopen the log to make sure the system actually writes it to disk rather than just caching
	WScript.Sleep(iSleepTime)
	Set objLogFile = objFSO.OpenTextFile(sLogFile, OpenForAppending, True)
Loop

objLogFile.Close
