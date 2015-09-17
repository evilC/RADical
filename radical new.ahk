#SingleInstance force

; ===========================================================================================================
; =====================================   SAMPLE CLIENT SCRIPT   ============================================
; ===========================================================================================================
rc := new RADicalClient()

class RADicalClient extends RADical {
	; Configure RADical - this is called before the GUI is created. Set RADical options etc here.

	Config(){
		; Add required tab(s)
		RADical.Tabs(["Tab A", "Tab B"])
	}
	
	; Called after Initialization - Assemble your GUI, set up your hotkeys etc here.
	Init(){
		; Place sample content in Tabs
		Loop 10 {
			Gui, Add, Edit, w300
		}
		
		; Switch to second Tab
		RADical.Tab("Tab B")
		Loop 5 {
			Gui, Add, Edit, w300
		}

	}
	
	; Once all setup is done, this function is called
	Main(){
		
	}
}

; ===========================================================================================================
; ========================================   RADICAL LIBRARY   ==============================================
; ===========================================================================================================

; Bootstrap class - Client Script must derive from this Class
; Instantiates client script
; Instantiates RADical class
; Fires off class methods in pre-determined order
class RADical {
	__New(){
		;static autostart := new RADicalClient()	; Trick to automatically instantiate Client Script
		OutputDebug DBGVIEWCLEAR
		OutputDebug % "Instantiating RADical class..."
		global RADical := new _radical(this)
		
		OutputDebug % "Configuring RADical..."
		this.Config()
		OutputDebug % "Initializing RADical..."
		RADical._Init()
		OutputDebug % "Initializing Client Script..."
		this.Init()
		OutputDebug % "Starting RADical..."
		RADical._Start()
		OutputDebug % "Calling Client Script Main()..."
		this.Main()
	}
}

; The main class that does the heavy lifting
; Client Scripts will call methods in this class
class _RADical {
	; --------------------- Public Routines ---------------------
	; Stuff Intended to be called by Client Scripts
	
	; Equivalent to Gui, Tab, Name
	Tab(name){
		Gui, % this._TabGuiHwnds[name] ":Default"
	}
	
	; Called during config phase to declare required Client Tabs
	Tabs(tabarr){
		if (tabarr.length()){
			this._ClientTabs := tabarr
		}
	}

	; Closes the script. Also causes the script to exit on Gui Close
	Exit(){
		GuiClose:
			ExitApp
	}
	
	; --------------------- Private Routines ---------------------
	; Behind-the-scenes stuff the user should not be touching
	_ClientTabs := ["Main"]			; Indexed Array of Client Tab names
	_TabFrameHwnds := {}			; Hwnds of the Textboxes that are the parents of the Child Guis inside the tabs
	_TabGuiHwnds := {}				; Hwnds of the child GUIs inside the tabs
	__New(clientscript){
		; Speed Optimizations
		SetBatchLines -1
		
		; Initialize values
		this._ClientScript := clientscript
		Gui, +Resize
		Gui, +Hwndhwnd
		this._MainHwnd := hwnd
		this._GuiSettings := {PosX: {_PHDefaultValue: 0}, PosY: {_PHDefaultValue: 0}}
	}
	
	; Sets up the GUI ready for the Client Script to add it's own GuiControls
	; Mainly for handling adding of the Tabs and Profile Management GuiControls
	_Init(){
		; Configure Tabs
		this._Tabs := []
		Loop % this._ClientTabs.length(){
			this._Tabs.push(this._ClientTabs[A_Index])
		}
		this._Tabs.push("Profiles")
		tablist := ""
		Loop % this._Tabs.length(){
			if (A_Index > 1){
				tablist .= "|"
			}
			tablist .= this._Tabs[A_Index]
		}
		Gui, Add, Tab2, w350 h240 hwndhTab -Wrap, % tablist
		colors := {"Tab A": "FF0000", "Tab B": "0000FF", "Profiles": "00FF00"}	; debugging - remove
		Loop % this._Tabs.length(){
			tabname := this._Tabs[A_Index]
			; Inject child gui into Tab
			Gui, % this._GuiCmd("Tab"), % tabname
			Gui, % this._GuiCmd("Add"), Text, % "hwndhwnd w330 h200"
			this._TabFrameHwnds[tabname] := hwnd
			Gui, New, hwndhwnd -Caption
			this._TabGuiHwnds[tabname] := hwnd
			Gui, % "+Parent" this._TabFrameHwnds[tabname]
			Gui, Color, % colors[tabname]	; debugging - remove
			Gui, Show
			Attach(this._TabFrameHwnds[tabname],"w1 h1")
		}
		Attach(hTab,"w1 h1")
		fn := this._OnSize.Bind(this)
		OnMessage(0x0005, fn)	; WM_SIZE
		
		this.Tab("Profiles")
		this._ProfileHandler := new ProfileHandler()
		
		; Set Default Gui as Child Gui of first Client Tab
		this.Tab(this._ClientTabs[1])
	}

	; Finish startup process
	_Start(){
		this._ProfileHandler.Init({Global: {GuiSettings: this._GuiSettings}})
		; ToDo: Check if coords lie outside screen area and move On-Screen if so.
		Gui, % this._GuiCmd("Show"), % "x" this._GuiSettings.PosX.value " y" this._GuiSettings.PosY.value
		; Hook into WM_MOVE after window is shown
		fn := this._OnMove.Bind(this)
		OnMessage(0x0003, fn)	; WM_MOVE
	}

	; Sizes child Guis in Tabs to fill size of tab
	_OnSize(wParam, lParam, msg, hwnd){
		if (hwnd != this._MainHwnd){
			return
		}
		W := (lParam & 0xffff) - 45
		H := (lParam >> 16) - 45
		Loop % this._Tabs.length(){
			tabname := this._Tabs[A_Index]
			dllcall("MoveWindow", "Ptr", this._TabGuiHwnds[tabname], "int", 0,"int", 0, "int", W, "int", H, "Int", 1)
		}
	}
	
	; Called when window moves. Store new coords in settings file
	_OnMove(wParam, lParam, msg, hwnd){
		if (hwnd != this._MainHwnd){
			return
		}
		;this._GuiSettings.PosX.value := (lParam & 0xffff) - 45
		;this._GuiSettings.PosY.value := (lParam >> 16) - 45
		; wParam and lParam are coords of the CLIENT area, and we want window position. Use WinGetPos instead
		WinGetPos, x, y
		this._GuiSettings.PosX.value := x
		this._GuiSettings.PosY.value := y
		this._ProfileHandler.SettingChanged()
	}
	
	; Prefixes _MainHwnd hwnd to guicommand
	_GuiCmd(cmd){
		return this._MainHwnd ":" cmd
	}
	
	;#include <HotClass>
}

#include <JSON>
#include <Attach>
#include <ProfileHandler>