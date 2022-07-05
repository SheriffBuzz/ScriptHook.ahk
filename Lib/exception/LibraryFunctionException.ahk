#Include %A_LineFile%\..\..\FunctionPostProcessor.ahk

/*
    LibraryFunctionException

    throwable object used by ScriptHook.ahk to alter the function post processor cfg of the current workflow. You also specify an exit code, which can be used by calling process (ie stream deck) to signal the success/error, on top of any ahk post processors.

    Dependencies - FunctionPostProcessor.ahk

    Remarks - this is not an Exception created from Exception() method, it is plain object

    @Param - message
    @Param - functionPostProcessorCfg - post processor cfg. See helper methods MsgboxFunctionPostProcessorCfg
    @Param - exitCode - exit code for ScriptHook.callFunction. It will be returned to the caller code that invokes sendMessage API - @default 0
    @Return - LibraryFunctionException obj. Keys: message, functionPostProcessorCfg, exitCode
*/
LibraryFunctionException(ByRef message, ByRef functionPostProcessorCfg, exitCode=0) {
    obj:= {}
    obj.message:= message
    obj.functionPostProcessorCfg:= functionPostProcessorCfg
    obj.exitCode:= exitCode
    obj.exceptionClass:= "LibraryFunctionException" ;no ahk specific meaning, just a flags for exception type in lieu of using Exception() to generate the exception
    return obj
}

LibraryFunctionMsgboxException(ByRef message, exitCode=0) {
    return LibraryFunctionException(message, FunctionPostProcessor.MsgboxTemplate, exitCode)
}

LibraryFunctionTrayTipException(ByRef message, exitCode=0, icon:="Error") {
    e:= LibraryFunctionException(message, FunctionPostProcessor.TrayTipTemplate, exitCode)
    e.functionPostProcessorCfg.trayTip.icon:= icon
    e.functionPostProcessorCfg.trayTip.notificationSound:= true
    return e
}

;LibraryFunctionNoOpException - exception that returns a message and error code but no function post processors
LibraryFunctionNoOpException(ByRef message, exitCode=0, icon:="Error") {
    e:= LibraryFunctionException(message, FunctionPostProcessor.NoOpTemplate, exitCode)
    return e
}
