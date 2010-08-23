@INTLTOOL_DESKTOP_RULE@
desktopdir = $(datadir)/applications
desktop_in_files = retroscope.desktop.in
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)

pkgdata_DATA = \
	viewport.json

EXTRA_DIST = \
	$(desktop_in_files) \
	$(pkgdata_DATA)

clean-local :
	rm -f *~

DISTCLEANFILES = \
	retroscope.desktop
