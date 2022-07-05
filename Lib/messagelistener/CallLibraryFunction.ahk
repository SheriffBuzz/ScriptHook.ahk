/*
    CallLibraryFunction

    Purpose - Provide an entry point into a persistent script, which includes ScriptHook.ahk. This script is an abstraction of the Windows SendMessage API. It can be called via the command line or any other means where the client is not able to call SendMessage. If an application is able to use SendMessage, it can send the message (WM_COPYDATA) directly to the persistent script.

    This script only stays alive long enough to send the request and wait for a response. This is ideal for stateful tasks, as persistent scripts can maintain state between successive calls while scripts that run once per one function can not. It may also be useful if the persistent script does a lot of startup processing (reading cfg from files, etc..) or defines a gui.

    @CommandLineArgument #1 winTitle - WinTitle of persistent script. If the script defines a gui, you can pass the gui name, but only if it is the default gui. (See CallLibraryFunctionTestClient.ahk for more details)
    @CommandLineArgument #2 scriptHookRequest - json request. see CallLibraryFunctionTest.ahk for examples
*/
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.

if (!A_IsUnicode) {
    Msgbox, % "Unicode version of AHK is required for CallLibraryFunction.ahk."
    ExitApp
}

if (A_Args.Count() != 2) { 
    str:= ""
    if (A_Args.MaxIndex() <= 1) {
        str:= "# No command line arguments passed #"
    } else {
        str.= "Args passed:`n"
        for arg in A_Args {
            str.= A_Index ": " A_Args[arg] "`n"
        }
    }
    Msgbox, % "CallLibraryFunction.ahk requires exactly 2 arguments:`n" "Arg1: Persistent script winTitle`n" "Arg2: ScriptHookRequest json" "`n" str  
    ExitApp
}
targetScriptWinTitle:= A_Args[1]
scriptHookRequest:= A_Args[2]

WM_COPYDATA:= 0x4a
setTitleMatchMode, 2
detectHiddenWindows on
VarSetCapacity(CopyDataStruct, 3*A_PtrSize, 0)
sizeInBytes:= (StrLen(scriptHookRequest) + 1) * (2)
NumPut(SizeInBytes, CopyDataStruct, A_PtrSize)
NumPut(&scriptHookRequest, CopyDataStruct, 2*A_PtrSize)
mode:= 1
SendMessage, %WM_COPYDATA%, mode, &CopyDataStruct,,%targetScriptWinTitle%,,,, 1000000
if (ErrorLevel = "FAIL") { ;if script name is wrong, it will fail immediately. If it is correct, wait some sufficiently long timeout because the script could be blocking on a messageBox and not return right away, and would inadvertently show the below error even though the script was called successfully
    Msgbox, % "Unable to call persistent script with title:`n`n" targetScriptWinTitle "`n`nPlease ensure the script is running."
}
