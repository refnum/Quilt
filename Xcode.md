Xcode
=====
Configure Environment
---------------------
Since Xcode invokes shell scripts with a reduced path, Quilt requires
a source tree called `Qt` that points to the root of your Qt
installation.



Create Target
-------------
Create a new "Quilt" target in your project, and add this as a dependency of your main target.

The Quilt target should contain a Run Script build phase which performs:

```
$ quilt.rb --moc  --in="${PROJECT_DIR}/../Source"
                 --out="${PROJECT_DIR}/../Source/QtGlue.moc"
```

The `--in` parameter controls the directory to scan for files that contain `Q_OBJECT`
definitions, and the `--out` parameter indicates where to save the list of files
that require moccing (this file must have a .moc extension).

An `--exclude` parameter can also be supplied, which defines a regexp to filter the
scanned files (e.g., "`--exclude=Win*`" will exclude any files starting with "`Win`").



Create Rule
-----------
Create a new Build Rule in the main target.

This rule should match files with `*.[mqu][ori]*`.

Unfortunately Xcode does not support alternation within globbing, however this will match .moc/.qrc/.ui extensions.

This rule should process files with:

```
$ quilt.rb --build  --in="${INPUT_FILE_PATH}"
                   --out="${DERIVED_FILES_DIR}/
                         ${INPUT_FILE_BASE}_${CURRENT_ARCH}.cpp"
```

and output to:

```
${DERIVED_FILES_DIR}/${INPUT_FILE_BASE}_${CURRENT_ARCH}.cpp
```



Add Source
----------
Create an empty text file as your QtGlue.moc file, and add it to the main target.

After adding this file, drag it from the "Copy Bundle Resources" phase of the main target into the "Compile Sources" phase.

If you have any .qrc or .ui files, these should also be added to the project.



How It Works
------------
* The Quilt target invokes quilt to update the .moc file, before Xcode performs
  dependency checking for the main target. This must be done from a separate
  target, since Run Script phases are invoked after dependency checking and
  Quilt must run before the main target performs this check. Quilt will detect
  any files that require preprocessing, and add them to the .moc file.

* The main target's build rule will invoke quilt for any .moc, .qrc, or .ui files
  in the target. Quilt will then invoke the appropriate meta-compiler, and
  generate derived source files within the project's build folder. 

* Xcode will compile the derived source files during the build, and include
  their object code when linking.

