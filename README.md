# encrypted_zip_creator

This is encrypted zip creator app.
(This is confirmed to test on MacOS but you might be able to run on Linux.
If you can prepare ```zip``` command, you can run on another environment.)

You can just drag&drop file or folder.
Also you can specify the password.

## setup the build environment

```
flutter doctor
```

Do suggested solution to satisfy with the build environment.

For MacOS

XCode is needed to install.

And you may not solve cocoapads by ```sudo gem install cocoapads```
In that case, you need to try with the following.

```
brew install cocoapads
```

## build

```
flutter build macos
...snip..
Building macOS application...                                           
✓ Built build/macos/Build/Products/Release/encrypted_zip_creator.app (49.3MB)
```
Then you can get the built app at the above path!

You can execute as

```
open build/macos/Build/Products/Release/encrypted_zip_creator.app

or simply do ```flutter run```


## additional instructions

If you want to run with libzip

### for mac

```
brew install libzip
```

### for windows

```
git clone https://github.com/microsoft/vcpkg.git
cd vcpkg
bootstrap-vcpkg.bat
vcpkg install libzip:x64-windows
cd installed/x64-windows/bin
```

Copy the files to fluter's release folder

```
cp *.* ~/work/encrypted_zip_archiver/build\windows\runner\Release
```

Please confirm the files place as follows:

```
./encrypted_zip_creator.exe
./zlib.pdb
./flutter_windows.dll
./zlib1.dll
./bz2.pdb
./bz2.dll
./zip.dll
./zip.pdb
./data/app.so
./data/icudtl.dat
./data/flutter_assets/NOTICES.Z
./data/flutter_assets/NativeAssetsManifest.json
./data/flutter_assets/AssetManifest.json
./data/flutter_assets/FontManifest.json
./data/flutter_assets/packages/cupertino_icons/assets/CupertinoIcons.ttf
./data/flutter_assets/shaders/ink_sparkle.frag
./data/flutter_assets/AssetManifest.bin
./data/flutter_assets/fonts/MaterialIcons-Regular.otf
./desktop_drop_plugin.dll
```