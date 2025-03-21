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
