## Makefile.am -- Process this file with automake to produce Makefile.in


# Rules for tolua++ binding files
SUFFIXES = .pkg

TOLUA = tolua++
.pkg.c:
	$(TOLUA) $(TOLUAFLAGS) $(AM_TOLUAFLAGS) -n jive -o $@ $^


# Convenience library: libui.la
noinst_LTLIBRARIES = libjiveui.la

BUILT_SOURCES = src/ui/lua_jiveui.c

libjiveui_la_SOURCES = \
	src/ui/jive_audio.c \
	src/ui/jive_event.c \
	src/ui/jive_font.c \
	src/ui/jive_framework.c \
	src/ui/jive_icon.c \
	src/ui/jive_label.c \
	src/ui/jive_menu.c \
	src/ui/jive_slider.c \
	src/ui/jive_style.c \
	src/ui/jive_surface.c \
	src/ui/jive_textarea.c \
	src/ui/jive_textinput.c \
	src/ui/jive_tile.c \
	src/ui/jive_timer.c \
	src/ui/jive_utils.c \
	src/ui/jive_widget.c \
	src/ui/jive_window.c \
	src/ui/lua_jiveui.c


libjiveui_la_LIBADD = -ltolua++ -llua -lSDL_image -lSDL_ttf -lSDL_gfx -lSDL


# Program: jivebrowser
bin_PROGRAMS = jive

# Test programs: jiveblit
testdir = $(bindir)
if TEST_PROGRAMS
test_PROGRAMS = jiveblit
else
test_PROGRAMS = 
endif


jive_SOURCES = \
	src/jive.c

jive_LDADD = libjiveui.la -llua


# Test program: jiveblit
jiveblit_SOURCES = \
	src/jiveblit.c

jiveblit_LDADD = -lSDL_image -lSDL_ttf -lSDL_gfx -lSDL


# Data: lua scripts
jivedir = $(pkgdatadir)/jive
dist_jive_DATA = \
	share/jive/JiveMain.lua \
	share/jive/Applet.lua \
	share/jive/AppletManager.lua \
	share/jive/AppletMeta.lua \
	share/jive/Iconbar.lua

jiveuidir = $(pkgdatadir)/jive/ui
dist_jiveui_DATA = \
	share/jive/ui/Checkbox.lua \
	share/jive/ui/Choice.lua \
	share/jive/ui/Event.lua \
	share/jive/ui/Framework.lua \
	share/jive/ui/Font.lua \
	share/jive/ui/Icon.lua \
	share/jive/ui/Label.lua \
	share/jive/ui/Menu.lua \
	share/jive/ui/Popup.lua \
	share/jive/ui/RadioButton.lua \
	share/jive/ui/RadioGroup.lua \
	share/jive/ui/SimpleMenu.lua \
	share/jive/ui/Scrollbar.lua \
	share/jive/ui/Slider.lua \
	share/jive/ui/Surface.lua \
	share/jive/ui/Textarea.lua \
	share/jive/ui/Textinput.lua \
	share/jive/ui/Tile.lua \
	share/jive/ui/Timer.lua \
	share/jive/ui/Widget.lua \
	share/jive/ui/Window.lua

luanetdir = $(pkgdatadir)/jive/net
dist_luanet_DATA = \
	share/jive/net/NetworkThread.lua \
	share/jive/net/SocketHttp.lua \
	share/jive/net/SocketHttpQueue.lua \
	share/jive/net/Socket.lua \
	share/jive/net/SocketUdpBcast.lua \
	share/jive/net/SocketTcp.lua \
	share/jive/net/RequestHttp.lua \
	share/jive/net/RequestJsonRpc.lua \
	share/jive/net/HttpPool.lua	

luaslimdir = $(pkgdatadir)/jive/slim
dist_luaslim_DATA = \
	share/jive/slim/Player.lua  \
	share/jive/slim/SlimServer.lua \
	share/jive/slim/SlimServers.lua \
	share/jive/slim/RequestsCli.lua

luautildir = $(pkgdatadir)/jive/utils
dist_luautil_DATA = \
	share/jive/utils/debug.lua \
	share/jive/utils/log.lua \
	share/jive/utils/queue.lua \
	share/jive/utils/strings.lua \
	share/jive/utils/autotable.lua \
	share/jive/utils/jsonfilters.lua \
	share/jive/utils/perfs.lua \
	share/jive/utils/table.lua


applets_bouncedir = $(pkgdatadir)/applets/Bounce
dist_applets_bounce_DATA = \
	share/applets/Bounce/BounceApplet.lua \
	share/applets/Bounce/BounceMeta.lua \
	share/applets/Bounce/squeezebox.png

applets_quitdir = $(pkgdatadir)/applets/Quit
dist_applets_quit_DATA = \
	share/applets/Quit/QuitApplet.lua \
	share/applets/Quit/QuitMeta.lua

applets_logdir = $(pkgdatadir)/applets/LogSettings
dist_applets_log_DATA = \
	share/applets/LogSettings/LogSettingsApplet.lua \
	share/applets/LogSettings/LogSettingsMeta.lua

applets_keylockdir = $(pkgdatadir)/applets/KeyLock
dist_applets_keylock_DATA = \
	share/applets/KeyLock/KeyLockApplet.lua \
	share/applets/KeyLock/KeyLockMeta.lua

applets_screensaversdir = $(pkgdatadir)/applets/ScreenSavers
dist_applets_screensavers_DATA = \
	share/applets/ScreenSavers/ScreenSaversApplet.lua \
	share/applets/ScreenSavers/ScreenSaversMeta.lua

applets_slimbrowserdir = $(pkgdatadir)/applets/SlimBrowser
dist_applets_slimbrowser_DATA = \
	share/applets/SlimBrowser/SlimBrowserApplet.lua \
	share/applets/SlimBrowser/SlimBrowserMeta.lua \
	share/applets/SlimBrowser/DB.lua

applets_slimdiscoverydir = $(pkgdatadir)/applets/SlimDiscovery
dist_applets_slimdiscovery_DATA = \
	share/applets/SlimDiscovery/SlimDiscoveryApplet.lua \
	share/applets/SlimDiscovery/SlimDiscoveryMeta.lua

applets_flickrdir = $(pkgdatadir)/applets/Flickr
dist_applets_flickr_DATA = \
	share/applets/Flickr/FlickrApplet.lua \
	share/applets/Flickr/FlickrMeta.lua

applets_testdir = $(pkgdatadir)/applets/Test
dist_applets_test_DATA = \
	share/applets/Test/TestApplet.lua \
	share/applets/Test/TestMeta.lua \
	share/applets/Test/test.txt \
	share/applets/Test/test.jpg \
	share/applets/Test/test.png \
	share/applets/Test/test.gif

applets_screenshotdir = $(pkgdatadir)/applets/Screenshot
dist_applets_screenshot_DATA = \
	share/applets/Screenshot/ScreenshotApplet.lua \
	share/applets/Screenshot/ScreenshotMeta.lua


# Default skin
applets_defaultskindir = $(pkgdatadir)/applets/DefaultSkin
dist_applets_defaultskin_DATA = \
	share/applets/DefaultSkin/DefaultSkinApplet.lua \
	share/applets/DefaultSkin/DefaultSkinMeta.lua


# Data: wallpaper
applets_defaultskin_wallpaperdir = $(pkgdatadir)/applets/DefaultSkin/wallpaper
dist_applets_defaultskin_wallpaper_DATA = \
	share/applets/DefaultSkin/wallpaper/Chapple_1.jpg \
	share/applets/DefaultSkin/wallpaper/Clearly-Ambiguous_1.jpg \
	share/applets/DefaultSkin/wallpaper/Clearly-Ambiguous_2.jpg \
	share/applets/DefaultSkin/wallpaper/Clearly-Ambiguous_3.jpg \
	share/applets/DefaultSkin/wallpaper/Clearly-Ambiguous_4.jpg \
	share/applets/DefaultSkin/wallpaper/Clearly-Ambiguous_5.jpg \
	share/applets/DefaultSkin/wallpaper/Clearly-Ambiguous_6.jpg \
	share/applets/DefaultSkin/wallpaper/dotDOTdot_1.jpg \
	share/applets/DefaultSkin/wallpaper/Los-Cardinalos_1.jpg \
	share/applets/DefaultSkin/wallpaper/Orin-Optiglot_1.jpg


# Data: default skin
applets_defaultskin_imagesdir = $(pkgdatadir)/applets/DefaultSkin/images
dist_applets_defaultskin_images_DATA = \
	share/applets/DefaultSkin/images/checkbox_off.png \
	share/applets/DefaultSkin/images/checkbox_on.png \
	share/applets/DefaultSkin/images/icon_home.png \
	share/applets/DefaultSkin/images/icon_mode_off.png \
	share/applets/DefaultSkin/images/icon_mode_pause.png \
	share/applets/DefaultSkin/images/icon_mode_play.png \
	share/applets/DefaultSkin/images/icon_repeat_1.png \
	share/applets/DefaultSkin/images/icon_repeat_off.png \
	share/applets/DefaultSkin/images/icon_shuffle_1.png \
	share/applets/DefaultSkin/images/icon_shuffle_off.png \
	share/applets/DefaultSkin/images/menu_album_noartwork.png \
	share/applets/DefaultSkin/images/menu_selection_box_bl.png \
	share/applets/DefaultSkin/images/menu_selection_box_b.png \
	share/applets/DefaultSkin/images/menu_selection_box_br.png \
	share/applets/DefaultSkin/images/menu_selection_box_l.png \
	share/applets/DefaultSkin/images/menu_selection_box.png \
	share/applets/DefaultSkin/images/menu_selection_box_r.png \
	share/applets/DefaultSkin/images/menu_selection_box_tl.png \
	share/applets/DefaultSkin/images/menu_selection_box_t.png \
	share/applets/DefaultSkin/images/menu_selection_box_tr.png \
	share/applets/DefaultSkin/images/note.png \
	share/applets/DefaultSkin/images/popup_volume_leftbody.png \
	share/applets/DefaultSkin/images/popup_volume_midbody.png \
	share/applets/DefaultSkin/images/popup_volume_rightbody.png \
	share/applets/DefaultSkin/images/radiobutton_off.png \
	share/applets/DefaultSkin/images/radiobutton_on.png \
	share/applets/DefaultSkin/images/scrollbar_bkgroundbottom.png \
	share/applets/DefaultSkin/images/scrollbar_bkgroundmid.png \
	share/applets/DefaultSkin/images/scrollbar_bkground.png \
	share/applets/DefaultSkin/images/scrollbar_bkgroundtop.png \
	share/applets/DefaultSkin/images/scrollbar_bodybottom.png \
	share/applets/DefaultSkin/images/scrollbar_bodymid.png \
	share/applets/DefaultSkin/images/scrollbar_bodytop.png \
	share/applets/DefaultSkin/images/selection_right.png \
	share/applets/DefaultSkin/images/selection_wait.png \
	share/applets/DefaultSkin/images/splash_squeezebox_jive.png \
	share/applets/DefaultSkin/images/titlebox_bl.png \
	share/applets/DefaultSkin/images/titlebox_b.png \
	share/applets/DefaultSkin/images/titlebox_br.png \
	share/applets/DefaultSkin/images/titlebox_l.png \
	share/applets/DefaultSkin/images/titlebox.png \
	share/applets/DefaultSkin/images/titlebox_r.png \
	share/applets/DefaultSkin/images/titlebox_tl.png \
	share/applets/DefaultSkin/images/titlebox_t.png  \
	share/applets/DefaultSkin/images/titlebox_tr.png \
	share/applets/DefaultSkin/images/border.png \
	share/applets/DefaultSkin/images/border_r.png \
	share/applets/DefaultSkin/images/border_l.png \
	share/applets/DefaultSkin/images/scrollbar_bkground_t.png \
	share/applets/DefaultSkin/images/scrollbar_bkground_b.png \
	share/applets/DefaultSkin/images/helpbox.png \
	share/applets/DefaultSkin/images/helpbox_l.png \
	share/applets/DefaultSkin/images/helpbox_r.png \
	share/applets/DefaultSkin/images/helpbox_t.png \
	share/applets/DefaultSkin/images/helpbox_tl.png \
	share/applets/DefaultSkin/images/helpbox_tr.png \
	share/applets/DefaultSkin/images/slider_bkgrd_l.png \
	share/applets/DefaultSkin/images/slider_bkgrd.png \
	share/applets/DefaultSkin/images/slider_bkgrd_r.png \
	share/applets/DefaultSkin/images/slider_fill_l.png \
	share/applets/DefaultSkin/images/slider_fill.png \
	share/applets/DefaultSkin/images/slider_fill_r.png \
	share/applets/DefaultSkin/images/icon_volume_max.png \
	share/applets/DefaultSkin/images/icon_volume_min.png \
	share/applets/DefaultSkin/images/popupbox_bl.png \
	share/applets/DefaultSkin/images/popupbox_b.png \
	share/applets/DefaultSkin/images/popupbox_br.png \
	share/applets/DefaultSkin/images/popupbox_l.png \
	share/applets/DefaultSkin/images/popupbox.png \
	share/applets/DefaultSkin/images/popupbox_r.png \
	share/applets/DefaultSkin/images/popupbox_tl.png \
	share/applets/DefaultSkin/images/popupbox_t.png \
	share/applets/DefaultSkin/images/popupbox_tr.png \
	share/applets/DefaultSkin/images/popup_volume_bkground_l.png \
	share/applets/DefaultSkin/images/popup_volume_bkground.png \
	share/applets/DefaultSkin/images/popup_volume_bkground_r.png \
	share/applets/DefaultSkin/images/text_entry_bkgrd.png \
	share/applets/DefaultSkin/images/text_entry_bkgrd_l.png \
	share/applets/DefaultSkin/images/text_entry_bkgrd_r.png \
	share/applets/DefaultSkin/images/text_entry_letter.png \
	share/applets/DefaultSkin/images/text_entry_select.png

applets_defaultskin_soundsdir = $(pkgdatadir)/applets/DefaultSkin/sounds
dist_applets_defaultskin_sounds_DATA = \
	share/applets/DefaultSkin/sounds/bump.wav \
	share/applets/DefaultSkin/sounds/click.wav \
	share/applets/DefaultSkin/sounds/jump.wav \
	share/applets/DefaultSkin/sounds/pushleft.wav \
	share/applets/DefaultSkin/sounds/pushright.wav \
	share/applets/DefaultSkin/sounds/select.wav \
	share/applets/DefaultSkin/sounds/shutdown.wav \
	share/applets/DefaultSkin/sounds/startup.wav

