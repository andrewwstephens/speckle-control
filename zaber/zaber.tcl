#!/usr/bin/wish

#
# This Source Code Form is subject to the terms of the GNU Public
# License, v. 2.1. If a copy of the GPL was not distributed with this file,
# You can obtain one at https://www.gnu.org/licenses/old-licenses/gpl-2.0.en.html
#
# Copyright(c) 2017 The Random Factory (www.randomfactory.com) 
#
#
# A = blue
# B = red

set SPECKLE_DIR $env(SPECKLE_DIR)

#source ../util/common.tcl
proc errordialog { msg} {puts stdout $msg}

proc loadZaberConfig { {fname zabersConfiguration} } {
global SPECKLE_DIR ZABERS SCOPE
   if { $SCOPE(telescope) == "GEMINI" } {  
      set fname "[set fname].gemini"
   }
   if { [file exists $SPECKLE_DIR/$fname] == 0 } {
     errordialog "Zaber configuration file $SPECKLE_DIR/$fname\n does not exist"
   } else {
     source $SPECKLE_DIR/$fname
     set NESCONFIG(zaberChange) 0
     debuglog "Loaded Zaber configuration from $SPECKLE_DIR/$fname"
   }
}

proc saveZaberConfig { fname } {
global SPECKLE_DIR ZABERS
   set fcfg [open $SPECKLE_DIR/$fname w]
   puts $fcfg  "#!/usr/bin/tclsh
   echoZaberConfig $fcfg
   close $fcfg
   set NESCONFIG(zaberChange) 0
   debuglog "Saved Zaber configuration in $SPECKLE_DIR/$fname"
}

proc logZaberConfig { } {
global FLOG
  echoZaberConfig $FLOG
}

proc echoZaberConfig { {fcfg stdout} } {
global ZABERS SCOPE
   puts $fcfg  "# Zaber stage configuration parameters
set ZABERS(port) $ZABERS(port)
"
   foreach i "A B " {
     foreach p "device speckle wide" {
         puts $fcfg "set ZABERS($i,$p) \"$ZABERS($i,$p)\""
     }
     puts $fcfg ""
   }
   foreach p "device speckle wide" {  
     puts $fcfg "set ZABERS(input,$p) \"$ZABERS(input,$p)\""
   }
   if { $SCOPE(telescope) == "GEMINI" } {
     foreach p "device in out" {  
       puts $fcfg "set ZABERS(pickoff,$p) \"$ZABERS(pickoff,$p)\""
     }
     foreach p "device extend stow" {  
       puts $fcfg "set ZABERS(focus,$p) \"$ZABERS(focus,$p)\""
     }
   }
   flush $fcfg
}

proc zaberPrintProperties { {fd stdout} } {
global ZABERS ZPROPERTIES SCOPE
   if { $SCOPE(telescope) == "WIYN" } {
    puts $fd "Property		A	B	input"
    foreach p [split $ZPROPERTIES \n] {
       puts $fd "[format %-20s $p]	$ZABERS(A,$p)	$ZABERS(B,$p)	$ZABERS(input,$p)"
     }
   }
   if { $SCOPE(telescope) == "GEMINI" } {
     puts $fd "Property		A	B	input	pickoff		focus"
     foreach p [split $ZPROPERTIES \n] {
       puts $fd "[format %-20s $p]	$ZABERS(A,$p)	$ZABERS(B,$p)	$ZABERS(input,$p)	$ZABERS(pickoff,$p)	$ZABERS(focus,$p)"
     }
   }
}


proc zaberConnect { } {
global ZABERS
   set handle -1
   if { $ZABERS(sim) } {
     set ZABERS(handle) -1
     debuglog "Zabers in SIMULATION mode"
     return
   } else {
      set handle [open $ZABERS(port) RDWR]
      fconfigure $handle -buffering none
      fconfigure $handle -blocking 0
      fconfigure $handle -mode 115200,n,8,1
      fileevent $handle readable [list zaberReader $handle]
    }
   if { $handle < 0 } {
     errordialog "Failed to connect to Zaber $name"
   } else {
     debuglog "Zabers connected to port $ZABERS(port) - OK"
     set ZABERS(handle) $handle
   }
   return $handle
}

proc zaberDisconnect { } {
global ZABERS
   debuglog "Disconnecting from Zabers"
   close $ZABERS(handle)
}

proc homeZabers { } {
global SCOPE
   zaberCommand A home
   zaberCommand B home
   zaberCommand input home
   if { $SCOPE(telescope) == "GEMINI" } {
      zaberCommand focus home
      zaberCommand pickof home
   }
}

proc zaberCommand { name cmd } {
global ZABERS ZPROP ZNAME ZSIMPROP
  if { $ZABERS(handle) > 0 } {
     set ZPROP none
     set ZNAME $name
     set ZSIMPROP ""
     if { [lindex $cmd 0] == "get" || [lindex $cmd 0] == "set" } {
         set ZPROP [lindex $cmd 1]
     }
     if { [lindex $cmd 0] == "move" } { set ZPROP pos }
     if { $ZABERS(sim) && [lindex $cmd 0] == "set" } {
        set ZSIMPROP [lindex $cmd 2]
     } else {
       debuglog "Sending zaber command /$ZABERS($name,device) $cmd"
       set result [puts $ZABERS(handle) "/$ZABERS($name,device) $cmd\r\n"]
       after 100 update
     }
  }
}

proc zaberCheck { } {
global ZABERS
  foreach s "A B input" {
    zaberCommand $s "get pos"
    zaberReader $ZABERS(handle)
    set ZABERS($s,readpos) $ZABERS($s,pos)
    if { [expr abs($ZABERS($s,pos) - $ZABERS($s,speckle)] < 5 } {set ZABERS($s,readpos) "speckle"}
    if { [expr abs($ZABERS($s,pos) - $ZABERS($s,wide)] < 5 } {set ZABERS($s,readpos) "wide"}
  }
  if { $SCOPE(telescope) == "GEMINI" } { 
    zaberCommand focus "get pos"
    zaberReader $ZABERS(handle)
    set ZABERS(focus,readpos) $ZABERS(focus,pos)
    if { [expr abs($ZABERS(focus,pos) - $ZABERS(focus,extend)] < 5 } {set ZABERS(focus,readpos) "extend"}
    if { [expr abs($ZABERS(focus,pos) - $ZABERS(focus,stow)] < 5 } {set ZABERS(focus,readpos) "stow"}
    zaberCommand pickoff "get pos"
    zaberReader $ZABERS(handle)
    set ZABERS(pickoff,readpos) $ZABERS(pickoff,pos)
    if { [expr abs($ZABERS(pickoff,pos) - $ZABERS(pickoff,in)] < 5 } {set ZABERS(pickoff,readpos) "in"}
    if { [expr abs($ZABERS(pickoff,pos) - $ZABERS(pickoff,out)] < 5 } {set ZABERS(pickoff,readpos) "out"}
  }
}


proc zaberReader { fh } {
global ZABERS ZPROP ZNAME ZSIMPROP
  if { $ZABERS(sim) && $ZSIMPROP != "" } {
    set ZABERS($ZNAME,$ZPROP) $ZSIMPROP
  } else {
    if { ![eof $fh] } {
      set res [gets $fh]
      debuglog "zaber : $res"
      if { [lindex $res 2] == "OK" } {
        set ZABERS($ZNAME,$ZPROP) "[lindex $res 5]"
      }
    }
  }
}

proc zaberGetProperties { name } {
global ZABERS ZPROPERTIES
   foreach p [split $ZPROPERTIES \n] {
       zaberCommand $name "get $p"
       after 100
       update
   }
}

set ZPROPERTIES "system.serial
deviceid
system.axiscount
version
version.build
system.voltage
system.access
comm.rs232.baud
comm.protocol
comm.rs232.protocol
stream.numbufs
stream.numstreams
comm.checksum
comm.alert
comm.address
system.led.enable
accel
driver.temperature
pos
limit.min
limit.max
limit.home.pos
motion.index.dist
motion.accelonly
motion.decelonly
maxspeed
driver.current.run
driver.current.hold
driver.current.max
resolution"



proc zaberSetPos  { name pos } {
global ZABERS
   if { $ZABERS(sim) } {
     debuglog "Zaber simulate : $name $pos"
   } else {
     zaberCommand $name  "move abs $pos"
   }
}

proc zaberSetProperty { name property value } {
   zaberCommand $name "set $property $value"
}
 
proc zaberLed { name state } {
   zaberSetProperty system.led.enable $state
}

proc zaberEngpos { name } {
global ZABERS
  set newp $ZABERS($name,target)
  set res [zaberSetPos $name $newp]
}


proc zaberGoto { name pos } {
global ZABERS
  set newp $ZABERS($name,$pos)
  set res [zaberSetPos $name $newp]
  if { $name == "input"  } {
    mimicMode input $pos
  } else {
    catch {mimicMode $ZABERS($name,arm) $pos}
  } 
}

proc zaberConfigurePos { name property {value current} } {
global ZABERS
    if { $value == "current" } {
        set ZABERS($name,$property) $ZABERS($name,pos)
    } else {
        set ZABERS($name,$property) $value
    }   
}


proc zaberHelp { } {
global ZABERS
   puts stdout "
Supported commands : 
    estop
    home
    speckle
    wide
    in
    out
    move abs nnn
    move rel nnn
    set xxx
"
}

proc zaberStopAll { } {
global ZABERS
  debuglog "Zabers estop"
  foreach d [array names ZABERS] {
     if { [lindex [split $d ,] 1] == "device" } {
        set id [lindex [split $d ,] 0]
        puts stdout "Requested estop for device $id"
        zaberCommand $id estop
     }
  }
}

proc positionZabers { station } {
   debuglog "Configure Zabers for $station"
   if { $station == "fullframe" } {
      zaberGoto A wide   
      zaberGoto B wide
      zaberGoto input wide
   }
   if { $station == "roi" } {
      zaberGoto A speckle  
      zaberGoto B speckle
      zaberGoto input speckle
   }
}

proc positionSpeckle { arm station } {
global ZABERS
   debuglog "Configure $arm Zaber for $station"
   if { $station == "fullframe" } {
      if { $ZABERS(A,arm) == $arm } {zaberGoto A wide} 
      if { $ZABERS(B,arm) == $arm } {zaberGoto B wide} 
   }
   if { $station == "roi" } {
      if { $ZABERS(A,arm) == $arm } {zaberGoto A speckle} 
      if { $ZABERS(B,arm) == $arm } {zaberGoto B speckle} 
   }
}



proc zaberService { name cmd {a1 ""} {a2 ""} } {
   switch $cmd {
      estop       {zaberStopAll}
      home        {zaberCommand $name home}
      speckle     {zaberGoto $name speckle}
      in          {zaberCommand $name in}
      out         {zaberCommand $name out}
      wide        {zaberGoto $name wide}
      move        {zaberCommand $name "move $a1 $a2"}
      set         {zaberSetProperty $a1 $a2}
   }
}

if { [info exists env(SPECKLE_SIM)] } {
   set simdev [split $env(SPECKLE_SIM) ,]
   if { [lsearch $simdev zaber] > -1 } {
       set ZABERS(sim) 1
   }
}

loadZaberConfig
echoZaberConfig
zaberConnect
if { $ZABERS(sim) == 0 } {
  zaberGetProperties A
  zaberGetProperties B
  zaberGetProperties input
  if { $SCOPE(telescope) == "GEMINI" } { zaberGetProperties pickoff ; zaberGetProperties focus }
  zaberPrintProperties
  zaberCommand A home
  zaberCommand B home
  zaberCommand input home
  after 3000
  zaberGoto A wide
  zaberGoto B wide
  zaberGoto input wide
  if { $SCOPE(telescope) == "GEMINI" } {
       zaberCommand focus home
       zaberCommand pickoff home
       after 2000
       zaberGoto pickoff out	
       zaberGoto focus stow 
  }
}

