#SingleInstance force
OutputDebug, DBGVIEWCLEAR

; ==================== TEST SCRIPT =================
test := new MyClient()
return

class MyClient extends RADical {
	; Initialize
	Init(){
		this._myname := "Client" ; debugging
		this.RADical.Tabs(["Settings","Second"])
	}
	
	Main(){
		;this.MyEdit := this.RADical.Gui("Add", "Edit", "xm ym", "")
		;fn := this.SettingChanged.bind(this)
		;this.MyEdit.MakePersistent("MyEdit", 1, fn)
	}
	
	SettingChanged(){
		SoundBeep
	}
}


; ===================== RADICAL LIB =================

class RADical {
	__New(){
		this.RADical := new _radical(this)
		this.Init()
		this.RADical._GuiCreate()
		this.Main()
	}
}

class _radical {
	__New(client){
		this._myname := "Library" ; debugging
		this._client := client
		
		this._hwnds := {}
		this._GuiSize := {w: 300, h: 150}	; Default size
	}
	
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
			Gui, % hMain ":Add",Text, % "w" this._GuiSize.w - 40 " h" this._GuiSize.h - 70 " hwndhGuiArea"
			
			Gui, New, hwndhTab
			Gui,% hTab ":+Owner"
			Gui, % hTab ":Color", red
			Gui, % hTab ":+parent" hGuiArea " -Border"
			Gui, % hTab ":Add", Edit, , Edit %A_Index%
			Gui, % hTab ":Show", % "x-5 y-5 w" this._GuiSize.w - 40 " h" this._GuiSize.h - 70
			this._hwnds.Tabs[this._TabIndex[A_Index]] := hTab
		}
	}
	
	Tabs(tabs){
		this._TabIndex := []
		this.Tabs := {}
		tabs.push("Bindings")
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