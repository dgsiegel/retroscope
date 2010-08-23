VALAFLAGS = \
	--thread \
	--vapidir vapi \
	--pkg config \
	--pkg gtk+-2.0 \
	--pkg gdk-x11-2.0 \
	--pkg gmodule-2.0 \
	--pkg gee-1.0 \
	--pkg clutter-1.0 \
	--pkg clutter-gst-1.0 \
	--pkg clutter-gtk-0.10 \
	--pkg gstreamer-0.10 \
	--pkg gstreamer-interfaces-0.10

AM_CPPFLAGS = \
	-DBINDIR=\"$(bindir)\"			 	\
	-DDATADIR=\"$(datadir)\"			\
	-DPREFIX=\""$(prefix)"\" 			\
	-DSYSCONFDIR=\""$(sysconfdir)"\" 		\
	-DLIBDIR=\""$(libdir)"\" 			\
	-DPACKAGE_DATADIR=\""$(datadir)/retroscope"\"	\
	-DPACKAGE_LOCALEDIR=\""$(datadir)/locale"\"	\
	-DGNOME_DESKTOP_USE_UNSTABLE_API=1 \
	$(RETROSCOPE_CFLAGS) \
	-include $(CONFIG_HEADER)

AM_CFLAGS = \
	-export-dynamic

bin_PROGRAMS = retroscope

retroscope_SOURCES = \
	retroscope.vala

retroscope_LDADD = \
	$(RETROSCOPE_LIBS)
