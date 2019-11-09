Quilt
=====
Quilt integrates Qt's meta-compilers into native Xcode and Visual
Studio projects, allowing automatic pre-processing without using
qmake.

Although qmake can generate simple Xcode/Visual Studio project files,
it does not support new IDE features such as external .xcconfig or
.vsprops files.


Usage
-----
Quilt is normally invoked by a pre-build step in the development
environment, and a build rule during the actual build.

During the pre-build phase Quilt scans your source tree for files that
contain Q_OBJECT macros. It then generates a single .moc file, which
identifies the source files that require pre-processing.

During the actual build Quilt is invoked to process any Qt files
(.moc, .qrc, or .ui) in the project. It invokes the appropriate Qt
meta-compiler for each file, and adds the derived source to the build.

Once Quilt has been attached to your project, the identification and
compilation of Qt source is automatic.
