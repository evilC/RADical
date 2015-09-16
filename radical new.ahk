#SingleInstance force

; ===========================================================================================================
; =====================================   SAMPLE CLIENT SCRIPT   ============================================
; ===========================================================================================================
; Class MUST be called RADicalClient for static auto-instantiate trick to work
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
		static autostart := new RADicalClient()	; Trick to automatically instantiate Client Script
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
		this._ClientScript := clientscript
		Gui, +Resize
		Gui, +Hwndhwnd
		this._MainHwnd := hwnd
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
		Gui, Add, Tab2, w320 h240 hwndhTab, % tablist
		colors := {"Tab A": "FF0000", "Tab B": "0000FF", "Profiles": "00FF00"}	; debugging - remove
		Loop % this._Tabs.length(){
			tabname := this._Tabs[A_Index]
			; Inject child gui into Tab
			Gui, % this._GuiCmd("Tab"), % tabname
			Gui, % this._GuiCmd("Add"), Text, % "hwndhwnd w300 h200"
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
		OnMessage(0x0005, fn)
		
		; Set Default Gui as Child Gui of first Client Tab
		this.Tab(this._ClientTabs[1])
	}

	; Sizes child Guis in Tabs to fill size of tab
	_OnSize(wParam, lParam){
		W := (lParam & 0xffff) - 45
		H := (lParam >> 16) - 45
		Loop % this._Tabs.length(){
			tabname := this._Tabs[A_Index]
			dllcall("MoveWindow", "Ptr", this._TabGuiHwnds[tabname], "int", 0,"int", 0, "int", W, "int", H, "Int", 1)
		}
	}

	; Finish startup process
	_Start(){
		Gui, % this._GuiCmd("Show"), x0 y0
	}
	
	; Prefixes _MainHwnd hwnd to guicommand
	_GuiCmd(cmd){
		return this._MainHwnd ":" cmd
	}
	
	;#include <HotClass>
}

#include <JSON>
#include <Attach>