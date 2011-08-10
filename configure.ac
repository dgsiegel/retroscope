# Process this file with autoconf to produce a configure script.

AC_INIT(retroscope, 0.1.0)

AM_INIT_AUTOMAKE(AC_PACKAGE_NAME, AC_PACKAGE_VERSION)
m4_ifdef([AM_SILENT_RULES],[AM_SILENT_RULES([yes])])
AM_CONFIG_HEADER(retroscope-config.h)
AM_MAINTAINER_MODE

AM_PROG_VALAC([0.9.2])

dnl make sure we keep ACLOCAL_FLAGS around for maintainer builds to work
AC_SUBST(ACLOCAL_AMFLAGS, "\${ACLOCAL_FLAGS}")

AC_ISC_POSIX
AC_PROG_CC
AM_PROG_CC_STDC
AC_HEADER_STDC
AM_PROG_LIBTOOL

CFLAGS="${CFLAGS} -Wall"
CFLAGS+=" -DGSEAL_ENABLE"

GNOME_MAINTAINER_MODE_DEFINES
GNOME_COMPILE_WARNINGS

GTK_DOC_CHECK([1.14],[--flavour no-tmpl])

#*******************************************************************************
# Internationalization
#*******************************************************************************
GETTEXT_PACKAGE=retroscope
AC_SUBST(GETTEXT_PACKAGE)
AC_DEFINE_UNQUOTED(GETTEXT_PACKAGE,"$GETTEXT_PACKAGE", [GETTEXT package name])

IT_PROG_INTLTOOL([0.40.0])
AM_GLIB_GNU_GETTEXT

GNOME_DOC_INIT

#*******************************************************************************
# Check required libraries
#*******************************************************************************

GLIB_REQUIRED=2.16.0
GOBJECT_REQUIRED=2.12.0
GIO_REQUIRED=2.16.0
GTK_REQUIRED=3.0
GSTREAMER_REQUIRED=0.10.23
CLUTTER_REQUIRED=1.2
CLUTTERGTK_REQUIRED=0.10.4
CLUTTERGST_REQUIRED=1.3.3
GEE_REQUIRED=0.5

#*******************************************************************************
# Check for udev
#*******************************************************************************

PKG_CHECK_MODULES(RETROSCOPE, \ 
  glib-2.0 >= $GLIB_REQUIRED \
  gobject-2.0 >= $GOBJECT_REQUIRED \
  gio-2.0 >= $GIO_REQUIRED \
  gtk+-3.0 >= $GTK_REQUIRED \
  gstreamer-0.10 >= $GSTREAMER_REQUIRED \
  gstreamer-plugins-base-0.10 >= $GSTREAMER_REQUIRED \
  clutter-1.0 >= $CLUTTER_REQUIRED \
  clutter-gtk-1.0 >= $CLUTTERGTK_REQUIRED \
  clutter-gst-1.0 >= $CLUTTERGST_REQUIRED \
  gee-1.0 >= $GEE_REQUIRED \
  )
AC_SUBST(RETROSCOPE_CFLAGS)

RETROSCOPE_LIBS="$RETROSCOPE_LIBS -lgstinterfaces-0.10"

AC_SUBST(RETROSCOPE_LIBS)

GLIB_GENMARSHAL=`$PKG_CONFIG --variable=glib_genmarshal glib-2.0`
GLIB_MKENUMS=`$PKG_CONFIG --variable=glib_mkenums glib-2.0`
AC_SUBST(GLIB_GENMARSHAL)
AC_SUBST(GLIB_MKENUMS)

#*******************************************************************************

AC_OUTPUT([
Makefile
data/Makefile
data/pixmaps/Makefile
src/Makefile
po/Makefile.in
])

#**************************************************************************
