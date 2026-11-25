package net.filebot;

import static java.nio.charset.StandardCharsets.*;
import static net.filebot.Logging.*;

import java.io.File;
import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.file.FileSystemException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.UserDefinedFileAttributeView;
import java.util.AbstractMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

public class MetaAttributeView extends AbstractMap<String, String> {

	private final UserDefinedFileAttributeView xattr;

	public MetaAttributeView(File file) throws IOException {
		// resolve symlinks
		Path path = file.toPath().toRealPath();

		xattr = Files.getFileAttributeView(path, UserDefinedFileAttributeView.class);

		// sanity check
		if (xattr == null) {
			throw new IOException("UserDefinedFileAttributeView is not supported");
		}
	}

	@Override
	public String get(Object key) {
		return get(key.toString());
	}

	public String get(String key) {
		try {
			ByteBuffer buffer = ByteBuffer.allocate(xattr.size(key));
			xattr.read(key, buffer);
			buffer.flip();

			return UTF_8.decode(buffer).toString();
		} catch (FileSystemException e) {
			// attribute does not exist
			return null;
		} catch (IOException e) {
			debug.warning(cause(e));
			return null;
		}
	}

	@Override
	public String put(String key, String value) {
		try {
			if (value == null || value.isEmpty()) {
				xattr.delete(key);
			} else {
				xattr.write(key, UTF_8.encode(value));
			}
		} catch (IOException e) {
			throw new RuntimeException(e);
		}

		return null; // since we don't know the old value
	}

	@Override
	public void clear() {
		try {
			for (String key : list()) {
				put(key, null);
			}
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	public List<String> list() throws IOException {
		return xattr.list();
	}

	@Override
	public Set<Entry<String, String>> entrySet() {
		try {
			Set<Entry<String, String>> entries = new LinkedHashSet<Entry<String, String>>();
			for (String name : list()) {
				entries.add(new AttributeEntry(name));
			}
			return entries;
		} catch (IOException e) {
			throw new RuntimeException(e);
		}
	}

	private class AttributeEntry implements Entry<String, String> {

		private final String name;

		public AttributeEntry(String name) {
			this.name = name;
		}

		@Override
		public String getKey() {
			return name;
		}

		@Override
		public String getValue() {
			return get(name);
		}

		@Override
		public String setValue(String value) {
			return put(name, value);
		}

		@Override
		public String toString() {
			return getKey() + "=" + getValue();
		}
	}

}
