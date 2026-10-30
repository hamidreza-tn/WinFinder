import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

// MARK: - ثابت‌های طراحی
/// Single source for spacing and corner radii so the UI stays consistent.
private enum Design {
    static let cornerRadius: CGFloat = 10
    static let cardPadding: CGFloat = 12
    static let groupSpacing: CGFloat = 16
    static let rowSpacing: CGFloat = 10
}

/// Brand accent (from the AccentColor asset) used by switches, buttons, and
/// the header mark.
private enum Brand {
    static let accent = Color("AccentColor")

    static var headerGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.85), accent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Lightweight localization system (English, Persian, Spanish, French,
// Simplified Chinese, Hindi). English is the primary language; every missing
// entry falls back to English, then to the raw key.
enum L10n {
    /// Supported interface languages with their native names, in picker order.
    static let supportedLanguages: [(code: String, nativeName: String)] = [
        ("en", "English"),
        ("es", "Español"),
        ("fr", "Français"),
        ("zh-Hans", "简体中文"),
        ("hi", "हिन्दी"),
        ("fa", "فارسی"),
    ]

    static func tr(_ language: String, _ key: String) -> String {
        tables[language]?[key] ?? tables["en"]?[key] ?? key
    }

    // Each language lives in its own constant: one enormous nested literal
    // makes the Release-mode SIL optimizer crash on some Swift 6.2 toolchains.
    private static let english: [String: String] = [
            "window.title": "WinFinder Pro Settings",
            "header.subtitle": "Windows shortcuts for macOS Finder",
            "header.version": "Version",
            "header.enableAccess": "Grant Access",
            "header.active": "Active",
            "header.connecting": "Connecting",
            "header.paused": "Paused",
            "menu.shortcutsEnabled": "Shortcuts enabled",
            "menu.settings": "Settings…",
            "menu.quit": "Quit WinFinder",
            "issue.tapCreation": "Could not attach to system keyboard events. Retrying shortly; if this repeats, quit from the menu bar and relaunch.",
            "issue.automationDenied": "Permission to control Finder (F5 refresh) was denied. Enable it with the button below.",
            "issue.refreshFailed": "Finder window refresh failed.",
            "issue.openAutomation": "Open Automation settings",
            "perm.openAccessibility": "Open Accessibility settings",
            "perm.openAutomation": "Open Automation settings",
            "perm.hint": "If shortcuts do not work, check the permissions with these buttons.",
            "group.files": "File Management",
            "group.nav": "Navigation & File Transfer",
            "group.system": "System",
            "group.guide": "Active Shortcut Guide",
            "enter.title": "Open with Return (Enter)",
            "enter.subtitle": "Files and folders open with the Enter key",
            "delete.title": "Delete with the Delete key",
            "delete.subtitle": "Quickly move files to the Trash",
            "shiftDelete.title": "Permanent delete with Shift + Delete",
            "shiftDelete.subtitle": "Delete directly, skipping the Trash (macOS asks for confirmation)",
            "rename.title": "Rename with Command + R",
            "rename.subtitle": "Enter rename mode with Cmd + R or F2",
            "cut.title": "Cut & move (Cmd + X / Cmd + V)",
            "cut.subtitle": "Windows-style file cut support",
            "properties.title": "Properties with Option + Enter",
            "properties.subtitle": "Show the file's Get Info window",
            "altNav.title": "Navigate with Alt keys",
            "altNav.subtitle": "Alt+Up parent, Alt+Down open, Alt+Left back, Alt+Right forward",
            "backspace.title": "Go up with Delete",
            "backspace.subtitle": "Delete navigates to the parent folder instead of deleting (Explorer behavior)",
            "ctrl.title": "Windows Ctrl shortcuts",
            "ctrl.subtitle": "Ctrl+C/X/V/Z/S/P and Ctrl+A/F/N/W/T/O map to their Command equivalents; Ctrl+L opens Go to Folder; Ctrl+Shift+N makes a new folder",
            "f5.title": "Refresh folder with F5",
            "f5.subtitle": "Refresh the active window; press fn+F5 on laptops",
            "login.title": "Launch automatically at login",
            "login.subtitle": "Keep the app running in the background after boot",
            "login.notApplications": "WinFinder is not in /Applications — move it there for a reliable launch at login.",
            "delete.inactiveHint": "Inactive while Delete opens the parent folder.",
            "diag.title": "Diagnostics",
            "diag.accessibility": "Accessibility",
            "diag.eventtap": "Keyboard hook (event tap)",
            "diag.automation": "Finder automation (F5)",
            "diag.granted": "Granted",
            "diag.missing": "Missing",
            "diag.pending": "Unknown until the first F5",
            "diag.denied": "Denied",
            "diag.failed": "Failed",
            "diag.macversion": "macOS version",
            "diag.appversion": "App version",
            "diag.copyreport": "Copy diagnostics report",
            "perm.title": "Permissions",
            "tab.shortcuts": "Shortcuts",
            "tab.status": "Status",
            "guide.empty": "All shortcuts are currently off. Turn on the ones you want above.",
            "about.title": "About WinFinder Pro",
            "about.license": "Released under the MIT License.",
            "about.github": "View on GitHub",
            "menu.pauseForHour": "Pause for 1 hour",
            "settings.export": "Export settings",
            "settings.import": "Import settings",
            "settings.importFailed": "Could not import the settings file.",
            "diag.copied": "Copied!",
            "reset.button": "Reset all shortcuts",
            "reset.confirm": "All shortcut toggles will return to their defaults. Launch-at-login and the language stay unchanged.",
            "reset.confirmAction": "Reset",
            "reset.cancel": "Cancel",
            "cs.ctrlGoto": "Open Go to Folder",
            "language.title": "Interface language",
            "guide.hint": "This list updates with your enabled shortcuts.",
            "cs.open": "Open the selected file or folder",
            "cs.trash": "Move to Trash",
            "cs.parentFolder": "Go to the parent folder",
            "cs.permanentDelete": "Delete permanently (skip Trash)",
            "cs.rename": "Rename",
            "cs.cutPaste": "Cut with Cmd+X and move with Cmd+V",
            "cs.properties": "Show Get Info",
            "cs.navUpDown": "Parent folder / Open",
            "cs.navBackForward": "Back / Forward",
            "cs.refresh": "Refresh the active window",
            "cs.ctrlLayer": "Mapped to the same key with Command (copy, cut, paste, undo, save, print, select all, find, new window, …)",
            "cs.ctrlNewFolder": "New folder",
            "footer.note": "Closing this window keeps WinFinder running in the menu bar.",
            "footer.close": "Close window",
        ]

    private static let spanish: [String: String] = [
            "window.title": "Ajustes de WinFinder Pro",
            "header.subtitle": "Atajos de Windows para Finder de macOS",
            "header.version": "Versión",
            "header.enableAccess": "Conceder acceso",
            "header.active": "Activo",
            "header.connecting": "Conectando",
            "header.paused": "En pausa",
            "menu.shortcutsEnabled": "Atajos activados",
            "menu.settings": "Ajustes…",
            "menu.quit": "Salir de WinFinder",
            "issue.tapCreation": "No se pudo conectar a los eventos del teclado del sistema. Se reintentará en unos momentos; si vuelve a ocurrir, salga de la app desde la barra de menús y ábrala de nuevo.",
            "issue.automationDenied": "Se denegó el permiso para controlar Finder (actualizar con F5). Actívelo con el botón siguiente.",
            "issue.refreshFailed": "No se pudo actualizar la ventana de Finder.",
            "issue.openAutomation": "Abrir ajustes de Automatización",
            "perm.openAccessibility": "Abrir ajustes de Accesibilidad",
            "perm.openAutomation": "Abrir ajustes de Automatización",
            "perm.hint": "Si los atajos no funcionan, compruebe los permisos con estos botones.",
            "group.files": "Gestión de archivos",
            "group.nav": "Navegación y transferencia de archivos",
            "group.system": "Sistema",
            "group.guide": "Guía de atajos activos",
            "enter.title": "Abrir con Return (Enter)",
            "enter.subtitle": "Los archivos y carpetas se abren con la tecla Enter",
            "delete.title": "Eliminar con la tecla Delete",
            "delete.subtitle": "Mueva archivos a la Papelera rápidamente",
            "shiftDelete.title": "Eliminación permanente con Mayús + Delete",
            "shiftDelete.subtitle": "Elimina directamente, sin pasar por la Papelera (macOS pide confirmación)",
            "rename.title": "Renombrar con Comando + R",
            "rename.subtitle": "Entre en el modo de renombrado con Cmd + R o F2",
            "cut.title": "Cortar y mover (Cmd + X / Cmd + V)",
            "cut.subtitle": "Soporte para cortar archivos al estilo Windows",
            "properties.title": "Propiedades con Opción + Enter",
            "properties.subtitle": "Muestra la ventana Obtener información del archivo",
            "altNav.title": "Navegación con las teclas Alt",
            "altNav.subtitle": "Alt+Arriba carpeta superior, Alt+Abajo abrir, Alt+Izquierda atrás, Alt+Derecha adelante",
            "backspace.title": "Ir a la carpeta superior con Delete",
            "backspace.subtitle": "Delete navega a la carpeta superior en lugar de eliminar (comportamiento del Explorador)",
            "ctrl.title": "Atajos de Ctrl de Windows",
            "ctrl.subtitle": "Ctrl+C/X/V/Z/S/P y Ctrl+A/F/N/W/T/O se asignan a sus equivalentes con Comando; Ctrl+L abre «Ir a la carpeta»; Ctrl+Mayús+N crea una carpeta nueva",
            "f5.title": "Actualizar carpeta con F5",
            "f5.subtitle": "Actualiza la ventana activa; pulse fn+F5 en portátiles",
            "login.title": "Iniciar automáticamente al iniciar sesión",
            "login.subtitle": "Mantener la app en segundo plano tras el arranque",
            "login.notApplications": "WinFinder no está en /Applications; muévelo allí para un inicio de sesión fiable.",
            "delete.inactiveHint": "Inactivo mientras Delete abre la carpeta superior.",
            "diag.title": "Diagnóstico",
            "diag.accessibility": "Accesibilidad",
            "diag.eventtap": "Gancho de teclado (event tap)",
            "diag.automation": "Automatización de Finder (F5)",
            "diag.granted": "Concedido",
            "diag.missing": "Falta",
            "diag.pending": "Desconocido hasta el primer F5",
            "diag.denied": "Denegado",
            "diag.failed": "Error",
            "diag.macversion": "Versión de macOS",
            "diag.appversion": "Versión de la app",
            "diag.copyreport": "Copiar informe de diagnóstico",
            "perm.title": "Permisos",
            "tab.shortcuts": "Atajos",
            "tab.status": "Estado",
            "guide.empty": "Todos los atajos están desactivados. Activa arriba los que quieras.",
            "about.title": "Acerca de WinFinder Pro",
            "about.license": "Publicado bajo la Licencia MIT.",
            "about.github": "Ver en GitHub",
            "menu.pauseForHour": "Pausar durante 1 hora",
            "settings.export": "Exportar ajustes",
            "settings.import": "Importar ajustes",
            "settings.importFailed": "No se pudo importar el archivo de ajustes.",
            "diag.copied": "¡Copiado!",
            "reset.button": "Restablecer todos los atajos",
            "reset.confirm": "Todos los atajos volverán a sus valores predeterminados. El inicio de sesión y el idioma no cambian.",
            "reset.confirmAction": "Restablecer",
            "reset.cancel": "Cancelar",
            "cs.ctrlGoto": "Abrir «Ir a la carpeta»",
            "language.title": "Idioma de la interfaz",
            "guide.hint": "Esta lista se actualiza según los atajos que tenga activados.",
            "cs.open": "Abrir el archivo o carpeta seleccionado",
            "cs.trash": "Mover a la Papelera",
            "cs.parentFolder": "Ir a la carpeta superior",
            "cs.permanentDelete": "Eliminar permanentemente (sin Papelera)",
            "cs.rename": "Renombrar",
            "cs.cutPaste": "Cortar con Cmd+X y mover con Cmd+V",
            "cs.properties": "Mostrar Obtener información",
            "cs.navUpDown": "Carpeta superior / Abrir",
            "cs.navBackForward": "Atrás / Adelante",
            "cs.refresh": "Actualizar la ventana activa",
            "cs.ctrlLayer": "Se asigna a la misma tecla con Comando (copiar, cortar, pegar, deshacer, guardar, imprimir, seleccionar todo, buscar, nueva ventana, …)",
            "cs.ctrlNewFolder": "Nueva carpeta",
            "footer.note": "Al cerrar esta ventana, WinFinder sigue activo en la barra de menús.",
            "footer.close": "Cerrar ventana",
        ]

    private static let french: [String: String] = [
            "window.title": "Réglages de WinFinder Pro",
            "header.subtitle": "Les raccourcis Windows pour le Finder de macOS",
            "header.version": "Version",
            "header.enableAccess": "Autoriser l'accès",
            "header.active": "Actif",
            "header.connecting": "Connexion",
            "header.paused": "En pause",
            "menu.shortcutsEnabled": "Raccourcis activés",
            "menu.settings": "Réglages…",
            "menu.quit": "Quitter WinFinder",
            "issue.tapCreation": "Impossible de capter les événements clavier du système. Nouvelle tentative dans quelques instants ; si le problème persiste, quittez l'app depuis la barre des menus puis relancez-la.",
            "issue.automationDenied": "L'autorisation de contrôler Finder (actualisation via F5) a été refusée. Activez-la avec le bouton ci-dessous.",
            "issue.refreshFailed": "Échec de l'actualisation de la fenêtre Finder.",
            "issue.openAutomation": "Ouvrir les réglages d'Automatisation",
            "perm.openAccessibility": "Ouvrir les réglages d'Accessibilité",
            "perm.openAutomation": "Ouvrir les réglages d'Automatisation",
            "perm.hint": "Si les raccourcis ne fonctionnent pas, vérifiez les autorisations avec ces boutons.",
            "group.files": "Gestion des fichiers",
            "group.nav": "Navigation et transfert de fichiers",
            "group.system": "Système",
            "group.guide": "Guide des raccourcis actifs",
            "enter.title": "Ouvrir avec Retour (Entrée)",
            "enter.subtitle": "Les fichiers et dossiers s'ouvrent avec la touche Entrée",
            "delete.title": "Supprimer avec la touche Suppr",
            "delete.subtitle": "Déplacer rapidement des fichiers vers la Corbeille",
            "shiftDelete.title": "Suppression définitive avec Maj + Suppr",
            "shiftDelete.subtitle": "Supprime directement, sans passer par la Corbeille (macOS demande une confirmation)",
            "rename.title": "Renommer avec Commande + R",
            "rename.subtitle": "Passer en mode renommage avec Cmd + R ou F2",
            "cut.title": "Couper et déplacer (Cmd + X / Cmd + V)",
            "cut.subtitle": "Prise en charge du couper de fichiers à la Windows",
            "properties.title": "Propriétés avec Option + Entrée",
            "properties.subtitle": "Affiche la fenêtre Lire les informations du fichier",
            "altNav.title": "Navigation avec les touches Alt",
            "altNav.subtitle": "Alt+Haut dossier parent, Alt+Bas ouvrir, Alt+Gauche retour, Alt+Droite avancer",
            "backspace.title": "Dossier parent avec Suppr",
            "backspace.subtitle": "Suppr navigue vers le dossier parent au lieu de supprimer (comportement de l'Explorateur)",
            "ctrl.title": "Raccourcis Ctrl de Windows",
            "ctrl.subtitle": "Ctrl+C/X/V/Z/S/P et Ctrl+A/F/N/W/T/O passent à leurs équivalents Commande ; Ctrl+L ouvre « Aller au dossier » ; Ctrl+Maj+N crée un nouveau dossier",
            "f5.title": "Actualiser le dossier avec F5",
            "f5.subtitle": "Actualise la fenêtre active ; utilisez fn+F5 sur les ordinateurs portables",
            "login.title": "Lancement automatique à l'ouverture de session",
            "login.subtitle": "Garder l'app en arrière-plan après le démarrage",
            "login.notApplications": "WinFinder n'est pas dans /Applications ; déplacez-le à cet endroit pour un lancement fiable à l'ouverture de session.",
            "delete.inactiveHint": "Inactif tant que Suppr ouvre le dossier parent.",
            "diag.title": "Diagnostic",
            "diag.accessibility": "Accessibilité",
            "diag.eventtap": "Crochet clavier (event tap)",
            "diag.automation": "Automatisation de Finder (F5)",
            "diag.granted": "Accordé",
            "diag.missing": "Manquant",
            "diag.pending": "Inconnu avant le premier F5",
            "diag.denied": "Refusé",
            "diag.failed": "Échec",
            "diag.macversion": "Version de macOS",
            "diag.appversion": "Version de l'app",
            "diag.copyreport": "Copier le rapport de diagnostic",
            "perm.title": "Autorisations",
            "tab.shortcuts": "Raccourcis",
            "tab.status": "État",
            "guide.empty": "Tous les raccourcis sont désactivés. Activez ci-dessus ceux que vous voulez.",
            "about.title": "À propos de WinFinder Pro",
            "about.license": "Publié sous licence MIT.",
            "about.github": "Voir sur GitHub",
            "menu.pauseForHour": "Mettre en pause pendant 1 heure",
            "settings.export": "Exporter les réglages",
            "settings.import": "Importer les réglages",
            "settings.importFailed": "Impossible d'importer le fichier de réglages.",
            "diag.copied": "Copié !",
            "reset.button": "Réinitialiser tous les raccourcis",
            "reset.confirm": "Tous les raccourcis reviendront à leurs valeurs par défaut. L'ouverture de session et la langue restent inchangées.",
            "reset.confirmAction": "Réinitialiser",
            "reset.cancel": "Annuler",
            "cs.ctrlGoto": "Ouvrir « Aller au dossier »",
            "language.title": "Langue de l'interface",
            "guide.hint": "Cette liste se met à jour selon vos raccourcis activés.",
            "cs.open": "Ouvrir le fichier ou dossier sélectionné",
            "cs.trash": "Mettre à la Corbeille",
            "cs.parentFolder": "Aller au dossier parent",
            "cs.permanentDelete": "Supprimer définitivement (sans Corbeille)",
            "cs.rename": "Renommer",
            "cs.cutPaste": "Couper avec Cmd+X et déplacer avec Cmd+V",
            "cs.properties": "Afficher Lire les informations",
            "cs.navUpDown": "Dossier parent / Ouvrir",
            "cs.navBackForward": "Retour / Avancer",
            "cs.refresh": "Actualiser la fenêtre active",
            "cs.ctrlLayer": "Mappée sur la même touche avec Commande (copier, couper, coller, annuler, enregistrer, imprimer, tout sélectionner, rechercher, nouvelle fenêtre, …)",
            "cs.ctrlNewFolder": "Nouveau dossier",
            "footer.note": "En fermant cette fenêtre, WinFinder reste actif dans la barre des menus.",
            "footer.close": "Fermer la fenêtre",
        ]

    private static let chinese: [String: String] = [
            "window.title": "WinFinder Pro 设置",
            "header.subtitle": "为 macOS Finder 带来 Windows 快捷键",
            "header.version": "版本",
            "header.enableAccess": "授予访问权限",
            "header.active": "运行中",
            "header.connecting": "连接中",
            "header.paused": "已暂停",
            "menu.shortcutsEnabled": "启用快捷键",
            "menu.settings": "设置…",
            "menu.quit": "退出 WinFinder",
            "issue.tapCreation": "无法连接系统键盘事件，稍后将自动重试；如果反复出现，请从菜单栏退出应用并重新打开。",
            "issue.automationDenied": "控制 Finder 的权限（F5 刷新）已被拒绝，请通过下方按钮开启。",
            "issue.refreshFailed": "刷新 Finder 窗口失败。",
            "issue.openAutomation": "打开“自动化”设置",
            "perm.openAccessibility": "打开“辅助功能”设置",
            "perm.openAutomation": "打开“自动化”设置",
            "perm.hint": "如果快捷键不起作用，请通过这些按钮检查权限。",
            "group.files": "文件管理",
            "group.nav": "导航与文件移动",
            "group.system": "系统",
            "group.guide": "已启用的快捷键",
            "enter.title": "用回车键打开",
            "enter.subtitle": "按 Enter 打开文件和文件夹",
            "delete.title": "用 Delete 键删除",
            "delete.subtitle": "快速将文件移到废纸篓",
            "shiftDelete.title": "Shift + Delete 永久删除",
            "shiftDelete.subtitle": "直接删除，不经过废纸篓（macOS 会要求确认）",
            "rename.title": "用 Command + R 重命名",
            "rename.subtitle": "按 Cmd + R 或 F2 进入重命名模式",
            "cut.title": "剪切与移动（Cmd + X / Cmd + V）",
            "cut.subtitle": "类似 Windows 的文件剪切功能",
            "properties.title": "Option + Enter 查看简介",
            "properties.subtitle": "显示文件的“显示简介”窗口",
            "altNav.title": "用 Alt 键导航",
            "altNav.subtitle": "Alt+↑ 上级文件夹，Alt+↓ 打开，Alt+← 返回，Alt+→ 前进",
            "backspace.title": "用 Delete 返回上级",
            "backspace.subtitle": "Delete 改为前往上级文件夹而不是删除（资源管理器行为）",
            "ctrl.title": "Windows Ctrl 快捷键",
            "ctrl.subtitle": "Ctrl+C/X/V/Z/S/P 与 Ctrl+A/F/N/W/T/O 映射为对应的 Command；Ctrl+L 打开“前往文件夹”；Ctrl+Shift+N 新建文件夹",
            "f5.title": "F5 刷新文件夹",
            "f5.subtitle": "刷新当前窗口；笔记本电脑请按 fn+F5",
            "login.title": "登录时自动启动",
            "login.subtitle": "开机后让应用在后台保持运行",
            "login.notApplications": "WinFinder 不在 /Applications 中——请将它移到该文件夹，以确保登录时可靠启动。",
            "delete.inactiveHint": "当 Delete 用于打开上级文件夹时不可用。",
            "diag.title": "诊断",
            "diag.accessibility": "辅助功能",
            "diag.eventtap": "键盘钩子（event tap）",
            "diag.automation": "Finder 自动化（F5）",
            "diag.granted": "已授权",
            "diag.missing": "缺失",
            "diag.pending": "首次按 F5 前未知",
            "diag.denied": "已拒绝",
            "diag.failed": "失败",
            "diag.macversion": "macOS 版本",
            "diag.appversion": "应用版本",
            "diag.copyreport": "复制诊断报告",
            "perm.title": "权限",
            "tab.shortcuts": "快捷键",
            "tab.status": "状态",
            "guide.empty": "所有快捷键当前已关闭。请在上方开启需要的快捷键。",
            "about.title": "关于 WinFinder Pro",
            "about.license": "基于 MIT 许可证发布。",
            "about.github": "在 GitHub 上查看",
            "menu.pauseForHour": "暂停 1 小时",
            "settings.export": "导出设置",
            "settings.import": "导入设置",
            "settings.importFailed": "无法导入设置文件。",
            "diag.copied": "已复制！",
            "reset.button": "重置所有快捷键",
            "reset.confirm": "所有快捷键开关将恢复默认。登录启动和语言保持不变。",
            "reset.confirmAction": "重置",
            "reset.cancel": "取消",
            "cs.ctrlGoto": "打开“前往文件夹”",
            "language.title": "界面语言",
            "guide.hint": "此列表会随你启用的快捷键自动更新。",
            "cs.open": "打开选中的文件或文件夹",
            "cs.trash": "移到废纸篓",
            "cs.parentFolder": "前往上级文件夹",
            "cs.permanentDelete": "永久删除（不进废纸篓）",
            "cs.rename": "重命名",
            "cs.cutPaste": "Cmd+X 剪切，Cmd+V 移动",
            "cs.properties": "显示简介",
            "cs.navUpDown": "上级文件夹 / 打开",
            "cs.navBackForward": "返回 / 前进",
            "cs.refresh": "刷新当前窗口",
            "cs.ctrlLayer": "映射为同样的键加 Command（复制、剪切、粘贴、撤销、保存、打印、全选、搜索、新窗口等）",
            "cs.ctrlNewFolder": "新建文件夹",
            "footer.note": "关闭此窗口后，WinFinder 仍会保留在菜单栏。",
            "footer.close": "关闭窗口",
        ]

    private static let hindi: [String: String] = [
            "window.title": "WinFinder Pro सेटिंग्स",
            "header.subtitle": "macOS Finder के लिए Windows शॉर्टकट",
            "header.version": "संस्करण",
            "header.enableAccess": "पहुँच प्रदान करें",
            "header.active": "सक्रिय",
            "header.connecting": "कनेक्ट हो रहा है",
            "header.paused": "रुका हुआ",
            "menu.shortcutsEnabled": "शॉर्टकट सक्रिय",
            "menu.settings": "सेटिंग्स…",
            "menu.quit": "WinFinder बंद करें",
            "issue.tapCreation": "सिस्टम कीबोर्ड इवेंट से कनेक्ट नहीं हो सका। कुछ क्षणों में फिर कोशिश की जाएगी; यदि बार-बार हो, तो मेन्यू बार से ऐप बंद करके दोबारा खोलें।",
            "issue.automationDenied": "Finder को नियंत्रित करने की अनुमति (F5 रिफ्रेश) अस्वीकृत है। नीचे दिए बटन से इसे सक्रिय करें।",
            "issue.refreshFailed": "Finder विंडो रिफ्रेश विफल रहा।",
            "issue.openAutomation": "Automation सेटिंग्स खोलें",
            "perm.openAccessibility": "Accessibility सेटिंग्स खोलें",
            "perm.openAutomation": "Automation सेटिंग्स खोलें",
            "perm.hint": "यदि शॉर्टकट काम नहीं कर रहे हैं, तो इन बटनों से अनुमतियाँ जाँचें।",
            "group.files": "फ़ाइल प्रबंधन",
            "group.nav": "नेविगेशन और फ़ाइल स्थानांतरण",
            "group.system": "सिस्टम",
            "group.guide": "सक्रिय शॉर्टकट गाइड",
            "enter.title": "Return (Enter) से खोलें",
            "enter.subtitle": "फ़ाइलें और फ़ोल्डर Enter कुंजी से खुलते हैं",
            "delete.title": "Delete कुंजी से हटाएँ",
            "delete.subtitle": "फ़ाइलें तुरंत ट्रैश में भेजें",
            "shiftDelete.title": "Shift + Delete से स्थायी हटाना",
            "shiftDelete.subtitle": "ट्रैश से गुज़रे बिना सीधे हटाएँ (macOS पुष्टि माँगेगा)",
            "rename.title": "Command + R से नाम बदलें",
            "rename.subtitle": "Cmd + R या F2 से नाम बदलने के मोड में जाएँ",
            "cut.title": "कट और मूव (Cmd + X / Cmd + V)",
            "cut.subtitle": "Windows जैसी फ़ाइल कट सुविधा",
            "properties.title": "Option + Enter से जानकारी",
            "properties.subtitle": "फ़ाइल की Get Info विंडो दिखाता है",
            "altNav.title": "Alt कुंजियों से नेविगेशन",
            "altNav.subtitle": "Alt+↑ पैरेंट फ़ोल्डर, Alt+↓ खोलें, Alt+← वापस, Alt+→ आगे",
            "backspace.title": "Delete से पैरेंट फ़ोल्डर पर जाएँ",
            "backspace.subtitle": "Delete हटाने के बजाय पैरेंट फ़ोल्डर पर ले जाता है (Explorer व्यवहार)",
            "ctrl.title": "Windows Ctrl शॉर्टकट",
            "ctrl.subtitle": "Ctrl+C/X/V/Z/S/P और Ctrl+A/F/N/W/T/O उनके Command समकक्षों पर मैप होते हैं; Ctrl+L «फ़ोल्डर पर जाएँ» खोलता है; Ctrl+Shift+N नया फ़ोल्डर बनाता है",
            "f5.title": "F5 से फ़ोल्डर रिफ्रेश करें",
            "f5.subtitle": "सक्रिय विंडो रिफ्रेश करें; लैपटॉप पर fn+F5 दबाएँ",
            "login.title": "लॉगिन पर स्वतः शुरू करें",
            "login.subtitle": "बूट के बाद ऐप को बैकग्राउंड में चालू रखें",
            "login.notApplications": "WinFinder /Applications में नहीं है — लॉगिन पर विश्वसनीय शुरुआत के लिए इसे वहाँ ले जाएँ।",
            "delete.inactiveHint": "जब तक Delete पैरेंट फ़ोल्डर खोलता है, निष्क्रिय रहता है।",
            "diag.title": "निदान",
            "diag.accessibility": "Accessibility",
            "diag.eventtap": "कीबोर्ड हुक (event tap)",
            "diag.automation": "Finder स्वचालन (F5)",
            "diag.granted": "प्रदान किया गया",
            "diag.missing": "अनुपस्थित",
            "diag.pending": "पहले F5 तक अज्ञात",
            "diag.denied": "अस्वीकृत",
            "diag.failed": "विफल",
            "diag.macversion": "macOS संस्करण",
            "diag.appversion": "ऐप संस्करण",
            "diag.copyreport": "निदान रिपोर्ट कॉपी करें",
            "perm.title": "अनुमतियाँ",
            "tab.shortcuts": "शॉर्टकट",
            "tab.status": "स्थिति",
            "guide.empty": "सभी शॉर्टकट अभी बंद हैं। ऊपर से जो चाहें चालू करें।",
            "about.title": "WinFinder Pro के बारे में",
            "about.license": "MIT लाइसेंस के अंतर्गत जारी।",
            "about.github": "GitHub पर देखें",
            "menu.pauseForHour": "1 घंटे के लिए रोकें",
            "settings.export": "सेटिंग्स निर्यात करें",
            "settings.import": "सेटिंग्स आयात करें",
            "settings.importFailed": "सेटिंग्स फ़ाइल आयात नहीं हो सकी।",
            "diag.copied": "कॉपी हो गया!",
            "reset.button": "सभी शॉर्टकट रीसेट करें",
            "reset.confirm": "सभी शॉर्टकट टॉगल डिफ़ॉल्ट पर लौट आएँगे। लॉगिन पर शुरुआत और भाषा अपरिवर्तित रहेंगे।",
            "reset.confirmAction": "रीसेट",
            "reset.cancel": "रद्द करें",
            "cs.ctrlGoto": "«फ़ोल्डर पर जाएँ» खोलें",
            "language.title": "इंटरफ़ेस भाषा",
            "guide.hint": "यह सूची आपके सक्रिय शॉर्टकट के अनुसार अपडेट होती है।",
            "cs.open": "चयनित फ़ाइल या फ़ोल्डर खोलें",
            "cs.trash": "ट्रैश में भेजें",
            "cs.parentFolder": "पैरेंट फ़ोल्डर पर जाएँ",
            "cs.permanentDelete": "स्थायी रूप से हटाएँ (ट्रैश के बिना)",
            "cs.rename": "नाम बदलें",
            "cs.cutPaste": "Cmd+X से कट करें और Cmd+V से मूव करें",
            "cs.properties": "Get Info दिखाएँ",
            "cs.navUpDown": "पैरेंट फ़ोल्डर / खोलें",
            "cs.navBackForward": "वापस / आगे",
            "cs.refresh": "सक्रिय विंडो रिफ्रेश करें",
            "cs.ctrlLayer": "उसी कुंजी Command के साथ (कॉपी, कट, पेस्ट, अनडू, सेव, प्रिंट, सभी चुनें, खोजें, नई विंडो, …)",
            "cs.ctrlNewFolder": "नया फ़ोल्डर",
            "footer.note": "यह विंडो बंद करने पर भी WinFinder मेन्यू बार में चालू रहता है।",
            "footer.close": "विंडो बंद करें",
        ]

    private static let persian: [String: String] = [
            "window.title": "تنظیمات WinFinder Pro",
            "header.subtitle": "فایندر مک با میانبرهای ویندوز",
            "header.version": "نسخه",
            "header.enableAccess": "فعال‌سازی دسترسی",
            "header.active": "فعال",
            "header.connecting": "در حال اتصال",
            "header.paused": "متوقف",
            "menu.shortcutsEnabled": "میانبرها فعال باشند",
            "menu.settings": "تنظیمات برنامه...",
            "menu.quit": "خروج کامل از برنامه",
            "issue.tapCreation": "اتصال به رویدادهای صفحه‌کلید برقرار نشد. چند لحظه بعد دوباره تلاش می‌شود؛ اگر تکرار شد برنامه را از منوی بالا ببندید و دوباره اجرا کنید.",
            "issue.automationDenied": "مجوز ارسال فرمان به Finder (رفرش با F5) رد شده است. با دکمه زیر مجوز Automation را فعال کنید.",
            "issue.refreshFailed": "رفرش پنجره Finder ناموفق بود.",
            "issue.openAutomation": "باز کردن تنظیمات Automation",
            "perm.openAccessibility": "باز کردن تنظیمات Accessibility",
            "perm.openAutomation": "باز کردن تنظیمات Automation",
            "perm.hint": "اگر میانبرها کار نمی‌کنند، وضعیت مجوزها را با این دکمه‌ها بررسی کنید.",
            "group.files": "مدیریت فایل‌ها",
            "group.nav": "ناوبری و انتقال فایل",
            "group.system": "راه‌اندازی سیستم",
            "group.guide": "راهنمای میانبرهای فعال",
            "enter.title": "باز کردن با Return (اینتر)",
            "enter.subtitle": "فایل‌ها و پوشه‌ها با کلید Enter باز می‌شوند",
            "delete.title": "حذف با کلید Delete",
            "delete.subtitle": "انتقال سریع فایل‌ها به سطل زباله",
            "shiftDelete.title": "حذف دائمی با Shift + Delete",
            "shiftDelete.subtitle": "حذف مستقیم بدون ورود به سطل زباله (macOS تأیید می‌خواهد)",
            "rename.title": "تغییر نام با Command + R",
            "rename.subtitle": "ورود به حالت تغییر نام با Cmd + R یا F2",
            "cut.title": "برش و انتقال (Cmd + X / Cmd + V)",
            "cut.subtitle": "قابلیت Cut فایل‌ها مانند ویندوز",
            "properties.title": "مشخصات با Option + Enter",
            "properties.subtitle": "نمایش پنجره مشخصات فایل (Properties)",
            "altNav.title": "ناوبری با کلیدهای Alt",
            "altNav.subtitle": "Alt+Up پوشه والد، Alt+Down باز کردن، Alt+Left برگشت و Alt+Right جلو",
            "backspace.title": "رفتن به پوشه والد با Delete",
            "backspace.subtitle": "Delete به‌جای حذف به پوشه بالاتر می‌رود (رفتار Explorer ویندوز)",
            "ctrl.title": "میانبرهای Ctrl ویندوزی",
            "ctrl.subtitle": "Ctrl+C/X/V/Z/S/P و Ctrl+A/F/N/W/T/O به معادل‌های Command نگاشت می‌شوند؛ Ctrl+L پنجره «رفتن به پوشه» را باز می‌کند؛ Ctrl+Shift+N پوشه جدید می‌سازد",
            "f5.title": "رفرش پوشه با F5",
            "f5.subtitle": "نوسازی محتویات پنجره فعال؛ روی لپ‌تاپ‌ها با fn+F5",
            "login.title": "اجرای خودکار هنگام روشن شدن مک",
            "login.subtitle": "برنامه پس از بوت سیستم در پس‌زمینه فعال شود",
            "login.notApplications": "WinFinder در پوشه Applications نیست؛ برای اجرای مطمئن هنگام شروع سیستم آن را به آن پوشه منتقل کنید.",
            "delete.inactiveHint": "تا وقتی Delete پوشه والد را باز می‌کند، غیرفعال است.",
            "diag.title": "عیب‌یابی",
            "diag.accessibility": "دسترسی Accessibility",
            "diag.eventtap": "قلاب صفحه‌کلید (event tap)",
            "diag.automation": "اتوماسیون Finder (F5)",
            "diag.granted": "داده شده",
            "diag.missing": "ندارد",
            "diag.pending": "تا اولین F5 نامشخص",
            "diag.denied": "رد شده",
            "diag.failed": "خطا",
            "diag.macversion": "نسخه macOS",
            "diag.appversion": "نسخه برنامه",
            "diag.copyreport": "کپی گزارش عیب‌یابی",
            "perm.title": "دسترسی‌ها",
            "tab.shortcuts": "میانبرها",
            "tab.status": "وضعیت",
            "guide.empty": "همه میانبرها خاموش‌اند؛ میانبرهای موردنظر را از بالای همین بخش فعال کنید.",
            "about.title": "درباره WinFinder Pro",
            "about.license": "تحت لایسنس MIT منتشر شده است.",
            "about.github": "مشاهده در گیت‌هاب",
            "menu.pauseForHour": "توقف برای یک ساعت",
            "settings.export": "برون‌بری تنظیمات",
            "settings.import": "درون‌بری تنظیمات",
            "settings.importFailed": "فایل تنظیمات درون‌ریزی نشد.",
            "diag.copied": "کپی شد!",
            "reset.button": "بازنشانی همه میانبرها",
            "reset.confirm": "همه کلیدهای میانبر به حالت پیش‌فرض برمی‌گردند. اجرای هنگام لاگین و زبان بدون تغییر می‌مانند.",
            "reset.confirmAction": "بازنشانی",
            "reset.cancel": "لغو",
            "cs.ctrlGoto": "باز کردن «رفتن به پوشه»",
            "language.title": "زبان رابط کاربری",
            "guide.hint": "این فهرست بر اساس کلیدهای فعال شما به‌روز می‌شود.",
            "cs.open": "باز کردن فایل یا پوشه انتخاب‌شده",
            "cs.trash": "انتقال به سطل زباله",
            "cs.parentFolder": "رفتن به پوشه والد",
            "cs.permanentDelete": "حذف دائمی (بدون سطل زباله)",
            "cs.rename": "تغییر نام",
            "cs.cutPaste": "برش با Cmd+X و انتقال با Cmd+V",
            "cs.properties": "نمایش مشخصات",
            "cs.navUpDown": "پوشه والد / باز کردن",
            "cs.navBackForward": "برگشت / جلو",
            "cs.refresh": "رفرش پنجره فعال",
            "cs.ctrlLayer": "همان کلید با Command (کپی، برش، چسباندن، واگرد، ذخیره، چاپ، انتخاب همه، جستجو، پنجره جدید و…)",
            "cs.ctrlNewFolder": "پوشه جدید",
            "footer.note": "با بستن پنجره، برنامه در نوار بالا فعال می‌ماند.",
            "footer.close": "بستن پنجره",
        ]

    private static let tables: [String: [String: String]] = [
        "en": english,
        "es": spanish,
        "fr": french,
        "zh-Hans": chinese,
        "hi": hindi,
        "fa": persian,
    ]
}

// MARK: - لینک مستقیم به بخش‌های System Settings
enum SystemSettingsOpener {
    static func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openAutomation() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - ابزارهای مشترک نمایش
/// The "2.4 (6)" style version string shown in Settings, Diagnostics, and About.
func appVersionText() -> String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
    return "\(version) (\(build))"
}

/// The currently enabled shortcuts as (keycap, description) rows. Shared by
/// the Settings cheat-sheet and the compact menu-bar list.
func activeShortcutRows(language: String) -> [(keys: String, description: String)] {
    let defaults = UserDefaults.standard
    let enterToOpen = defaults.bool(forKey: "enterToOpen")
    let deleteToTrash = defaults.bool(forKey: "deleteToTrash")
    let shiftDeletePermanent = defaults.bool(forKey: "shiftDeletePermanent")
    let cmdRRename = defaults.bool(forKey: "cmdRRename")
    let cutAndPaste = defaults.bool(forKey: "cutAndPaste")
    let altEnterProperties = defaults.bool(forKey: "altEnterProperties")
    let altNavFolders = defaults.bool(forKey: "altNavFolders")
    let f5Refresh = defaults.bool(forKey: "f5Refresh")
    let backspaceUpFolder = defaults.bool(forKey: "backspaceUpFolder")
    let ctrlShortcuts = defaults.bool(forKey: "ctrlShortcuts")

    var rows: [(String, String)] = []
    if enterToOpen {
        rows.append(("Enter", L10n.tr(language, "cs.open")))
    }
    if backspaceUpFolder {
        rows.append(("Delete", L10n.tr(language, "cs.parentFolder")))
    } else if deleteToTrash {
        rows.append(("Delete", L10n.tr(language, "cs.trash")))
    }
    if shiftDeletePermanent {
        rows.append(("Shift + Delete", L10n.tr(language, "cs.permanentDelete")))
    }
    if cmdRRename {
        rows.append(("Cmd + R  /  F2", L10n.tr(language, "cs.rename")))
    }
    if cutAndPaste {
        rows.append(("Cmd + X  /  Cmd + V", L10n.tr(language, "cs.cutPaste")))
    }
    if altEnterProperties {
        rows.append(("Alt + Enter", L10n.tr(language, "cs.properties")))
    }
    if altNavFolders {
        rows.append(("Alt + ↑  /  Alt + ↓", L10n.tr(language, "cs.navUpDown")))
        rows.append(("Alt + ←  /  Alt + →", L10n.tr(language, "cs.navBackForward")))
    }
    if f5Refresh {
        rows.append(("F5", L10n.tr(language, "cs.refresh")))
    }
    if ctrlShortcuts {
        rows.append(("Ctrl + C / X / V / Z / S / P / A / F / N / W / T / O", L10n.tr(language, "cs.ctrlLayer")))
        rows.append(("Ctrl + L", L10n.tr(language, "cs.ctrlGoto")))
        rows.append(("Ctrl + Shift + N", L10n.tr(language, "cs.ctrlNewFolder")))
    }
    return rows
}

/// Card look for settings groups: rounded panel, hairline border, group label
/// as a section heading instead of the stock inset GroupBox chrome.
struct CardGroupBoxStyle: GroupBoxStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: Design.rowSpacing) {
            configuration.label
                .font(.subheadline.weight(.semibold))
            configuration.content
        }
        .padding(Design.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Design.cornerRadius, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }
}

extension AppDelegate.AppIssue {
    func displayText(_ language: String) -> String {
        switch self {
        case .eventTapCreation:
            return L10n.tr(language, "issue.tapCreation")
        case .finderAutomationDenied:
            return L10n.tr(language, "issue.automationDenied")
        case .finderRefreshFailed:
            return L10n.tr(language, "issue.refreshFailed")
        }
    }
}

// MARK: - رابط گرافیکی تنظیمات
struct MainSettingsView: View {
    @EnvironmentObject private var appDelegate: AppDelegate
    @AppStorage("appLanguage") private var appLanguage = "en"
    @AppStorage("enterToOpen") private var enterToOpen = true
    @AppStorage("deleteToTrash") private var deleteToTrash = true
    @AppStorage("shiftDeletePermanent") private var shiftDeletePermanent = true
    @AppStorage("cmdRRename") private var cmdRRename = true
    @AppStorage("cutAndPaste") private var cutAndPaste = true
    @AppStorage("altEnterProperties") private var altEnterProperties = true
    @AppStorage("altNavFolders") private var altNavFolders = true
    @AppStorage("f5Refresh") private var f5Refresh = true
    @AppStorage("backspaceUpFolder") private var backspaceUpFolder = false
    @AppStorage("ctrlShortcuts") private var ctrlShortcuts = true
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @State private var didCopyReport = false
    @State private var showResetConfirmation = false
    @State private var isApplyingLoginChange = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            issuesBanner
            TabView {
                ScrollView {
                    VStack(spacing: Design.groupSpacing) {
                        shortcutGuideGroup
                        fileManagementGroup
                        navigationGroup
                    }
                    .padding()
                }
                .tabItem {
                    Label(L10n.tr(appLanguage, "tab.shortcuts"), systemImage: "keyboard")
                }
                ScrollView {
                    VStack(spacing: Design.groupSpacing) {
                        systemGroup
                    }
                    .padding()
                }
                .tabItem {
                    Label(L10n.tr(appLanguage, "group.system"), systemImage: "gearshape")
                }
                ScrollView {
                    VStack(spacing: Design.groupSpacing) {
                        permissionsGroup
                        diagnosticsGroup
                    }
                    .padding()
                }
                .tabItem {
                    Label(L10n.tr(appLanguage, "tab.status"), systemImage: "waveform.path.ecg")
                }
            }
            Divider()
            footer
        }
        .frame(minWidth: 470, idealWidth: 490, maxWidth: 560,
               minHeight: 540, idealHeight: 620, maxHeight: 780)
        .navigationTitle(L10n.tr(appLanguage, "window.title"))
        .environment(\.layoutDirection, appLanguage == "fa" ? .rightToLeft : .leftToRight)
        .confirmationDialog(
            L10n.tr(appLanguage, "reset.confirm"),
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.tr(appLanguage, "reset.confirmAction"), role: .destructive) {
                resetShortcutsToDefaults()
            }
            Button(L10n.tr(appLanguage, "reset.cancel"), role: .cancel) {}
        }
    }

    /// Restores every shortcut toggle to its compiled-in default. System-level
    /// choices (launch at login) and the interface language are untouched.
    private func resetShortcutsToDefaults() {
        enterToOpen = true
        deleteToTrash = true
        shiftDeletePermanent = true
        cmdRRename = true
        cutAndPaste = true
        altEnterProperties = true
        altNavFolders = true
        f5Refresh = true
        backspaceUpFolder = false
        ctrlShortcuts = true
    }

    // MARK: سربرگ

    private var header: some View {
        HStack {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Brand.headerGradient)
                )
                .shadow(color: Brand.accent.opacity(0.35), radius: 4, y: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("WinFinder Pro")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(L10n.tr(appLanguage, "header.subtitle"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(L10n.tr(appLanguage, "header.version")) \(appVersionText())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: appDelegate.eventTapState)
        .animation(.easeInOut(duration: 0.2), value: appDelegate.isPaused)
    }

    @ViewBuilder
    private var statusBadge: some View {
        if appDelegate.isAccessGranted {
            let state = appDelegate.eventTapState
            HStack(spacing: 6) {
                Circle()
                    .fill(AppStatusPresentation.color(isPaused: appDelegate.isPaused, state: state))
                    .frame(width: 10, height: 10)
                Text(AppStatusPresentation.label(
                    isPaused: appDelegate.isPaused,
                    state: state,
                    language: appLanguage
                ))
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppStatusPresentation.color(isPaused: appDelegate.isPaused, state: state))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppStatusPresentation.color(isPaused: appDelegate.isPaused, state: state).opacity(0.12))
            .cornerRadius(12)
        } else {
            Button(L10n.tr(appLanguage, "header.enableAccess")) {
                appDelegate.requestAccessManually()
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(nsColor: .systemOrange))
        }
    }

    // MARK: بنر خطاها

    @ViewBuilder
    private var issuesBanner: some View {
        if !appDelegate.activeIssues.isEmpty {
            VStack(spacing: 6) {
                ForEach(appDelegate.activeIssues, id: \.self) { issue in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(Color(nsColor: .systemOrange))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.displayText(appLanguage))
                                .font(.caption)
                                .foregroundColor(.primary)
                            if issue == .finderAutomationDenied {
                                Button(L10n.tr(appLanguage, "issue.openAutomation")) {
                                    SystemSettingsOpener.openAutomation()
                                }
                                .font(.caption)
                                .buttonStyle(.bordered)
                            }
                        }
                        Spacer()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color(nsColor: .systemOrange).opacity(0.08))
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.easeOut(duration: 0.2), value: appDelegate.activeIssues)
        }
    }

    // MARK: گروه‌های تنظیمات

    private var fileManagementGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "group.files"), systemImage: "doc.on.doc")) {
            VStack(spacing: Design.rowSpacing) {
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "enter.title"),
                    subtitle: L10n.tr(appLanguage, "enter.subtitle"),
                    isOn: $enterToOpen
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "delete.title"),
                    subtitle: deleteSubtitle,
                    isOn: $deleteToTrash
                )
                .disabled(backspaceUpFolder)
                .animation(.easeInOut(duration: 0.2), value: backspaceUpFolder)
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "shiftDelete.title"),
                    subtitle: L10n.tr(appLanguage, "shiftDelete.subtitle"),
                    isOn: $shiftDeletePermanent
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "rename.title"),
                    subtitle: L10n.tr(appLanguage, "rename.subtitle"),
                    isOn: $cmdRRename
                )
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    /// The trash toggle is overridden by the Delete-to-parent-folder shortcut;
    /// say so instead of showing a switch that silently does nothing.
    private var deleteSubtitle: String {
        if backspaceUpFolder {
            return L10n.tr(appLanguage, "delete.inactiveHint")
        }
        return L10n.tr(appLanguage, "delete.subtitle")
    }

    private var navigationGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "group.nav"), systemImage: "arrow.triangle.swap")) {
            VStack(spacing: Design.rowSpacing) {
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "cut.title"),
                    subtitle: L10n.tr(appLanguage, "cut.subtitle"),
                    isOn: $cutAndPaste
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "properties.title"),
                    subtitle: L10n.tr(appLanguage, "properties.subtitle"),
                    isOn: $altEnterProperties
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "altNav.title"),
                    subtitle: L10n.tr(appLanguage, "altNav.subtitle"),
                    isOn: $altNavFolders
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "backspace.title"),
                    subtitle: L10n.tr(appLanguage, "backspace.subtitle"),
                    isOn: $backspaceUpFolder
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "f5.title"),
                    subtitle: L10n.tr(appLanguage, "f5.subtitle"),
                    isOn: $f5Refresh
                )
                Divider()
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "ctrl.title"),
                    subtitle: L10n.tr(appLanguage, "ctrl.subtitle"),
                    isOn: $ctrlShortcuts
                )
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var systemGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "group.system"), systemImage: "gearshape")) {
            VStack(spacing: Design.rowSpacing) {
                ToggleRowItem(
                    title: L10n.tr(appLanguage, "login.title"),
                    subtitle: L10n.tr(appLanguage, "login.subtitle"),
                    isOn: Binding(
                        get: { launchAtLogin },
                        set: { newValue in
                            applyLaunchAtLogin(newValue)
                        }
                    )
                )
                .disabled(isApplyingLoginChange)
                if !appDelegate.isRunningFromPreferredLocation {
                    Label(L10n.tr(appLanguage, "login.notApplications"), systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundColor(Color(nsColor: .systemOrange))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                HStack {
                    Text(L10n.tr(appLanguage, "language.title"))
                        .fontWeight(.medium)
                    Spacer()
                    Picker("", selection: $appLanguage) {
                        ForEach(L10n.supportedLanguages, id: \.code) { language in
                            Text(language.nativeName).tag(language.code)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                    .labelsHidden()
                    .accessibilityLabel(L10n.tr(appLanguage, "language.title"))
                }
                Divider()
                HStack(spacing: 10) {
                    Button(L10n.tr(appLanguage, "settings.export")) {
                        exportSettings()
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button(L10n.tr(appLanguage, "settings.import")) {
                        importSettings()
                    }
                    .buttonStyle(.bordered)
                }
                Divider()
                Button(L10n.tr(appLanguage, "reset.button"), role: .destructive) {
                    showResetConfirmation = true
                }
                .frame(maxWidth: .infinity)
                .help(L10n.tr(appLanguage, "reset.confirm"))
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var permissionsGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "perm.title"), systemImage: "lock.shield")) {
            VStack(spacing: Design.rowSpacing) {
                HStack {
                    Button(L10n.tr(appLanguage, "perm.openAccessibility")) {
                        SystemSettingsOpener.openAccessibility()
                    }
                    .buttonStyle(.bordered)
                    .help(L10n.tr(appLanguage, "perm.openAccessibility"))
                    Spacer()
                    Button(L10n.tr(appLanguage, "perm.openAutomation")) {
                        SystemSettingsOpener.openAutomation()
                    }
                    .buttonStyle(.bordered)
                    .help(L10n.tr(appLanguage, "perm.openAutomation"))
                }
                Text(L10n.tr(appLanguage, "perm.hint"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    // MARK: عیب‌یابی

    private var diagnosticsGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "diag.title"), systemImage: "stethoscope")) {
            VStack(spacing: 8) {
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.accessibility"),
                    value: appDelegate.isAccessGranted
                        ? L10n.tr(appLanguage, "diag.granted")
                        : L10n.tr(appLanguage, "diag.missing"),
                    ok: appDelegate.isAccessGranted
                )
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.eventtap"),
                    value: eventTapStateText,
                    ok: appDelegate.eventTapState == .running && !appDelegate.isPaused
                )
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.automation"),
                    value: appDelegate.isFinderAutomationDenied
                        ? L10n.tr(appLanguage, "diag.denied")
                        : L10n.tr(appLanguage, "diag.pending"),
                    ok: !appDelegate.isFinderAutomationDenied
                )
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.macversion"),
                    value: ProcessInfo.processInfo.operatingSystemVersionString,
                    ok: true,
                    neutral: true
                )
                diagnosticRow(
                    L10n.tr(appLanguage, "diag.appversion"),
                    value: appVersionText(),
                    ok: true,
                    neutral: true
                )
                HStack {
                    Spacer()
                    Button(didCopyReport ? L10n.tr(appLanguage, "diag.copied") : L10n.tr(appLanguage, "diag.copyreport")) {
                        copyDiagnosticsReport()
                        didCopyReport = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            didCopyReport = false
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(didCopyReport)
                }
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var eventTapStateText: String {
        if appDelegate.isPaused { return L10n.tr(appLanguage, "header.paused") }
        switch appDelegate.eventTapState {
        case .running:
            return L10n.tr(appLanguage, "header.active")
        case .failed, .retrying:
            return L10n.tr(appLanguage, "diag.failed")
        default:
            return L10n.tr(appLanguage, "header.connecting")
        }
    }

    private func diagnosticRow(_ title: String, value: String, ok: Bool, neutral: Bool = false) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
            Spacer()
            if !neutral {
                Circle()
                    .fill(ok ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange))
                    .frame(width: 7, height: 7)
            }
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(neutral ? .primary : (ok ? Color(nsColor: .systemGreen) : Color(nsColor: .systemOrange)))
        }
    }

    private func copyDiagnosticsReport() {
        let accessibility = appDelegate.isAccessGranted ? "granted" : "missing"
        let automation = appDelegate.isFinderAutomationDenied ? "denied" : "not determined"
        let issues = appDelegate.activeIssues.map { $0.logText }.joined(separator: "; ")
        let report = """
        WinFinder Pro \(appVersionText())
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Accessibility: \(accessibility)
        Event tap: \(appDelegate.eventTapState.rawValue)\(appDelegate.isPaused ? " (paused)" : "")
        Finder automation: \(automation)
        Issues: \(issues.isEmpty ? "none" : issues)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    private var shortcutGuideGroup: some View {
        GroupBox(label: Label(L10n.tr(appLanguage, "group.guide"), systemImage: "list.bullet.rectangle")) {
            VStack(alignment: .leading, spacing: 8) {
                let rows = shortcutRows
                if rows.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "keyboard")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text(L10n.tr(appLanguage, "guide.empty"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                        ForEach(rows, id: \.keys) { row in
                            GridRow {
                                Text(row.keys)
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.secondary.opacity(0.10)))
                                    .overlay(Capsule().strokeBorder(Color.secondary.opacity(0.22)))
                                    .shadow(color: .black.opacity(0.10), radius: 0.5, y: 1)
                                    .environment(\.layoutDirection, .leftToRight)
                                Text(row.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                Text(L10n.tr(appLanguage, "guide.hint"))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .groupBoxStyle(CardGroupBoxStyle())
    }

    private var shortcutRows: [(keys: String, description: String)] {
        activeShortcutRows(language: appLanguage)
    }

    // MARK: پابرگ

    private var footer: some View {
        HStack {
            Text(L10n.tr(appLanguage, "footer.note"))
                .font(.footnote)
                .foregroundColor(.secondary)
            Spacer()
            Button(L10n.tr(appLanguage, "footer.close")) {
                NSApp.keyWindow?.close()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// Applies a launch-at-login change off the main thread so the SMAppService
    /// XPC round-trip cannot stutter the UI. The toggle moves optimistically
    /// and reverts if the service rejects the change.
    private func applyLaunchAtLogin(_ enabled: Bool) {
        guard !isApplyingLoginChange else { return }
        isApplyingLoginChange = true
        let previousValue = launchAtLogin
        launchAtLogin = enabled
        DispatchQueue.global(qos: .userInitiated).async {
            var success = false
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                success = true
            } catch {
                NSLog("WinFinder: launch-at-login update failed; previous state restored: \(error)")
            }
            DispatchQueue.main.async {
                isApplyingLoginChange = false
                if success {
                    // Reflect the service's real state, including the approval-pending state.
                    launchAtLogin = LaunchAtLoginState.isRegistered
                } else {
                    launchAtLogin = previousValue
                }
            }
        }
    }

    // MARK: برون‌بری و درون‌ریزی تنظیمات

    private static let exportableSettings: [(key: String, defaultValue: Bool)] = [
        ("enterToOpen", true),
        ("deleteToTrash", true),
        ("shiftDeletePermanent", true),
        ("cmdRRename", true),
        ("cutAndPaste", true),
        ("altEnterProperties", true),
        ("altNavFolders", true),
        ("f5Refresh", true),
        ("backspaceUpFolder", false),
        ("ctrlShortcuts", true),
    ]

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "WinFinderSettings.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        var payload: [String: Bool] = [:]
        for entry in Self.exportableSettings {
            payload[entry.key] = UserDefaults.standard.bool(forKey: entry.key)
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("WinFinder: settings export failed: \(error)")
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let payload = try JSONSerialization.jsonObject(with: data) as? [String: Bool] ?? [:]
            let knownKeys = Set(Self.exportableSettings.map { $0.key })
            var applied = 0
            for (key, value) in payload where knownKeys.contains(key) {
                UserDefaults.standard.set(value, forKey: key)
                applied += 1
            }
            if applied == 0 { showImportFailure() }
        } catch {
            NSLog("WinFinder: settings import failed: \(error)")
            showImportFailure()
        }
    }

    private func showImportFailure() {
        let alert = NSAlert()
        alert.messageText = L10n.tr(appLanguage, "settings.importFailed")
        alert.alertStyle = .warning
        alert.runModal()
    }
}

// MARK: - ردیف کلید تغییر وضعیت
struct ToggleRowItem: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @State private var isHovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(Color("AccentColor"))
                .accessibilityLabel(title)
                .accessibilityHint(subtitle)
                .help(subtitle)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isHovering && isEnabled ? Color.secondary.opacity(0.07) : Color.clear)
        )
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
    }
}

// MARK: - پنجره درباره
struct AboutView: View {
    @AppStorage("appLanguage") private var appLanguage = "en"

    var body: some View {
        VStack(spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            VStack(spacing: 3) {
                Text("WinFinder Pro")
                    .font(.title2)
                    .fontWeight(.bold)
                Text(L10n.tr(appLanguage, "header.subtitle"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(L10n.tr(appLanguage, "header.version")) \(appVersionText())")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Divider()
            Text(L10n.tr(appLanguage, "about.license"))
                .font(.caption)
                .foregroundColor(.secondary)
            Button(L10n.tr(appLanguage, "about.github")) {
                if let url = URL(string: "https://github.com/hamidreza-tn/WinFinder") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.bordered)
            .help(L10n.tr(appLanguage, "about.github"))
            Divider()
            Text(L10n.tr(appLanguage, "footer.note"))
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(width: 300)
        .navigationTitle(L10n.tr(appLanguage, "about.title"))
        .environment(\.layoutDirection, appLanguage == "fa" ? .rightToLeft : .leftToRight)
    }
}
