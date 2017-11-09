;=====================================================================
; [wkillcx] - (c) 2009 Jérôme Bruandet <floodmon@spamcleaner.org>
;
; Sources + docs : http://wkillcx.sourceforge.net/
;
;---------------------------------------------------------------------
; Close any TCP connection under Windows
;
; OS           : Windows (XP/Vista/Seven + Windows Server 2003/2008)
; Language     : Assembler
; Compiler     : Borland Tasm32
;
;---------------------------------------------------------------------
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;=====================================================================
.586p
locals
jumps
.model flat, STDCALL
; ====================================================================
; API :
extrn ExitProcess                : proc
extrn GetCommandLineA            : proc
extrn GetProcAddress             : proc
extrn GetProcessHeap             : proc
extrn GetStdHandle               : proc
extrn GlobalAlloc                : proc
extrn GlobalFree                 : proc
extrn GlobalLock                 : proc
extrn GlobalUnlock               : proc
extrn HeapFree                   : proc
extrn LoadLibraryA               : proc
extrn lstrlenA                   : proc
extrn WriteFile                  : proc
extrn _wsprintfA                 : proc
extrn htons                      : proc
extrn inet_addr                  : proc
extrn inet_ntoa                  : proc

; ====================================================================
.const
copyrightMsg   db 13,10, ' wkillcx - v1.0.2 - (c) 2009 Jerome Bruandet'
               db ' <floodmon@spamcleaner.org>',13,10,13,10,0
syntaxMsg      db '   syntax   : wkillcx [dest_ip:dest_port]',13,10,13,10
               db '   example  : wkillcx 10.11.22.23:1234',13,10,13,10
               db '   full doc : http://wkillcx.sourceforge.net/',13,10,0
DLLname        db 'iphlpapi.dll',0
DLLnotfoundMsg db ' - error : cannot find [iphlpapi.dll] !',0
; XP / Windows Server 2003 :
winOldAPIname  db 'AllocateAndGetTcpExTableFromStack',0
; XP SP2 / Vista / Seven / Server 2003 SP1 & 2008 :
winNewApiName  db 'GetExtendedTcpTable',0
APInotfoundMsg db ' - error : your operating system is not compatible !'
               db ' Please read the doc file.',0
SetTcpEntry    db 'SetTcpEntry',0
SetTcpErrMsg   db ' - error : cannot find SetTcpEntry API !',0
NoCxMsg        db ' - error : there are currently no connection !',0
TotCxMsg       db ' - found [%i] connections, parsing them all',13,10,0
notFoundMsg    db ' - error : no matching connection found !',0
killOkMsg      db ' - success : connection has been closed !',0
killErr1Msg    db ' - error : you must have administrative privileges'
               db ' to kill a connection !',0
killErr2Msg    db ' - error : cannot kill the connection !',0
memErrMsg      db ' - error : GetExtendedTcpTable returned '
               db 'ERROR_INSUFFICIENT_BUFFER !',0
aagErrMsg      db " - error : AllocateAndGetTcpExTableFromStack didn't"
               db ' return ERROR_SUCCESS !',0
strErrMsg      db ' - error : cannot get TcpTable !',0
APIsizeBuffer  dd 10240
lookingMsg     db ' - looking for connection with [%s:%s]',13,10,0
endianErrMsg   db ' - error : network byte order conversion failed,'
               db ' check IP or port syntax.',0
foundFormat    db ' - found connection with [%s:%i]',13,10,0
Exiting        db 13,10,13,10, ' Exiting.',13,10,0

.data
MIB_TCP        struc
 dwState       dd ?
 dwLocalAddr   dd ?
 dwLocalPort   dd ?
 dwRemoteAddr  dd ?
 dwRemotePort  dd ?
MIB_TCP        ends
TCPtable       MIB_TCP <>
oldWinVer      db 0
APIaddress     dd 0
hProcess       dd 0
null           dd 0
APImemAlloc    dd 0
APIptr         dd 0
memAlloc       dd 0
SetTcpEntryAPI dd 0
bytesWritten   dd 0
stdout         dd 0
ip_string      db 16 dup (0)
port_string    db 5 dup (0)
searchRemAddr  dd 0
searchRemPort  dd 0
outBuffer      db 150 dup (0)

; ====================================================================
.code

start:
   ; get console handle :
   call     GetStdHandle, -11
   mov      stdout, eax
   call     Write2Console, offset copyrightMsg

   ; look for iphlpapi.dll :
   call     LoadLibraryA, offset DLLname
   test     eax, eax
   jnz      DLL_found
   push     offset DLLnotfoundMsg
   jmp      quit

DLL_found:
   mov      null, eax
   ; look for AllocateAndGetTcpExTableFromStack :
   call     GetProcAddress, eax, offset winOldAPIname
   test     eax, eax
   jz       isNewer
   mov      oldWinVer, 1
   mov      APIaddress, eax
   call     GetProcessHeap
   mov      hProcess, eax
   jmp      API_found

isNewer:
   ; look for GetExtendedTcpTable :
   call     GetProcAddress, null, offset winNewApiName
   test     eax, eax
   jnz      isNewer2
   push     offset APInotfoundMsg
   jmp      quit

isNewer2:
   mov      APIaddress, eax
   ; allocate a 10Kb buffer for the TcpTable :
   call     GlobalAlloc, 42h, 10240          ; GHND
   mov      APImemAlloc, eax
   call     GlobalLock, eax
   mov      APIptr, eax

API_found:
   ; look for SetTcpEntry :
   call     GetProcAddress, null, offset SetTcpEntry
   test     eax, eax
   jnz      saveTcpEntry
   push     offset SetTcpErrMsg
   jmp      quit
saveTcpEntry:
   mov      SetTcpEntryAPI, eax

   ; fetch command line parameters :
   call     GetCommandLineA
   ; parse it :
   call     ParseCmdLine
   test     eax, eax
   jz       display_lookingMsg
   push     offset syntaxMsg
   jmp      quit
display_lookingMsg:
   ; display what we are looking for :
   call     _wsprintfA, offset outBuffer, offset lookingMsg, \
            offset ip_string, offset port_string
   add      esp, 4*4
   call     Write2Console, offset outBuffer

   ; convert IP/port to network byte order :
   call     inet_addr, offset ip_string
   cmp      eax, 0ffffffffh
   jne      convert_port
   push     offset endianErrMsg
   jmp      quit
convert_port:
   mov      searchRemAddr, eax
   mov      esi, offset port_string
   xor      ecx, ecx
   xor      eax, eax
   mov      bl, 9
   cld
convert_port_loop:
   lodsb
   sub      al, '0'
   js       convert_port_end_loop
   cmp      al, bl
   ja       convert_port_end_loop
   lea      ecx, [ecx+4*ecx]
   lea      ecx, [2*ecx+eax]
   jmp      short convert_port_loop
convert_port_end_loop:
   push     ecx
   call     htons
   cmp      eax, 0ffffffffh
   jne      convert_port2
   push     offset endianErrMsg
   jmp      quit
convert_port2:
   mov      searchRemPort, eax

   cmp      oldWinVer, 1
   jnz      GetExtendedTcpTable
   ; AllocateAndGetTcpExTableFromStack :
   call     dword ptr [APIaddress], offset APIptr, 0, \
            hProcess, 0, 2
   test     eax, eax                         ; ERROR_SUCCESS ?
   je       APIok
   push     offset aagErrMsg
   jmp      quit

GetExtendedTcpTable:
   ; GetExtendedTcpTable :
   call     dword ptr [APIaddress], [APIptr], offset APIsizeBuffer, \
            0, 2, 5, 0
   cmp      eax, 122                         ; ERROR_INSUFFICIENT_BUFFER
   jne      APIok
   push     offset memErrMsg
   jmp      quit

APIok:
   mov      esi, [APIptr]                    ; our structure
   test     esi, esi
   jne      fetch_cx
   push     offset strErrMsg
   jmp      quit

fetch_cx:
   ; number of active connections :
   mov      ecx, [esi]
   test     ecx, ecx                         ; none ?
   jne      display_totcx
   push     offset NoCxMsg
   jmp      quit
display_totcx:
   push     ecx
   call     _wsprintfA, offset outBuffer, offset TotCxMsg, ecx
   add      esp, 4*3
   call     Write2Console, offset outBuffer
   pop      ecx

next_cx:
   push     ecx                              ; counter
   push     esi                              ; pointer

   ; try to find our IP/port :
   mov      eax, dword ptr [esi+10h]         ; dwRemoteAddr
   cmp      eax, searchRemAddr
   jne      unwanted
   mov      TCPtable.dwRemoteAddr, eax
   mov      eax, dword ptr [esi+14h]         ; dwRemotePort
   cmp      eax, searchRemPort
   jne      unwanted
   mov      TCPtable.dwRemotePort, eax

   ; found matching connection :
   mov      eax, dword ptr [esi+0Ch]         ; dwLocalPort
   mov      TCPtable.dwLocalPort, eax
   xchg     ah, al
   push     eax
   mov      eax, dword ptr [esi+08h]         ; dwLocalAddr
   mov      TCPtable.dwLocalAddr, eax
   ; convert IP to ASCII :
   call     inet_ntoa, eax
   push     eax
   push     offset foundFormat
   push     offset outBuffer
   call     _wsprintfA
   add      esp, 4*4
   call     Write2Console, offset outBuffer
   pop      esi
   pop      ecx

   ; kill the connection :
   mov      TCPtable.dwState, 12             ; MIB_TCP_STATE_DELETE_TCB
   call     dword ptr [SetTcpEntryAPI], offset TCPtable
   test     eax, eax
   jnz      kill_error
   push     offset killOkMsg
   jmp      quit

kill_error:
   cmp      eax, 5                           ; ERROR_ACCESS_DENIED
   jne      unknown_err
   push     offset killErr1Msg
   jmp      quit
unknown_err:
   push     offset killErr2Msg
   jmp      quit

unwanted:
   pop      esi
   pop      ecx
   dec      ecx
   jcxz     noMoreCX
   add      esi, 18h                         ; next structure
   jmp      next_cx
noMoreCX:
   push     offset notFoundMsg

quit:
   call     Write2Console

   cmp      oldWinVer, 1
   jnz      noHeapFree
   ; free memory if AllocateAndGetTcpExTableFromStack was used :
   call     HeapFree, hProcess, 0, [APIptr]
   jmp      noGlobalFree

noHeapFree:
   cmp      APImemAlloc, 0
   jz       noGlobalFree
   call     GlobalUnlock, [APImemAlloc]
   call     GlobalFree, [APImemAlloc]

noGlobalFree:
   push     offset Exiting
   call     Write2Console
   call     ExitProcess, 0

endp

; ====================================================================
; output text to console
; param :  [esp+4] : msg to output

Write2Console proc

   call     lstrlenA, dword ptr [esp+4]
   call     WriteFile, stdout, dword ptr [esp+4*4], eax, bytesWritten, 0
   ; clean up stack
   retn     4

Write2Console endp

; ====================================================================
; parse the command line parameters
; ret : success (eax == 0) or error (eax == 1)

ParseCmdLine      proc

   ; need to check whether there
   ; are quotes (") or not :
   cmp      byte ptr [eax], 22h
   jne      check_next
find_last_quote:
   inc      eax
   cmp      byte ptr [eax], 22h
   jne      find_last_quote

check_next:
   inc      eax
   ; look for space or NULL
   cmp      byte ptr [eax], 20h
   je       space_found
   cmp      byte ptr [eax], 00h
   je       cmdLineError
   jmp      check_next
space_found:
   ; some Windows versions have 2 spaces
   ; between program name and parameters :
   cmp      byte ptr [eax+1], 20h
   je       check_next
   inc      eax
   mov      esi, eax
   push     eax
   call     lstrlenA
   ; size must be from 9 to 21 characters :
   cmp      eax, 9
   jb       cmdLineError
   cmp      eax, 21
   ja       cmdLineError
   mov      edi, offset ip_string
next_ip_char:
   test     eax, eax
   jz       cmdLineError
   cmp      byte ptr [esi], 3ah              ; colon ?
   je       fetch_port
   cmp      byte ptr[esi], 39h
   ja       cmdLineError
   cmp      byte ptr[esi], 30h
   jb       is_dot
   jmp      copy_ip
is_dot:
   cmp      byte ptr [esi], 2eh              ; dot ?
   jne      cmdLineError
copy_ip:
   movsb                                     ; save to dest buffer
   dec      eax
   jmp      next_ip_char
fetch_port:
   inc      esi
   mov      edi, offset port_string
next_port_char:
   dec      eax
   test     eax, eax
   je       test_port
   cmp      byte ptr [esi], 39h
   ja       cmdLineError
   cmp      byte ptr[esi], 30h
   jb       cmdLineError
   movsb
   jmp      next_port_char

test_port:
   cmp      byte ptr [port_string], 0
   jne      endcmdLine

cmdLineError:
   mov      eax, 1
   ret
endcmdLine:
   xor      eax, eax
   ret

ParseCmdLine      endp

end start
; ====================================================================
; EOF
