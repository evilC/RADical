#SingleInstance force
OutputDebug, DBGVIEWCLEAR

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
		;ToolTip % "Edit box contents: " this.MyEdit.value
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
				
				this._MouseLookup := {}
				this._MouseLookup[0x201] := { name: "LButton", event: 1 }
				this._MouseLookup[0x202] := { name: "LButton", event: 0 }
				this._MouseLookup[0x204] := { name: "RButton", event: 1 }
				this._MouseLookup[0x205] := { name: "RButton", event: 0 }
				this._MouseLookup[0x207] := { name: "MButton", event: 1 }
				this._MouseLookup[0x208] := { name: "MButton", event: 0 }
			}
			
			OptionSelected(){
				GuiControlGet, option,, % this._hwnd
				if (option = 1){
					; Bind Mode
					;ToolTip Bind MODE
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

				this._BindModeState := 1
				this._SelectedInput := []
				this._KeyCount := 0
				
				Gui, new, hwndhPrompt -Border +AlwaysOnTop
				Gui, % hPrompt ":Add", Text, w300 h100 Center, BIND MODE`n`nPress the desired key combination.`n`nBinding ends when you release a key.`nPress Esc to exit.
				Gui,  % hPrompt ":Show"
				
				this._hHookKeybd := this._SetWindowsHookEx(WH_KEYBOARD_LL, RegisterCallback(this._ProcessKHook,"Fast",,&this)) ; fn)
				this._hHookMouse := this._SetWindowsHookEx(WH_MOUSE_LL, RegisterCallback(this._ProcessMHook,"Fast",,&this)) ; fn)
				Loop {
					if (this._BindModeState = 0){
						break
					}
					Sleep 10
				}	
				this._UnhookWindowsHookEx(this._hHookKeybd)
				this._UnhookWindowsHookEx(this._hHookMouse)
				Gui,  % hPrompt ":Destroy"
				
				out := ""
				Loop % this._SelectedInput.length(){
					if (A_Index > 1){
						out .= ","
					}
					out .= this._GetKeyName(this._SelectedInput[A_Index])
				}
				MsgBox % "You hit keys: " out
			}
			
			_SetWindowsHookEx(idHook, pfn){
				Return DllCall("SetWindowsHookEx", "Ptr", idHook, "Ptr", pfn, "Uint", DllCall("GetModuleHandle", "Uint", 0, "Ptr"), "Uint", 0, "Ptr")
			}
			
			_UnhookWindowsHookEx(idHook){
				Return DllCall("UnhookWindowsHookEx", "Ptr", idHook)
			}
			
			_CallNextHookEx(nCode, wParam, lParam, hHook := 0){
				Return DllCall("CallNextHookEx", "Uint", hHook, "int", nCode, "Uint", wParam, "Uint", lParam)
			}
			
			_GetKeyName(keycode){
				return GetKeyName(Format("vk{:x}", keycode))
			}
			
			; Process Keyboard messages from Hooks
			_ProcessKHook(wParam, lParam){
				; KBDLLHOOKSTRUCT structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms644967%28v=vs.85%29.aspx
				; KeyboardProc function: https://msdn.microsoft.com/en-us/library/windows/desktop/ms644984(v=vs.85).aspx
				
				; ToDo:
				; Use Repeat count, transition state bits from lParam to filter keys
				
				static last_down := 0	; used to filter key repeats
				Critical
				
				if (this<0){
					Return DllCall("CallNextHookEx", "Uint", Object(A_EventInfo)._hHookKeybd, "int", this, "Uint", wParam, "Uint", lParam)
				}
				this:=Object(A_EventInfo)
				
				keycode := NumGet(lParam+0,0,"Uint")
				
				; Find the key code and whether key went up/down
				if (wParam = 0x100) || (wParam = 0x101) {
					; WM_KEYDOWN || WM_KEYUP message received
					; Normal keys / Release of ALT
					if (wParam = 260){
						; L/R ALT released
						event := 0
					} else {
						; Down event message is 0x100, up is 0x100
						event := abs(wParam - 0x101)
					}
				} else if (wParam = 260){
					; Alt keys pressed
					event := 1
				}
				
				; We now know the keycode and the event - filter out repeat down events
				if (event){
					if (last_down = keycode){
						return 1
					}
					last_down := keycode
				}

				/*
				; SetWindowsHookEx repeats down events - filter those out
				if (event){
					dupe := 0
					Loop % this._SelectedInput.length() {
						;OutputDebug % "checking " this._SelectedInput[A_Index]
						if (this._SelectedInput[A_Index] = keycode){
							dupe := 1
							;OutputDebug % "DUPE"
							break
						}
					}
					if (dupe){
						; Exit and block key
						return 1
					}
				}
				*/
				
			
				modifier := 0
				if (keycode == 27){
					; Quit Bind Mode on Esc
					this._BindModeState := 0
				} else {
					; Determine if key is modifier or normal key
					if ( (keycode >= 160 && keycode <= 165) || (keycode >= 91 && keycode <= 93) ) {
						modifier := 1
					} else {
						/*
						if (this._KeyCount){
							; do not allow, >1 non-modifier keys
							OutputDebug, % "Blocked - too many non-modifiers: " this._KeyCount
							
							if (event){
								; warning beep on key down
								SoundBeep
								; abort and block key - do not process up or down event
								return 1
							} else {
								; surplus key released
								this._KeyCount--
							}
						}
						*/
					}
				}

				OutputDebug, % "Key Code: " keycode ", event: " event ", name: " GetKeyName(Format("vk{:x}", keycode)) ", modifier: " modifier

				; We now have all the info we need, process the event
				if (event){
					; Key went down
					if (!modifier){
						this._KeyCount++
					}
					this._SelectedInput.push(keycode)
				} else {
					; Key went up
					this._BindModeState := 0
				}
				
				this._ProcessInput({Type: "k", code : keycode, event: event, modifier: modifier})
				return 1	; block key
			}
			
			; Process Mouse messages from Hooks
			_ProcessMHook(wParam, lParam){
				/*
				typedef struct tagMSLLHOOKSTRUCT {
				  POINT     pt;
				  DWORD     mouseData;
				  DWORD     flags;
				  DWORD     time;
				  ULONG_PTR dwExtraInfo;
				}
				*/
				; MSLLHOOKSTRUCT structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms644970(v=vs.85).aspx
				static WM_LBUTTONDOWN := 0x0201, WM_LBUTTONUP := 0x0202 , WM_RBUTTONDOWN := 0x0204, WM_RBUTTONUP := 0x0205, WM_MBUTTONDOWN := 0x0207, WM_MBUTTONUP := 0x0208, WM_MOUSEHWHEEL := 0x20E, WM_MOUSEWHEEL := 0x020A, WM_XBUTTONDOWN := 0x020B, WM_XBUTTONUP := 0x020C
				Critical
				if (this<0 || wParam = 0x200){
					Return DllCall("CallNextHookEx", "Uint", Object(A_EventInfo)._hHookMouse, "int", this, "Uint", wParam, "Uint", lParam)
				}
				this:=Object(A_EventInfo)
				out := "Mouse: " wParam " "
				
				found := 0
				for key, value in this._MouseLookup {
					if (key = wParam){
						found := 1
						out .= value.name ", event: " value.event
						break
					}
				}
				
				if (!found){
					; Find HiWord of mouseData from Struct
					mouseData := NumGet(lParam+0, 10, "Short")
					
					if (wParam = WM_MOUSEHWHEEL || wParam = WM_MOUSEWHEEL){
						; Mouse Wheel - mouseData indicate direction (up/down)
						event := 1	; wheel has no up event, only down
						if (wParam = WM_MOUSEWHEEL){
							out .= "Wheel"
							if (mouseData > 1){
								out .= "U"
							} else {
								out .= "D"
							}
						} else {
							out .= "Wheel"
							if (mouseData > 1){
								out .= "R"
							} else {
								out .= "L"
							}
						}
						out .= ", event: " event
					} else if (wParam = WM_XBUTTONDOWN || wParam = WM_XBUTTONUP){
						; X Buttons - mouseData indicates Xbutton 1 or Xbutton2
						if (wParam = WM_XBUTTONDOWN){
							event := 1
						} else {
							event := 0
						}
						out .= "XButton" mouseData ", event: " event
					}
				}
				
				OutputDebug % out
				
			}

		}
		
		_ProcessInput(obj){
			;{Type: "k", code : keycode, event: event, modifier: modifier}
			if (obj.Type = "k"){
				
			} else if (obj.Type = "m"){
				
			} else if (obj.Type = "j"){
				
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