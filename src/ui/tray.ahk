/**
 * TrayManager - System tray integration for Simple Transcriber
 */
class TrayManager {
    static DefaultIcon := ""

    static Initialize() {
        ; Resolve icon path (handle both compiled and source layouts)
        if A_IsCompiled {
            this.DefaultIcon := A_ScriptDir "\assets\icon.ico"
        } else {
            this.DefaultIcon := A_ScriptDir "\..\assets\icon.ico"
        }

        if FileExist(this.DefaultIcon)
            TraySetIcon(this.DefaultIcon)

        A_TrayMenu.Delete()
        A_TrayMenu.Add("Open", (*) => MainWindow.Show())
        A_TrayMenu.Add()
        A_TrayMenu.Add("Settings", (*) => SettingsWindow.Show())
        A_TrayMenu.Add()
        A_TrayMenu.Add("Exit", (*) => ExitApp())
        A_TrayMenu.Default := "Open"
        A_TrayMenu.ClickCount := 1
        A_IconTip := "Simple Transcriber"
    }

    /**
     * Set tray icon to processing state
     */
    static SetProcessing() {
        A_IconTip := "Simple Transcriber - Processing..."
    }

    /**
     * Restore tray icon to default state
     */
    static SetDefault() {
        if FileExist(this.DefaultIcon)
            TraySetIcon(this.DefaultIcon)
        A_IconTip := "Simple Transcriber"
    }
}
