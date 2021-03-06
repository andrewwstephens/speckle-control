#!/usr/bin/wish
proc debuglog { msg } {
   puts stdout $msg
}

proc cAndorSetProperty { cam prop val } {
global ANDOR_CFG
   set res [andorSetProperty $cam $prop $val]
   if { $res == "" } {
     set ANDOR_CFG($cam,$prop) $val
   }
   return $res
}


set SPECKLE_DIR $env(SPECKLE_DIR)
load $SPECKLE_DIR/lib/andorTclInit.so
load $SPECKLE_DIR/lib/libfitstcl.so
load $SPECKLE_DIR/lib/libccd.so
load $SPECKLE_DIR/lib/libguider.so
set ckey [string tolower $env(TELESCOPE)]
source $SPECKLE_DIR/andor/andor.tcl
source $SPECKLE_DIR/andorsConfiguration.[set ckey]
source $SPECKLE_DIR/gui-scripts/headerBuilder.tcl 
source $SPECKLE_DIR/gui-scripts/camera_init.tcl 
if { $env(TELESCOPE) == "GEMINI" } {
  set SCOPE(telescope) "GEMINI"
  set SCOPE(instrument) speckle
  source $SPECKLE_DIR/gui-scripts/gemini_telemetry.tcl 
  set GEMINITLM(sim) 0
  if { [info exists env(SPECKLE_SIM)] } {
    set simdev [split $env(SPECKLE_SIM) ,]
    if { [lsearch $simdev geminitlm] > -1 } {
       set GEMINITLM(sim) 1
       debuglog "Gemini telemetry in SIMULATION mode"
       simGeminiTelemetry
   }
  } else {
    geminiConnect north
  }
} else {
  set SCOPE(telescope) WIYN
}


set cameraNum [lindex $argv 0]
set hstart [lindex $argv 1]
set hend   [lindex $argv 2]
set vstart [lindex $argv 3]
set vend   [lindex $argv 4]
set SPECKLE_DATADIR $env(SPECKLE_DATADIR)

debuglog "Establishing server for camera $cameraNum"
debuglog "hstart =  $hstart"
debuglog "hend =  $hend"
debuglog "vstart =  $vstart"
debuglog "vend =  $vend"
set ncam [GetAvailableCameras]
debuglog "Detected $ncam cameras"

set handle -1
set handle [andorConnectCamera $cameraNum]
if { $handle < 0} {exit}

debuglog "Connected to camera $cameraNum, handle = $handle"
set CAM [expr $cameraNum - 1]
set ANDOR_CFG($CAM,OutputAmplifier) 0
set ANDOR_CFG($CAM,PreAmpGain) 2
set ANDOR_CFG($CAM,VSSpeed) 0
set ANDOR_CFG($CAM,HSSpeed) 0
set ANDOR_CFG($CAM,EMHSSpeed) 0
set ANDOR_CFG(configure) "1 1 1 1024 1 1024 2 2 1 3"
andorConfigure $CAM 1 1 1 1024 1 1024 $ANDOR_CFG($CAM,PreAmpGain) $ANDOR_CFG($CAM,VSSpeed) $ANDOR_CFG($CAM,HSSpeed) $ANDOR_CFG($CAM,EMHSSpeed)
debuglog "Configured camera id $CAM for ccd mode"

set ANDOR_CFG(red) -1
set ANDOR_CFG(blue) -1
set ANDOR_CFG($CAM,SerialNumber) "X-[GetCameraSerialNumber]"
debuglog "Camera $CAM is serial number $ANDOR_CFG($CAM,SerialNumber) = $ANDORS($ANDOR_CFG($CAM,SerialNumber)) arm"
if { $ANDOR_CFG($CAM,SerialNumber) == $ANDORS(red,serialnum) }  {
  set ANDOR_CFG(red) $CAM
  debuglog "ANDOR_CFG(red) = $ANDOR_CFG(red)"
  set ANDOR_ARM red
  set ANDOR_CFG(cmap) Heat
}
if { $ANDOR_CFG($CAM,SerialNumber) == $ANDORS(blue,serialnum) } {
  set ANDOR_CFG(blue) $CAM
  debuglog "ANDOR_CFG(blue) = $ANDOR_CFG(blue)"
  set ANDOR_ARM blue
  set ANDOR_CFG(cmap) Cool
}
foreach i "GetCameraSerialNumber GetEMAdvanced GetEMCCDGain GetFIFOUsage GetFilterMode GetImageRotate GetKeepCleanTime GetMaximumExposure GetMaximumNumberRingExposureTimes GetMinimumImageLength GetMinimumNumberInSeries GetNumberADChannels GetNumberAmp GetNumberDevices GetNumberFKVShiftSpeeds GetNumberHorizontalSpeeds GetNumberIO GetNumberPreAmpGains GetNumberRingExposureTimes GetNumberVSAmplitudes GetNumberVSSpeeds GetNumberVerticalSpeeds GetReadOutTime GetStartUpTime GetStatus GetTotalNumberImagesAcquired" {
     set ANDOR_CFG($CAM,[string range $i 3 end]) "[$i]"
     debuglog "$CAM : $i = $ANDOR_CFG($CAM,[string range $i 3 end])"
}
SetExposureTime 0.04
cAndorSetProperty $CAM Temperature -60
cAndorSetProperty $CAM Cooler 1

set shmid [andorConnectShmem 512 512]
debuglog "$ANDOR_ARM memory buffers @ $shmid"
initds9 [lindex $shmid 0] 512 512
set ANDOR_CFG(shmem) [lindex $shmid 0]
andorPrepDataCube
exec xpaset -p ds9 single
exec xpaset -p ds9 zoom to fit
andorPrepDataFrame
cAndorSetProperty $CAM Shutter 0
cAndorSetProperty $CAM FrameTransferMode 1
cAndorSetProperty $CAM OutputAmplifier 0
cAndorSetProperty $CAM EMAdvanced 1
cAndorSetProperty $CAM EMCCDGain 1
cAndorSetProperty $CAM VSSpeed 0
cAndorSetProperty $CAM PreAmpGain 0
cAndorSetProperty $CAM ReadMode 4
cAndorSetProperty $CAM AcquisitionMode 1
cAndorSetProperty $CAM KineticCycleTime 0.0
cAndorSetProperty $CAM NumberAccumulations 1
cAndorSetProperty $CAM NumberKinetics 100
cAndorSetProperty $CAM AccumulationCycleTime 0.0


proc showstatus { } {
global CAM ANDOR_CFG
  foreach i "GetCameraSerialNumber GetEMAdvanced GetEMCCDGain GetFIFOUsage GetFilterMode GetImageRotate GetKeepCleanTime GetMaximumExposure GetMaximumNumberRingExposureTimes GetMinimumImageLength GetMinimumNumberInSeries GetNumberADChannels GetNumberAmp GetNumberDevices GetNumberFKVShiftSpeeds GetNumberHorizontalSpeeds GetNumberIO GetNumberPreAmpGains GetNumberRingExposureTimes GetNumberVSAmplitudes GetNumberVSSpeeds GetNumberVerticalSpeeds GetReadOutTime GetStartUpTime GetStatus GetTotalNumberImagesAcquired" {
     set ANDOR_CFG($CAM,[string range $i 3 end]) "[$i]"
     debuglog "$CAM : $i = $ANDOR_CFG($CAM,[string range $i 3 end])"
  }
  foreach i "Shutter FrameTransferMode OutputAmplifier HSSpeed VSSpeed PreAmpGain ReadMode AcquisitionMode KineticCycleTime NumberAccumulations NumberKinetics AccumulationCycleTime" {
     debuglog "$CAM : $i = $ANDOR_CFG($CAM,$i)"
     lappend s $ANDOR_CFG($CAM,$i)
  }
  set t [andorGetProperty $CAM timings]
  foreach x $t { lappend s $x }
  return $s
} 


proc resetCamera { mode } {
global CAM ANDOR_CFG
   andorShutDown
   set handle [andorConnectCamera [expr $CAM+1]]
   if { $mode == "fullframe" } {
     debuglog "Connected to camera $CAM for fullframe, handle = $handle"
     andorConfigure $CAM 1 1 1 1024 1 1024 $ANDOR_CFG($CAM,PreAmpGain) $ANDOR_CFG($CAM,VSSpeed) $ANDOR_CFG($CAM,HSSpeed) $ANDOR_CFG($CAM,EMHSSpeed)
   }
   if { $mode == "roi" } {
     debuglog "Connected to camera $CAM for ROI, handle = $handle"
     andorConfigure $CAM 1 1 1 256 1 256 $ANDOR_CFG($CAM,PreAmpGain) $ANDOR_CFG($CAM,VSSpeed) $ANDOR_CFG($CAM,HSSpeed) $ANDOR_CFG($CAM,EMHSSpeed)
   }
}

proc configureFrame { mode } {
global CAM ANDOR_ROI ANDOR_CFG SCOPE
   if { $mode == "fullframe" } {
     debuglog "Configure camera $CAM for fullframe"
     andorConfigure $CAM 1 1 1 1024 1 1024 $ANDOR_CFG($CAM,PreAmpGain) $ANDOR_CFG($CAM,VSSpeed) $ANDOR_CFG($CAM,HSSpeed) $ANDOR_CFG($CAM,EMHSSpeed)
     andorPrepDataFrame
     cAndorSetProperty $CAM AcquisitionMode 1
     cAndorSetProperty $CAM OutputAmplifier 0
     set SCOPE(numframes) 1
   }
   if { $mode == "roi" } {
     debuglog "Configure camera $CAM for ROI : $ANDOR_ROI(xs) $ANDOR_ROI(xe) $ANDOR_ROI(ys) $ANDOR_ROI(ye)"
     andorConfigure $CAM 1 1 $ANDOR_ROI(xs) $ANDOR_ROI(xe) $ANDOR_ROI(ys) $ANDOR_ROI(ye) $ANDOR_CFG($CAM,PreAmpGain) $ANDOR_CFG($CAM,VSSpeed) $ANDOR_CFG($CAM,HSSpeed) $ANDOR_CFG($CAM,EMHSSpeed)
     cAndorSetProperty $CAM AcquisitionMode 3
     cAndorSetProperty $CAM OutputAmplifier 0
   }
}

proc acquireDataFrame { exp } {
global ANDOR_CFG SPECKLE_DATADIR ANDOR_ARM
    debuglog "Starting $ANDOR_ARM full-frame with exposure = $exp"
    set t [clock seconds]
    SetExposureTime $exp
    if { $ANDOR_CFG(red) > -1} {
      andorGetData $ANDOR_CFG(red)
      andorStoreFrame $ANDOR_CFG(red) $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits 1024 1024 1 1
      appendHeader $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits
      exec xpaset -p ds9 frame 1
      exec xpaset -p ds9 zoom to fit
      exec xpaset -p ds9 cmap $ANDOR_CFG(cmap)
      after 400
      exec xpaset -p ds9 file $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits
    }
    if { $ANDOR_CFG(blue) > -1 } {
      andorGetData $ANDOR_CFG(blue)
      andorStoreFrame $ANDOR_CFG(blue) $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits 1024 1024 1 1
      appendHeader $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits
      exec xpaset -p ds9 frame 2
      exec xpaset -p ds9 zoom to fit
      exec xpaset -p ds9 cmap $ANDOR_CFG(cmap)
      after 400
      exec xpaset -p ds9 file $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits
    }
}

proc acquireDataROI { exp x y n } {
global ANDOR_CFG SPECKLE_DATADIR ANDOR_ARM
    debuglog "Starting $ANDOR_ARM ROI sequence with exposure = $exp"
    set t [clock seconds]
    SetExposureTime $exp
    if { $ANDOR_CFG(red) > -1} {
      andorSetROI $ANDOR_CFG(red) $x [expr $x+$n-1] $y [expr $y+$n-1] 1
      andorGetData $ANDOR_CFG(red)
      andorSaveData $ANDOR_CFG(red) $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits $n $n 1 1
      appendHeader $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits
      exec xpaset -p ds9 frame 1
      exec xpaset -p ds9 cmap $ANDOR_CFG(cmap)
      after 400
      exec xpaset -p ds9 file $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits
    }
    if { $ANDOR_CFG(blue) > -1 } {
      andorSetROI $ANDOR_CFG(blue) $x [expr $x+$n-1] $y [expr $y+$n-1] 1
      andorGetData $ANDOR_CFG(blue)
      andorSaveData $ANDOR_CFG(blue) $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits $n $n 1 1
      appendHeader $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits
      exec xpaset -p ds9 frame 2
      exec xpaset -p ds9 cmap $ANDOR_CFG(cmap)
      after 400
      exec xpaset -p ds9 file $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits
    }
}

proc OldacquireDataCube { exp x y npix n } {
global ANDOR_CFG SPECKLE_DATADIR ANDOR_ARM ANDOR_ARM ANDOR_ROI
  debuglog "Starting $ANDOR_ARM roi cube sequence with exposure = $exp x=$x y=$y geom=$npix n=$n"
  if { $ANDOR_ARM == "blue" } {
    exec xpaset -p ds9 shm array shmid $ANDOR_CFG(shmem) \\\[xdim=512,ydim=512,bitpix=32\\\]
  }
  refreshds9 [expr int($exp*2000)] [expr $n*4]
  set t [clock seconds]
  SetExposureTime $exp
  if { $ANDOR_CFG(red) > -1} {
     andorSetROI $ANDOR_CFG(red) $x [expr $x+$npix-1] $y [expr $y+$npix-1] 1
  }
  if { $ANDOR_CFG(blue) > -1} {
     andorSetROI $ANDOR_CFG(blue) $x [expr $x+$npix-1] $y [expr $y+$npix-1] 1
  }
  set count 0
  set dofft 1
  andorStartAcq;
  while { $count < $n } {
    incr count 1
    if { $ANDOR_CFG(red) > -1} {
      andorGetFrameN $ANDOR_CFG(red) $count
      andorSaveData $ANDOR_CFG(red) $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits $npix $npix $count $n
      andorDisplayFrame $ANDOR_CFG(red) $npix $npix 1
    }
    if { $ANDOR_CFG(blue) > -1 } {
      andorGetFrameN $ANDOR_CFG(blue) $count
      andorSaveData $ANDOR_CFG(blue) $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits $npix $npix $count $n
      andorDisplayFrame $ANDOR_CFG(blue) $npix $npix 1
    }
    update idletasks
    after 1
  }
  if { $ANDOR_CFG(red) > -1} {
    appendHeader $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits
    andorDisplayAvgFFT $ANDOR_CFG(red) $npix $npix $n
    catch {andorAbortAcq $ANDOR_CFG(red)}
  }
  if { $ANDOR_CFG(blue) > -1} {
    appendHeader $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits
    andorDisplayAvgFFT $ANDOR_CFG(blue) $npix $npix $n
    catch {andorAbortAcq $ANDOR_CFG(blue)}
  }
  debuglog "Finished acquisition"
}

proc andorSaveData { cid fname nx ny count n } {
global ANDOR_CFG
  switch $ANDOR_CFG(fitsbits) { 
      short   { andorStoreFrameI2 $cid $fname $nx $ny $count $n }
      long    { andorStoreFrameI4 $cid $fname $nx $ny $count $n }
      default { andorStoreFrame   $cid $fname $nx $ny $count $n }
  }
}

proc acquireDataCube { exp x y npix n } {
global ANDOR_CFG SPECKLE_DATADIR ANDOR_ARM ANDOR_ARM ANDOR_ROI
  debuglog "Starting $ANDOR_ARM roi cube sequence with exposure = $exp x=$x y=$y geom=$npix n=$n"
  if { $ANDOR_ARM == "blue" } {
    exec xpaset -p ds9 shm array shmid $ANDOR_CFG(shmem) \\\[xdim=512,ydim=512,bitpix=32\\\]
    exec xpaset -p ds9 cmap grey
  }
  refreshds9 [expr int($exp*2000)] [expr $n*4]
  set t [clock seconds]
  SetExposureTime $exp
  if { $ANDOR_CFG(red) > -1} {
     andorSetROI $ANDOR_CFG(red) $x [expr $x+$npix-1] $y [expr $y+$npix-1] 1
  }
  if { $ANDOR_CFG(blue) > -1} {
     andorSetROI $ANDOR_CFG(blue) $x [expr $x+$npix-1] $y [expr $y+$npix-1] 1
  }
  set count 0
  set dofft 1
  if { $ANDOR_CFG(red) > -1} {
      andorGetDataCube $ANDOR_CFG(red) $n $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits $dofft
  }
  if { $ANDOR_CFG(blue) > -1 } {
      andorGetDataCube $ANDOR_CFG(blue) $n $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits $dofft
  }
  update idletasks
  if { $ANDOR_CFG(red) > -1} {
    appendHeader $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_red.fits
    andorDisplayAvgFFT $ANDOR_CFG(red) $npix $npix $n
    catch {andorAbortAcq $ANDOR_CFG(red)}
  }
  if { $ANDOR_CFG(blue) > -1} {
    appendHeader $SPECKLE_DATADIR/[set ANDOR_CFG(imagename)]_blue.fits
    andorDisplayAvgFFT $ANDOR_CFG(blue) $npix $npix $n
    catch {andorAbortAcq $ANDOR_CFG(blue)}
  }
  debuglog "Finished acquisition"
}

set ANDOR_CFG(fitsbits) default


proc locateStar { steps smooth } {
global ANDOR_CFG
  if { $ANDOR_CFG(red) > -1} {
     set res [andorLocateStar $ANDOR_CFG(red) $steps $smooth]
  }  
  if { $ANDOR_CFG(blue) > -1} {
     set res [andorLocateStar $ANDOR_CFG(blue) $steps $smooth]
  }  
  return $res
}

proc selectROI { idim } {
global ANDOR_ARM ANDOR_ROI
  set xy [locateStar 20 5]
  set x [lindex $xy 0]
  set y [lindex $xy 1]
  set xs [expr $x - $idim/2]
  set xe [expr $x + $idim/2 -1]
  if { $xs < 1 } { set xs 1 ; set xe $idim}
  if { $xe > 1024 } {set xe 1024 ; set xs [expr 1024-$idim-1}
  set ys [expr $y - $idim/2]
  set ye [expr $y + $idim/2 -1]
  if { $ys < 1 } { set yd 1 ; set ye $idim}
  if { $ye > 1024 } {set ye 1024 ; set ys [expr 1024-$idim-1]}
  exec xpaset -p ds9 regions deleteall
  exec echo "box [expr $xs+$idim/2] [expr $ys+$idim/2] $idim $idim 0" | xpaset  ds9 regions
  set ANDOR_ROI(xs) $xs
  set ANDOR_ROI(xe) $xe
  set ANDOR_ROI(ys) $ys
  set ANDOR_ROI(ye) $ye
  debuglog "$ANDOR_ARM ROI measured as $xs , $xe , $ys , $ye [lrange $xy 2 3]"
  return "$xy"
}

proc forceROI { xs xe ys ye } {
global ANDOR_ARM ANDOR_ROI
  set ANDOR_ROI(xs) $xs
  set ANDOR_ROI(xe) $xe
  set ANDOR_ROI(ys) $ys
  set ANDOR_ROI(ye) $ye
  debuglog "$ANDOR_ARM ROI user selected as $xs , $xe , $ys , $ye"
}



proc shutDown { } {
  debuglog "Shutting down Andor acqusition servers"
  andorShutDown
  exit
}

proc doService {sock msg} {
global TLM SCOPE CAM ANDOR_ARM DATADIR ANDOR_CFG TELEMETRY
    debuglog "echosrv:$msg"
    set ANDOR_CFG([lindex $msg 0]) [lrange $msg 1 end]
    switch [lindex $msg 0] {
         shutdown        { shutDown ; puts $sock "OK"; exit }
         reset           { resetCamera [lindex $msg 1] ; puts $sock "OK"}
         grabframe       { after 10 "acquireDataFrame [lindex $msg 1]" ; puts $sock "Acquiring frame"}
         setroi          { set res [selectROI [lindex $msg 1]] ; puts $sock "$res"}
         grabroi         { after 10 "acquireDataROI [lindex $msg 1] [lindex $msg 2] [lindex $msg 3] [lindex $msg 4]" ; puts $sock "Acquiring roi"}
         version         { puts $sock "1.0" }
         grabcube        { after 10 "acquireDataCube [lindex $msg 1] [lindex $msg 2] [lindex $msg 3] [lindex $msg 4] [lindex $msg 5]" ; puts $sock "Acquiring cube"}
         setframe        { configureFrame [lindex $msg 1] ;  puts $sock "OK"}
         fitsbits        { set ANDOR_CFG(fitsbits) [lindex $msg 1] ; puts $sock "OK"}
         whicharm        { puts $sock $ANDOR_ARM }
         forceroi        { forceROI  [lindex $msg 1] [lindex $msg 2] [lindex $msg 3] [lindex $msg 4] ; puts $sock "OK"}
         locatestar      { puts $sock "[locateStar [lindex $msg 1] [lindex $msg 2]]" }
         datadir         { set SPECKLE_DATADIR [lindex $msg 1] ; puts $sock "OK"}
         imagename       { set ANDOR_CFG(imagename) [lindex $msg 1] ; set SCOPE(datadir) [lindex $msg 1] ; set ANDOR_CFG(overwrite) [lindex $msg 2] ; puts $sock "OK"}
         gettemp         { set it [andorGetProperty $CAM temperature] ; set ANDOR_CFG(ccdtemp) $it ; puts $sock $it }
         status          { set it [showstatus] ; puts $sock $it}
         shutter         { set it [cAndorSetProperty $CAM Shutter [lindex $msg 1]] ; puts $sock $it}
         frametransfer   { set it [cAndorSetProperty $CAM FrameTransferMode [lindex $msg 1]] ; puts $sock $it}
         outputamp       { set it [cAndorSetProperty $CAM OutputAmplifier [lindex $msg 1]] ; puts $sock $it}
         emadvanced      { set it [cAndorSetProperty $CAM EMAdvanced [lindex $msg 1]] ; puts $sock $it}
         emccdgain       { set it [cAndorSetProperty $CAM EMCCDGain [lindex $msg 1]] ; puts $sock $it}
         hsspeed         { set it [cAndorSetProperty $CAM HSSpeed "[lindex $msg 1] [lindex $msg 2]"] ; puts $sock $it}
         vsspeed         { set it [cAndorSetProperty $CAM VSSpeed [lindex $msg 1]] ; puts $sock $it}
         preampgain      { set it [cAndorSetProperty $CAM PreAmpGain [lindex $msg 1]] ; puts $sock $it}
         readmode        { set it [cAndorSetProperty $CAM ReadMode [lindex $msg 1]] ; puts $sock $it}
         acquisition     { set it [cAndorSetProperty $CAM AcquisitionMode [lindex $msg 1]] ; puts $sock $it}
         kineticcycletime      { set it [cAndorSetProperty $CAM KineticCycleTime [lindex $msg 1]] ; puts $sock $it}
         numberaccumulations    { set it [cAndorSetProperty $CAM NumberAccumulations [lindex $msg 1]] ; puts $sock $it}
         numberkinetics        { set it [cAndorSetProperty $CAM NumberKinetics [lindex $msg 1]] ; puts $sock $it}
         accumulationcycletime { set it [cAndorSetProperty $CAM AccumulationCycleTime [lindex $msg 1]] ; puts $sock $it}
         setexposure     { SetExposureTime [lindex $msg 1] ; puts $sock "OK"}
         settemperature  { SetTemperature [lindex $msg 1] ; puts $sock "OK"}
         positiontelem   { set TELEMETRY(speckle.andor.inputzaber [lindex $msg 1]
                           set TELEMETRY(speckle.andor.fieldzaber) [lindex $msg 2]
                           set TELEMETRY(speckle.andor.filter) [lindex $msg 3]
                           puts $sock "OK"
                         }
         dqtelemetry     { set TELEMETRY(speckle.andor.rawiq) [lindex $msg 1]
                           set TELEMETRY(speckle.andor.rawcc) [lindex $msg 2]
                           set TELEMETRY(speckle.andor.rawwv) [lindex $msg 3]
                           set TELEMETRY(speckle.andor.rawbg) [lindex $msg 4]
                           puts $sock "OK"
                         }
         configure       { set hbin [lindex $msg 1]
                           set vbin [lindex $msg 2]
                           set vstart [lindex $msg 3]
                           set vend [lindex $msg 4]
                           set hstart [lindex $msg 5]
                           set hend [lindex $msg 6]
                           set preamp_gain [lindex $msg 7]
                           set vertical_speed [lindex $msg 8]
                           set ccd_horizontal_speed [lindex $msg 9]
                           set em_horizontal_speed [lindex $msg 10]
                           andorConfigure $CAM $hbin $vbin $hstart $hend $vstart $vend $preamp_gain $vertical_speed $ccd_horizontal_speed $em_horizontal_speed
                           set ANDOR_CFG($CAM,PreAmpGain) $preamp_gain
                           set ANDOR_CFG($CAM,VSSpeed) $vertical_speed
                           if { $ANDOR_CFG($CAM,OutputAmplifier) == 0 } {
                             set ANDOR_CFG($CAM,EMHSSpeed) $em_horizontal_speed
                           } else {
                             set ANDOR_CFG($CAM,HSSpeed) $ccd_horizontal_speed
                           }
			   puts $sock "OK"
                         }
         setupcamera     { set it [andorSetupCamera $CAM [lindex $msg 1]] ; puts $sock $it}
         default         { if { [string range [lindex $msg 0] 0 3] == "Get" } {
                             puts $sock [eval [lindex $msg 0]]
                           } else {
                             if { [string range [lindex $msg 0] 0 3] == "Set" } {
                                puts $sock [eval [lindex $msg 0] [lindex $msg 1]]
                             } else {
                                puts $sock "ERROR: unknown $msg"
                             }
                           }
                         }
    }
    flush $sock
}


wm withdraw .

# Handles the input from the client and  client shutdown
proc  svcHandler {sock} {
  set l [gets $sock]    ;# get the client packet
  if {[eof $sock]} {    ;# client gone or finished
     close $sock        ;# release the servers client channel
  } else {
    doService $sock $l
  }
}

# Accept-Connection handler for Server.
# called When client makes a connection to the server
# Its passed the channel we're to communicate with the client on,
# The address of the client and the port we're using
#
# Setup a handler for (incoming) communication on
# the client channel - send connection Reply and log connection
proc accept {sock addr port} {

  # if {[badConnect $addr]} {
  #     close $sock
  #     return
  # }

  # Setup handler for future communication on client socket
  fileevent $sock readable [list svcHandler $sock]

  # Note we've accepted a connection (show how get peer info fm socket)
  puts "Accept from [fconfigure $sock -peername]"

  # Read client input in lines, disable blocking I/O
  fconfigure $sock -buffering line -blocking 0

  # Send Acceptance string to client
  #  puts $sock "$addr:$port, You are connected to the echo server."
  #  puts $sock "It is now [exec date]"

  # log the connection
  puts "Accepted connection from $addr at [exec date]"
}

 


# Create a server socket on port $svcPort.
# Call proc accept when a client attempts a connection.
set svcPort [expr 2000 + $cameraNum]
socket -server accept $svcPort
vwait events    ;# handle events till variable events is set

