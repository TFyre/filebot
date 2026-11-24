package net.filebot.cli;

import static java.util.Arrays.*;
import static net.filebot.Logging.*;
import static net.filebot.util.FileUtilities.*;

import java.io.File;
import java.io.FileNotFoundException;
import java.io.InputStream;

import org.tukaani.xz.XZInputStream;

import net.filebot.Resource;

public enum ScriptSource {

	// legacy name: the bundled scripts refer to ScriptSource.GITHUB_STABLE
	GITHUB_STABLE {

		@Override
		public String accept(String input) {
			return input.startsWith("fn:") ? input.substring(3) : null;
		}

		@Override
		public ScriptProvider getScriptProvider(String input) throws Exception {
			// the signed script bundle is embedded in the application jar
			Resource<byte[]> bundle = () -> {
				try (InputStream in = ScriptSource.class.getResourceAsStream("m1.jar.xz")) {
					if (in == null) {
						throw new FileNotFoundException("Script bundle not found: m1.jar.xz");
					}
					try (XZInputStream xz = new XZInputStream(in)) {
						return xz.readAllBytes();
					}
				}
			};

			return new ScriptBundle(bundle, ScriptSource.class.getResourceAsStream("repository.cer"));
		}

	},

	INLINE_GROOVY {

		@Override
		public String accept(String input) {
			return input.startsWith("g:") ? input.substring(2) : null;
		}

		@Override
		public ScriptProvider getScriptProvider(String input) throws Exception {
			return g -> g;
		}

	},

	LOCAL_FILE {

		@Override
		public String accept(String input) {
			try {
				File f = new File(input).getCanonicalFile();
				if (f.isFile()) {
					return getName(f);
				}
			} catch (Exception e) {
				debug.finest(e::toString);
			}
			return null;
		}

		@Override
		public ScriptProvider getScriptProvider(String input) throws Exception {
			File base = new File(input).getCanonicalFile().getParentFile();

			return f -> readTextFile(new File(base, f + ".groovy"));
		}

	};

	public abstract String accept(String input);

	public abstract ScriptProvider getScriptProvider(String input) throws Exception;

	public static ScriptSource findScriptProvider(String input) throws Exception {
		return stream(values()).filter(s -> s.accept(input) != null).findFirst().orElseThrow(() -> {
			return new CmdlineException("Bad script source: " + input);
		});
	}

}
