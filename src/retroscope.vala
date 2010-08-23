/*
 * Copyright © 2010 daniel g. siegel <dgsiegel@gnome.org>
 *
 * Licensed under the GNU General Public License Version 2
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * compile with:
 * valac --pkg gtk+-2.0 --pkg gdk-x11-2.0 --pkg gstreamer-0.10 --pkg gstreamer-interfaces-0.10 retroscope.vala
 */

using Gtk;
using Gst;
using Clutter;
using ClutterGst;
using GtkClutter;

const bool USE_FFMPEG_ENCODING = true;

const int WIDTH = 640;
const int HEIGHT = 480;

public class Retroscope : Gtk.Window
{
  private Element     pipeline;
  private static bool is_fullscreen;
  private static int  minutes;
  private static int  seconds;
  private static int  delay;
  private Clutter.Stage stage;
  private Clutter.Box viewport_layout;
  private Clutter.BinLayout viewport_layout_manager;
  private Clutter.Rectangle background_layer;
  private static Clutter.Texture video_preview;
  private static Clutter.Text countdown_layer;

  const OptionEntry[] options = {
    {"fullscreen", 'f', 0, OptionArg.NONE, ref is_fullscreen, "Start in fullscreen", null     },
    {"minutes",    'm', 0, OptionArg.INT,  ref minutes,       "Delay in minutes",    "MINUTES"},
    {"seconds",    's', 0, OptionArg.INT,  ref seconds,       "Delay in seconds",    "SECONDS"},
    {null}
  };


  private Retroscope ()
  {
    var clutter_builder = new Clutter.Script ();
    try
    {
      clutter_builder.load_from_file (GLib.Path.build_filename ("../data", "viewport.json"));
    }
    catch (Error err)
    {
      error ("Error: %s", err.message);
    }

    var viewport = new GtkClutter.Embed();
    this.stage = viewport.get_stage().get_stage();
    this.stage.allocation_changed.connect (on_stage_resize);

    this.video_preview           = (Clutter.Texture) clutter_builder.get_object ("video_preview");
    this.viewport_layout         = (Clutter.Box) clutter_builder.get_object ("viewport_layout");
    this.viewport_layout_manager = (Clutter.BinLayout) clutter_builder.get_object ("viewport_layout_manager");
    this.countdown_layer         = (Clutter.Text) clutter_builder.get_object ("countdown_layer");
    this.background_layer        = (Clutter.Rectangle) clutter_builder.get_object ("background");

this.countdown_layer.reactive = true;
    video_preview.keep_aspect_ratio = true;
    video_preview.request_mode      = Clutter.RequestMode.HEIGHT_FOR_WIDTH;
    this.stage.add_actor (this.background_layer);
    this.stage.add_actor (this.viewport_layout);
    viewport_layout.set_layout_manager (this.viewport_layout_manager);

    this.set_size_request (WIDTH, HEIGHT);
    this.set_title ("Retroscope");
    this.set_icon_name ("forward");
    this.position = WindowPosition.CENTER;
    this.destroy.connect (this.quit);
    this.key_press_event.connect (this.on_key_press_event);

    var vbox = new VBox (false, 0);
    vbox.pack_start (viewport, true, true, 0);

    this.add (vbox);
    this.show_all ();
    this.stage.show_all();

    this.create_pipeline ();
  }


  public void on_stage_resize (Clutter.Actor           actor,
                               Clutter.ActorBox        box,
                               Clutter.AllocationFlags flags)
  {
    this.viewport_layout.set_size (this.stage.width, this.stage.height);
    this.background_layer.set_size (this.stage.width, this.stage.height);
  }

  private void create_pipeline ()
  {
    this.pipeline = ElementFactory.make ("camerabin", "video");
    var queue   = ElementFactory.make ("queue", "queue");
    queue.set_property ("min-threshold-time", (uint64)this.delay * 1000000000);
    queue.set_property ("max-size-time", 0);
    queue.set_property ("max-size-bytes", 0);
    queue.set_property ("max-size-buffers", 0);
    var sink = new ClutterGst.VideoSink (this.video_preview);

    if (USE_FFMPEG_ENCODING)
    {
      var ffmpeg1 = ElementFactory.make ("ffmpegcolorspace", "ffmpeg1");
      var ffmpeg2 = ElementFactory.make ("ffmpegcolorspace", "ffmpeg2");
      var ffenc   = ElementFactory.make ("ffenc_huffyuv", "ffenc");
      var ffdec   = ElementFactory.make ("ffdec_huffyuv", "ffdec");

      var bin = new Gst.Bin ("delay_bin");
      bin.add_many (ffmpeg1, ffenc, queue, ffdec, ffmpeg2);
      ffmpeg1.link_many (ffenc, queue, ffdec, ffmpeg2);

      var pad_sink   = ffmpeg1.get_static_pad ("sink");
      var ghost_sink = new GhostPad ("sink", pad_sink);
      bin.add_pad (ghost_sink);

      var pad_src   = ffmpeg2.get_static_pad ("src");
      var ghost_src = new GhostPad ("src", pad_src);
      bin.add_pad (ghost_src);

      this.pipeline.set_property ("viewfinder-filter", bin);
    }
    else
    {
      this.pipeline.set_property ("viewfinder-filter", queue);
    }
    this.pipeline.set_property ("viewfinder-sink", sink);

  }

  private void toggle_fullscreen ()
  {
    this.is_fullscreen = !this.is_fullscreen;
    if (this.is_fullscreen)
      this.fullscreen ();
    else
      this.unfullscreen ();
  }

  private bool on_key_press_event (Gdk.EventKey event)
  {
    var keyname = Gdk.keyval_name (event.keyval);

    if (keyname == "F11")
      this.toggle_fullscreen ();
    else
    if (keyname == "Escape")
      if (this.is_fullscreen)
        this.toggle_fullscreen ();
      else
        this.quit ();
    return false;
  }

  private void do_countdown ()
  {
    var time = Time();

    var min = this.delay / 60;
    var sec = this.delay % 60;
    var tmp = string.join (":", min.to_string(), sec.to_string ());
    time.strptime (tmp, "%M:%S");

    this.countdown_layer.text = time.format("%M:%S");
    this.delay--;
    if (this.delay < 0)
    {
      this.countdown_layer.animate (Clutter.AnimationMode.LINEAR, 1000, "opacity", 0);
      this.video_preview.animate (Clutter.AnimationMode.LINEAR, 1000, "opacity", 255);
      return;
    }

    var anim = this.countdown_layer.animate (Clutter.AnimationMode.LINEAR, 1000, "opacity", 255);
    Signal.connect_after (anim, "completed", (GLib.Callback) this.do_countdown, this);
  }

  private void run ()
  {
    this.pipeline.set_state (State.PLAYING);

    this.do_countdown();
  }

  private void quit ()
  {
    this.pipeline.set_state (State.NULL);
    Gtk.main_quit ();
  }

  public static int main (string[] args)
  {
    Gtk.init (ref args);
    Clutter.init (ref args);

    try {
      var context = new OptionContext ("- The Retroscope. Default delay is 10 seconds.");
      context.set_help_enabled (true);
      context.add_main_entries (options, null);
      context.add_group (Gtk.get_option_group (true));
      context.add_group (Gst.init_get_option_group ());
      context.add_group (Clutter.get_option_group ());
      context.parse (ref args);
    }
    catch (OptionError e)
    {
      stdout.printf ("%s\n", e.message);
      stdout.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
      return 1;
    }

    delay = 0;
    if (minutes > 0)
      delay = minutes * 60;
    if (seconds > 0)
      delay = delay + seconds;
    if (delay == 0)
      delay = 10;

    message ("Delay set to %d seconds", delay);

    var retroscope = new Retroscope ();
    if (is_fullscreen)
      retroscope.toggle_fullscreen ();
    retroscope.run ();

    Gtk.main ();

    return 0;
  }
}
