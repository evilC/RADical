#SingleInstance force
OutputDebug, DBGVIEWCLEAR

/*
RADical - A Rapid Application Development framework for AutoHotkey

ToDo:

* Hotkey bound, removed, bound due to _AssociatedAppChanged

* Profiles system
+ Streamline Add / Delete / Copy / Rename code
+ Allow Auto switching of profiles based upon active application

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

GuiClose:
	ExitApp

; Example client script.
; When a hotkey is pressed, send the contents of the edit box
; Allow the end user to choose any hotkey, but specify a default of F12
; Save the contents of the edit box between runs
class MyClient extends RADical {
	; Initialize - this is called before the GUI is created. Set RADical options etc.
	Init(){
		this._myname := "Client" ; debugging
		; Add required tab(s)
		this.RADical.Tabs(["Settings"])
	}
	
	; Called after Initialization - Assemble your GUI, set up your hotkeys etc here
	Main(){
		; Set the current tab - analagous to Gui, Tab, Settings
		;this.RADical.Gui("Tab", "Settings")
		
		; Define a hotkey and specify the default key and what routine to run when it is pressed
		fn := this.SendMyStuff.Bind(this)
		this.RADical.Tabs.Settings.Gui("Add", "Text", "xm ym w300", "RADical Demo:`n`n1) Select a hotkey: ")
		this.RADical.Tabs.Settings.AddHotkey("SendStuff", fn, "xm yp+40", "F12")

		this.RADical.Tabs.Settings.Gui("Add", "Text", "xm yp+30 w300", "2) Type something in the box ")
		
		; Add an Edit box called MyEdit. Coords are relative to the tab canvas, not the whole GUI
		this.MyEdit := this.RADical.Tabs.Settings.Gui("Add", "Edit", "w100")
		
		; Tell RADical to save the value of the Edit box in an INI file (under the key name "MyEdit"), and call a routine any time it changes.
		fn := this.SettingChanged.bind(this)
		this.MyEdit.MakePersistent("MyEdit", "Settings Editbox", fn)
		
		this.RADical.Tabs.Settings.Gui("Add", "Text", "xm yp+30 w300", "3) Press the hotkey you bound.`nA tooltip will appear with the contents of the box on key down, and will disappear on key up. Also note that the settings for the boxes change when you switch profiles.")
	}
	
	; User-defined routine to call when any of the persistent settings change
	SettingChanged(){
		;ToolTip % "Edit box contents: " this.MyEdit.value
	}
	
	; The user-defined hotkey changed state
	SendMyStuff(state){
		if (state){
			; key pressed
			; Send contents of MyEdit box
			;Send % this.MyEdit.value
			this.RADical.AsynchBeep(1000, 200)
			ToolTip % this.MyEdit.Value
		} else {
			; key released
			this.RADical.AsynchBeep(500, 200)
			ToolTip
		}
	}
}


; ==================================================== RADICAL LIB =======================================================

; Create a class for the client script to derive from, that configures it and starts it up
class RADical {
	__New(){
		this.RADical := new _radical(this)
		OutputDebug % "Initializing Client Script Init START"
		this.Init()
		OutputDebug % "Initializing Client Script Init END"
		this.RADical._GuiCreate()
		OutputDebug % "Initializing Client Script Main START"
		this.Main()
		OutputDebug % "Initializing Client Script Main END"
		this.RADical._StartupDone()
	}
}

; The main class that does the heavy lifting
class _radical {
	; --------------------- Internal Routines ---------------------
	; Behind-the-scenes stuff the user should not be touching
	__New(client){
		OutputDebug % "RADical._New START"
		this._myname := "Library" ; debugging
		this._client := client
		
		this._hwnds := {}
		this._GuiSize := {w: 350, h: 250}	; Default size
		this._Profiles := []
		
		this._Hotkeys := {}					; basic info about hotkeys - bindings etc.
		this._PersistentControls := {}		; Array of persistent controls
		this._StartingUp := 1
		
		SplitPath, % A_ScriptName,,,,ScriptName
		this._ININame := ScriptName ".ini"
		OutputDebug % "RADical._New END"
	}
	
	; Create the main GUI
	_GuiCreate(){
		OutputDebug % "RADical._GuiCreate START"
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
		
		this.Tabs.Profiles.Gui("Add", "Text", "x5 y5", "Current Profile: ")
		this._ProfileSelect := this.Tabs.Profiles.Gui("Add", "DDL", "xp+80 yp-3 w210")
		fn := this._ProfileChanged.Bind(this)
		;this._ProfileSelect._MakePersistent("!Settings", "CurrentProfile", "Default", fn)
		this._ProfileSelect._MakePersistent("CurrentProfile", "Default", fn)

		; Associated App
		this.Tabs.Profiles.Gui("Add", "GroupBox", "x1 yp+30 R3.5 w295", "Associated Application:")
		this.Tabs.Profiles.Gui("Add", "Text", "x10 yp+20", "ahk_class: ")
		this._AssociatedAppEdit := this.Tabs.Profiles.Gui("Add", "Edit", "xp+60 yp-3 w175")
		
		fn := this._AssociatedAppChanged.Bind(this)
		this._AssociatedAppEdit.MakePersistent("AssociatedAppClass", "", fn)
		
		this._AssociatedAppLimit := this.Tabs.Profiles.Gui("Add", "Checkbox", "x10 yp+25", "Limit hotkeys to only work in Associated App")
		this._AssociatedAppLimit.MakePersistent("AssociatedAppLimit", 0, fn)
		
		this._AssociatedAppSwitch := this.Tabs.Profiles.Gui("Add", "Checkbox", "x10 yp+20 disabled", "Switch to this profile when Associated App is active")
		this._AssociatedAppSwitch.MakePersistent("AssociatedAppSwitch", 0, fn)
		
		; Set value of this.CurrentProfile
		this._ProfileSelect._LoadValue()
		/*
		; Add non-client GUIcontrols
		
		; ================================ Profiles ==========================================
		; Get list of profiles
		this.Tabs.Profiles.Gui("Add", "Text", "x5 y5", "Current Profile: ")
		;this._ProfileSelect := this.Tabs.Profiles.Gui("Add", "DDL", "xp+80 yp-3 w150", "Default|" profile_list)
		this._ProfileSelect := this.Tabs.Profiles.Gui("Add", "DDL", "xp+80 yp-3 w210")
		this._BuildProfileDDL()
		
		this._ProfileAddButton := this.Tabs.Profiles.Gui("Add", "Button", "x3 yp+25 center w70", "Add New")
		fn := this._AddProfile.Bind(this)
		GuiControl % "+g", % this._ProfileAddButton._hwnd, % fn
		
		this._ProfileCopyButton := this.Tabs.Profiles.Gui("Add", "Button", "xp+75 yp center w70", "Copy")
		fn := this._CopyProfile.Bind(this)
		GuiControl % "+g", % this._ProfileCopyButton._hwnd, % fn
		
		this._ProfileRenameButton := this.Tabs.Profiles.Gui("Add", "Button", "xp+75 yp center w70", "Rename")
		fn := this._RenameProfile.Bind(this)
		GuiControl % "+g", % this._ProfileRenameButton._hwnd, % fn
		
		this._ProfileDeleteButton := this.Tabs.Profiles.Gui("Add", "Button", "xp+75 yp center w70", "Delete")
		fn := this._DeleteProfile.Bind(this)
		GuiControl % "+g", % this._ProfileDeleteButton._hwnd, % fn
		
		fn := this._ProfileChanged.Bind(this)
		;this._ProfileSelect.MakePersistent("CurrentProfile", "Default", fn)
		
		this._ProfileSelect._MakePersistent("!Settings", "CurrentProfile", "Default", fn)
		
		; Associated App
		this.Tabs.Profiles.Gui("Add", "GroupBox", "x1 yp+30 R3.5 w295", "Associated Application:")
		this.Tabs.Profiles.Gui("Add", "Text", "x10 yp+20", "ahk_class: ")
		this._AssociatedAppEdit := this.Tabs.Profiles.Gui("Add", "Edit", "xp+60 yp-3 w175")
		
		fn := this._AssociatedAppChanged.Bind(this)
		this._AssociatedAppEdit.MakePersistent("AssociatedAppClass", "", fn)
		
		this._AssociatedAppLimit := this.Tabs.Profiles.Gui("Add", "Checkbox", "x10 yp+25", "Limit hotkeys to only work in Associated App")
		this._AssociatedAppLimit.MakePersistent("AssociatedAppLimit", 0, fn)
		
		this._AssociatedAppSwitch := this.Tabs.Profiles.Gui("Add", "Checkbox", "x10 yp+20 disabled", "Switch to this profile when Associated App is active")
		this._AssociatedAppSwitch.MakePersistent("AssociatedAppSwitch", 0, fn)
		
		; Load non-client GUI elements values
		this._ProfileSelect._LoadValue()
		

		;this._ProfileChanged()
		*/
		OutputDebug % "RADical._GuiCreate END"
	}
	
	_StartupDone(){
		OutputDebug % "RADical._StartupDone START"
		
		; Kick off loading of settings
		this._ProfileChanged()

		/*
		this._ProfileChanged()
		this._StartingUp := 0
		*/
		OutputDebug % "RADical._StartupDone END"
		OutputDebug % " "
	}
	
	_AssociatedAppChanged(){
		/*
		for name, hk in this._Hotkeys {
			hk.ctrl._HotkeyChangedBinding(hk.obj)
		}
		*/
	}
	
	_ProfileChanged(){
		val := this._ProfileSelect.value
		OutputDebug % "RADical._ProfileChanged START, profile='" val "'"
		this.CurrentProfile := val
		
		for name, obj in this._PersistentControls {
			if (!obj._ProfileSpecific){
				continue
			}
			; Load new Control value for this profile
			OutputDebug % "ProfileChanged: Loading persistent setting for " obj.name
			obj._LoadValue()
		}

		/*
		OutputDebug % "ProfileChanged : Processing change to profile " this._ProfileSelect.value
		this.CurrentProfile := this._ProfileSelect.value
		;ToolTip % this._ProfileSelect.value
		for name, obj in this._PersistentControls {
			; Load new Control value for this profile
			OutputDebug % "ProfileChanged: Loading persistent setting for " obj.name
			obj._LoadValue()
		}

		for name, hk in this._Hotkeys {
			val := this.IniRead(this.CurrentProfile, Name, hk.obj._DefaultValue)
			OutputDebug % "ProfileChanged: Loading hotkey setting for " name ", value = " val
			hk.obj.value := val
		}
		*/
		OutputDebug % "RADical._ProfileChanged END"
	}
	
	_BuildProfileDDL(){
		/*
		this._Profiles := ["Default"]
		profile_list := this.IniRead("!Settings", "ProfileList", "")
		profile_arr := StrSplit(profile_list, "|")
		Loop % profile_arr.length() {
			this._Profiles.push(profile_arr[A_Index])
		}
		GuiControl, , % this._ProfileSelect._hwnd, % "|Default|" profile_list
		GuiControl, choose,  % this._ProfileSelect._hwnd, % this.CurrentProfile
		this._ProfileChanged()
		*/
	}
	
	/*
	_AddProfile(){
		InputBox, new_name, " " , Enter new profile name ,,200 ,130,,,,,
		if (ErrorLevel = 0){
			if (new_name = ""){
				return
			}
			if (!this._IsValidNewProfileName(new_name)){
				return
			}
			this._Profiles.push(new_name)
			new_list := ""
			Loop % this._Profiles.length() {
				if (A_Index = 1){
					; do not list default
					continue
				}
				if (A_Index != 2){
					new_list .= "|"
				}
				new_list .= this._Profiles[A_Index]
			}
			this.IniWrite(new_list, "!Settings", "ProfileList", "")
			this.CurrentProfile := new_name
			this.IniWrite(new_name, "!Settings", "CurrentProfile", "Default")
			this._BuildProfileDDL()
		}
	}
	
	_DeleteProfile(){
		if (this.CurrentProfile = "Default"){
			this.AsynchBeep(500, 200)
		} else {
			new_list := ""
			profiles_added := 0
			Loop % this._Profiles.length() {
				if (A_Index = 1 || this._Profiles[A_Index] = this.CurrentProfile){
					; do not list default or deleted profile
					continue
				}
				if (profiles_added > 0){
					new_list .= "|"
				}
				new_list .= this._Profiles[A_Index]
				profiles_added++
			}
			IniDelete, % this._ININame, % this.CurrentProfile
			this.IniWrite(new_list, "!Settings", "ProfileList", "")
			this.CurrentProfile := "Default"
			this.IniWrite("Default", "!Settings", "CurrentProfile", "Default")
			this._BuildProfileDDL()
		}
	}
	
	_CopyProfile(){
		InputBox, new_name, " " , Enter new profile name ,,200 ,130,,,,,
		if (ErrorLevel = 0){
			if (!this._IsValidNewProfileName(new_name)){
				this.AsynchBeep(500, 200)
				return
			}
			this._Profiles.push(new_name)
			
			new_list := ""
			Loop % this._Profiles.length() {
				if (A_Index = 1){
					; do not list default
					continue
				}
				if (A_Index != 2){
					new_list .= "|"
				}
				new_list .= this._Profiles[A_Index]
			}
			IniRead, old_section, % this._ININame, % this.CurrentProfile
			IniWrite, % old_section, % this._ININame, % new_name
			this.IniWrite(new_list, "!Settings", "ProfileList", "")
			this.CurrentProfile := new_name
			this.IniWrite(new_name, "!Settings", "CurrentProfile", "Default")
			this._BuildProfileDDL()
		}
	}
	
	_RenameProfile(){
		if (this.CurrentProfile != "Default"){
			old_profile := this.CurrentProfile
			InputBox, new_name, " " , Enter new profile name ,,200 ,130,,,,,
			if (ErrorLevel = 0){
				if (!this._IsValidNewProfileName(new_name)){
					this.AsynchBeep(500, 200)
					return
				}
				IniRead, old_section, % this._ININame, % this.CurrentProfile
				profiles_added := 0
				new_list := ""
				Loop % this._Profiles.length() {
					if (A_Index = 1){
						; do not list default
						continue
					}
					if (profiles_added > 0){
						new_list .= "|"
					}
					if (this._Profiles[A_Index] = this.CurrentProfile){
						item := new_name
					} else {
						item := this._Profiles[A_Index]
					}
					new_list .= item
					profiles_added++
				}
				IniDelete, % this._ININame, % this.CurrentProfile
				IniWrite, % old_section, % this._ININame, % new_name
				this.IniWrite(new_list, "!Settings", "ProfileList", "")
				this.CurrentProfile := new_name
				this.IniWrite(new_name, "!Settings", "CurrentProfile", "Default")
				this._BuildProfileDDL()
			}
		}
	}
	*/

	; Checks that a new profile name is valid
	_IsValidNewProfileName(profile){
		if (Substr(profile, 1, 1) = "!"){
			; Do not allow profile names beginning with !
			return 0
		}
		Loop % this._Profiles.length() {
			if (this._Profiles[A_Index] = profile){
				return 0
			}
		}
		return 1
	}
	
	; --------- INI Reading / Writing -----------
	IniRead(Section, key, Default){
		;IniRead, val, % this._ININame, % Section, % this.Name, %A_Space%
		IniRead, val, % this._ININame, % Section, % key, % A_Space
		if (val = ""){
			val := Default
		}
		return val
	}
	
	IniWrite(value, section, key, Default){
		if (value = Default){
			IniDelete, % this._ININame, % Section, % key
		} else {
			IniWrite, % value, % this._ININame, % Section, % key
		}
	}

	; ----------------------------- GUI class ---------------------------
	; Wraps Child GUIs into a class
	class _CGui {
		#include <CHotkeyControl>

		__New(root, hwndParent){
			this._root := root
			
			Gui, New, hwndhGui
			this._hwnd := hGui
			Gui,% this._hwnd ":+Owner"
			Gui,% this._hwnd ":+OwnDialogs"
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
			/*
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
			*/
				GuiControl, % this._hwnd ":" cmd, % ctrl._hwnd, % Param3
				return this
			;}
		}

		; Wraps GuiControlGet
		GuiControlGet(cmd := "", ctrl := "", param4 := ""){
			GuiControlGet, ret, % this._hwnd ":" cmd, % ctrl._hwnd, % Param4
			return ret
		}
		
		; ----------------------------- GUI Control class ---------------------------
		class _CGuiControl {
			__New(parent, ctrltype, options := "", text := ""){
				this._Parent := parent		; Parent of this class
				this._root := parent._root	; this._root should always point to the root RADical class instance.
				this._CtrlType := ctrltype	; Egit "Edit", "DDL" etc
				this.Name := 0				; The name of the GuiControl
				this._glabel := 0			; The callback to be called on Control Change
				this._DefaultValue := ""	; The default value for the control (When reading from the Settings file)
				this._updating := 0			; Set to 1 when writing to GuiControl, to stop it writing to the settings file
				;this._ForceSection := ""	; Used to store setting not by profile, but in the settings section
				this._ProfileSpecific := 1	; Whether the control is a Profile Specific (Saved in current profile's section) or a Global Control (Saved in !Settings section)
				
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
					if (this._CtrlType = "DDL" || this._CtrlType = "DropdownList" || this._CtrlType = "Combobox"){
						return this._parent.GuiControl("Choose" ,this, aValue)
					} else {
						return this._parent.GuiControl(,this, aValue)
					}
				}
			}
		
			_OnChange(){
				OutputDebug % "GuiControl._OnChange START: '" this.name "'"
				/*
				; Update persistent settings
				if (this.Name){
					; Write settings to file
					; ToDo: Make Asynchronous
					if (!this._updating){
						if (this._ForceSection){
							Section := this._ForceSection
						} else {
							Section := this._parent._root.CurrentProfile
						}
						this._parent._root.IniWrite(this.value, Section, this.Name, this._DefaultValue)
					}
					
					; Call user glabel
					if (ObjHasKey(this,"_glabel") && this._glabel != 0){
						OutputDebug % "CGuiControl._OnChange: Firing callback for " this.name
						;%this._glabel%() ; ahk v2
						this._glabel.() ; ahk v1
					}
				}
				*/
				
				if (this.Name){
					this._parent._root.IniWrite(this.value, this._GetSectionName(this), this.Name, this._DefaultValue)
					
					; Call user glabel
					if (ObjHasKey(this,"_glabel") && this._glabel != 0){
						OutputDebug % "CGuiControl._OnChange: Firing callback for " this.name
						;%this._glabel%() ; ahk v2
						this._glabel.() ; ahk v1
					}
				}
				
				OutputDebug % "GuiControl._OnChange END: '" this.name "'"
			}
			
			; Internal MakePersistent - section is static, not dictated by current profile
			;_MakePersistent(Section, name, Default, glabel := 0){
			_MakePersistent(name, Default, glabel := 0){
				;OutputDebug % "_GuiControl._MakePersistent START: Name = '" name "'"
				this._ProfileSpecific := 0
				this.MakePersistent(name, Default, glabel)
				/*
				this._ForceSection := Section
				this.MakePersistent(name, Default, glabel)
				*/
			}
			
			; Makes a Gui Control persistent - value is saved in settings file
			MakePersistent(Name, Default := "", glabel := 0){
				OutputDebug % "_GuiControl.MakePersistent START: Name= '" name "', Profile Specific= " this._ProfileSpecific ", CtrlType: " this._CtrlType
				this.Name := Name
				this._glabel := glabel

				; If Ctrl Type is a ListBox, Combobox etc, load values from settings now
				if (this._IsListType(this._CtrlType)){
					;this._parent.GuiControl("", this, "A|B|C")
					val := this._root.IniRead(this._GetSectionName(this), this.Name "List", this._DefaultValue)
					; Populate Items
					GuiControl,, % this._hwnd, % val
				}
				; Set Default Value
				this._DefaultValue := Default
				; Add to list of Persistent controls
				this._root._PersistentControls[name] := this
				/*
				; ToDo: Check for uniqueness of name
				OutputDebug % "MakePersistent: Name = " name ", Default = " Default
				this.Name := Name
				this._glabel := glabel
				if (Default != ""){
					this._DefaultValue := Default
				}
				;if (!this._ForceSection){
					this._parent._root._PersistentControls[name] := this
				;}
				*/
				OutputDebug % "_GuiControl.MakePersistent END"
			}
			
			_GetSectionName(obj){
				if (obj._ProfileSpecific){
					return this._root.CurrentProfile
				} else {
					return "!Settings"
				}
			}
			
			; Is the GuiControl a list type that requires loading of the list in addition to selecting the current value?
			_IsListType(Type){
				if (Type = "DDL" || Type = "DropDownList" || Type = "ComboBox"){
					return 1
				} else {
					return 0
				}
			}

			; Loads the value for a control from an INI file.
			_LoadValue(){
				if (this._ProfileSpecific){
					Section := this._root.CurrentProfile
				} else {
					Section := "!Settings"
				}
				OutputDebug % "_GuiControl._LoadValue START: name= '" this.Name "', Section: " Section
				val := this._root.IniRead(Section, this.Name, this._DefaultValue)
				this.value := val
				/*
				this._updating := 1
				if (this._ForceSection){
					Section := this._ForceSection
				} else {
					Section := this._parent._root.CurrentProfile
				}
				this.value := this._parent._root.IniRead(Section, this.Name, this._DefaultValue)
				OutputDebug % "Loading Value for " this.name ", profile: " Section ", value = " this.value
				this._updating := 0
				*/
			}
			
		}
		
		; Client command to add a hotkey
		AddHotkey(name, callback, options, default){
			;OutputDebug % "AddHotkey: Name = " name ", Default = " Default
			/*
			this._root._Hotkeys[name] := {}
			fn := this._HotkeyChangedBinding.Bind(this)
			this._root._Hotkeys[name].callback := callback
			hk := new this._CHotkeyControl(this._hwnd, name, fn, options, "")
			hk._DefaultValue := Default
			this._root._Hotkeys[name].obj := hk
			this._root._Hotkeys[name].ctrl := this
			return hk
			*/
		}

		; A Hotkey changed binding
		_HotkeyChangedBinding(hkobj){
			/*
			;ToolTip % hkobj.Value
			if (ObjHasKey(this._root._Hotkeys[hkobj.name], "binding") && this._root._Hotkeys[hkobj.name].binding){
				cls := ""
				if (ObjHasKey(this._root._Hotkeys[hkobj.name], "winactive") && this._root._Hotkeys[hkobj.name].winactive){
					cls := this._root._Hotkeys[hkobj.name].winactive
				}
				hotkey, IfWinActive, % cls
				
				OutputDebug % "Removing old binding " this._root._Hotkeys[hkobj.name].binding ", class: " cls
				; hotkey already bound, un-bind first
				hotkey, % this._root._Hotkeys[hkobj.name].binding, Off
				;hotkey, % this._root._Hotkeys[hkobj.name].binding " up", Off
			}
			if (hkobj.Value = ""){
				return
			}
			; Bind new hotkey
			this._root._Hotkeys[hkobj.name].binding := hkobj.Value
			
			
			cls := ""
			if (this._root._AssociatedAppLimit.Value && this._root._AssociatedAppEdit.Value){
				cls := "ahk_class " this._root._AssociatedAppEdit.Value
			}
			this._root._Hotkeys[hkobj.name].winactive := cls
			
			if (hkobj.Value){
				hotkey, IfWinActive, % cls
				OutputDebug % "Adding new binding " hkobj.Value ", class: " cls
				; Bind Down Event
				fn := this._HotkeyChangedState.bind(this, hkobj, 1)
				hotkey, % hkobj.Value, % fn
				hotkey, % hkobj.Value, On
				
				; Bind Up Event
				fn := this._HotkeyChangedState.bind(this, hkobj, 0)
				hotkey, % hkobj.Value " up", % fn
				hotkey, % hkobj.Value " up", On
			}

			; Don't write to INI when starting up
			if (this._root._StartingUp){
				return
			}

			; Update INI File
			this._root.IniWrite(hkobj.Value, this._root.CurrentProfile, hkobj.name, hkobj._DefaultValue)
			OutputDebug % "BINDING: " hkobj._Value ", DEF: " hkobj._DefaultValue
			*/
		}
		
		; A bound hotkey changed state (ie was pressed or released)
		_HotkeyChangedState(hkobj, event){
			/*
			; Block duplicate down events for hotkeys
			if (hkobj._state = event){
				return
			}
			hkobj._state := event
			; Fire callback
			this._root._Hotkeys[hkobj.name].callback.(event)
			*/
		}
	}
	
	; Do not call directly, AsynchBeep calls this Asynchronously.
	_AsynchBeep(freq, dur){
		SoundBeep % freq, % dur
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
	
	; Send a beep but do not wait for it to finish
	AsynchBeep(freq, dur){
		fn := this._AsynchBeep.Bind(this, freq, dur)
		SetTimer, % fn, -0
	}
	
}