Visual Studio
=============
Configure Environment
---------------------
Define a `QT_ROOT` environment variable that points to the location of your Qt
installation, and a `QUILT_ROOT` environment variable that points to the
directory containing Quilt.

You will also need to install Ruby 1.8.6 or later.



Create Pre-Build Step
---------------------
Open your project's properties, and create a pre-build step with a command line of:

```
"$(QUILT_ROOT)\quilt.rb" --moc  --in="$(ProjectDir)\..\Source"
                               --out="$(ProjectDir)\..\Source\QtGlue.moc"
```
``

The `--in` parameter controls the directory to scan for files that contain `Q_OBJECT`
definitions, and the `--out` parameter indicates where to save the list of files
that require moccing (this file must have a .moc extension).

An `--exclude` parameter can also be supplied, which defines a regexp to filter the
scanned files (e.g., "`--exclude=Win*`" will exclude any files starting with "`Win`").



Add Rule
--------
Right-click on your project, select "Custom Build Rules...", "Find Existing...",
then select the Support/Visual Studio/Quilt.rules file.



Add Source
----------
Create an empty text file as your QtGlue.moc file, and add it to the project.

After adding this file, drag it from the "Resources" section of the project
into the "Sources" section.

If you have any .qrc or .ui files, these should also be added to the project.

Quit Visual Studio, and edit the .vcproj file with a text editor. For each
file to be processed by Quilt (.moc, .qrc, or .ui files), add a corresponding
.cpp file reference in the "Sources" section.

For example:

```
<File
    RelativePath="Source\QtGlue.moc"
    >
</File>
<File
    RelativePath="$(IntDir)\QtGlue.cpp"
    >
</File>
```

For each foo.xxx file, Quilt generates a `$(IntDir)\foo.cpp` file. These files
must be included in the project to be compiled, however since these are
relative to `$(IntDir)` they must be added by editing the project file directly.



How It Works
------------
* The pre-build step will invoke quilt to update the .moc file, before Visual
  Studio performs dependency checking for the project. This must be done from
  a pre-build step, to ensure it is invoked before dependency checking.

* The build rule will invoke quilt for any .moc, .qrc, or .ui files in the
  project. Quilt will then invoke the appropriate meta-compiler, and generate derived
source files within `$(IntDir)`.

* Visual Studio will compile the derived source files during the build, and
  include their object code when linking. Since build rules can't inherit compiler
  options, these derived source files must be added to the project to ensure they
  are compiled with the same configuration as normal source.




