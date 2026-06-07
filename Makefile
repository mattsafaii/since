APP = dist/Since.app

.PHONY: app install login uninstall icon clean

# Assemble Since.app from the swift build, Info.plist, and icon.
app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp .build/release/Since $(APP)/Contents/MacOS/since
	cp assets/Info.plist $(APP)/Contents/Info.plist
	cp assets/Since.icns $(APP)/Contents/Resources/Since.icns
	codesign --force --sign - $(APP)

# Copy the bundle into /Applications.
install: app
	rm -rf /Applications/Since.app
	cp -R $(APP) /Applications/Since.app

# Launch at login: install the LaunchAgent and start it now.
login: install
	pkill -f /Applications/Since.app/Contents/MacOS/since || true
	cp assets/com.mattsafaii.since.plist ~/Library/LaunchAgents/
	launchctl bootout gui/$$(id -u)/com.mattsafaii.since 2>/dev/null || true
	launchctl bootstrap gui/$$(id -u) ~/Library/LaunchAgents/com.mattsafaii.since.plist

# Remove the app, the LaunchAgent, and any running instance.
uninstall:
	launchctl bootout gui/$$(id -u)/com.mattsafaii.since 2>/dev/null || true
	rm -f ~/Library/LaunchAgents/com.mattsafaii.since.plist
	pkill -f /Applications/Since.app/Contents/MacOS/since || true
	rm -rf /Applications/Since.app

# Regenerate assets/Since.icns from the Swift drawing script.
icon:
	swift assets/make-icon.swift
	rm -rf assets/Since.iconset && mkdir -p assets/Since.iconset
	for s in 16 32 128 256 512; do \
		sips -z $$s $$s assets/icon_1024.png --out assets/Since.iconset/icon_$${s}x$${s}.png >/dev/null; \
		sips -z $$((s*2)) $$((s*2)) assets/icon_1024.png --out assets/Since.iconset/icon_$${s}x$${s}@2x.png >/dev/null; \
	done
	iconutil -c icns assets/Since.iconset -o assets/Since.icns
	rm -rf assets/Since.iconset

clean:
	rm -rf dist .build
