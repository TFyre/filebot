package net.filebot.platform.windows;

import static javax.swing.BorderFactory.*;

import java.awt.Color;

import javax.swing.UIManager;

public class WinAppUtilities {

	public static void initializeApplication() {
		// improved UI defaults
		UIManager.put("TitledBorder.border", createCompoundBorder(createLineBorder(new Color(0xD7D7D7), 1, true), createCompoundBorder(createMatteBorder(6, 5, 6, 5, new Color(0xE5E5E5)), createEmptyBorder(0, 2, 0, 2))));
	}

	private WinAppUtilities() {
		throw new UnsupportedOperationException();
	}

}
