# ScriptHook.ahk
Defines a listener for SendMessage API, to call functions in a persistent script by other processes

### Links
  * [streamdeck-ahk-client](https://github.com/SheriffBuzz/streamdeck-ahk-client)
  * [SendMessage AHK Tutorial](https://www.autohotkey.com/docs/misc/SendMessage.htm)
  * [SendMessage Microsoft Docs](https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendmessage)
  * [SendMessage WM_COPYDATA](https://docs.microsoft.com/en-us/windows/win32/dataxchg/wm-copydata)

## Overview

This script allows functions of a persistent script to be called by other ahk scripts or Windows processes. This might be useful if you have a main script that maintains state, uses a GUI, or performs initialization work that takes a relatively long time. It allows for functions to be called by other Windows processes directly with out defining a hotkey (mainly an Elgato StreamDeck plugin).

Next, this script defines an optional dependency **FunctionPostProcessor.ahk**. The goal is to decouple the low level library functions from what the caller wants to do with the result. A User might want to use a function that produces a filepath, but in different scenerios they might want to copy it to the clipboard, or open it directly in file explorer. If they decided they wanted to do something else with the result, they would need to modify the ahk script, or have duplicate function definitions that handled the clipboard or launch of file explorer.

The caller can pass a *postProcessorCfg* that identifies what they want to be done with the output. This lifts the state out of the low level components in the persistent script and up to the client application. This can be very powerful in combination with the [streamdeck-ahk-client StreamDeck plugin](https://github.com/SheriffBuzz/streamdeck-ahk-client). The stream deck can store the post processor cfg in the form UI elements in the property inspector. You could have 2 stream deck buttons, one that copies the file path to the clipboard, and one opens it in file explorer.

The main processors are Msgbox, Traytip, Copy to clipboard, Open resource in File explorer, Open url in web browser.

## Usage
  * This script should be included by a persistent script using **[#Include](https://www.autohotkey.com/docs/commands/_Include.htm)**.
  * A client application should send WM_COPYDATA message to the HWND (window handle) of the persistent script.
    * The payload is json of type [ScriptHookRequest](/resources/test/ScriptHookRequest.json)
    * See [**CallLibraryFunction.ahk**](#CallLibraryFunction.ahk) subheading below for sending from another ahk script or the command line.

### Dependencies
The only required dependency is Jxon, which is included in a separate file. This is a slightly tweaked version of the jxon library.
[https://github.com/cocobelgica/AutoHotkey-JSON/blob/master/Jxon.ahk](https://github.com/cocobelgica/AutoHotkey-JSON/blob/master/Jxon.ahk)
  - Wraps JXON_Load() and JXON_Dump() in a class JxonClass, with class instance *jxon* at the global scope. Methods are load and dump.
  - *isNullAsString* and *isBooleanAsString* parameters for load. Allows you to specify if json literals should be coerced to ahk equivalents or as string.
    - ScriptHook hardcodes this preference, alter the script if you would like to change it.
    ![image](https://user-images.githubusercontent.com/83767022/177240313-a35c4c53-17f1-4c5d-9d6e-20315e5febe6.png)

The other dependencies are optional. The persistent script that includes [ScriptHook.ahk](/Lib\messagelistener\ScriptHook.ahk) can be anywhere, however the dependencies are as follows:
  * [Lib\messagelistener\ScriptHook.ahk](/Lib\messagelistener\ScriptHook.ahk)
  * [Lib\json\JXON.ahk](/Lib\json\JXON.ahk) *required*
  * [Lib\FunctionPostProcessor.ahk](/Lib\FunctionPostProcessor.ahk) *optional*. If not included, functions will run without any indication of their completion unless the function itself displays something to the user.
  * [Lib\exception\LibraryFunctionException.ahk](/Lib\exception\LibraryFunctionException.ahk) *optional*

### State Management
Functions can be called if they reside at the global scope, or alternatively, methods of class instances at the global scope. While postProcessorCfg state lives on the client, the persistent script can store state between requests in the form of global variables or class instances. Class instances are supported by passing either "ClassInstanceVariableName.FunctionName" for the "functionName" property on *[ScriptHookRequest](/resources/test/ScriptHookRequest.json)*, or by passing "ClassInstanceVariableName" as the "classInstanceName" property, and "FunctionName" for the "functionName" property.

![image](https://user-images.githubusercontent.com/83767022/177240978-3eae1681-db4d-472f-840c-4584579505ea.png)
![image](https://user-images.githubusercontent.com/83767022/177237715-a54165a4-c9df-4e37-9eaf-812b7f72b8c4.png)
![image](https://user-images.githubusercontent.com/83767022/177237768-225349d8-1c41-4ffd-a8f1-602a7a947e83.png)

## Exception Handling
There is an optional [LibraryFunctionException](/Lib\exception\LibraryFunctionException.ahk) that wraps a postProcessorCfg. Library functions can call this exception to alter how they want the function post processors to run. This is powerful for deciding what should happen when an error occurs, because alternative actions can run independent of what the user wants to do when it completes normally. Some errors might need immediate attention, while some are better if they fail silently.

## Remarks
  - Only Unicode (UTF-16) strings are accepted. UTF-8 is Planned.
  - This script uses [OnMessage](https://www.autohotkey.com/docs/commands/OnMessage.htm), which has the following remarks:
    * Any script that calls OnMessage anywhere is automatically persistent. It is also single-instance unless #SingleInstance has been used to override that.
  - Function parameters will be interpreted as Object or Array if they deserialize as such according to Jxon.
        
## [CallLibraryFunction.ahk](/Lib/messagelistener/CallLibraryFunction.ahk)

CallLibraryFunction.ahk can be used as a temporary script to hook into a persistent script. The Send Message API requires a window handle to send the message to. CallLibraryFunction.ahk abstracts this by letting you pass in a WinTitle.
The script can be passed 2 command line arguments:
  - Persistent Script **[WinTitle](https://www.autohotkey.com/docs/misc/WinTitle.htm)**
  - [ScriptHookRequest json](/resources/test/ScriptHookRequest.json)

![image](https://user-images.githubusercontent.com/83767022/177235612-2343aa4e-619f-4fcf-9e6c-09af34b22a19.png)

### Remarks
Command line arguments must be escaped for double quotes. See example usage in [CallLibraryFunctionClientTest.ahk](/test/CallLibraryFunctionClientTest.ahk)
ScriptHook.ahk can be used a top level script, but is designed to be included by other scripts. The WinTitle parameter for CallLibraryFunction.ahk must be for the top level script (and not neccessarily ScriptHook.ahk)
## Examples
Examples may be found in the below files. First run the persistent script, then call the client script.
  - [CallLibraryFunctionTestClient.ahk](/test/CallLibraryFunctionTestClient.ahk)
  - [CallLibraryFunctionTestPersistentScript.ahk](/test/CallLibraryFunctionTestPersistentScript.ahk)
