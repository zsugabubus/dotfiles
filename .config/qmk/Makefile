DEST := /tmp/qmk
bootstrap :
	sudo pacman -S --noconfirm avr-gcc avr-libc
	git clone https://github.com/qmk/qmk_firmware --depth 1 $(DEST)
	$(MAKE) -C  $(DEST) git-submodule

firmware :
	cp -rfuv ~/.config/qmk/zsugabubus $(DEST)/keyboards/ergodox_ez/keymaps
	$(MAKE) -C $(DEST) ergodox_ez:zsugabubus
	teensy-loader-cli --mcu=atmega32u4 -w $(DEST)/.build/ergodox_ez_zsugabubus.hex
.PHONY: bootstrap firmware
