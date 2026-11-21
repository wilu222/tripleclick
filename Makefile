APP = build/TripleClick.app
# Self-signed cert from Keychain Access (see README). Falls back to ad-hoc.
IDENTITY ?= TripleClick Self-Signed

.PHONY: app zip install clean

app:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp Info.plist $(APP)/Contents/
	cp Resources/* $(APP)/Contents/Resources/
	xattr -cr $(APP)
	cp .build/release/TripleClick $(APP)/Contents/MacOS/
	codesign --force -s "$(IDENTITY)" $(APP) 2>/dev/null || { echo "No '$(IDENTITY)' cert, signing ad-hoc"; codesign --force -s - $(APP); }

zip: app
	cd build && rm -f TripleClick.zip && ditto -c -k --keepParent TripleClick.app TripleClick.zip

install: app
	-pkill -x TripleClick
	rm -rf /Applications/TripleClick.app
	cp -R $(APP) /Applications/
	open /Applications/TripleClick.app

clean:
	rm -rf .build build
