package net.filebot.ui.transfer;

import java.awt.datatransfer.DataFlavor;
import java.awt.datatransfer.Transferable;
import java.awt.datatransfer.UnsupportedFlavorException;
import java.io.File;
import java.io.IOException;
import java.nio.CharBuffer;
import java.util.Arrays;
import java.util.Collection;
import java.util.List;

public class FileTransferable implements Transferable {

	public static final DataFlavor uriListFlavor = createUriListFlavor();

	private static DataFlavor createUriListFlavor() {
		try {
			return new DataFlavor("text/uri-list;class=java.nio.CharBuffer");
		} catch (ClassNotFoundException e) {
			// will never happen
			throw new RuntimeException(e);
		}
	}

	public static boolean isFileListFlavor(DataFlavor flavor) {
		return flavor.isFlavorJavaFileListType() || flavor.equals(uriListFlavor);
	}

	public static boolean hasFileListFlavor(Transferable tr) {
		return tr.isDataFlavorSupported(DataFlavor.javaFileListFlavor) || tr.isDataFlavorSupported(FileTransferable.uriListFlavor);
	}

	private final File[] files;

	public FileTransferable(File... files) {
		this.files = files;
	}

	public FileTransferable(Collection<File> files) {
		this.files = files.toArray(new File[0]);
	}

	@Override
	public Object getTransferData(DataFlavor flavor) throws UnsupportedFlavorException {
		if (flavor.isFlavorJavaFileListType())
			return Arrays.asList(files);
		else if (flavor.equals(uriListFlavor))
			return CharBuffer.wrap(getUriList());
		else
			throw new UnsupportedFlavorException(flavor);
	}

	/**
	 * @return line separated list of file URIs
	 */
	private String getUriList() {
		StringBuilder sb = new StringBuilder(80 * files.length);

		for (File file : files) {
			// use URI encoded path
			sb.append("file://").append(file.toURI().getRawPath());
			sb.append("\r\n");
		}

		return sb.toString();
	}

	@Override
	public DataFlavor[] getTransferDataFlavors() {
		return new DataFlavor[] { DataFlavor.javaFileListFlavor, uriListFlavor };
	}

	@Override
	public boolean isDataFlavorSupported(DataFlavor flavor) {
		return isFileListFlavor(flavor);
	}

	public static List<File> getFilesFromTransferable(Transferable tr) throws IOException, UnsupportedFlavorException {
		// Windows and default handling
		if (tr.isDataFlavorSupported(DataFlavor.javaFileListFlavor)) {
			// file list flavor
			Object transferable = tr.getTransferData(DataFlavor.javaFileListFlavor);

			if (transferable instanceof List<?>) {
				return (List<File>) transferable;
			}

			// on some platforms transferable data will not be available until the drop has been accepted
			return null;
		}

		// cannot get files from transferable
		throw new UnsupportedFlavorException(DataFlavor.javaFileListFlavor);
	}

}
