package net.filebot;

import static net.filebot.Logging.*;

import java.io.File;
import java.io.IOException;
import java.nio.file.LinkOption;
import java.nio.file.Paths;
import java.util.logging.Level;

public enum ApplicationFolder {

	UserHome(System.getProperty("user.home")),

	AppData(System.getProperty("application.dir", UserHome.resolve(".filebot").getPath())),

	TemporaryFiles(System.getProperty("java.io.tmpdir")),

	Cache(System.getProperty("application.cache", AppData.resolve("cache").getPath()));

	private File path;

	ApplicationFolder(String path) {
		try {
			// use canonical file path
			this.path = Paths.get(path).toRealPath(LinkOption.NOFOLLOW_LINKS).toFile();
		} catch (IOException e) {
			debug.log(Level.WARNING, e, e::toString);

			// default to file path as is
			this.path = new File(path).getAbsoluteFile();
		}
	}

	public File get() {
		return path;
	}

	public File resolve(String name) {
		return new File(path, name);
	}

}
