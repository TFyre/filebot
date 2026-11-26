#!/bin/sh -xu

MEDIAINFO_VERSION="18.03"


# Download and extract archives
mkdir -p "Staging" && cd "Staging"

curl -O "https://mediaarea.net/download/binary/libmediainfo0/${MEDIAINFO_VERSION}/MediaInfo_DLL_${MEDIAINFO_VERSION}_Windows_x64_WithoutInstaller.7z"

for FILE in *.7z
	do mkdir -p "${FILE%.*}" && 7z x "$FILE" -aoa -o"${FILE%.*}"
done


# Copy native libraries into repository
cd ..

cp Staging/*Windows*x64*/MediaInfo.dll win32-x64/MediaInfo.dll

rm -r Staging
