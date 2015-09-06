#SingleInstance force
OutputDebug, DBGVIEWCLEAR

mc := new MyClass()
return

GuiClose:
	ExitApp
	return

class MyClass extends RADical {
	StartUp(){
		/*
		Loop 3 {
			name := "hk" A_Index
			this.RADical.AddHotkey(name, this.hkPressed.Bind(this, A_Index), "w280 xm")
		}
		*/
		this.MyEdit := this.RADical.AddGui("MyEdit", "Edit", "w200", "default", this.EditChanged.Bind(this))
	}
	
	hkPressed(hk, event){
		ToolTip % "hk " hk " - " event
		SoundBeep
	}
	
	EditChanged(){
		;ToolTip % this.MyEdit.value
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
			this._Settings := new this._SettingsHandler()
			;this._Settings.RegisterSetting("CurrentProfile", "Radical Profiles", "CurrentProfile", "Default")
			;this._Settings.RegisterSetting("ProfileList", "Radical Profiles", "ProfileList", {Default: 1, Test: 1})
			;this._Settings.RegisterGlobal("CurrentProfile", "Default")
			;this._Settings.RegisterGlobal("ProfileList", {Default: 1, Test: 1})
			this._ClientClass := clientclass
			
			this._GuiControls := {}
			
			; Instantiate Hotkey Class
			this._HotkeyClass := new this.HotClass({disablejoystickhats: 1}) ; Disable joystick hats for now as timers interfere with debugging

			Gui, new, hwndhwnd
			this.hwnd := hwnd
			
			Gui, Add, Tab2, w310 , Main|Settings|Profiles
			
			Gui, Tab, Profiles
			Gui, Add, DDL, w250 hwndhwnd
			fn := this._ProfileDDLChanged.Bind(this)
			GuiControl +g, % hwnd, % fn
			this._hProfilesDDL := hwnd
			
			; Default to main
			Gui, Tab, Main

		}

		Init(){
			list := this._BuildProfileList()
			GuiControl, , % this._hProfilesDDL, % list
			GuiControl, Choose, % this._hProfilesDDL, % this._Settings.GetGlobal("CurrentProfile")
		}
		
		AddGui(name, ctrltype, options := "", text := "", callback := ""){
			gui := new this._GuiControl(this._Settings, name, ctrltype, options, text, callback)
			this._GuiControls[name] := gui
		}
		
		; User command to add a new hotkey
		AddHotkey(name, callback, aParams*){
			this._HotkeyClass.AddHotkey(name, callback, aParams*)
		}
		
		_ProfileDDLChanged(){
			GuiControlGet, val ,, % this._hProfilesDDL
			this._Settings.SetGlobal("CurrentProfile", val)
		}
		
		_BuildProfileList(){
			list := "Default"
			;for profile in this._ProfileList {
			for profile in this._Settings.GetGlobal("ProfileList") {
				if (profile = "default"){
					continue
				}
				list .= "|" profile
			}
			return list
		}

		class _GuiControl{
			__New(settingshandler, name, ctrltype, options := "", text := "", callback := ""){
				this._SettingsHandler := settingshandler
				this.Name := name
				if (IsObject(callback)){
					this._Callback := callback
				}
				; Register Setting with Settings Handler
				this._SettingsHandler.RegisterPerProfile(name, text)
								
				; Load initial setting
				this._value := this._SettingsHandler.GetPerProfile(name)
				
				Gui, Add, % ctrltype, % "hwndhwnd " options, % this._value
				this.hwnd := hwnd
				
		
				fn := this._OnChange.Bind(this)
				GuiControl +g, % this.hwnd, % fn
			}
			
			_OnChange(){
				
				if (IsObject(this._Callback)){
					this._Callback.()
				}
			}
		}
		
		class _SettingsHandler{
			;_shst := 1	; disable setter at startup
			__New(){
				SplitPath, % A_ScriptName,,,,ScriptName
				this._ININame := ScriptName ".ini"
				
				; Instantiate JSON class
				this.JSON := new JSON()

				;this._Options := {}
				this._GlobalOptions := {}
				this._GlobalValues := {}
				this._PerProfileOptions := {}
				this._PerProfileValues := {}
				
				this.RegisterGlobal("CurrentProfile", "Default")
				this.GetGlobal("CurrentProfile")
				this.RegisterGlobal("ProfileList", {Default: 1, Test: 1})
				this.GetGlobal("ProfileList")
			}
			
			; Global Settings - Not influenced by profiles
			RegisterGlobal(setting, default){
				obj := {Section: "Global Settings", key: key, Default: default}
				obj.obj := IsObject(Default)
				this._GlobalOptions[setting] := obj
			}
			
			GetGlobal(setting){
				if (!ObjHasKey(this._GlobalValues, setting) && ObjHasKey(this._GlobalOptions, setting)){
					this._GlobalValues[setting] := this._ReadSetting(this._GlobalOptions[setting].Section, setting, this._GlobalOptions[setting].Default)
				}
				return this._GlobalValues[setting]
			}
			
			SetGlobal(setting, value){
				this._GlobalValues[setting] := value
				this._WriteSetting(value, this._GlobalOptions[setting].Section, setting, this._GlobalOptions[setting].Default)
			}

			; Per Profile settings - values will vary depending upon current profile
			RegisterPerProfile(setting, Default){
				obj := {key: key, Default: default}
				obj.obj := IsObject(Default)
				this._PerProfileOptions[setting] := obj
				; Set initial value from settings file
				if (!IsObject(this._PerProfileValues[this._GlobalValues.CurrentProfile])){
					this._PerProfileValues[this._GlobalValues.CurrentProfile] := {}
				}
				this._PerProfileValues[this._GlobalValues.CurrentProfile, setting] := this._ReadSetting(this._GlobalValues.CurrentProfile, setting, this._PerProfileOptions[setting].Default)
			}
			
			GetPerProfile(setting){
				;if (!ObjHasKey(this._PerProfileValues[this._GlobalValues.CurrentProfile], setting) && ObjHasKey(this._PerProfileOptions, setting)){
					return this._PerProfileValues[this._GlobalValues.CurrentProfile, setting]
				;}
			}
			
			SetPerProfile(setting, value){
				
			}
			
			_ReadSetting(section, key, default := ""){
				IniRead, val, % this._ININame, % section, % key, % A_Space
				if (val = ""){
					val := default
				} else {
					if (this._RegisteredSettings[setting].obj){
						val := this.JSON.Load(val)
					}
				}
				return val
			}
			
			_WriteSetting(value, section, key, default := ""){
				if (value = default){
					IniDelete, % this._ININame, % section, % key
				} else {
					IniWrite, % value, % this._ININame, % section, % key
				}
			}
			

		}
		#include <HotClass>
	}
}
#include <JSON>

