#SingleInstance force
OutputDebug, DBGVIEWCLEAR

mc := new MyClass()
return

GuiClose:
	ExitApp
	return

class MyClass extends RADical {
	StartUp(){
		Loop 3 {
			name := "hk" A_Index
			this.RADical.AddHotkey(name, this.hkPressed.Bind(this, A_Index), "w280 xm y" A_Index * 30)
		}
		this.MyEdit := this.RADical.AddGui("MyEdit", "Edit", "w200 yp+30", "myeditdefault", this.EditChanged.Bind(this))
	}
	
	hkPressed(hk, event){
		ToolTip % "hk " hk " - " event
		SoundBeep
	}
	
	EditChanged(){
		ToolTip % "Edit Value: " this.MyEdit.value
	}
}


class RADical {
	__New(){
		this.RADical := new this._RADical(this)
		this.StartUp()
		Gui, Show, x0 y0
		this.RADical.Init()
	}
	
	class _RADical {
		__New(clientclass){
			SplitPath, % A_ScriptName,,,,ScriptName
			this._ININame := ScriptName ".ini"

			this._SettingChangedFunc := this.__SettingChanged.Bind(this)
			this.ProfileData := {}
			this._ClientClass := clientclass
			
			this._GuiControls := {}
			this._Hotkeys := {}
			this.JSON := new JSON()
			
			; Instantiate Hotkey Class
			this._HotkeyClass := new this.HotClass({disablejoystickhats: 1, StartActive: 0, OnChangeCallback: this._HotkeyChanged.Bind(this)}) ; Disable joystick hats for now as timers interfere with debugging

			Gui +hwndhwnd
			this.hwnd := hwnd
			
			Gui, Add, Tab2, w310 , Main|Settings|Profiles
			
			Gui, Tab, Profiles
			Gui, Add, DDL, w250 hwndhwnd
			fn := this._ProfileDDLChanged.Bind(this)
			GuiControl +g, % hwnd, % fn
			this._hProfilesDDL := hwnd

			this._LoadSettings()
			
			; Default to main
			Gui, Tab, Main
			
			
		}

		; Initialize.
		; Fire off profile load
		; Build profiles DDL
		Init(){
			GuiControl, , % this._hProfilesDDL, % this._BuildProfileList()
			GuiControl, Choose, % this._hProfilesDDL, % this._Settings.CurrentProfile
			this._ChangeProfile(this._Settings.CurrentProfile)
		}

		; User Script wants to add a Gui Control
		AddGui(name, ctrltype, options := "", default := "", callback := ""){
			gui := new this._GuiControl(this, name, ctrltype, options, default, callback)
			this._GuiControls[name] := gui
			return gui
		}

		; User script wants to add a Hotkey
		AddHotkey(name, callback, aParams*){
			this._Hotkeys[name] := this._HotkeyClass.AddHotkey(name, callback, aParams*)
		}

		; Set initial state of persistent settings
		_LoadSettings(){
			FileRead, str, % this._ININame
			if (!str){
				this._Settings := {CurrentProfile: "Default", Profiles: {}}
				this._CreateProfile("Default")
				this._CreateProfile("TestProfile")
			} else {
				this._Settings := this.JSON.Load(str)
			}
		}
		
		; Creates an entry in the Settings profile list.
		_CreateProfile(profile){
			this._Settings.Profiles[profile] := {GuiControls: {}, Hotkeys: {}}
		}
		
		; This should be called after any setting (something in this._Settings) changes.
		_SettingChanged(){
			; Asynchronously fire write to disk
			;fn := this._SettingChangedFunc
			;SetTimer, % fn, -0
			this.__SettingChanged()
		}
		
		; Asynchronously called to write settings file to disk
		__SettingChanged(){
			str := this.JSON.Dump(this._Settings, true)
			file := FileOpen(this._ININame, "w")
			file.Write(str)
			file.Close()
		}
		
		; The user changed the binding of a hotkey
		_HotkeyChanged(name, value){
			this._Settings.Profiles[this._Settings.CurrentProfile].Hotkeys[name] := value
			OutputDebug % "Hotkey " Name " changed. new value: " value[1].code
			this._SettingChanged()
		}
		
		; Called when profile changes (including on start)
		_ChangeProfile(profile){
			; Iterate through GuiControls and Hotkeys, set them to new value
			for name, obj in this._GuiControls {
				;obj.value := "aaa"
				obj.value := this._Settings.Profiles[profile].GuiControls[name]
			}
			
			; Iterate through Hotkeys, set them to new value
			this._HotkeyClass.DisableHotkeys()
			for name, obj in this._Hotkeys {
				this._HotkeyClass.SetHotkey(name, this._Settings.Profiles[profile].Hotkeys[name])
				;OutputDebug % "HK: " newval[1].code
			}
			this._HotkeyClass.EnableHotkeys()
		}
		
		; Called when the Profile Select DDL changes
		_ProfileDDLChanged(){
			GuiControlGet, val ,, % this._hProfilesDDL
			this._Settings.CurrentProfile := val
			this._SettingChanged()
			this._ChangeProfile(val)
		}

		; Called when a GuiControl changes state due to a user changing it
		_ControlChanged(name, value){
			this._Settings.Profiles[this._Settings.CurrentProfile].GuiControls[name] := value
			this._SettingChanged()
		}


		; Builds a | delimited list of profiles for the Profile Select DDL.
		; Default is always first
		_BuildProfileList(){
			list := "Default"
			;for profile in this._ProfileList {
			for profile in this._Settings.Profiles {
				if (profile = "default"){
					continue
				}
				list .= "|" profile
			}
			return list
		}

		; Wraps a guicontrol
		; Fires the _ControlChanged method of the handler class if the value of the Control Changes through user interaction.
		class _GuiControl{
			__New(handler, name, ctrltype, options := "", default := "", callback := ""){
				this._handler := handler
				this._default := Default
				this.Name := name
				this._SetByValue := 0
				if (IsObject(callback)){
					this._Callback := callback
				}
				Gui, Add, % ctrltype, % "hwndhwnd " options
				this.hwnd := hwnd

				fn := this._OnChange.Bind(this)
				GuiControl +g, % this.hwnd, % fn
			}
			
			__Get(param){
				if (param = "value"){
					; GuiControl value was requested
					return this._value
				}
			}
			
			__Set(param, value){
				if (param = "value"){
					; Set of GuiControl by handler - update guicontrol, but do not fire the handler's _ControlChanged method
					this._value := value
					this._SetByValue := 1
					; Trigger write of settings file etc.
					OutputDebug % "Guicontrol __Set: Updating GuiControl " this.name " to " value
					; Trigger update of GuiControl
					GuiControl, , % this.hwnd, % value
					return this._value
				}
			}
			
			; Called when a GuiControl changes.
			; If this._SetByValue is set, then this change was due to it's value being set by the handler, so do not fire the handler's _ControlChanged method
			; Otherwise, it is the user changing the value - fire the handler's _ControlChanged method
			_OnChange(){
				if (!this._SetByValue){
					GuiControlGet, val ,, % this.hwnd
					OutputDebug % "GuiControl " this.name " OnChange Event. Firing Settings Change. New value: " val
					this._value := val
					this._handler._ControlChanged(this.Name, val)
				}
				; Trigger Callback - the value changed from the user's perspective - so fire the callback to let his script know
				if (IsObject(this._callback)){
					this._Callback.()
				}
				this._SetByValue := 0
			}
		}

		#include <HotClass> ; https://github.com/evilC/HotClass/
	}
}
#include <JSON> ; http://ahkscript.org/boards/viewtopic.php?f=6&t=627

