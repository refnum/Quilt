#!/usr/bin/ruby -w
#============================================================================
#	NAME:
#		Quilt
#
#	DESCRIPTION:
#		Meta-meta compiler for Qt.
#
#		Quilt can scan source files to create a .moc file, which identifies
#		the files that require processing with the Qt meta-compiler.
#
#		Quilt can also invoke the Qt compilers to convert .moc, .qrc, and
#		.ui files into their .cpp form.
#
#	COPYRIGHT:
#		Copyright (c) 2010, refNum Software
#		<http://www.refnum.com/>
#
#		All rights reserved.
#
#		Redistribution and use in source and binary forms, with or without
#		modification, are permitted provided that the following conditions
#		are met:
#
#			o Redistributions of source code must retain the above
#			copyright notice, this list of conditions and the following
#			disclaimer.
#
#			o Redistributions in binary form must reproduce the above
#			copyright notice, this list of conditions and the following
#			disclaimer in the documentation and/or other materials
#			provided with the distribution.
#
#			o Neither the name of refNum Software nor the names of its
#			contributors may be used to endorse or promote products derived
#			from this software without specific prior written permission.
#
#		THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#		"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#		LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
#		A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
#		OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
#		SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
#		LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
#		DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
#		THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#		(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
#		OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#============================================================================
#		Imports
#----------------------------------------------------------------------------
require 'digest/md5'
require 'fileutils';
require 'getoptlong';
require 'pathname';





#============================================================================
#		Configuration
#----------------------------------------------------------------------------
if (RUBY_PLATFORM =~ /darwin/)
	$QT_ROOT    = ENV['Qt'];
	$QT_DEFINES = "-DQT_GUI_LIB -DQT_CORE_LIB -DQT_SHARED -D__APPLE__ -D__GNUC__";
	$QT_INCPATH = "-I#{$QT_ROOT}/lib/QtCore.framework/Headers "					+
				  "-I#{$QT_ROOT}/lib/QtGui.framework/Headers "					+
				  "-I#{$QT_ROOT}/mkspecs/macx-xcode"							+
				  "-I/System/Library/Frameworks/CarbonCore.framework/Headers "	+
				  "-I/usr/include "												+
				  "-I/usr/local/include ";

	$moc = $QT_ROOT + "/bin/moc";
	$uic = $QT_ROOT + "/bin/uic";
	$rcc = $QT_ROOT + "/bin/rcc";

elsif (RUBY_PLATFORM =~ /i386/)
	$QT_ROOT    = ENV['QT_ROOT'];
	$QT_DEFINES = "-DQT_CORE_LIB -DQT_GUI_LIB -DQT_SHARED -DUNICODE -DWIN32";
	$QT_INCPATH = "-I#{$QT_ROOT}/include/QtCore -I#{$QT_ROOT}/include/QtGui";

	$moc = $QT_ROOT + '\bin\moc';
	$uic = $QT_ROOT + '\bin\uic';
	$rcc = $QT_ROOT + '\bin\rcc';

else
	raise("Unknown platform!");
end





#============================================================================
#		Constants
#----------------------------------------------------------------------------
$kMocHeader = <<FRAGMENT_MOC
# Autogenerated by quilt
#
# THIS FILE IS REBUILT AUTOMATICALLY - MANUAL CHANGES WILL BE LOST!
# -----------------------------------------------------------------
FRAGMENT_MOC





#============================================================================
#		buildMoc : Build a .moc file.
#----------------------------------------------------------------------------
def buildMoc(pathIn, pathOut)

	# Get the state we need
	pathRoot = File.dirname(pathIn);
	mocFile  = IO.read(     pathIn);



	# Compile the files
	FileUtils.rm_f(pathOut);

	mocFile.split("\n").each do |theFile|
		if (theFile !~ /^#/):
			theFile  = File.expand_path(pathRoot + "/" + theFile);
			`#{$moc} #{$QT_DEFINES} #{$QT_INCPATH} -nw #{theFile} >> #{pathOut}`;
		end
	end

end





#============================================================================
#		buildQrc : Build a .qrc file.
#----------------------------------------------------------------------------
def buildQrc(pathIn, pathOut)

	# Get the state we need
	theName = File.basename(pathIn, ".qrc");



	# Compile the file
	print `#{$rcc} -name #{theName} #{pathIn} -o #{pathOut}`;

end





#============================================================================
#		buildUI : Build a .ui file.
#----------------------------------------------------------------------------
def buildUI(pathIn, pathOut)

	# Get the state we need
	pathHdr = pathOut.sub(/\.cpp$/, ".h");


	# Compile the file
	print `#{$uic} #{pathIn} -o #{pathHdr}`;
	print `#{$moc} #{$QT_DEFINES} #{$QT_INCPATH} -nw #{pathIn} -o #{pathOut}`;

end





#============================================================================
#		doMoc : Perform a moc command.
#----------------------------------------------------------------------------
def doMoc(pathIn, pathOut, excludeFiles)

	# Check our parameters
	doHelp() if (pathIn == nil || pathOut == nil);



	# Scan the headers
	mocFiles  = Array.new();
	theFilter = Regexp.compile(excludeFiles);

	Dir["#{pathIn}/**/*\.h*"].each do |theFile|
		if (theFilter.match(theFile) == nil)
			theData = IO.read(theFile);
			if (theData =~ /Q_OBJECT/)
				mocFiles << theFile;
			end
		end
	end



	# Build the .moc file
	#
	# To allow the .moc file to be kept in source control without absolute
	# paths, all paths are stored as relative to the .moc file.
	pathRoot = Pathname.new(File.dirname(pathOut));
	mocFile  = $kMocHeader;

	mocFiles.sort.each do |theFile|
		mocFile += Pathname.new(theFile).relative_path_from(pathRoot);
		mocFile += "\n";
	end



	# Decide if we need to rebuild
	#
	# We need to rebuild if the moc file doesn't exist, a header has
	# been touched, or a header has been added/removed from the list.
	buildMoc = !File.exists?(pathOut);

	if (!buildMoc):
		mocTime = File.mtime(pathOut);

		mocFile.split("\n").each do |theFile|
			if (theFile !~ /^#/):
				theFile  = pathRoot.to_s + "/" + theFile;
				buildMoc = (File.mtime(theFile) > mocTime);
				break if (buildMoc);
			end

		end

	end

	if (!buildMoc):
		oldMD5   = Digest::MD5.hexdigest(IO.read(pathOut));
		newMD5   = Digest::MD5.hexdigest(mocFile);
		buildMoc = (oldMD5 != newMD5);
	end



	# Update the moc file
	if (buildMoc):
		File.open(pathOut, 'w') {|theFile| theFile.write(mocFile) };
	end

end





#============================================================================
#		doBuild : Perform a build command.
#----------------------------------------------------------------------------
def doBuild(pathIn, pathOut)

	# Check our parameters
	doHelp() if (pathIn == nil || pathOut == nil);



	# Build the file
	if (pathIn =~ /\.moc$/):
		buildMoc(pathIn, pathOut);

	elsif (pathIn =~ /\.qrc$/):
		buildQrc(pathIn, pathOut);

	elsif (pathIn =~ /\.ui$/):
		buildUI(pathIn, pathOut);

	else
		doHelp();
	end;

end





#============================================================================
#		doHelp : Display some help.
#----------------------------------------------------------------------------
def doHelp

	# Print some help
	puts("quilt --moc --in=path --out=file.moc [--exclude=pattern]");
	puts("        Scan path for .h files that contain Q_OBJECT references, and");
	puts("        generate a list of mocable files in file.moc");
	puts("");
	puts("quilt --build --in=file.[moc|qrc|ui] --out=file.cpp");
	puts("        Build a .moc, .qrc, or .ui file into a .cpp file");
	puts("");
	exit(0);

end





#============================================================================
#		quilt : Qt meta-meta compiler.
#----------------------------------------------------------------------------
def quilt

	# Get the arguments
	theCmd       = nil;
	pathIn       = nil;
	pathOut      = nil;
	excludeFiles = "";
	
	args = GetoptLong.new(	[ '--moc',		GetoptLong::NO_ARGUMENT       ],
							[ '--build',	GetoptLong::NO_ARGUMENT       ],
							[ '--in',		GetoptLong::REQUIRED_ARGUMENT ],
							[ '--out',		GetoptLong::REQUIRED_ARGUMENT ],
							[ '--exclude',	GetoptLong::REQUIRED_ARGUMENT ]
							);

	args.each do |theArg, theValue|
		if (theArg == "--moc"):
			theCmd = "moc";

		elsif (theArg == "--build"):
			theCmd = "build";
		
		elsif (theArg == "--in"):
			pathIn = theValue;

		elsif (theArg == "--out"):
			pathOut = theValue;

		elsif (theArg == "--exclude"):
			excludeFiles = theValue;
		end
    end



	# Normalise paths
	pathIn  = File.expand_path(pathIn)  if (pathIn  != nil);
	pathOut = File.expand_path(pathOut) if (pathOut != nil);



	# Perform the command
	if (theCmd == "moc"):
		doMoc(pathIn, pathOut, excludeFiles);

	elsif (theCmd == "build"):
		doBuild(pathIn, pathOut);

	else
		doHelp();
	end

end





#============================================================================
#		quilt : Qt meta-meta compiler.
#----------------------------------------------------------------------------
quilt();
