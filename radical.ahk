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
			this.RADical.AddHotkey(name, this.hkPressed.Bind(this, A_Index), "w280 xm")
		}
	}
	
	hkPressed(hk, event){
		ToolTip % "hk " hk " - " event
		SoundBeep
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
			this._ClientClass := clientclass
			
			SplitPath, % A_ScriptName,,,,ScriptName
			this._ININame := ScriptName ".ini"
			; Instantiate JSON class
			this.JSON := new JSON()

			; Instantiate Hotkey Class
			this._HotkeyClass := new this.HotClass({disablejoystickhats: 1}) ; Disable joystick hats for now as timers interfere with debugging

			Gui, new, hwndhwnd
			this.hwnd := hwnd
			
			Gui, Add, Tab2, w310 , Main|Settings|Profiles
			
			; Profiles
			this._CurrentProfile := this._ReadSetting("Radical Profiles", "CurrentProfile", "Default")
			this._ProfileList := this.JSON.Load(this._ReadSetting("Radical Profiles", "ProfileList", "{""default"": 1, ""blah"": 1}"))

			Gui, Tab, Profiles
			Gui, Add, DDL, w250 hwndhwnd
			this._hProfilesDDL := hwnd
			
			; Default to main
			Gui, Tab, Main

		}
		
		_ReadSetting(section, key, default := ""){
			IniRead, val, % this._ININame, % section, % key, % A_Space
			if (val = ""){
				val := default
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
		
		Init(){
			list := this._BuildProfileList()
			GuiControl, , % this._hProfilesDDL, % list
			GuiControl, Choose, % this._hProfilesDDL, % this._CurrentProfile
		}
		
		; User command to add a new hotkey
		AddHotkey(name, callback, aParams*){
			this._HotkeyClass.AddHotkey(name, callback, aParams*)
		}
		
		_BuildProfileList(){
			list := "Default"
			for profile in this._ProfileList {
				if (profile = "default"){
					continue
				}
				list .= "|" profile
			}
			return list
		}

		#include <HotClass>
	}
}
#include <JSON>

