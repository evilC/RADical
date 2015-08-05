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
	;SendMyStuff(value){
	SendMyStuff(){
		SoundBeep
		if (value){
			; key pressed
			; Send contents of MyEdit box
			;Send % this.MyEdit.value
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
		
		this._Hotkeys := {}
		
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
			static _MenuText := "Select new Binding|Toggle Wild (*) |Toggle PassThrough (~)|Remove Binding"
			
			__New(hwnd, name, callback, options := "", default := ""){
				this._Value := default			; AHK Syntax of current binding, eg ~*^!a
				this.HotkeyString := ""		; AHK Syntax of current binding, eg ^!a WITHOUT modes such as * or ~
				this.ModeString := ""
				this.HumanReadable := ""	; Human Readable version of current binding, eg CTRL + SHIFT + A
				this.Wild := 0
				this.PassThrough := 0
				this._ParentHwnd := hwnd
				this.Name := name
				this._callback := callback
				
				; Lookup table to accelerate finding which mouse button was pressed
				this._MouseLookup := {}
				this._MouseLookup[0x201] := { name: "LButton", event: 1 }
				this._MouseLookup[0x202] := { name: "LButton", event: 0 }
				this._MouseLookup[0x204] := { name: "RButton", event: 1 }
				this._MouseLookup[0x205] := { name: "RButton", event: 0 }
				this._MouseLookup[0x207] := { name: "MButton", event: 1 }
				this._MouseLookup[0x208] := { name: "MButton", event: 0 }

				; Add the GuiControl
				Gui, % this._ParentHwnd ":Add", ComboBox, % "hwndhwnd AltSubmit " options, % this._MenuText
				this._hwnd := hwnd
				
				; Find hwnd of EditBox that is a child of the ComboBox
				this._hEdit := DllCall("GetWindow","PTR",this._hwnd,"Uint",5) ;GW_CHILD = 5
				
				; Bind an OnChange event
				fn := this.OptionSelected.Bind(this)
				GuiControl % "+g", % this._hwnd, % fn
						
				this.Value := this._Value	; trigger __Set meta-func to configure control
			}
			
			; value was set
			__Set(aParam, aValue){
				if (aParam = "value"){
					this._ValueSet(aValue)
					return this._Value
				}
			}
			
			; Read of value
			__Get(aParam){
				if (aParam = "value"){
					return this._Value
				}
			}

			; Change hotkey AND modes to new values
			_ValueSet(hotkey_string){
				arr := this._SplitModes(hotkey_string)
				this._SetModes(arr[1])
				this.HotkeyString := arr[2]
				this._HotkeySet()
			}
			
			; Change hotkey only and LEAVE modes
			_HotkeySet(){
				this.HumanReadable := this._BuildHumanReadable(this.HotkeyString)
				this._value := this.ModeString this.HotkeyString
				this._UpdateGuiControl()
				; Fire the OnChange callback
				this._callback.(this)

			}
			
			; ============== HOTKEY MANAGEMENT ============
			; An option was selected in the drop-down list
			OptionSelected(){
				GuiControlGet, option,, % this._hwnd
				GuiControl, Choose, % this._hwnd, 0
				if (option = 1){
					; Bind Mode
					;ToolTip Bind MODE
					this._BindMode()
					
				} else if (option = 2){
					;ToolTip Wild Option Changed
					this.Wild := !this.Wild
					this.ModeString := this._BuildModes()
					this._HotkeySet()
				} else if (option = 3){
					;ToolTip PassThrough Option Changed
					this.PassThrough := !this.PassThrough
					this.ModeString := this._BuildModes()
					this._HotkeySet()
				} else if (option = 4){
					;ToolTip Remove Binding
					this.Value := ""
				}
			}
			
			; Bind mode was enabled
			_BindMode(){
				static WH_KEYBOARD_LL := 13, WH_MOUSE_LL := 14
				static modifier_symbols := {91: "#", 92: "#", 160: "+", 161: "+", 162: "^", 163: "^", 164: "!", 165: "!"}
				;static modifier_lr_variants := {91: "<", 92: ">", 160: "<", 161: ">", 162: "<", 163: ">", 164: "<", 165: ">"}

				this._BindModeState := 1
				this._SelectedInput := []
				this._ModifiersUsed := []
				
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
				end_modifier := 0
				
				if (this._SelectedInput.length() < 1){
					return
				}

				; Prefix with current modes
				hotkey_string := ""
				if (this.Wild){
					hotkey_string .= "*"
				}
				if (this.PassThrough){
					hotkey_string .= "~"
				}

				; build hotkey string
				l := this._SelectedInput.length()
				Loop % l {
					if (this._SelectedInput[A_Index].Type = "k" && this._SelectedInput[A_Index].modifier && A_Index != l){
						hotkey_string .= modifier_symbols[this._SelectedInput[A_Index].vk]
					} else {
						hotkey_string .= this._SelectedInput[A_Index].name
					}
				}
				
				; trigger __Set meta-func to configure control
				this.Value := hotkey_string
			}
			
			; Builds mode string from this.Wild and this.Passthrough
			_BuildModes(){
				str := ""
				if (this.Wild){
					str .= "*"
				}
				if (this.PassThrough){
					str .= "~"
				}
				return str
			}
			; Converts an AHK hotkey string (eg "^+a"), plus the state of WILD and PASSTHROUGH properties to Human Readable format (eg "(WP) CTRL+SHIFT+A")
			_BuildHumanReadable(hotkey_string){
				static modifier_names := {"+": "Shift", "^": "Ctrl", "!": "Alt", "#": "Win"}
				
				dbg := "TRANSLATING: " hotkey_string " : "
				
				if (hotkey_string = ""){
					return "(Select to Bind)"
				}
				str := ""
				mode_str := ""
				idx := 1
				; Add mode indicators
				if (this.Wild){
					mode_str .= "W"
				}
				if (this.PassThrough){
					mode_str .= "P"
				}
				
				if (mode_str){
					str := "(" mode_str ") " str
				}
				
				idx := 1
				; Parse modifiers
				Loop % StrLen(hotkey_string) {
					chr := SubStr(hotkey_string, A_Index, 1)
					if (ObjHasKey(modifier_names, chr)){
						str .= modifier_names[chr] " + "
						idx++
					} else {
						break
					}
				}
				str .= SubStr(hotkey_string, idx)
				StringUpper, str, str
				
				;OutputDebug % "BHR: " dbg hotkey_string
				return str
			}

			; Splits a hotkey string (eg *~^a" into an array with 1st item modes (eg "*~") and 2nd item the rest of the hotkey (eg "^a")
			_SplitModes(hotkey_string){
				mode_str := ""
				idx := 0
				Loop % StrLen(hotkey_string) {
					chr := SubStr(hotkey_string, A_Index, 1)
					if (chr = "*" || chr = "~"){
						idx++
					} else {
						break
					}
				}
				if (idx){
					mode_str := SubStr(hotkey_string, 1, idx)
				}
				return [mode_str, SubStr(hotkey_string, idx + 1)]
			}
			
			; Sets modes from a mode string (eg "*~")
			_SetModes(hotkey_string){
				this.Wild := 0
				this.PassThrough := 0
				this.ModeString := ""
				Loop % StrLen(hotkey_string) {
					chr := SubStr(hotkey_string, A_Index, 1)
					if (chr = "*"){
						this.Wild := 1
					} else if (chr = "~"){
						this.PassThrough := 1
					} else {
						break
					}
					this.ModeString .= chr
				}
			}
			
			; The binding changed - update the GuiControl
			_UpdateGuiControl(){
				static EM_SETCUEBANNER:=0x1501
				DllCall("User32.dll\SendMessageW", "Ptr", this._hEdit, "Uint", EM_SETCUEBANNER, "Ptr", True, "WStr", modes this.HumanReadable)
			}
			
			; ============= HOOK HANDLING =================
			_SetWindowsHookEx(idHook, pfn){
				Return DllCall("SetWindowsHookEx", "Ptr", idHook, "Ptr", pfn, "Uint", DllCall("GetModuleHandle", "Uint", 0, "Ptr"), "Uint", 0, "Ptr")
			}
			
			_UnhookWindowsHookEx(idHook){
				Return DllCall("UnhookWindowsHookEx", "Ptr", idHook)
			}
			
			; Process Keyboard messages from Hooks
			_ProcessKHook(wParam, lParam){
				; KBDLLHOOKSTRUCT structure: https://msdn.microsoft.com/en-us/library/windows/desktop/ms644967%28v=vs.85%29.aspx
				; KeyboardProc function: https://msdn.microsoft.com/en-us/library/windows/desktop/ms644984(v=vs.85).aspx
				
				; ToDo:
				; Use Repeat count, transition state bits from lParam to filter keys
				
				static WM_KEYDOWN := 0x100, WM_KEYUP := 0x101, WM_SYSKEYDOWN := 0x104
				static last_vk, last_sc
				
				Critical
				
				if (this<0){
					Return DllCall("CallNextHookEx", "Uint", Object(A_EventInfo)._hHookKeybd, "int", this, "Uint", wParam, "Uint", lParam)
				}
				this:=Object(A_EventInfo)
				
				vk := NumGet(lParam+0, "UInt")
				Extended := NumGet(lParam+0, 8, "UInt") & 1
				sc := (Extended<<8)|NumGet(lParam+0, 4, "UInt")
				sc := sc = 0x136 ? 0x36 : sc
				key:=GetKeyName(Format("vk{1:x}sc{2:x}", vk,sc))
				
				event := wParam = WM_SYSKEYDOWN || wParam = WM_KEYDOWN
				
				OutputDebug % "Processing Key Hook... " key " | event: " event " | WP: " wParam
				
				; Find out if key went up or down, plus filter repeated down events
				if (event) {
					if (last_vk = vk && last_sc = sc){
						return 1
					}
					last_vk := vk
					last_sc := sc
				}

				modifier := (vk >= 160 && vk <= 165) || (vk >= 91 && vk <= 93)

				;OutputDebug, % "Key VK: " vk ", event: " event ", name: " GetKeyName(Format("vk{:x}", vk)) ", modifier: " modifier
				
				this._ProcessInput({Type: "k", name: key , vk : vk, event: event, modifier: modifier})
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
				
				keyname := ""
				event := 0
				
				if (IsObject(this._MouseLookup[wParam])){
					; L / R / M  buttons
					keyname := this._MouseLookup[wParam].name
					event := 1
				} else {
					; Wheel / XButtons
					; Find HiWord of mouseData from Struct
					mouseData := NumGet(lParam+0, 10, "Short")
					
					if (wParam = WM_MOUSEHWHEEL || wParam = WM_MOUSEWHEEL){
						; Mouse Wheel - mouseData indicate direction (up/down)
						event := 1	; wheel has no up event, only down
						if (wParam = WM_MOUSEWHEEL){
							keyname .= "Wheel"
							if (mouseData > 1){
								keyname .= "U"
							} else {
								keyname .= "D"
							}
						} else {
							keyname .= "Wheel"
							if (mouseData > 1){
								keyname .= "R"
							} else {
								keyname .= "L"
							}
						}
					} else if (wParam = WM_XBUTTONDOWN || wParam = WM_XBUTTONUP){
						; X Buttons - mouseData indicates Xbutton 1 or Xbutton2
						if (wParam = WM_XBUTTONDOWN){
							event := 1
						} else {
							event := 0
						}
						keyname := "XButton" mouseData
					}
				}
				
				;OutputDebug % "Mouse: " keyname ", event: " event
				this._ProcessInput({Type: "m", name: keyname, event: event})
				return 1
			}

			; All input (keyboard, mouse, joystick) should flow through here when in Bind Mode
			_ProcessInput(obj){
				;{Type: "k", name: keyname, code : keycode, event: event, modifier: modifier}
				;{Type: "m", name: keyname, event: event}
				; Do not process key if bind mode has been exited.
				; Prevents users from being able to hit multiple keys together and exceeding valid length
				static modifier_variants := {91: 92, 92: 91, 160: 161, 161: 160, 162: 163, 163: 162, 164: 165, 165: 164}
				
				if (!this._BindModeState){
					return
				}
				modifier := 0
				out := "PROCESSINPUT: "
				if (obj.Type = "k"){
					out .= "key = " obj.name ", code: " obj.vk
					if (obj.vk == 27){
						;Escape
						this._BindModeState := 0
						return
					}
					modifier := obj.modifier
					; RALT sends CTRL, ALT continuously when held - ignore down events for already held modifiers
					Loop % this._ModifiersUsed.length(){
						if (obj.event = 1 && obj.vk = this._ModifiersUsed[A_Index]){
							;OutputDebug % "IGNORING : " obj.vk
							return
						}
						;OutputDebug % "ALLOWING : " obj.vk " - " this._ModifiersUsed.length()
					}
					this._ModifiersUsed.push(obj.vk)
					; Push l/r variant to used list
					this._ModifiersUsed.push(modifier_variants[obj.vk])
				} else if (obj.Type = "m"){
					out .= "mouse = " obj.name
				} else if (obj.Type = "j"){
					
				}
				
				; Detect if Bind Mode should end
				;OutputDebug % out
				if (obj.event = 0){
					; key / button up
					this._BindModeState := 0
				} else {
					; key / button down
					this._SelectedInput.push(obj)
					; End if not modifier
					if (!modifier){
						this._BindModeState := 0
					}
				}
			}
		}		
		; Client command to add a hotkey
		AddHotkey(name, callback, options, default){
			this._Hotkeys[name] := {}
			fn := this.HotkeyChanged.Bind(this)
			this._Hotkeys[name].callback := callback
			hk := new this._CHotkeyControl(this._hwnd, name, fn, options, default)
			return hk
		}

		HotkeyChanged(hkobj){
			;MsgBox % "Hotkey :" hkobj.Name "`nNew Human Readable: " hkobj.HumanReadable "`nNew Hotkey String: " hkobj.Value
			ToolTip % hkobj.Value
			if (ObjHasKey(this._Hotkeys[hkobj.name], "binding")){
				; hotkey already bound, un-bind first
				hotkey, % this._Hotkeys[hkobj.name].binding, Off
			}
			; Bind new hotkey
			this._Hotkeys[hkobj.name].binding := hkobj.Value
			fn := this._Hotkeys[hkobj.name].callback
			hotkey, % hkobj.Value, % fn
			hotkey, % hkobj.Value, On
			OutputDebug % "BINDING: " hkobj._Value
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