
/*
    ScriptHook.ahk
    @Author - https://github.com/SheriffBuzz
    Defines a listener for SendMessage API to call functions in a persistent script by other processes
    ;https://www.autohotkey.com/docs/misc/SendMessage.htm
    ;https://docs.microsoft.com/en-us/windows/win32/dataxchg/wm-copydata
    ;https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendmessage

    Overview: This script allows functions of a persistent script to be called by other ahk scripts or windows processes. This might be useful if you have a main script that maintains state, uses a GUI, or performs initialization work that takes a relatively long time. It also allows for functions to be called by other windows processes directly (mainly a stream deck plugin). It also allows for calling functions without binding each function to a hotkey. This has the benefit of not having to keep track of hotkey mappings, and the hotkeys not being hardcoded into the ahk script.

    Next, this script defines an optional dependency FunctionPostProcessor.ahk. The goal is to decouple the low level library functions from what the caller wants to do with the result. A User might want to use a function that produces a filepath, but in different scenerios they might want to copy it to the clipboard, or open it directly in file explorer. If they decided they wanted to do something else with the result, they would need to modify the ahk script, or have duplicate function definitions that handled the clipboard or launch of file explorer.
    
    The caller can pass a "postProcessorCfg" that identifies what they want to be done with the output. This lifts the state out of the low level components in the persistent script and up to the client application. This can be very powerful in combination with the AHK Client stream deck plugin. The stream deck can store the post processor cfg in the form UI elements in the property inspector. You could have 2 stream deck buttons, one that copies the file path to the clipboard, and one opens it in file explorer.
    
    The main processors are Msgbox, Traytip, Copy to clipboard, Open resource in File explorer, open resource/url in web browser. See FunctionPostProcessor.ahk for more details and sample json.

    Finally, there is an optional LibraryFunctionException that wraps a postProcessorCfg. Library functions can call this exception to alter how they want the function post processors to run. This is powerful for deciding what should happen when an error occurs, independent of what the user wants to do when it completes normally. Some errors might need immediate attention, while some are better if they fail silently. By default, functions that throw an error will display in a Msgbox.
    
    Usage:
        This script should be included by a persistent script using #Include.
        A client app should either use CallLibraryFunction.ahk, or use sendMessage Api directly. CallLibraryFunction can be called from the command line with 2 command like arguments, TopLevel Script Name, and ScriptHookRequest (json)
        -Send Message API requires a window handle to send the message to. CallLibraryFunction.ahk abstracts this by letting you pass in a WinTitle.
        -ScriptHook can be used as a top level script, but is designed to be included by another script. Make note of the included files below, and set them neccessary if you do not use the same file/folder structure.
        -See Resources\ScriptHookRequest.json for sample request json.
    
    The only required dependency is Jxon, which is in a separate file. This is a modified version of the jxon library ;https://github.com/cocobelgica/AutoHotkey-JSON/blob/master/Jxon.ahk
    The other dependencies are optional.
        The project hierarachy should be as follows:
                Lib\messagelistener\ScriptHook.ahk
                Lib\json\JXON.ahk -REQUIRED
                Lib\FunctionPostProcessor.ahk -OPTIONAL
                Lib\exception\LibraryFunctionException.ahk -OPTIONAL

    Remarks:
        -SendMessage/ WM_COPYDATA api is used, but you could also implement with sockets.
        -Only Unicode (UTF-16) strings are accepted.
        -This script uses OnMessage https://www.autohotkey.com/docs/commands/OnMessage.htm, which has the following remarks:
            -Any script that calls OnMessage anywhere is automatically persistent. It is also single-instance unless #SingleInstance has been used to override that.

    Examples: see Test\CallLibraryFunctionTestClient.ahk for example.
*/
#Include %A_LineFile%\..\..\json\JXON.ahk
#Include *i %A_LineFile%\..\..\FunctionPostProcessor.ahk
#Include *i %A_LineFile%\..\..\exception\LibraryFunctionException.ahk

global scriptHookOptions = new ScriptHookOptionsClass() ;@Export scriptHookOptions
global scriptHook = new ScriptHookClass(scriptHookOptions) ;@Export scriptHook
OnMessage(scriptHook.msg, ObjBindMethod(scriptHook, "sendMessageMonitor"))

class ScriptHookOptionsClass {
    __New() {
        ;specify if function parameters should be deserialized as "null" or "", "true" or 1, "false" or 0
        this.isJsonNullAsString:= true
        this.isJsonBooleanAsString:= true
    }
}

class ScriptHookClass {

    __New(ByRef scriptHookOptions) {
        this.scriptHookOptions:= scriptHookOptions
        this.msg:= 0x4a ;WM_COPYDATA ;https://docs.microsoft.com/en-us/windows/win32/dataxchg/wm-copydata
    }

    sendMessageMonitor(wParam, lParam, msg) {
        stringAddress:= NumGet(lParam + 2*A_PtrSize)
        copyData:= StrGet(stringAddress,, "UTF-16")
        if(wParam == 1) {
            try {
                request:= Jxon.load(copyData, this.scriptHookOptions.isNullAsString, this.scriptHookOptions.isBooleanAsString)
                return this.callFunction(request)
            }
            catch e {
                Msgbox, % this.ExceptionMsg(e)
                return 0
            }
        }
    }

    callFunction(request){
        functionResult:=
        exitCode:= 1
        classInstanceName:= request.ClassInstanceName
        functionName:= request.functionName
        postProcessorCfg:= request.postProcessorCfg
        functionParameters:= request.functionParameters

        ;GuiInputPopup is not currently included in this project
        for i, param in functionParameters {
            if (param = "%GuiInputPopup%") {
                guiInputPopupRef:= Func("GuiInputPopup")          
                if (guiInputPopupRef) {
                    functionParameters[i]:= guiInputPopupRef.call()
                } else {
                    throw "ScriptHook call func - Attempted to send input with %GuiInputPopup% but GuiInputPopup.ahk is not included in the current script."
                }
            }
        }

        if (!functionName) {
            throw "ScriptHook - call func - function name not valid.`nfuncName:`n`t" functionName
        }
        
        if (classInstanceName || InStr(functionName, ".")) {
            if (!classInstanceName) {
                splitFunctionName:= StrSplit(functionName, ".")
                classInstanceName:= splitFunctionName[1]
                functionName:= splitFunctionName[2]
            }
            classInstanceRef:= %classInstanceName%
            if (!IsObject(classInstanceRef)) {
                throw "ScriptHook - call func - classInstance was given but no object was found at the global scope. You may pass classInstanceName + functionName in the request, or leave classInstanceName blank and pass ClassInstanceName.FunctionName for the function name.`n`nClass instance: " classInstance "`nFunctionName: " request.functionName
            }
            functionRef:= ObjBindMethod(classInstanceRef, functionName)
        } else {
            functionRef:= Func(functionName)
        }

        try {
            functionResult:= functionRef.call(functionParameters*)
        } catch e {
            if (IsObject(e) && e.exceptionClass = "LibraryFunctionException") { ;Library functions can throw an exception that wraps a postProcessorCfg, to do something other than simple msgbox.
                functionResult:= e.message
                postProcessorCfg:= e.postProcessorCfg
                exitCode:= e.exitCode
            } else {
                throw e
            }
        }

        postProcessorRef:= Func("FunctionPostProcessorProcess") ;using funcRef so compile error isnt thrown if file isnt included
        if (postProcessorRef && IsObject(postProcessorCfg)) {
            postProcessorRef.call(postProcessorCfg, functionResult, functionName)
        }
        return exitCode
    }

    /*
        Identity
        Identity function that returns its input. (Not a true identity function as args are newline separated, this is supposed to be for display purposes) 
        Intended to be used as a test function to see if caller process is working correctly, in absense of other functions to call by name in a persistent script
    */
    Identity(vals*){
        if (vals.MaxIndex() < 2) {
            return vals[1]
        }
        acc:= ""
        for i, val in vals {
            if (IsObject(val)) {
                for key, value in val {
                    acc.= "[" key "," value "]"
                }
            }
            acc.= val "`n"
        }
	    return acc
    }

    ExceptionMsg(ByRef e) {
        if (!IsObject(e)) {
            return e
        }
        str:= ""
        str.= "Exception:`n`n"
        str.= "File: " e.File "`n"
        str.= "Line: " e.Line "`n"
        str.= "Message: " e.Message "`n"
        str.= "Extra: " e.Extra "`n"
        str.= "What: " e.What "`n"
        return str
    }
}
