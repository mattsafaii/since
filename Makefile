APP = dist/Since.app

.PHONY: app install icon clean

# Assemble Since.app from the binary, Info.plist, and icon.
app:
	go build -o dist/since .
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	mv dist/since $(APP)/Contents/MacOS/since
	cp assets/Info.plist $(APP)/Contents/Info.plist
	cp assets/Since.icns $(APP)/Contents/Resources/Since.icns

# Copy the bundle into /Applications.
install: app
	rm -rf /Applications/Since.app
	cp -R $(APP) /Applications/Since.app

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
	rm -rf dist
