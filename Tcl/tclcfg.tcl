puts "tclsh=[info nameofexecutable]"
set libdir [file join [file dirname [file dirname [info nameofexe]]] lib]
puts "tclConfig.sh=[file join $libdir tclConfig.sh]"
puts "tcl_library=$tcl_library"
puts "tcl_version=$tcl_version"
