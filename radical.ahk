#SingleInstance force
OutputDebug, DBGVIEWCLEAR
#include <_Struct>
#include <WinStructs>

/*
RADical - A Rapid Application Development for AutoHotkey

ToDo:
* Hotkey GuiControl
Allow end users to select input / output keys via a GuiControl

* Profiles system
Save sets of persistent settings and allow switching.
Allow Auto switching of profiles based upon active application

* Callbacks for events
eg Tab Changed, Profile Changed

* Update notification system
Check text file at URL for library / client script versions

* Scrollbar support
Tab contents should be scrollable

* Window Resizing
Anchor type system

* Help System
Tooltips?
Help page?

*/

; ================================================================= TEST SCRIPT =================================
test := new MyClient()
return

; Example client script.
; When a hotkey is pressed, send the contents of the edit box
; Allow the end user to choose any hotkey, but specify a default of F12
; Save the contents of the edit box between runs
class MyClient extends RADical {
	; Initialize - this is called before the GUI is created. Set RADical options etc.
	Init(){
		this._myname := "Client" ; debugging
		; Add required tab(s)
		this.RADical.Tabs(["Settings","Blank"])
	}
	
	; Called after Initialization - Assemble your GUI, set up your hotkeys etc here
	Main(){
		; Set the current tab - analagous to Gui, Tab, Settings
		;this.RADical.Gui("Tab", "Settings")
		
		; Add an Edit box called MyEdit. Coords are relative to the tab canvas, not the whole GUI
		this.MyEdit := this.RADical.Tabs.Settings.Gui("Add", "Edit", "w100")
		
		; Tell RADical to save the value of the Edit box in an INI file (under the key name "MyEdit"), and call a routine any time it changes.
		fn := this.SettingChanged.bind(this)
		this.MyEdit.MakePersistent("MyEdit", "Settings Editbox", fn)
		
		; Define a hotkey and specify the default key and what routine to run when it is pressed
		fn := this.SendMyStuff.Bind(this)
		this.RADical.Tabs.Settings.AddHotkey("SendStuff", fn, "xm y50", "F12")
	}
	
	; User-defined routine to call when any of the persistent settings change
	SettingChanged(){
		ToolTip % "Edit box contents: " this.MyEdit.value
	}
	
	; The user-defined hotkey changed state
	SendMyStuff(value){
		if (value){
			; key pressed
			; Send contents of MyEdit box
			Send % this.MyEdit.value
		} else {
			; key released
		}
	}
}


; ==================================================== RADICAL LIB =======================================================

; Create a class for the client script to derive from, that configures it and starts it up
class RADical {
	__New(){
		this.RADical := new _radical(this)
		this.Init()
		this.RADical._GuiCreate()
		this.Main()
	}
}

; The main class that does the heavy lifting
class _radical {
	; --------------------- Internal Routines ---------------------
	; Behind-the-scenes stuff the user should not be touching
	__New(client){
		this._myname := "Library" ; debugging
		this._client := client
		
		this._hwnds := {}
		this._GuiSize := {w: 300, h: 150}	; Default size
		
		SplitPath, % A_ScriptName,,,,ScriptName
		this._ScriptName := ScriptName ".ini"
		
		; Bodge for now
		this.CurrentProfile := "Default"
	}
	
	; Create the main GUI
	_GuiCreate(){
		; Create Main GUI Window
		Gui, New, HwndhMain
		this._hwnds.MainWindow := hMain
		Gui, % this._hwnds.MainWindow ":Show", % "x0 y0 w" this._GuiSize.w " h" this._GuiSize.h
		
		; Add Status Bar
		Gui, % this._hwnds.MainWindow ":Add", StatusBar,, Blah blah blah
		
		; Create list of Tabs - client script should have defined required number of tabs by now
		tabs := ""
		Loop % this._TabIndex.length() {
			if (A_Index != 1){
				tabs .= "|"
			}
			tabs .= this._TabIndex[A_Index]
			if (A_Index = this._CurrentTabIndex){
				tabs .= "|"
			}
		}

		; Add Tabs
		Gui, % hMain ":Add", Tab2, % "-Wrap hwndhTabs xm ym h" this._GuiSize.h-35 " w" this._GuiSize.w-20, % tabs

		Loop % this._TabIndex.length() {
			Gui, % hMain ":Tab", % A_Index
			; Create Frame for Gui, as we cannot get Hwnd of client area of each tab
			Gui, % hMain ":Add",Text, % "w" this._GuiSize.w - 40 " h" this._GuiSize.h - 70 " hwndhGuiArea"
			; Add Gui for tab contents
			this.Tabs[this._TabIndex[A_Index]] := new this._CGui(this, hGuiArea)
		}
	}
	
	; ----------------------------- GUI class ---------------------------
	; Wraps Child GUIs into a class
	class _CGui {
		__New(root, hwndParent){
			this._root := root
			
			Gui, New, hwndhGui
			this._hwnd := hGui
			Gui,% this._hwnd ":+Owner"
			;Gui, % this._hwnd ":Color", red
			Gui, % this._hwnd ":+parent" hwndParent " -Border"
			Gui, % this._hwnd ":Show", % "x-5 y-5 w" this._root._GuiSize.w - 40 " h" this._root._GuiSize.h - 70
		}
		
		; Wrapper for Gui commands
		Gui(cmd, aParams*){
			if (cmd = "add"){
				; Create GuiControl
				obj := new this._CGuiControl(this, aParams*)
				return obj
			} else if (cmd = "new"){
				;obj := new _Gui(this, aParams*)
				;return obj
			}
		}
		
		; Wraps GuiControl to use hwnds and function binding etc
		GuiControl(cmd := "", ctrl := "", Param3 := ""){
			m := SubStr(cmd,1,1)
			if (m = "+" || m = "-"){
				; Options
				o := SubStr(cmd,2,1)
				if (o = "g"){
					; Bind g-label to _glabel property
					fn := Param3.Bind(this)
					ctrl._glabel := fn
					return this
				}
			} else {
				GuiControl, % this._hwnd ":" cmd, % ctrl._hwnd, % Param3
				return this
			}
		}

		; Wraps GuiControlGet
		GuiControlGet(cmd := "", ctrl := "", param4 := ""){
			GuiControlGet, ret, % this._hwnd ":" cmd, % ctrl._hwnd, % Param4
			return ret
		}
		
		; ----------------------------- GUI Control class ---------------------------
		class _CGuiControl {
			__New(parent, ctrltype, options := "", text := ""){
				this._Parent := parent
				this._CtrlType := ctrltype
				this._PersistenceName := 0
				this._glabel := 0
				this._DefaultValue := ""
				this._updating := 0		; Set to 1 when writing to GuiControl, to stop it writing to the settings file
				
				Gui, % this._parent._hwnd ":Add", % ctrltype, % "hwndhwnd " options, % text
				this._hwnd := hwnd
				
				; Hook into OnChange event
				fn := this._OnChange.bind(this)
				GuiControl % "+g", % this._hwnd, % fn
			}
			
			__Get(aParam){
				if (aParam = "value"){
					return this._parent.GuiControlGet(,this)
				}
			}
			
			__Set(aParam, aValue){
				if (aParam = "value"){
					return this._parent.GuiControl(,this, aValue)
				}
			}
		
			_OnChange(){
				; Update persistent settings
				if (this._PersistenceName){
					; Write settings to file
					; ToDo: Make Asynchronous
					if (!this._updating){
						this._parent.IniWrite(this.value, this._parent._root.CurrentProfile, this._PersistenceName, this._DefaultValue)
					}
					
					; Call user glabel
					if (ObjHasKey(this,"_glabel") && this._glabel != 0){
						;%this._glabel%() ; ahk v2
						this._glabel.() ; ahk v1
					}
				}
			}
			
			; Makes a Gui Control persistent - value is saved in settings file
			MakePersistent(Name, Default := "", glabel := 0){
				; ToDo: Check for uniqueness of name
				this._PersistenceName := Name
				this._glabel := glabel
				if (Default != ""){
					this._DefaultValue := Default
				}
				this._updating := 1
				val := this._parent.IniRead(this._parent._root.CurrentProfile, this._PersistenceName, this._DefaultValue)
				this.value := val
				this._updating := 0
			}
			
		}
		
		; ----------------------------- Hotkey GuiControl class ---------------------------
		class _CHotkeyControl {
			static MenuText := "||Wild|PassThrough|Remove"
			__New(parent, name, callback, options := "", default := ""){
				this.value := ""
				
				this._parent := parent
				Gui, % parent._hwnd ":Add", DDL, % "hwndhDDL AltSubmit " options, % "(UnBound)" this.MenuText
				this._hwnd := hDDl
				fn := this.OptionSelected.Bind(this)
				GuiControl % "+g", % this._hwnd, % fn
			}
			
			OptionSelected(){
				GuiControlGet, option,, % this._hwnd
				if (option = 1){
					; Bind Mode
					ToolTip Bind MODE
					this._BindMode()
					
				} else if (option = 2){
					ToolTip Wild Option Changed
				} else if (option = 3){
					ToolTip PassThrough Option Changed
				} else if (option = 4){
					ToolTip Remove Binding
				}
				GuiControl, Choose, % this._hwnd, 1
			}
			
			_BindMode(){
				static WH_KEYBOARD_LL := 13, WH_MOUSE_LL := 14

				this._BindMode := 1
				this._SelectedInput := []
				this._KeyCount := 0
				
				fn := this._BindCallback(this._ProcessKHook,"Fast",,this)
				this._hHookKeybd := this._SetWindowsHookEx(WH_KEYBOARD_LL, fn)
				;fn := _BindCallback(this._ProcessMHook,"Fast",,this)
				;this._hHookMouse := this._SetWindowsHookEx(WH_MOUSE_LL, fn)
				Loop {
					if (this._BindMode = 0){
						break
					}
					Sleep 10
				}	
				this._UnhookWindowsHookEx(this._hHookKeybd)
				
				out := ""
				Loop % this._SelectedInput.length(){
					if (A_Index > 1){
						out .= ","
					}
					out .= this._GetKeyName(this._SelectedInput[A_Index])
				}
				MsgBox % "You hit keys: " out
			}
			
			; _BindCallback by GeekDude
			; ToDo: Should be standard way of doing now? remove?
			_BindCallback(Params*)
			{
				if IsObject(Params)
				{
					this := {}
					this.Function := Params[1]
					this.Options := Params[2]
					this.ParamCount := Params[3]
					Params.Remove(1, 3)
					this.Params := Params
					if (this.ParamCount == "")
						this.ParamCount := IsFunc(this.Function)-1 - Floor(Params.MaxIndex())
					return RegisterCallback(A_ThisFunc, this.Options, this.ParamCount, Object(this))
				}
				else
				{
					this := Object(A_EventInfo)
					MyParams := [this.Params*]
					Loop, % this.ParamCount
						MyParams.Insert(NumGet(Params+0, (A_Index-1)*A_PtrSize))
					return this.Function.(MyParams*)
				}
			}

			_SetWindowsHookEx(idHook, pfn){
				Return DllCall("SetWindowsHookEx", "Ptr", idHook, "Uint", pfn, "Uint", DllCall("GetModuleHandle", "Uint", 0, "Ptr"), "Uint", 0, "Ptr")
			}
			
			_UnhookWindowsHookEx(idHook){
				Return DllCall("UnhookWindowsHookEx", "Ptr", idHook)
			}
			
			_GetKeyName(keycode){
				return GetKeyName(Format("vk{:x}", keycode))
			}
			
			; Process Keyboard messages from Hooks and feed _ProcessInput
			_ProcessKHook(nCode, wParam, lParam){
				; KBDLLHOOKSTRUCT structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms644967%28v=vs.85%29.aspx
				; KeyboardProc function: https://msdn.microsoft.com/en-us/library/windows/desktop/ms644984(v=vs.85).aspx
				Critical
				
				keycode := new _Struct(WinStructs.KBDLLHOOKSTRUCT,wParam+0)
				keycode := keycode.vkCode
				
				; Find the key code and whether key went up/down
				if (nCode = 0x100) || (nCode = 0x101) {
					; WM_KEYDOWN || WM_KEYUP message received
					; Normal keys / Release of ALT
					if (nCode = 260){
						; L/R ALT released
						event := 0
					} else {
						; Down event message is 0x100, up is 0x100
						event := abs(nCode - 0x101)
					}
				} else if (nCode = 260){
					; Alt keys pressed
					event := 1
				}
				
				; SetWindowsHookEx repeats down events - filter those out
				if (event){
					dupe := 0
					Loop % this._SelectedInput.length() {
						if (this._SelectedInput[A_Index] = keycode){
							dupe := 1
							break
						}
					}
					if (dupe){
						; Exit and block key
						return 1
					}
				}

				
				modifier := 0
				if (keycode == 27){
					; Quit Bind Mode on Esc
					this._BindMode := 0
				} else {
					; Determine if key is modifier or normal key
					if ( (keycode >= 160 && keycode <= 165) || (keycode >= 91 && keycode <= 93) ) {
						modifier := 1
					} else {
						if (this._KeyCount && event := 1){
							; do not allow, too many non-modifier keys
							OutputDebug, % "Blocked - too many non-modifiers: " this._KeyCount
							; abort and block key - do not process up or down event
							return 1
						}
					}
				}

				OutputDebug, % "Key Code: " keycode ", event: " event ", name: " GetKeyName(Format("vk{:x}", keycode)) ", modifier: " modifier

				; We now have all the info we need, process the event
				if (event){
					; Key went down
					if (!modifier){
						;this._KeyCount++
					}
					this._SelectedInput.push(keycode)
				} else {
					; Key went up
					this._BindMode := 0
				}

				;Return this._CallNextHookEx(nCode, wParam, lParam) ; allow key through
				return 1	; block key
			}
		}
		
		; Client command to add a hotkey
		AddHotkey(name, callback, options, default){
			hk := new this._CHotkeyControl(this, name, callback, options, default)
			return hk
		}

		
		; --------- INI Reading / Writing -----------
		IniRead(Section, key, Default){
			;IniRead, val, % this._ScriptName, % Section, % this._PersistenceName, %A_Space%
			IniRead, val, % this._root._ScriptName, % Section, % key, % A_Space
			if (val = ""){
				val := Default
			}
			return val
		}
		
		IniWrite(value, section, key, Default){
			OutputDebug, % "DEFAULT: *" default "*"
			if (value = Default){
				IniDelete, % this._root._ScriptName, % Section, % key
			} else {
				OutputDebug, % "UPDATE - " this._parent._ScriptName
				IniWrite, % value, % this._root._ScriptName, % Section, % key
			}
		}

	}
	
	; -------------- Client routines ----------------
	; Stuff that client scripts are intended to call
	
	; Client script declaring how many tabs it needs.
	; Builds the WHOLE tab list - this needs to happen before GUI creation.
	Tabs(tabs){
		this._TabIndex := []
		this.Tabs := {}
		tabs.push("Profiles")
		tabs.push("About")
		Loop % tabs.length() {
			this.Tabs[tabs[A_Index]] := {}
			this._TabIndex.push(tabs[A_Index])
		}
		
		this._CurrentTabName := tabs[1]
		this._CurrentTabIndex := 1
	}
	
}

GuiClose:
	ExitApp