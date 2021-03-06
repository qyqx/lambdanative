#!/bin/sh
# LambdaNative - a cross-platform Scheme framework
# Copyright (c) 2009-2013, University of British Columbia
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or
# without modification, are permitted provided that the
# following conditions are met:
#
# * Redistributions of source code must retain the above
# copyright notice, this list of conditions and the following
# disclaimer.
#
# * Redistributions in binary form must reproduce the above
# copyright notice, this list of conditions and the following
# disclaimer in the documentation and/or other materials
# provided with the distribution.
#
# * Neither the name of the University of British Columbia nor
# the names of its contributors may be used to endorse or
# promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# application building, packaging and installation

. ./config.cache

. ./SETUP

evallog=`pwd`"/eval.log"

if [ -f $evallog ]; then
  rm $evallog
fi

#########################
# general functions

# since os x doesn't have md5sum
md5summer=md5sum
if [ "X"`which md5sum 2> /dev/null` = "X" ]; then
  md5summer="md5 -r"
fi

veval()
{
  if [ $SYS_VERBOSE ]; then 
    echo "$1"
    eval $1
  else 
    echo "$1" > $evallog
    eval $1 >> $evallog 2>&1
  fi
}

vecho()
{
  if [ $SYS_VERBOSE ]; then 
    echo "$1"
  fi
}

getparam()
{
  if [ "$1" = "1" ]; then echo "$2"; fi
  if [ "$1" = "2" ]; then echo "$3"; fi
  if [ "$1" = "3" ]; then echo "$4"; fi
  if [ "$1" = "4" ]; then echo "$5"; fi
  if [ "$1" = "5" ]; then echo "$6"; fi
}

rmifexists()
{
  if [ "$1" ]; then
    if [ -e "$1" ]; then
      vecho " => removing old $1.."
      rm -rf "$1"
    fi
  fi
}

###############################
# keep track of state to reset partial builds

statefile=`pwd`"/make.state"

setstate()
{
  echo "state=$1" > $statefile
}

resetstate()
{
  state=
  if [ -f $statefile ]; then
    . $statefile
    rm $statefile
  fi
  if [ ! "X$state" = "X" ]; then
    echo " ** WARNING: previous build aborted unexpectantly in state: $state"
    case $state in
      ARTWORK)
       file=`locatefile apps/$SYS_APPNAME/artwork.eps silent`
       if [ -f $file ]; then
         touch $file
       fi
      ;;
      STRINGS)
       file="$SYS_PREFIXROOT/build/$SYS_APPNAME/strings/strings_include.scm"
       rmifexists $file
       ;;
      FONTS)
       file="$SYS_PREFIXROOT/build/$SYS_APPNAME/fonts/fonts_include.scm"
       rmifexists $file
       ;;
      TEXTURES)
       file="$SYS_PREFIXROOT/build/$SYS_APPNAME/textures/textures_include.scm"
       rmifexists $file
       ;;
    esac
  fi
} 

#################################
# abort on missing files and errors

assertfile()
{
  if [ ! -e "$1" ]; then
    if [ -f $evallog ]; then
      cat $evallog | sed '/^$/d'
    fi
    echo "ERROR: failed on file $1" 1>&2
    exit 1
  fi
}

asserterror()
{
  if [ ! $1 = 0 ]; then
    if [ -f $evallog ]; then
      cat $evallog | sed '/^$/d'
    fi
    echo "ERROR: failed with exit code $1" 1>&2
    exit 1
  fi
}

#################################
# misc file and directory support

stringhash()
{
  echo "$1" | $md5summer | cut -f 1 -d " "
}

isnewer()
{
  result=no
  if [ ! -e "$2" ]; then
    result=yes
  else
    if `test "$1" -nt "$2"`; then
      result=yes
    fi
  fi
  echo $result
}

newersourceindir()
{
  result="no"
  tgt="$2"
  dir=`dirname $1`
  srcfiles=`ls -1 $dir/*.scm` 
  for src in $srcfiles; do
    if `test "$src" -nt "$tgt"`; then
      result="yes"
    fi
  done
  echo $result
}

newerindir()
{
  result="no"
  tgt="$2"
  if [ -d $1 ]; then
    dir=$1
  else
    dir=`dirname $1`
  fi
  srcfiles=`ls -1 $dir/*`
  for src in $srcfiles; do
    if `test "$src" -nt "$tgt"`; then
      result="yes"
    fi
  done
  echo $result
}

locatetest()
{
  here=`pwd`
  file=
  dirs=$(echo "$SYS_PATH" | tr ":" "\n")
  for dir in $dirs; do
    tmp="$dir/$2"
    if [ ! "X$tmp" = "X" ]; then
      if [ $1 $tmp ]; then
        if [ "X$file" = "X" ]; then
          file=$tmp
        else
          if [ ! "X$3" = "Xsilent" ]; then
             echo "WARNING: $file shadows $tmp" 1>&2
          fi
        fi
      fi
    fi 
  done
  if [ "X$file" = "X" ]; then
    if [ ! "X$3" = "Xsilent" ]; then
      echo "WARNING: [$2] not found" 1>&2
    fi
  fi
  if [ ! -e $file ]; then
    if [ ! "X$3" = "Xsilent" ]; then
      echo "WARNING: [$2] not found" 1>&2
    fi
  fi
  cd "$here"
  echo $file
}

locatedir()
{
  locatetest "-d" $@
}

locatefile()
{
  locatetest "-f" $@
}

wildcard_dir()
{
  find $1 -maxdepth 0 -print |sort -r| head -n 1
}

#################################
# autoconf-like parameter substitution

ac_sedsub=

ac_subst()
{
  newcmd="echo \"s|@${1}@|\$${1}|g;\""
  newsub=`eval $newcmd`
  ac_sedsub="${ac_sedsub}${newsub}"
}

ac_output()
{
  infile=`echo "${1}" | sed 's/\.in$//'`.in
  if [ "X$2" = "X" ]; then
    outfile=$1
  else 
    outfile=$2
  fi
  assertfile $infile
  cat $infile | sed "$ac_sedsub" > $outfile
  assertfile $outfile
}

#################################
# misc source code checks

has_module()
{
  res=no
  modfile=`locatefile apps/$SYS_APPNAME/MODULES`
  if [ -f "$modfile" ]; then
    if [ ! "X"`cat "$modfile" | grep "$1" | cut -c 1` = "X" ]; then
       res=yes
    fi
  fi 
  echo $res
}

is_gui_app()
{
  res=`has_module ln_glcore`
  if [ "$res" = "no" ]; then
    res=`has_module glcore`
  fi
  echo "$res"
}

is_standalone_app()
{
  neg=`has_module eventloop`
  if [ $neg = no ]; then
    neg=yes
  else
    neg=no
  fi
  echo $neg
}

###########################
# general compiler functions

compile()
{
  if [ $SYS_MODE = "debug" ]; then
    opts="(declare (block)(not safe)(debug)(debug-location))"
    optc="-g -Wall -Wno-unused-variable -Wno-unused-label -Wno-unused-parameter"
  else 
    opts="(declare (block)(not safe))"
    optc="-O2 -Wall -Wno-unused-variable -Wno-unused-label -Wno-unused-parameter"
  fi
  src="$1"
  ctgt="$2"
  otgt="$3"
  defs="$4"
  path=`dirname $src`
  here=`pwd`
  cd $path
  rmifexists "$ctgt"
  echo " => $src.." 
  veval "$SYS_GSC -prelude \"$opts\" -c -o $ctgt $src"
  assertfile "$ctgt"
  rmifexists "$otgt"
  veval "$SYS_CC $SYS_CPPFLAGS $SYS_CFLAGS $defs -c -o $otgt $ctgt -I$SYS_PREFIX/include"
  assertfile "$otgt"
  cd $here
}

compile_payload()
{
  name=$1
  srcs="$2"
  csrcs=
  libs="$3"
  objs=
  defs="-D___SINGLE_HOST -D___LIBRARY -D___PRIMAL"
  echo "==> creating payload needed for $name.."
  mkdir -p "$SYS_PREFIX/build"
  dirty=
  for src in $srcs; do
    chsh=`stringhash "$src"`
    ctgt="$SYS_PREFIX/build/$chsh.c"
    csrcs="$csrcs $ctgt"
    otgt=`echo "$ctgt" | sed 's/c$/o/'`
    objs="$objs $otgt"
    flag=
    if [ ! -f "$otgt" ]; then
      flag=yes
    else 
      if [ `newersourceindir "$src" "$otgt"` = "yes" ]; then
        flag=yes
      fi
    fi
    if [ $flag ]; then
      dirty=yes
      compile "$src" "$ctgt" "$otgt" "$defs"
    fi
  done
  lctgt=`echo "$ctgt" | sed 's/\.c$/\_\.c/'`
  lotgt=`echo "$lctgt" | sed 's/c$/o/'`
  if [ ! -f "$lotgt" ]; then
    dirty=yes
  fi
  if [ $dirty ]; then
    echo " => creating gsc link.."
    vecho "$SYS_GSC -link $csrcs"
    $SYS_GSC -link $csrcs 
    assertfile $lctgt
    veval "$SYS_CC $SYS_CPPFLAGS $SYS_CFLAGS $defs -o $lotgt -c $lctgt -I$SYS_PREFIX/include"
    assertfile $lotgt
  fi
  objs="$objs $lotgt"
  hookhash=`stringhash "apps/$SYS_APPNAME/hook.c"`
  hctgt="$SYS_PREFIX/build/$hookhash.c"
  hotgt=`echo "$hctgt" | sed 's/c$/o/'`
  if [ ! -f "$hotgt" ]; then
    dirty=yes
  fi
  if [ $dirty ]; then
    echo " => generating hook.."
    linker=`echo $chsh"__"`
cat > $hctgt  << _EOF
// automatically generated. Do not edit.
#include <stdlib.h>
#include <CONFIG.h>
#define ___VERSION 407000
#include <gambit.h>
#define LINKER ____20_$linker
___BEGIN_C_LINKAGE
extern ___mod_or_lnk LINKER (___global_state_struct*);
___END_C_LINKAGE
___setup_params_struct setup_params;
int debug_settings = ___DEBUG_SETTINGS_INITIAL;
#ifdef STANDALONE
char *cmd_arg1=0;
int main(int argc, char *argv[])
{
  if (argc>1) cmd_arg1=argv[1];
  ___setup_params_reset (&setup_params);
  setup_params.version = ___VERSION;
  setup_params.linker = LINKER;
  debug_settings = (debug_settings & ~___DEBUG_SETTINGS_REPL_MASK) | 
  (___DEBUG_SETTINGS_REPL_STDIO << ___DEBUG_SETTINGS_REPL_SHIFT);
  setup_params.debug_settings = debug_settings;
  ___setup(&setup_params);
  ___cleanup();
  return 0;
}
#else 
void ffi_event(int t, int x, int y)
{
  static int lock=0;
  static int gambitneedsinit=1;
  if (lock) { return; } else { lock=1; }
  if (gambitneedsinit) {
      ___setup_params_reset (&setup_params);
      setup_params.version = ___VERSION;
      setup_params.linker = LINKER;
      debug_settings = (debug_settings & ~___DEBUG_SETTINGS_REPL_MASK) | 
        (___DEBUG_SETTINGS_REPL_STDIO << ___DEBUG_SETTINGS_REPL_SHIFT);
      setup_params.debug_settings = debug_settings;
      ___setup(&setup_params);
      gambitneedsinit=0;
  }
  if (!gambitneedsinit) scm_event(t,x,y);
  if (t==EVENT_TERMINATE) { ___cleanup(); exit(0); }
  lock=0;
}
#endif
_EOF
    if [ `is_standalone_app` = "yes" ]; then
      defs="$defs -DSTANDALONE"
    fi
    veval "$SYS_CC $SYS_CPPFLAGS $SYS_CFLAGS $defs -c -o $hotgt $hctgt -I$SYS_PREFIX/include"
    assertfile $hotgt
  fi
  objs="$objs $hotgt"
  for lib in $libs; do
   objs=`ls -1 $SYS_PREFIX/build/$lib/*.o`" $objs"
  done
  tgtlib="$SYS_PREFIX/lib/libpayload.a"
  echo " => assembling payload.."
  sobjs=
  for obj in $objs; do
    sobjs="$sobjs $obj"
  done
  rmifexists "$tgtlib"
  vecho "$SYS_AR rc $tgtlib $sobjs"
  $SYS_AR rc $tgtlib $sobjs  2> /dev/null
  vecho "$SYS_RANLIB $tgtlib"
  $SYS_RANLIB $tgtlib 2> /dev/null
  assertfile "$tgtlib"
}

##################################
# extract object files from static library

explode_library()
{
  libname=$1
  libfile="$SYS_PREFIX/lib/$libname.a"
  libdir="$SYS_PREFIX/build/$libname"
  assertfile $libfile
  if [ `isnewer $libfile $libdir` = "yes" ]; then
    rmifexists "$libdir"
    echo " => exploding library $libname.."
    mkdir -p "$libdir"
    here=`pwd`
    cd "$libdir"
    $SYS_AR -x $libfile
    cd "$here"
  fi
}

###################################
# artwork & texture generation

make_artwork()
{
  setstate ARTWORK
  echo "==> creating artwork needed for $SYS_APPNAME.."
  objsrc=`locatefile "apps/$SYS_APPNAME/artwork.obj" silent`
  epssrc=`locatefile "apps/$SYS_APPNAME/artwork.eps" silent`
  if [ "X$epssrc" = "X" ]; then
    assertfile $objsrc
    epssrc=`echo $objsrc | sed 's/obj$/eps/'`
  fi
  if [ `isnewer $objsrc $epssrc` = "yes" ]; then
    if [ ! "X$objsrc" = "X" ]; then
      assertfile $objsrc
      echo " => generating eps artwork.."
      tgif -print -stdout -eps -color $objsrc > $epssrc
    fi
  fi
  assertfile $epssrc
  mkdir -p "$SYS_PREFIX/build"
  mkdir -p "$SYS_PREFIXROOT/build/$SYS_APPNAME"
  pngsrc="$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork.png"
  tmpfile="$SYS_PREFIXROOT/build/$SYS_APPNAME/tmp.png"
  if [ `isnewer $epssrc $pngsrc` = "yes" ]; then
    echo " => generating master pixmap.."
    veval "gs -r600 -dNOPAUSE -sDEVICE=png16m -dEPSCrop -sOutputFile=$tmpfile $epssrc quit.ps"
    assertfile $tmpfile
    veval "convert $tmpfile -trim -transparent \"#00ff00\" $pngsrc"
    rm $tmpfile
  fi
  assertfile $pngsrc
# the crazy list of artwork sizes:
# 1024: iTunes
# 512:  google play
# 144: 	retina ipad
# 128:  macosx
# 114: 	retina iphone
# 96:  	Retina iPad spotlight, android launcher
# 72:   ipad, android launcher
# 58:	iphone 4 settings
# 57:   iphone
# 48:   iPad Spotlight, android launcher, macosx
# 36:   android launcher
# 32:   macosx
# 29: 	iphone settings
# 16:   macosx
  sizes="1024 512 144 128 114 96 72 58 57 48 36 32 29 16"
  for s in $sizes; do
    tgt="$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-$s.png"
    if [ `isnewer $epssrc $tgt` = "yes" ]; then
      echo " => generating "$s"x"$s" pixmap.."
      convert $pngsrc -resize $s"x"$s $tgt
      assertfile $tgt
    fi
  done
  # create a dummy splash image to get full screen on retina displays
  tgt="$SYS_PREFIXROOT/build/$SYS_APPNAME/retina.png"
  if [ ! -f "$tgt" ]; then
    echo " => generating retina default image.."
    convert -size 640x1136 xc:black $tgt
  fi
  assertfile $tgt
  setstate
}

make_textures()
{
  setstate TEXTURES
  echo "==> creating textures needed for $SYS_APPNAME.."
  srcdir=`locatedir apps/$SYS_APPNAME/textures silent`
  if [ "X" == "X$srcdir" ]; then 
    return 
  fi
  tgtdir=$SYS_PREFIXROOT/build/$SYS_APPNAME/textures
  mkdir -p $tgtdir
  incfile=$tgtdir/textures_include.scm
  images=`ls -1 "$srcdir"/*.png 2> /dev/null`
  dirty="no"
  empty=yes
  for imgfile in $images; do
    empty=no
    if [ `isnewer $imgfile $incfile` = "yes" ]; then
      dirty="yes" 
    fi
  done
  if [ "$dirty" = "yes" ]; then
    echo ";; Automatically generated. Do not edit."  > $incfile
    if [ -d "$srcdir" ]; then
      for imgfile in $images; do
        scmfile=$SYS_PREFIXROOT/build/$SYS_APPNAME/textures/`basename $imgfile | sed 's/png$/scm/'`
        if [ `isnewer $imgfile $scmfile` = "yes" ]; then
          echo " => $imgfile.."
          $SYS_HOSTPREFIX/bin/png2scm $imgfile > $scmfile
        fi
        echo "(include \"$scmfile\")" >> $incfile
      done
    fi
    echo ";; eof" >> $incfile
  fi
  if [ "$empty" = "yes" ]; then
    if [ ! -e $incfile ]; then
      touch $incfile
    fi
  fi
  setstate
}

make_fonts()
{
  setstate FONTS
  echo "==> creating fonts needed for $SYS_APPNAME.."
  tgtdir=$SYS_PREFIXROOT/build/$SYS_APPNAME/fonts
  mkdir -p $tgtdir
  srcfile=`locatefile apps/$SYS_APPNAME/FONTS silent`
  if [ "X$srcfile" = "X" ]; then
    touch $tgtdir/fonts_include.scm
  else
    incfile=$tgtdir/fonts_include.scm
    if [ `isnewer $srcfile $incfile` = "yes" ]; then
      echo ";; Automatically generated. Do not edit."  > $incfile
      while read line; do
        fline=`echo "$line" | sed '/^#/d'`
        if [ "$fline" ]; then 
          fontname=`echo "$fline" | cut -f 1 -d " "`
          font=`locatefile fonts/$fontname`
          assertfile $font 
          bits=`echo "$fline" | cut -f 2 -d " "`
          sizes=`echo "$fline" | cut -f 3 -d " "`
          name=`echo "$fline" | cut -f 4 -d " "`
          scmfile=$tgtdir/${name}.scm
          if [ `isnewer $srcfile $scmfile` = "yes" ]; then
             echo " => $name.."
             $SYS_HOSTPREFIX/bin/ttffnt2scm $font $bits $sizes $name > $scmfile
          fi
          echo "(include \"$scmfile\")" >> $incfile
        fi
      done < $srcfile
      echo ";; eof" >> $incfile
    fi
  fi
  setstate
}

make_string_aux()
{
  oldpath=`pwd`
  newpath=`mktemp -d tmp.XXXXXX`
  cd $newpath
  srcfont=$1
  fontname=`$SYS_HOSTPREFIX/bin/ttfname $srcfont`
  tgtfont="$fontname".ttf
  cp $srcfont $tgtfont
  fontpath=`pwd`"/"
  size=$2
  string="$3"
  name=$4
  opt="$5"
cat > tmp.tex << __EOF
\documentclass{article}
\makeatletter 
\renewcommand{\Large}{\@setfontsize\Large{$size}{$size}} 
\makeatother 
\usepackage{fontspec}
\usepackage{xunicode}
%\fontspec [ Path = $fontpath ]{$fontname}
\setmainfont[$opt]{"[$fontname.ttf]"}
\usepackage[margin=0.1in, paperwidth=40in, paperheight=2in]{geometry}
\begin{document}
\thispagestyle{empty}
\noindent \Large
$string
\end{document}
__EOF
  xelatex tmp.tex > /dev/null 2> /dev/null
  assertfile tmp.pdf
  if [ "X"`which pdftops 2> /dev/null` = "X" ]; then
    pdf2ps tmp.pdf > /dev/null 2> /dev/null
  else
    pdftops tmp.pdf > /dev/null 2> /dev/null
  fi
  assertfile tmp.ps
  ps2eps -B -C tmp.ps > /dev/null 2> /dev/null
  assertfile tmp.eps
  gs -r300 -dNOPAUSE -sDEVICE=pnggray -dEPSCrop -sOutputFile=$name.png tmp.eps quit.ps > /dev/null 2> /dev/null
  assertfile $name.png
  convert $name.png  -bordercolor White -border 5x5 -negate -scale 25% $name.png > /dev/null 2> /dev/null
  $SYS_HOSTPREFIX/bin/png2scm $name.png
  cd $oldpath
  rm -rf $newpath
}

make_strings()
{
  setstate STRINGS
  echo "==> creating strings needed for $SYS_APPNAME.."
  tgtdir=$SYS_PREFIXROOT/build/$SYS_APPNAME/strings
  mkdir -p $tgtdir
  incfile=$tgtdir/strings_include.scm
  srcfile=`locatefile apps/$SYS_APPNAME/STRINGS silent`
  if [ "X$srcfile" = "X" ]; then
    touch $incfile
  else
    assertfile $srcfile
    if [ `isnewer $srcfile $incfile` = "yes" ]; then
      cat $srcfile | sed '/^#/d' > $tgtdir/STRINGS
      echo ";; Automatically generated. Do not edit."  > $incfile
      while read -r fline; do
#        fline=`echo "$line" | sed '/^#/d'`
        if [ "$fline" ]; then 
          fontname=`eval "getparam 1 $fline"`
          font=`locatefile fonts/$fontname`
          assertfile $font
          size=`eval "getparam 2 $fline"`
          label=`eval "getparam 3 $fline" | sed 's:_/:@TMP@:g;s:/:\\\\:g;s:@TMP@:/:g'`
          name=`eval "getparam 4 $fline"`
          opt=`eval "getparam 5 $fline"`
          scmfile=$tgtdir/${name}.scm
          if [ `isnewer $srcfile $scmfile` = "yes" ]; then
             echo " => $name.."
#           echo "$SYS_HOSTPREFIX/bin/ttfstr2scm $font $size \"$label\" $name > $scmfile"
#             $SYS_HOSTPREFIX/bin/ttfstr2scm $font $size "$label" $name > $scmfile
             make_string_aux $font $size "$label" $name $opt > $scmfile
          fi
          echo "(include \"$scmfile\")" >> $incfile
        fi
      done < $tgtdir/STRINGS
      echo ";; eof" >> $incfile
    fi 
  fi
  setstate
}

###################################
# platform specific stuff

make_setup()
{
  profile=`locatefile PROFILE`
  assertfile "$profile"
  . "$profile"
  versionfile=`locatefile apps/$SYS_APPNAME/VERSION`
  assertfile $versionfile
  SYS_APPVERSION=`cat $versionfile`
  SYS_APPVERSIONCODE=`echo $SYS_APPVERSION | sed 's/\.//'`
  echo "=== using profile $SYS_PROFILE [$profile].."
  echo "=== configured to build $SYS_APPNAME version $SYS_APPVERSION for $SYS_PLATFORM on $SYS_HOSTPLATFORM in $SYS_MODE mode"
  if [ "$SYS_MODE" = "release" ]; then
    SYS_IOSCERT=$SYS_IOSRELCERT
  else
    SYS_IOSCERT=$SYS_IOSDEVCERT
  fi
  SYS_PREFIXROOT=`pwd`"-cache"
  SYS_PREFIX="$SYS_PREFIXROOT/$SYS_PLATFORM"
  SYS_HOSTPREFIX="$SYS_PREFIXROOT/$SYS_HOSTPLATFORM"
  SYS_GSC=$SYS_HOSTPREFIX/bin/gsc
  SYS_DEBUGFLAG=
  if [ "X$SYS_MODE" = "Xdebug" ]; then
    SYS_DEBUGFLAG="-g"
  fi
  mkdir -p $SYS_PREFIX/bin
  mkdir -p $SYS_PREFIX/lib
  mkdir -p $SYS_PREFIX/include
  mkdir -p $SYS_PREFIX/build
  mkdir -p $SYS_HOSTPREFIX/bin
  mkdir -p $SYS_HOSTPREFIX/lib
  mkdir -p $SYS_HOSTPREFIX/include
  mkdir -p $SYS_PREFIXROOT/packages
  mkdir -p $SYS_PREFIXROOT/build
  buildsys=$SYS_PLATFORM"_"$SYS_HOSTPLATFORM
  case "$buildsys" in
    win32_macosx|win32_linux)
      SDKROOT=$WIN32SDK/i?86*-mingw32
      CROSS=$WIN32SDK/bin/i?86*-mingw32-
      SYS_CC=$CROSS"gcc $SYS_DEBUGFLAG -isysroot $SDKROOT -DWIN32"
      SYS_AR=$CROSS"ar"
      SYS_RANLIB=$CROSS"ranlib"
      SYS_STRIP=$CROSS"strip"
      SYS_WINDRES=$CROSS"windres"
      SYS_EXEFIX=".exe"
      SYS_APPFIX=
    ;;
    linux_macosx)
      SDKROOT=$LINUXSDK/i?86-linux
      CROSS=$LINUXSDK/bin/i?86-linux-
      ## fixme: should be no need to include /usr/local/linux/i686-linux/include
      SYS_CC=$CROSS"gcc $SYS_DEBUGFLAG -isysroot $SDKROOT -DLINUX -I/usr/local/linux/i686-linux/include"
      SYS_AR=$CROSS"ar"
      SYS_RANLIB=$CROSS"ranlib"
      SYS_STRIP=$CROSS"strip"
      SYS_WINDRES=
      SYS_EXEFIX=
      SYS_APPFIX=
    ;;
    linux_linux)
      SYS_CC="gcc $SYS_DEBUGFLAG -m32 -DLINUX"
      SYS_AR=ar
      SYS_RANLIB=ranlib
      SYS_STRIP=strip
      SYS_WINDRES=
      SYS_EXEFIX=
      SYS_APPFIX=
    ;;
    openbsd_openbsd)
      SYS_CC="gcc $SYS_DEBUGFLAG -DOPENBSD -I/usr/X11R6/include"
      SYS_AR=ar
      SYS_RANLIB=ranlib
      SYS_STRIP=strip
      SYS_WINDRES=
      SYS_EXEFIX=
      SYS_APPFIX=
    ;;
    macosx_macosx)
      SYS_CC=gcc
      SYS_CC="$SYS_CC $SYS_DEBUGFLAG -m32 -DMACOSX"
      SYS_AR=ar
      SYS_RANLIB=ranlib
      SYS_STRIP=strip
      SYS_WINDRES=
      SYS_EXEFIX=
      SYS_APPFIX=.app
    ;;
    ios_macosx)
      SYS_IOSSDK=`basename $IOSSDK`
      SYS_IOSVERSION=$IOSVERSION
      CROSS=$IOSROOT/usr/bin
      SYS_CC=`ls -1 $CROSS/arm-apple-darwin*-gcc-* | sort -r | sed '/llvm/d' | head -n 1`
      if [ "X$SYS_CC" = "X" ]; then
        SYS_CC=`ls -1 $CROSS/arm-apple-darwin*-gcc-* | sort -r | head -n 1`
      fi
      if [ "X$SYS_CC" = "X" ]; then
        SYS_CC=`ls -1 $CROSS/arm-apple-darwin*-llvm-* | sort -r | head -n 1`
      fi
      assertfile $SYS_CC
      SYS_CC="$SYS_CC $SYS_DEBUGFLAG -isysroot $IOSSDK -DIOS -DIPHONE -miphoneos-version-min=$SYS_IOSVERSION"
      SYS_CC="$SYS_CC -fPIC -fsigned-char -fomit-frame-pointer -fforce-addr"
      SYS_AR="$CROSS/ar"
      SYS_RANLIB="$CROSS/ranlib"
      SYS_STRIP="$CROSS/strip"
      SYS_WINDRES=
      SYS_EXEFIX=
      SYS_APPFIX=".app"
   ;;
   android_macosx|android_linux)
#     TOOLCHAIN=`echo $ANDROIDNDK/toolchains/arm-*/prebuilt/*-x86`
     TOOLCHAIN=`wildcard_dir $ANDROIDNDK/toolchains/arm-*/prebuilt/*-x86 2> /dev/null`
     if [ "X$TOOLCHAIN" = "X" ]; then
       TOOLCHAIN=`wildcard_dir $ANDROIDNDK/toolchains/arm-*/prebuilt/*-x86_64 2> /dev/null`
     fi 
     assertfile "$TOOLCHAIN"
#     SYSROOT=`wildcard_dir $ANDROIDNDK/platforms/android-*/arch-arm`
     SYSROOT=`echo $ANDROIDNDK/platforms/android-9/arch-arm`
     assertfile "$SYSROOT"
     CROSS="$TOOLCHAIN/bin/arm-linux-androideabi-"
     # the linker gunk is just to fool gambit's configure into thinking the gcc can make binaries
     SYS_CC=$CROSS"gcc $SYS_DEBUGFLAG -DANDROID -isysroot $SYSROOT -fno-short-enums -nostdlib -I$SYSROOT/usr/include -L$SYSROOT/usr/lib -lstdc++ -lc -ldl -lgcc"
     SYS_AR=$CROSS"ar"
     SYS_RANLIB=$CROSS"ranlib"
     SYS_STRIP=$CROSS"strip"
     SYS_WINDRES=
     SYS_EXEFIX=
     SYS_APPFIX=
   ;;
  esac
  SYS_LOCASEAPPNAME=`echo $SYS_APPNAME | tr A-Z a-z`
  SYS_ANDROIDAPI=$ANDROIDAPI 
  # Add git path for overlay, additional paths, and the lambdanative path
  here=`pwd`
  SYS_BUILDHASH=
  for p in $(echo "$SYS_PATH" | tr ":" "\n"); do
    cd $p
    if [ -d "$p/.git" ]; then
      SYS_BUILDHASH="$SYS_BUILDHASH"`basename $p`": "`git log --pretty=format:"%h" -1`","
    fi
    cd $here
  done
  SYS_BUILDHASH=`echo "$SYS_BUILDHASH" | sed 's/,$//'`
  echo $SYS_BUILDHASH
  SYS_BUILDEPOCH=`date +"%s"`
  # Adding BUILD info requires rebuilding of config module
  touch modules/config/config.scm
  ac_subst SYS_ORGTLD
  ac_subst SYS_ORGSLD
  ac_subst SYS_APPNAME
  ac_subst SYS_LOCASEAPPNAME
  ac_subst SYS_IOSCERT
  ac_subst SYS_IOSVERSION
  ac_subst SYS_IOSSDK
  ac_subst SYS_PLATFORM
  ac_subst SYS_HOSTPLATFORM
  ac_subst SYS_PREFIX
  ac_subst SYS_PREFIXROOT
  ac_subst SYS_HOSTPREFIX
  ac_subst SYS_GSC
  ac_subst SYS_CC
  ac_subst SYS_AR
  ac_subst SYS_RANLIB
  ac_subst SYS_STRIP
  ac_subst SYS_WINDRES
  ac_subst SYS_EXEFIX
  ac_subst SYS_APPFIX
  ac_subst SYS_APPVERSION
  ac_subst SYS_APPVERSIONCODE
  ac_subst SYS_ANDROIDAPI
  ac_subst SYS_BUILDHASH
  ac_subst SYS_BUILDEPOCH
  ac_output CONFIG.h $SYS_PREFIX/include/CONFIG.h
}

make_bootstrap()
{ 
  setstate BOOTSTRAP
  locaseappname=`echo $SYS_APPNAME | tr A-Z a-z`
  here=`pwd`
  echo "==> creating $SYS_PLATFORM bootstrap needed for $SYS_APPNAME.."
  case $SYS_PLATFORM in
################################
ios)
  tgtdir="$SYS_PREFIX/$SYS_APPNAME$SYS_APPFIX"
  srcdir=`pwd`"/bootstraps/ios"
  cmakedir=`mktemp -d tmp.XXXXXX`
  cmakedir=`pwd`"/$cmakedir"
  cd $here
  ac_output $srcdir/CMakeLists.txt $cmakedir/CMakeLists.txt
  cp $srcdir/*.m $cmakedir
  cp $srcdir/*.mm $cmakedir
  cp $srcdir/*.h $cmakedir
  echo " => preparing icons.."
  cp "$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-57.png" "$cmakedir/Icon.png"
  cp "$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-114.png" "$cmakedir/Icon@2x.png"
  cp "$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-72.png" "$cmakedir/Icon-72.png"
  cp "$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-144.png" "$cmakedir/Icon-72@2x.png"
  # go full screen on retina displays!
  cp "$SYS_PREFIXROOT/build/$SYS_APPNAME/retina.png" "$cmakedir/Default-568h@2x.png"

  snddir=`locatedir apps/$SYS_APPNAME/sounds silent`
  if [ -d "$snddir" ]; then
    echo " => transferring sounds..."
    snds=`ls -1 $snddir/*.wav`
    for snd in $snds; do
#      locasesnd=`basename $snd | tr A-Z a-z`
#     echo " => $locasesnd.."
#     cp $snd $cmakedir/$locasesnd
      vecho " => $snd.."
      cp $snd $cmakedir
    done
 fi

 echo " => preparing plist.."
  configsrc=`locatedir apps/$SYS_APPNAME`"/CONFIG_IOS.in"
  configtgt=$SYS_PREFIXROOT/build/$SYS_APPNAME/CONFIG_IOS
  ac_output $configsrc $configtgt
  assertfile $configtgt
  cat $configtgt | sed '/^#/d' > "$SYS_PREFIXROOT/build/$SYS_APPNAME/Info.plist"
  echo "// automatically generated. Do not edit" > "$cmakedir/config.h"
  cat $configtgt | sed -n '/^#+/p' | cut -f 2- -d "+" >> "$cmakedir/config.h"
  echo " => building bootstrap.."
  xcodedir=`mktemp -d tmp.XXXXXX`
  xcodedir=`pwd`"/$xcodedir"
  cd $here
  cd $xcodedir
  veval "cmake -GXcode $cmakedir"
  asserterror $?
#  xcodebuild -configuration Release | grep -A 2 error
  veval "xcodebuild -configuration Release"
  asserterror $?
  cd $here
  tmpappdir=$xcodedir/Release-iphoneos/$SYS_APPNAME$SYS_APPFIX
  if [ ! -d $tmpappdir ]; then
    tmpappdir=$xcodedir/Release/$SYS_APPNAME$SYS_APPFIX
  fi
  assertfile $tmpappdir
  echo " => verifying application.."
  checkfail=`codesign --verify $tmpappdir 2>&1`
  if [ "$checkfail" ]; then
    echo "ERROR: $SYS_APPNAME build was not successful"
    exit 1
  fi
  echo " => relocating application.."
  rmifexists "$tgtdir"
  cp -R $tmpappdir $tgtdir
  echo " => cleaning up.."
  rm -rf "$cmakedir" "$xcodedir" 2> /dev/null
;;
#####################################
android)
  echo " => creating android project.."
  tmpdir=`mktemp -d tmp.XXXXXX`
  tmpdir=`pwd`"/$tmpdir"
  cd $here
  ANDROIDSDKTARGET=`$ANDROIDSDK/tools/android list targets | grep "^id:" | grep "android-$ANDROIDAPI" | cut -f 2 -d " "`
  if [ "X$ANDROIDSDKTARGET" = "X" ]; then
    echo "ERROR: API $ANDROIDAPI not a target."
    exit
  else
    echo " => using target $ANDROIDSDKTARGET [API $ANDROIDAPI]"
  fi
  $ANDROIDSDK/tools/android --silent create project \
    --target $ANDROIDSDKTARGET --name $SYS_APPNAME --path $tmpdir \
    --activity $SYS_APPNAME --package $SYS_ORGTLD.$SYS_ORGSLD.$SYS_LOCASEAPPNAME
  echo " => preparing icons.."
  mkdir -p $tmpdir/res/drawable
  cp $SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-72.png $tmpdir/res/drawable/icon.png
  snddir=`locatedir apps/$SYS_APPNAME/sounds silent`
  if [ -d "$snddir" ]; then
    echo " => transferring sounds..."
    snds=`ls -1 $snddir/*.wav`
    mkdir -p $tmpdir/res/raw
    for snd in $snds; do
      locasesnd=`basename $snd | tr A-Z a-z`
      vecho " => $locasesnd.."
      cp $snd $tmpdir/res/raw/$locasesnd
    done
  fi
  echo " => transferring java hook.."
  hookfile=$tmpdir/src/$SYS_ORGTLD/$SYS_ORGSLD/$SYS_LOCASEAPPNAME/$SYS_APPNAME.java
  ac_output bootstraps/android/bootstrap.java $hookfile
  # Helper for adding module specific Java code to app
  ac_java_sedsub=
  ac_java_subst(){
    newcmd="echo \"s|@${1}@|\$${1}@${1}@|g;\""
    newsub=`eval $newcmd`
    ac_java_sedsub="${ac_java_sedsub}${newsub}"
  }

  for m in $modules; do
    javaincfile=`locatefile modules/$m/ANDROID.java.in silent`
    if [ -f "$javaincfile" ]; then
      . $javaincfile
      ac_java_sedsub=
      ac_java_subst ANDROID_IMPORTS
      ac_java_subst ANDROID_IMPLEMENTS
      ac_java_subst ANDROID_VARIABLES
      ac_java_subst ANDROID_ONCREATE
      ac_java_subst ANDROID_ONPAUSE
      ac_java_subst ANDROID_ONRESUME
      ac_java_subst ANDROID_ONSENSORCHANGED
      ac_java_subst ANDROID_ACTIVITYADDITIONS
      tmphookfile=$hookfile.tmp
      sed -e "$ac_java_sedsub" $hookfile > $tmphookfile
      mv $tmphookfile $hookfile
      ANDROID_IMPLEMENTS=
    fi
  done
  tmphookfile=$hookfile.tmp
  sed -e 's/@ANDROID_[A-Z]*@//' $hookfile > $tmphookfile
  mv $tmphookfile $hookfile
  echo " => preparing manifest.."
  configsrc=`locatedir apps/$SYS_APPNAME`"/CONFIG_ANDROID.in"
  assertfile $configsrc
  configtgt=$SYS_PREFIXROOT/build/$SYS_APPNAME/CONFIG_ANDROID
  ac_output $configsrc $configtgt
  assertfile $configtgt
  cat $configtgt | sed '/^#/d' > "$tmpdir/AndroidManifest.xml"
  oldtail=`tail -n 1 "$tmpdir/AndroidManifest.xml"`
  head -n $(( `wc -l < "$tmpdir/AndroidManifest.xml"` - 1)) "$tmpdir/AndroidManifest.xml" > "$tmpdir/AndroidManifest.xml2"
  mv "$tmpdir/AndroidManifest.xml2" "$tmpdir/AndroidManifest.xml"
  for m in $modules; do
    javaincfile=`locatefile modules/$m/ANDROID.java.in silent`
    if [ -f "$javaincfile" ]; then
      . $javaincfile
      echo "$ANDROID_PERMISSIONS" >> "$tmpdir/AndroidManifest.xml"
    fi
  done
  echo $oldtail >> "$tmpdir/AndroidManifest.xml"
  echo " => creating payload module.."
  cd $here
  tmpmoddir=`mktemp -d tmp.XXXXXX`
  tmpmoddir=`pwd`"/$tmpmoddir"
  mkdir $tmpmoddir/libpayload
  cp bootstraps/android/Android.mk.module $tmpmoddir/libpayload/Android.mk
  cp $SYS_PREFIX/lib/libpayload.a $tmpmoddir/libpayload
  echo " => preparing JNI.."
  mkdir $tmpdir/jni
  # opensl was introduced at api 10
  if [ `echo "$ANDROIDAPI > 9" | bc` = 1 ]; then
    cp bootstraps/android/Android.mk.jni $tmpdir/jni/Android.mk
  else
    cat bootstraps/android/Android.mk.jni | sed 's/-lOpenSLES//' > $tmpdir/jni/Android.mk
  fi
  cp $SYS_PREFIX/include/CONFIG.h $tmpdir/jni
  cat $configtgt | sed -n '/^#+/p' | cut -f 2- -d "+" > "$tmpdir/jni/config.h"
  ac_output bootstraps/android/bootstrap.c $tmpdir/jni/bootstrap.c
  # Add module specific C code to end of file
  for m in $modules; do
    jnifile=`locatefile modules/$m/ANDROID.c.in silent`
    if [ -f "$jnifile" ]; then
      cat $jnifile >> $tmpdir/jni/bootstrap.c
      tmpbootstrap=bootstrap.tmp 
      sed -e "$ac_sedsub" $tmpdir/jni/bootstrap.c > $tmpbootstrap
      mv $tmpbootstrap $tmpdir/jni/bootstrap.c
    fi
  done
  cd $tmpdir
  if [ $SYS_MODE = "debug" ]; then
    echo " => compiling payload module with debug options.."
    veval "NDK_MODULE_PATH=$tmpmoddir $ANDROIDNDK/ndk-build NDK_LOG=1 NDK_DEBUG=1"
  else
   echo " => compiling payload module.."
   veval "NDK_MODULE_PATH=$tmpmoddir $ANDROIDNDK/ndk-build --silent"
  fi
  asserterror $?
  echo " => adding precompiled libaries.."
  for lib in $libs; do
    if [ -f "$SYS_PREFIXROOT/android/lib/$lib.jar" ]; then
      cp $SYS_PREFIXROOT/android/lib/$lib.jar $tmpdir/libs/
    fi
  done
  echo " => compiling application.."
  veval "ant -quiet release"
  asserterror $?
  cd $here
  pkgfile="$tmpdir/bin/$(echo $SYS_APPNAME)-release-unsigned.apk"
  assertfile "$pkgfile"
  echo " => transferring application.."
  fnlfile=$SYS_PREFIXROOT/packages/$(echo $SYS_APPNAME)-$(echo $SYS_APPVERSION)-android.apk
  cp $pkgfile $fnlfile
  assertfile $fnlfile
  keystore=`locatefile PROFILE | sed 's/PROFILE$/android\.keystore/'`
  if [ ! -e $keystore ]; then
    echo " => generating keystore [$keystore].."
    keytool -genkey -v -keystore $keystore -dname "CN=$SYS_ORGTLD.$SYS_ORGSLD" -alias "$SYS_ORGTLD.$SYS_ORGSLD" -keyalg RSA -keysize 2048 -validity 10000 -storepass "$SYS_ANDROIDPW" -keypass "$SYS_ANDROIDPW"
    asserterror $?
  fi
  echo " => signing application with keystore $keystore"
  jarsigner -sigalg MD5withRSA -digestalg SHA1 -keystore $keystore -keypass "$SYS_ANDROIDPW" -storepass "$SYS_ANDROIDPW" $fnlfile $SYS_ORGTLD.$SYS_ORGSLD
  asserterror $?
  echo " => zipaligning.."
  assertfile $fnlfile
  mv $fnlfile tmp.apk
  $ANDROIDSDK/tools/zipalign -f 4 tmp.apk $fnlfile
  asserterror $?
  rmifexists tmp.apk
  echo " => cleaning up.."
  rm -rf $tmpmoddir
  if [ $SYS_MODE = "debug" ]; then
    echo "DEBUG: android build is in $tmpdir"
  else
    rm -rf $tmpdir
  fi
;;
#####################################
macosx)
  appdir="$SYS_PREFIX/$SYS_APPNAME.app"
  rmifexists "$appdir"
  mkdir "$appdir"
  if [ `is_gui_app` = "yes" ]; then
    tiffs=
    dirty=no
    sizes="128 48 32 16"
    for size in $sizes; do
      srcimg=$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-$size.png
      tgtimg=$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-$size.tif
      assertfile $srcimg
      if [ `isnewer $srcimg $tgtimg` = "yes" ]; then
        echo " => generating $tgtimg.."
        convert $srcimg $tgtimg
        dirty=yes
      fi
      tiffs="$tiffs $tgtimg"
    done
    if [ $dirty = "yes" ]; then
      echo " => generating icns icon.."
      tiffutil -catnosizecheck $tiffs -out tmp.tif 2> /dev/null
      assertfile tmp.tif
      tiff2icns tmp.tif $appdir/Icon.icns
      rm tmp.tif
    fi
    echo " => preparing plist.."
    cp bootstraps/macosx/Info.plist $appdir
  fi
  sounddir=`locatedir apps/$SYS_APPNAME/sounds silent`
  if [ -d "$sounddir" ]; then
    echo " => transferring sounds..."
    snds=`ls -1 $sounddir/*.wav`
    mkdir -p $appdir/sounds
    for snd in $snds; do
       vecho " => $snd.."
       cp $snd $appdir/sounds
    done
  fi
  tmpdir=`mktemp -d tmp.XXXXXX`
  echo " => compiling application.."
  if [ `is_standalone_app` = "yes" ]; then
    cd "$tmpdir"
    veval "$SYS_CC -framework ApplicationServices -framework CoreAudio -framework AudioUnit -framework AudioToolbox -framework CoreFoundation -framework CoreServices -framework Foundation -I$SYS_PREFIX/include -L$SYS_PREFIX/lib -DUSECONSOLE -o $appdir/$SYS_APPNAME $SYS_LDFLAGS -lpayload"
  else
    if [ `is_gui_app` = "yes" ]; then
      cp bootstraps/macosx/*.[mh] $tmpdir
      cd "$tmpdir"
      veval "$SYS_CC -framework OpenGL -framework Cocoa -framework ApplicationServices -framework CoreAudio -framework AudioUnit -framework AudioToolbox -framework CoreFoundation -framework CoreServices -framework Foundation -x objective-c -I$SYS_PREFIX/include -L$SYS_PREFIX/lib -o $appdir/$SYS_APPNAME $SYS_LDFLAGS -lpayload main.m SimpleOpenGLView.m"
    else
      cp bootstraps/common/main.c $tmpdir
      cd "$tmpdir"
      veval "$SYS_CC -framework ApplicationServices -framework CoreAudio -framework AudioUnit -framework AudioToolbox -framework CoreFoundation -framework CoreServices -framework Foundation -I$SYS_PREFIX/include -L$SYS_PREFIX/lib -DUSECONSOLE -o $appdir/$SYS_APPNAME $SYS_LDFLAGS -lpayload main.c"
    fi
  fi
  cd $here
  assertfile $appdir/$SYS_APPNAME
  rm -rf "$tmpdir"
;;
#####################################
win32)
  appdir="$SYS_PREFIX/$SYS_APPNAME"
  rmifexists "$appdir"
  mkdir "$appdir"
  tmpdir=`mktemp -d tmp.XXXXXX`
  if [ `is_gui_app` = yes ]; then
    cp bootstraps/win32/win32_microgl.c $tmpdir
  fi
  if [ `is_standalone_app` = "no" ]; then
    cp bootstraps/common/main.c $tmpdir
  fi
  cd $tmpdir
  sounddir=`locatedir apps/$SYS_APPNAME/sounds silent`
  if [ -d "$sounddir" ]; then
    echo " => transferring sounds..."
    mkdir -p $appdir/sounds
    snds=`ls -1 $sounddir/*.wav`
    for snd in $snds; do
       vecho " => $snd.."
       cp $snd $appdir/sounds
    done
  fi
  if [ `is_gui_app` = yes ]; then
    srcimg=$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-32.png
    tgtimg=$SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-32.ico
    assertfile $srcimg
    if [ ! -e $tgtimg ]; then
      echo " => preparing icon.."
      pngtopnm $srcimg | pnmquant 256 > icon.ppm
      asserterror $?
      assertfile icon.ppm
      pngtopnm -alpha $srcimg > icon.pgm
      asserterror $?
      assertfile icon.pgm
      ppmtowinicon -andpgms -output $tgtimg icon.ppm icon.pgm
      asserterror $?
    fi
    assertfile $tgtimg
    cp $tgtimg icon.ico
    echo "AppIcon ICON \"icon.ico\"" > icon.rc
    $SYS_WINDRES -O coff -i icon.rc -o icon.o
    asserterror $?
    assertfile icon.o
  fi
  echo " => compiling application.."
  tgt=$appdir/$SYS_APPNAME$SYS_EXEFIX
  if [ `is_standalone_app` = "yes" ]; then
    veval "$SYS_CC -I$SYS_PREFIX/include \
      -DUSECONSOLE -o $tgt \
      -L$SYS_PREFIX/lib -lpayload -lgdi32 -lwinmm -lwsock32 -lws2_32 -lm"
  else
    if [ `is_gui_app` = yes ]; then
      veval "$SYS_CC -I$SYS_PREFIX/include \
        -mwindows win32_microgl.c main.c icon.o -o $tgt \
        -L$SYS_PREFIX/lib -lpayload -lglu32 -lopengl32 -lgdi32 -lwinmm -lwsock32 -lws2_32 -lm"
    else
      veval "$SYS_CC -I$SYS_PREFIX/include \
        -DUSECONSOLE main.c -o $tgt \
        -L$SYS_PREFIX/lib -lpayload -lgdi32 -lwinmm -lwsock32 -lws2_32 -lm"
    fi
  fi
  asserterror $?
  assertfile $tgt
  $SYS_STRIP $tgt
  asserterror $?
  cd $here
  echo " => cleaning up.."
  rm -rf "$tmpdir"
;;
#####################################
linux)
  appdir="$SYS_PREFIX/$SYS_APPNAME"
  rmifexists "$appdir"
  mkdir "$appdir"
  tmpdir=`mktemp -d tmp.XXXXXX`
  if [ `is_gui_app` = yes ]; then
    cp bootstraps/x11/x11_microgl.c $tmpdir 
  fi
  if [ `is_standalone_app` = "no" ]; then
    cp bootstraps/common/main.c $tmpdir
  fi
  cd $tmpdir
  sounddir=`locatedir apps/$SYS_APPNAME/sounds silent`
  if [ -d "$sounddir" ]; then
    echo " => transferring sounds..."
    snds=`ls -1 $sounddir/*.wav`
    mkdir -p $appdir/sounds
    for snd in $snds; do
       vecho " => $snd.."
       cp $snd $appdir/sounds
    done
  fi
  echo " => compiling application.."
  tgt=$appdir/$SYS_APPNAME$SYS_EXEFIX
  if [ `is_standalone_app` = "yes" ]; then
      veval "$SYS_CC -I$SYS_PREFIX/include \
        -DUSECONSOLE -o $tgt \
        -L/usr/local/linux/i686-linux/lib \
        -L$SYS_PREFIX/lib -lpayload -lrt -lutil -lpthread -ldl -lm"
  else
    if [ `is_gui_app` = yes ]; then
      veval "$SYS_CC -I$SYS_PREFIX/include \
        x11_microgl.c main.c -o $tgt \
        -L/usr/local/linux/i686-linux/lib \
        -L$SYS_PREFIX/lib -lpayload -lGL -lXext -lX11 -lasound -lrt -lutil -lpthread -ldl -lm"
    else
      veval "$SYS_CC -I$SYS_PREFIX/include \
        -DUSECONSOLE main.c -o $tgt \
        -L/usr/local/linux/i686-linux/lib \
        -L$SYS_PREFIX/lib -lpayload -lrt -lasound -lutil -lpthread -ldl -lm"
    fi
  fi
  asserterror $?
  assertfile $tgt
  $SYS_STRIP $tgt
  asserterror $?
  cd $here
  echo " => cleaning up.."
  rm -rf "$tmpdir"
;;
#####################################
openbsd)
  appdir="$SYS_PREFIX/$SYS_APPNAME"
  rmifexists "$appdir"
  mkdir "$appdir"
  tmpdir=`mktemp -d tmp.XXXXXX`
  if [ `is_gui_app` = yes ]; then
    cp bootstraps/x11/x11_microgl.c $tmpdir 
  fi
  if [ `is_standalone_app` = "no" ]; then
    cp bootstraps/common/main.c $tmpdir
  fi
  cd $tmpdir
  sounddir=`locatedir apps/$SYS_APPNAME/sounds silent`
  if [ -d "$sounddir" ]; then
    echo " => transferring sounds..."
    snds=`ls -1 $sounddir/*.wav`
    mkdir -p $appdir/sounds
    for snd in $snds; do
       vecho " => $snd.."
       cp $snd $appdir/sounds
    done
  fi
  echo " => compiling application.."
  tgt=$appdir/$SYS_APPNAME$SYS_EXEFIX
  if [ `is_standalone_app` = "yes" ]; then
      veval "$SYS_CC -I$SYS_PREFIX/include \
        -DUSECONSOLE -o $tgt \
        -L$SYS_PREFIX/lib -lpayload -lsndio -lutil -lpthread -lm"
  else
    if [ `is_gui_app` = yes ]; then
      veval "$SYS_CC -I$SYS_PREFIX/include \
        x11_microgl.c main.c -o $tgt \
        -L/usr/X11R6/lib \
        -L$SYS_PREFIX/lib -lpayload -lGL -lXext -lX11 -lsndio -lutil -lpthread -lm"
    else
      veval "$SYS_CC -I$SYS_PREFIX/include \
        -DUSECONSOLE main.c -o $tgt \
        -L$SYS_PREFIX/lib -lpayload -lsndio -lutil -lpthread -lm"
    fi
  fi
  asserterror $?
  assertfile $tgt
  $SYS_STRIP $tgt
  asserterror $?
  cd $here
  echo " => cleaning up.."
  rm -rf "$tmpdir"
;;
#####################################
*)
  echo "ERROR: Don't know how to make the bootstrap!"
  exit 1
esac
  echo "=== $SYS_PREFIX/$SYS_APPNAME$SYS_APPFIX" 
  setstate
}

###################################
# high level make functions

make_payload()
{
  setstate PAYLOAD
  name=$SYS_APPNAME
  here=`pwd`
  appdir=`locatedir apps/$name`
  modules=
  if [ -f "$appdir/MODULES" ]; then
    modules=`cat $appdir/MODULES`
  fi
  plugins=
  if [ -f "$appdir/PLUGINS" ]; then
    plugins=`cat $appdir/PLUGINS`
  fi
  libraries=
  if [ -f "$appdir/LIBRARIES" ]; then
    libraries=`cat $appdir/LIBRARIES`
  fi
  fonts=$SYS_PREFIXROOT/build/$SYS_APPNAME/fonts/fonts_include.scm
  if [ ! -f "$fonts" ]; then
    fonts=
  fi
  textures=$SYS_PREFIXROOT/build/$SYS_APPNAME/textures/textures_include.scm
  if [ ! -f "$textures" ]; then
    textures=
  fi
  strings=$SYS_PREFIXROOT/build/$SYS_APPNAME/strings/strings_include.scm
  if [ ! -f "$strings" ]; then
    strings=
  fi
  srcs=
  for m in $modules; do
    modsrc=`locatefile modules/$m/$m.scm`
    srcs="$srcs $modsrc"
  done
  for p in $plugins; do
    plugsrc=`locatefile plugins/$p/$p.scm`
    srcs="$srcs $plugsrc"
  done
  # note: textures, fonts and strings can't go before glcore!
  srcs="$srcs $textures $fonts $strings $appdir/main.scm"
  libs=
  for l in $libraries; do
    libname=`echo "$l!" | cut -f 1 -d "!"`
    excludes=`echo "$l!" | cut -f 2- -d "!"`
    excluded=`echo "$excludes" | grep $SYS_PLATFORM`
    if [ "X$excluded" = "X" ]; then
      libs="$libs $libname"
    fi
  done
  compile_payload $name "$srcs" "$libs"
  setstate
}

make_clean()
{
  echo "==> cleaning up build files.."
  rmifexists $SYS_PREFIX/lib/libpayload.a
# these files are platform independent
#  rmifexists $SYS_PREFIXROOT/build
  rmifexists $SYS_PREFIX/build
}

make_scrub()
{
  echo "==> removing entire build cache.."
  platforms="ios macosx android win32 linux openbsd"
  for platform in $platforms; do
    rmifexists $SYS_PREFIXROOT/$platform
  done
}

make_install()
{
  case $SYS_PLATFORM in
  ios)
    echo "==> attempting to install $SYS_PLATFORM application $SYS_APPNAME.."
    havefruit="X"`which fruitstrap`
    if [ ! $havefruit = "X" ]; then 
      fruitstrap -b $SYS_PREFIX/$SYS_APPNAME$SYS_APPFIX
    else
      echo "Fruitstrap not found, must install manually"
    fi
  ;;
  android)
    echo "==> attempting to install android application $SYS_APPNAME.."
    adb=`$ANDROIDSDK/platform-tools/adb devices | sed -n '/device\$/p'`
    if [ ! "X$adb" = "X" ]; then
      pkgfile="$SYS_PREFIXROOT/packages/$(echo $SYS_APPNAME)-$(echo $SYS_APPVERSION)-android.apk"
      assertfile $pkgfile
      echo "==> Found device, installing android application $SYS_APPNAME.."
      $ANDROIDSDK/platform-tools/adb install -r $pkgfile
      echo "==> Starting application.."
      $ANDROIDSDK/platform-tools/adb shell am start -n $SYS_ORGTLD.$SYS_ORGSLD.$SYS_LOCASEAPPNAME/.$SYS_APPNAME
    fi
  ;;
  default)
    echo "==> no install setup for this platform ($SYS_PLATFORM)"
  ;;
  esac
}

make_executable()
{
  if [ ! "$SYS_MODULES" ]; then
    make_bootstrap
  else
    echo "==> making standalone executable for $SYS_APPNAME.."
    veval "$SYS_CC $SYS_CPPFLAGS $SYS_CFLAGS -o $SYS_PREFIX/bin/$SYS_APPNAME$SYS_EXEFIX $SYS_PREFIX/lib/libpayload.a"
    assertfile $SYS_PREFIX/bin/$SYS_APPNAME$SYS_EXEFIX
  fi
}

make_package()
{
  here=`pwd`
  echo "==> making package.."
  case $SYS_PLATFORM in
  win32|linux|openbsd|macosx)
    pkgfile="$SYS_PREFIXROOT/packages/$(echo $SYS_APPNAME)-$(echo $SYS_APPVERSION)-$(echo $SYS_PLATFORM).zip"
    rmifexists $pkgfile
    echo " => making generic zip archive $pkgfile.."
    cd $SYS_PREFIX
    veval "zip -9 -y -r $pkgfile $SYS_APPNAME$SYS_APPFIX"
    cd $here
    assertfile $pkgfile
    echo "=== $pkgfile"
  ;;
  ios)
#  an ipa is not needed anymore? 
#    echo " => making iphone ipa archive.."
#    tmpdir=`mktemp -d tmp.XXXXXX`
#    mkdir $tmpdir/Payload
#    cp -R $SYS_PREFIX/$SYS_APPNAME.app $tmpdir/Payload
#    cp $SYS_PREFIXROOT/build/$SYS_APPNAME/artwork-1024.png $tmpdir/iTunesArtwork 
#    cd $tmpdir
#    mkdir -p "$SYS_PREFIXROOT/packages"
#    pkgfile=$SYS_PREFIXROOT/packages/$SYS_APPNAME-$SYS_APPVERSION-iphone.ipa
#    if [ -f $pkgfile ]; then
#      rm $pkgfile
#    fi
#    /usr/bin/zip -9 -y -r $pkgfile Payload iTunesArtwork
#    cd $here
#    assertfile $pkgfile
#    rm -rf $tmpdir
    echo " => making $SYS_PLATFORM zip archive.."
    pkgfile=$SYS_PREFIXROOT/packages/$SYS_APPNAME-$SYS_APPVERSION-$SYS_PLATFORM.zip
    if [ -f $pkgfile ]; then
      rm $pkgfile
    fi
    cd $SYS_PREFIX
    veval "zip -q -y -r $pkgfile ${SYS_APPNAME}.app"
    cd $here
    assertfile $pkgfile
    echo "=== $pkgfile"
  ;;
  android)
    pkgfile="$SYS_PREFIXROOT/packages/$(echo $SYS_APPNAME)-$(echo $SYS_APPVERSION)-$(echo $SYS_PLATFORM).apk"
    assertfile $pkgfile
    echo "=== $pkgfile"
  ;;
  *)
    echo "=== no packaging setup for this platform ($SYS_PLATFORM)"
  ;;
  esac
}

make_libraries()
{
  echo "==> creating libraries needed for $SYS_APPNAME.."
  libfile=`locatefile apps/$SYS_APPNAME/LIBRARIES` 
  assertfile $libfile
  libraries=
  if [ -f "$libfile" ]; then
    libraries=`cat $libfile`
  fi
  here=`pwd`
  for lib in $libraries; do
    libname=`echo "$lib!" | cut -f 1 -d "!"`
    excludes=`echo "$lib!" | cut -f 2- -d "!"`
    excluded=`echo "$excludes" | grep $SYS_PLATFORM`
    if [ "X$excluded" = "X" ]; then    
      libfile="$SYS_PREFIX/lib/$libname.a"
      libdir=`locatedir libraries/$libname`
      assertfile $libdir
      if [ `newerindir $libdir $libfile` = "yes" ]; then
        echo " => $libname.."
        cd $libdir
        ac_output build.sh
        sh build.sh
        rm build.sh
        cd $here
      fi
      explode_library $libname
    fi
  done
}

make_tools()
{
  echo "==> creating tools needed for $SYS_APPNAME.."
  tools=`ls -1 tools`
  here=`pwd`
  for tool in $tools; do
    tooldir=tools/$tool
    assertfile $tooldir
    cd $tooldir
    ac_output build.sh
    sh build.sh
    asserterror $?
    rm build.sh
    cd $here
  done
}

make_info()
{
  echo " => Application	: $SYS_APPNAME"
  echo " => Version	: $SYS_APPVERSION"
  echo " => Platform	: $SYS_PLATFORM"
  echo " => Org. ID	: $SYS_ORGSLD.$SYS_ORGTLD"
  exit 1
}

usage()
{
  echo "usage: make.sh <clean|tools|resources|libraries|payload|executable|all|install|package|info>"
  exit 0;
}

##############################
# main dispatcher

make_setup

# try to prevent a failed build from contaminating next make
# this has to be called after make_setup
resetstate

case "$1" in
clean) 
  rm -rf tmp.?????? 2> /dev/null
  make_clean
;;
scrub)
  rm -rf tmp.?????? 2> /dev/null
  make_scrub
;;
tools)
  make_tools
;;
resources)
  make_artwork
  make_textures
  make_fonts
  make_strings
;;
libraries)
  make_libraries
;;
explode)
  explode_library $2
;;
payload)
  make_payload
;;
executable)
  make_executable
;;
all)
  rm -rf tmp.?????? 2> /dev/null
  make_libraries
  make_tools
if [ `is_gui_app` = "yes" ]; then
  make_artwork
  make_textures
  make_fonts
  make_strings
fi
  make_payload
  make_executable
  make_package
;;
package)
  make_package
;;
install)
  make_install
;;
info)
  make_info
;;
*)
  usage
;;
esac

if [ -f $evallog ]; then
  rm $evallog
fi

# all is well if we got here, so clear the state cache
resetstate

#eof
