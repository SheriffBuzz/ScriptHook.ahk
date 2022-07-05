;MessageListenerTest. Used in conjunction with CallLibraryFunctionTest.ahk.
#SingleInstance, Force
#Include %A_LineFile%\..\..\Lib\messageListener\ScriptHook.ahk


;https://www.autohotkey.com/docs/commands/Gui.htm#ControlOptions
/* ;This gui has a different title. CallLibraryFunction.ahk can be called with either the Script name or gui title.
Gui, new,, ThisGUIHasADifferentWinTitle
gui, add, button, w200
gui, show
*/

/* ;This gui does not have a different title, but it is declared as not the default gui. CallLibraryFunction.ahk cant be called with gui name.
Gui, ThisGUIIsNotDefault:new
gui, ThisGUIIsNotDefault:add, button, w200
gui, ThisGUIIsNotDefault:show
*/