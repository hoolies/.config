function screenName(screen) {
    if (!screen) {
        return "";
    }
    try {
        return String(screen.name);
    } catch (e) {
        return "";
    }
}

function laptopScreen() {
    const screens = workspace.screens;
    for (let i = 0; i < screens.length; i++) {
        const name = screenName(screens[i]);
        if (name.indexOf("eDP") === 0 || name.indexOf("LVDS") === 0 || name.indexOf("DSI") === 0) {
            return screens[i];
        }
    }
    if (screens.length > 0) {
        return screens[0];
    }
    return null;
}

function isConky(window) {
    try {
        const cls = window.resourceClass.toString();
        return cls === "Conky" || cls === "conky";
    } catch (e) {
        return false;
    }
}

function place(window) {
    if (!isConky(window)) {
        return;
    }
    // A wallpaper layer is already on every desktop. Pinning a normal window
    // there makes Plasma show it as its own app on each virtual desktop.
    try {
        window.keepBelow = true;
        window.skipTaskbar = true;
        window.skipPager = true;
        window.skipSwitcher = true;
    } catch (e) {
        print("conkyplace: " + e);
    }
    const screen = laptopScreen();
    if (!screen) {
        return;
    }
    try {
        workspace.sendClientToScreen(window, screen);
    } catch (e) {
        print("conkyplace: " + e);
    }
}

function placeAll() {
    workspace.windowList().forEach(place);
}

workspace.windowAdded.connect(place);
workspace.screensChanged.connect(placeAll);
placeAll();
