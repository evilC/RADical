#SingleInstance force
OutputDebug, DBGVIEWCLEAR

test := new test()

class test extends Radical {
	Init(){
		this.MyEdit := this.radical.Gui("Add", "Edit", "xm ym", "")
		fn := this.SettingChanged.bind(this)
		this.MyEdit.MakePersistent("MyEdit", "1", fn)
	}
	
	SettingChanged(){
		SoundBeep
	}
}

; =====================================================================================================

class Radical {
	__New(){
		this.radical := new this._radical()
		this.Init()
		this.radical.Show()
	}
	
	; Designed to be overridden
	Init(){
		MsgBox % "You have not overridden the Init() class"
		ExitApp
	}
	
	; ================== MAIN CLASS ==============
	class _radical {
		__New(){
			this.CurrentProfile := "Test Profile"
			
			Gui, new, hwndhGui
			this._hwnd := hGui
			SplitPath, % A_ScriptName,,,,ScriptName
			this._ScriptName .= ScriptName ".ini"
		}
		
		Show(){
			Gui, % this._hwnd ":Show"			
		}
		
		; Wrapper for Gui commands
		Gui(cmd, aParams*){
			if (cmd = "add"){
				; Create GuiControl
				obj := new this._GuiControl(this, aParams*)
				return obj
			} else if (cmd = "new"){
				;obj := new _Gui(this, aParams*)
				;return obj
			}
		}
		
		; Wraps GuiControlGet
		GuiControlGet(cmd := "", ctrl := "", param4 := ""){
			GuiControlGet, ret, % this._hwnd ":" cmd, % ctrl._hwnd, % Param4
			return ret
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

		PrefixHwnd(cmd){
			return this._hwnd ":" cmd
		}

		IniRead(Section, key, Default){
			;IniRead, val, % this._ScriptName, % Section, % this._PersistenceName, %A_Space%
			IniRead, val, % this._ScriptName, % Section, % key, % A_Space
			if (val = ""){
				val := Default
			}
			return val
		}
		
		IniWrite(value, section, key, Default){
			OutputDebug, % "DEFAULT: *" default "*"
			if (value = Default){
				IniDelete, % this._ScriptName, % Section, % key
			} else {
				IniWrite, % value, % this._ScriptName, % Section, % key
			}
		}
		
		; ============================= GUI Control ===========================
		class _GuiControl {
			__New(parent, ctrltype, options := "", text := ""){
				this._Parent := parent
				this._CtrlType := ctrltype
				this._PersistenceName := 0
				this._glabel := 0
				this._DefaultValue := ""
				this._updating := 0		; Set to 1 when writing to GuiControl, to stop it writing to the settings file
				
				Gui, % this._parent.PrefixHwnd("Add"), % ctrltype, % "hwndhwnd " options, % text
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
						this._parent.IniWrite(this.value, this._parent.CurrentProfile, this._PersistenceName, this._DefaultValue)
					}
					
					; Call user glabel
					if (ObjHasKey(this,"_glabel") && this._glabel != 0){
						%this._glabel%()
					}
				}
			}
			
			MakePersistent(Name, Default := "", glabel := 0){
				this._PersistenceName := Name
				this._glabel := glabel
				if (Default != ""){
					this._DefaultValue := Default
				}
				this._updating := 1
				val := this._parent.IniRead(this._parent.CurrentProfile, this._PersistenceName, this._DefaultValue)
				this.value := val
				this._updating := 0
			}
			
		}
		
	}
}
