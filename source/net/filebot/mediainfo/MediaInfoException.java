package net.filebot.mediainfo;

public class MediaInfoException extends RuntimeException {

	public MediaInfoException(String message) {
		super(message);
	}

	public MediaInfoException(LinkageError e) {
		super(getLinkageErrorMessage(e), e);
	}

	private static String getLinkageErrorMessage(LinkageError e) {
		return String.format("Unable to load %s native library MediaInfo.dll: %s", System.getProperty("os.arch"), e.getMessage());
	}

}
