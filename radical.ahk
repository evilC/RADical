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
		this.MyEdit := this.RADical.AddGui("MyEdit", "Edit", "w200", "myeditdefault", this.EditChanged.Bind(this))
	}
	
	hkPressed(hk, event){
		ToolTip % "hk " hk " - " event
		SoundBeep
	}
	
	EditChanged(){
		ToolTip % this.MyEdit.value
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

			this.ProfileData := {}
			this._ClientClass := clientclass
			
			this._GuiControls := {}
			
			this.JSON := new JSON()
			; Instantiate Hotkey Class
			;this._HotkeyClass := new this.HotClass({disablejoystickhats: 1}) ; Disable joystick hats for now as timers interfere with debugging

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

			; Get Profile List
			this._ProfileList := this.JSON.Load(this._ReadSetting("Global Settings", "ProfileList", "{""Default"":1"))
			this._CurrentProfile := this._ReadSetting("Global Settings", "CurrentProfile", "Default")
			for profile in this._ProfileList {
				this.ProfileData[profile] := this.JSON.Load(this._ReadSetting("User Profiles", profile, "{}"))
			}
		}

		Init(){
			list := this._BuildProfileList()
			
			GuiControl, , % this._hProfilesDDL, % list
			GuiControl, Choose, % this._hProfilesDDL, % this._CurrentProfile
		}

		_ProfileDDLChanged(){
			GuiControlGet, val ,, % this._hProfilesDDL
			this._CurrentProfile := val
			this._WriteSetting(val, "Global Settings", "CurrentProfile", "Default")
			; Update Gui Controls
			for name, obj in this._GuiControls {
				obj._LoadValue()
			}
		}

		_BuildProfileList(){
			list := "Default"
			;for profile in this._ProfileList {
			for profile in this._ProfileList {
				if (profile = "default"){
					continue
				}
				list .= "|" profile
			}
			return list
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
			fn := this.__WriteSetting.Bind(this, value, section, key, default)
			SetTimer, % fn, -0
		}
		
		__WriteSetting(value, section, key, default := ""){
			if (value = default){
				IniDelete, % this._ININame, % section, % key
			} else {
				IniWrite, % value, % this._ININame, % section, % key
			}
		}

		_ControlChanged(name, value){
			this.ProfileData[this._CurrentProfile, name] := value
			; Remove entries that are default settings
			profile := this.ProfileData[this._CurrentProfile].clone()
			if (value = this._GuiControls[name]._default){
				profile.Delete(name)
			}
			; Write new entry for this profile
			profile := this.JSON.Dump(profile)
			this._WriteSetting(profile, "User Profiles", this._CurrentProfile, "{}")
		}
		
		AddGui(name, ctrltype, options := "", default := "", callback := ""){
			gui := new this._GuiControl(this, name, ctrltype, options, default, callback)
			this._GuiControls[name] := gui
			return gui
		}

		class _GuiControl{
			__New(handler, name, ctrltype, options := "", default := "", callback := ""){
				this._loading := 1
				this._handler := handler
				this._default := Default
				this.Name := name
				if (IsObject(callback)){
					this._Callback := callback
				}
				Gui, Add, % ctrltype, % "hwndhwnd " options
				this.hwnd := hwnd

				this._LoadValue()

				fn := this._OnChange.Bind(this)
				GuiControl +g, % this.hwnd, % fn
				this._loading := 0
			}
			
			__Get(param){
				if (param = "value"){
					return this._value
				}
			}
			
			;__Set(){
				; ToDo: Implement setter
			;}
			
			_LoadValue(){
				if (ObjHasKey(this._handler.ProfileData[this._handler._CurrentProfile], this.Name)){
					this._value := this._handler.ProfileData[this._handler._CurrentProfile, this.name]
				} else {
					this._value := this._default
				}
				GuiControl, , % this.hwnd, % this._value
			}
			
			_OnChange(){
				GuiControlGet, val ,, % this.hwnd
				this._value := val
				; Trigger Settings File Update
				this._handler._ControlChanged(this.Name, val)
				if (IsObject(this._callback)){
					this._Callback.()
				}
			}
		}

	}
}
#include <JSON>

