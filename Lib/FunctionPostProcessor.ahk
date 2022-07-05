/*
    FunctionPostProcessor.ahk
    @Author - https://github.com/SheriffBuzz
    Function post processor - processes the output of a function. performs 0 or more operations based on a handle representing which operations to execute. In the case where the caller process does not need to do lots of processing of a function result beyond displaying it, it is convient to not send a response to the caller directly (The temp script that calls the persistent script, or the stream deck plugin). However, we want our library functions to be pure functions (have no side effects, only modifies objects passed to it). This allows the caller code to decide what to do with the result, and leave the library function to do the core operation. To implement this, the caller can send json cfg data for what they want to happen. The main processors are Msgbox, Traytip, Copy to clipboard, Open resource in File explorer, open resource/url in web browser.

    -6/19/22 added GuiPopup post processor. Must include \Lib\gui\elements\GuiPopup.ahk in persistent script, otherwise will not attempt to do a popup. (Scripts that dont include this file will not throw an error if it is enabled in functionPostProcessorCfg)

    If the function result is empty do something based on processor. For msgbox and traytip we can display default value, for clipboard do nothing. For file explorer/ web browser, validate the function result is a valid path/url before opening.
    -6/25/22 added suppressMessageBoxForEmptyFunctionResult to give user the option to disable messagebox showing if result is empty. Ideally we should suppress the messages but it might be useful for someone else who is using the script and trying to debug if their request for a library function was executed or just returned nothing.
*/
#Include %A_LineFile%\..\json\JXON.ahk

global FunctionPostProcessor:= new FunctionPostProcessorClass(true) ;@Export FunctionPostProcessor

class FunctionPostProcessorClass {
    static MsgboxTemplate:= {messageBox: {enabled: true}}
    static TrayTipTemplate:= {trayTip: {enabled: true}} 
    static NoOpTemplate:= {messageBox: {enabled: false}}
    
    __New(suppressMessageBoxForEmptyFunctionResult) {
        this.suppressMessageBoxForEmptyFunctionResult:= suppressMessageBoxForEmptyFunctionResult
    }

    /*FunctionPostProcessor process
        @param functionPostProcessorConfig - ahk object. If caller is using json string as input, use Jxon.load first
        @param functionResult
        @param functionName - function name. Can be used by certain controls (traytip) for a title. 

        Remarks - if the file path is expanded due to file explorer/web browser, it will also be reflected in MessageBox/TrayTip/Clipboard outputs.
            -Traytip icon prop: valid values are None, Info, Warning, Error. Default is "Info" if not provided.
        
        sample Json:
        {
            "messageBox": {
                "enabled": 1
            },
            "trayTip": {
                "enabled": 0,
                "icon" : "Warning",
                "NotificationSound", 0
            },
            "clipboard": {
                "enabled": 0
            },
            "webBrowser": {
                "browser": "chrome.exe",
                "incognito": 0,
                "resolveFilePath": 0,
                "enabled": 0
            },
            "fileExplorer": {
                "enabled": 0
            },
            "guiPopup": {
                "enabled": 1
            }
        }
    */
    process(ByRef functionPostProcessorCfg, functionResult, functionName="FunctionResult") {
        cfg:= functionPostProcessorCfg
        
        hasResult:= (functionResult = "") ? false : true
        filePathExpanded:= false ;file explorer and web browser both needed paths expanded, store state if expanded already.
        
        ;restrict certain processors based on function result (invalid url, invalid file path) and show a Msgbox error instead
        clipboardAllowed:= true
        trayTipAllowed:= true

        cfg.webBrowser.resolveFilePath:= 1 ;resolveFilePath not implemented on ui

        if (cfg.webBrowser && cfg.webBrowser.enabled) {
            webBrowser:= cfg.webBrowser
            if (webBrowser.resolveFilePath) {
                filePathExpanded:= true
                functionResult:= this.ExpandEnvironmentVariables(functionResult)
            }
            this.OpenUrlInBrowser(functionResult, webBrowser.browser, webBrowser.incognito)
        }

        if (cfg.fileExplorer && cfg.fileExplorer.enabled) {
            functionResult:= (filePathExpanded) ? functionResult : this.ExpandEnvironmentVariables(functionResult)
            if(FileExist(functionResult)) {
                this.RunWindowsExplorer(functionResult)
            } else {
                clipboardAllowed:= false
                trayTipAllowed:= false
                functionResult:= "Invalid filepath produced by:`n`n" functionName "`n`nThe function was executed but the file explorer post processor will not run. Function return value: `n`n" functionResult
                cfg.messageBox.enabled:= true
            }
            
        }

        if (cfg.clipboard && cfg.clipboard.enabled && clipboardAllowed) {
            Clipboard:= functionResult
        }

        functionResult:= (hasResult) ? functionResult : "Empty Result"
        if (cfg.trayTip && cfg.trayTip.enabled && trayTipAllowed) {
            trayTipIcon:= cfg.trayTip.icon
            trayTipOptions:= 1
            if (trayTipIcon) {
                if (trayTipIcon = "None") {
                    trayTipOptions:= 0
                } else if (trayTipIcon = "Info") {
                    trayTipOptions:= 1
                } else if (trayTipIcon = "Warning") {
                    trayTipOptions:= 2
                } else if (trayTipIcon = "Error") {
                    trayTipOptions:= 3
                }
            }

            if (cfg.trayTip.notificationSound) {
                trayTipOptions:= trayTipOptions + 16
            }

            TrayTip, %functionName%, %functionResult%, 1, %trayTipOptions%
        }

        if (cfg.guiPopup && cfg.guiPopup.enabled) {
            guiOutputPopupFactoryRef:= Func("GuiOutputPopup")
            if (guiOutputPopupFactoryRef) {
                guiOutputPopupFactoryRef.call(functionResult)
            }
        }
        ;Msgbox should be called last as it will block the other operations until alertbox is accepted
        if (cfg.messageBox && cfg.messageBox.enabled && (hasResult || !this.suppressMessageBoxForEmptyFunctionResult)) {
            MsgBox, 0, %functionName%, %functionResult%
        }
    }

    ;Util functions coming from other parts of my project, but included here to avoid extra imports

    /*
	ExpandEnvironmentVariables - expand env varaibles (without using EnvGet, as #NoEnv may be enabled)
	https://www.autohotkey.com/board/topic/9516-function-expand-paths-with-environement-variables/
    */
    ExpandEnvironmentVariables(ByRef path) {
        VarSetCapacity(dest, 2000) 
        DllCall("ExpandEnvironmentStrings", "str", path, "str", dest, int, 1999, "Cdecl int") 
        return dest
    }

    ;StartProcessWorkflow - standard library for startProcess commands. Each workflow may combine both start process and window utils such as activating or moving windows.
    RunWindowsExplorer(ByRef path) {
        explorerverbInfo:= this.ConvertPathToExplorerVerbInfo(path)
        itemName:= explorerverbInfo[1]
        explorerVerb:= explorerverbInfo[2]
        if (!itemName || !explorerVerb) {
            Msgbox, % "RunWindowsExplorer - path incorrect or missing"
            return
        }
        this.startProcess(explorerverb, [])
    }

    ;ConvertPathToWindowsVerb
    ;Convert path to explorer verb based on presence of a period in the last component of a path hierarchy.
    ;In case the folder path has periods in it, we are splitting the path and only taking the last segment, either a file name or final folder name. Trailing backslash for folders are also accepted.
    ;@param path - path to navigate to in windows explorer
    ;@param explorerverbInfo - return array of [itemName, explorer verb] - run command doesnt return correct pid for explorer as it merges the new process with existing. So pass back title so it can be used by caller for winwait/winactivate
    ConvertPathToExplorerVerbInfo(ByRef filePath) {
        filePath:= StrReplace(filePath, "/", "\")
        splitPath:= StrSplit(filePath, "\")
        maxIndex:= splitPath.MaxIndex()
        if (maxIndex = 2 && splitPath[2] == "") {
            explorerpath:= "explorer " """" filePath """"
            return ["$DRIVE$", explorerpath] ;return dummy value for drive (caller should be checking if non empty)
        }
        itemName:= splitPath[maxIndex]
        lastItemArr:= StrSplit(itemName, "`.")
        if (lastItemArr[2]) {
            explorerpath:= "explorer /select, " filePath
            itemName:= lastItemArr[1]
        } else {
            explorerpath:= "explorer " """" filePath """"
        }
        return [itemName, explorerpath]
    }

    ;StartProcess
    ;-Remarks - hack - not trimming the trailing whitespace for combining the args with append, but shouldnt matter since every arg is quoted.
    ;@param path - path to executable, or file name if program is on the system path.
    ;@param args - array of arguments. the contents of each argument will be escaped for quotes, and then surrounded by single quotes.
    ;@return pid - pid of spawned process
    startProcess(ByRef processPath, ByRef args="") {
        if (processPath = "") { ; not working if using the variable "path" for some reason, so dont use that as a variable name
            Msgbox, % "start process - no path passed"
            return
        }
        
        singleQuote:= """"
        escapedQuote:= "`\"""
        argString:= ""
        if (args.Length() > 0) {
            processPath.= " "
            for i, arg in args {
                replaced:= StrReplace(arg, singleQuote, escapedQuote)
                processPath.= singleQuote replaced singleQuote " "
            }
        }
        Run, %processPath%,,,pid
        return pid
    }

    /*
        OpenUrlInBroswer
        @param url
        @param browser - path to browser exe, or chrome, msedge, etc.. if location is added to path windows environment variable
        -Remarks - does not handle multiple browser windows. By default the url with open in a new tab on most recently used window. Use different browsers if you want windows to open in a specific area of the screen.
    */
    OpenUrlInBrowser(ByRef url, ByRef browser="chrome.exe", incognito=false) {
        incognitoStr:= (incognito) ? (browser = "msedge.exe") ? " --inprivate" : " --incognito" : ""
        cmdStr:= browser " """ url """ " incognitoStr
        try {
            Run, % cmdStr
        } catch e {
            
        }
    }
}
