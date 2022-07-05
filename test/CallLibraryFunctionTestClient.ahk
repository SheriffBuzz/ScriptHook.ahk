/*
    CallLibraryFunctionTest.ahk

    Test for CallLibraryFunction.ahk. This test shows a sample for how CallLibraryFunction should be called, by passing in 2 cmd arguments, which are then parsed from the A_Args build in variable.
    Requirements: CallLibraryFunctionTestPersistentScript.ahk should be run first.
    Remarks - if your persistent script defines a gui, you can also send the gui title instead of the script name, if and only if the gui is the default gui. See example gui declaration in CallLibraryFunctionTestPersistentScript.ahk
*/
SetWorkingDir, % A_ScriptDir "\..\Lib\messageListener"

ScriptHookRequest:= "{""postProcessorCfg"":{""messagebox"":{""enabled"":1}},""classInstanceName"":"""",""functionName"":""ScriptHook.Identity"", ""functionParameters"": [""a1"", ""a2""]}"
escapedForCmd:= """" StrReplace(ScriptHookRequest, """", "\""") """"

RunWait, "CallLibraryFunction.ahk" "CallLibraryFunctionTestPersistentScript" %escapedForCmd%
;RunWait, "CallLibraryFunction.ahk" "ThisGUIHasADifferentWinTitle" %escapedForCmd% ;Persistent scripts that define default gui can be called with either the script title or the gui title
;RunWait, "CallLibraryFunction.ahk" "ThisGUIIsNotDefault" %escapedForCmd% ;Peristent scripts with a non default gui can only be called with the script title

