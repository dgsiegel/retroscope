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

using GLib;
using Gtk;
using Gst;
using Clutter;
using ClutterGst;
using GtkClutter;

const int WIDTH  = 640;
const int HEIGHT = 480;

const int BUTTON_NORMAL = 90;
const int BUTTON_ACTIVE = 255;

public class Retroscope : Gtk.Window
{
  private Element                  pipeline;
  private Element                  queue;
  private static bool              is_fullscreen;
  private static int               hours;
  private static int               minutes;
  private static int               seconds;
  private static int               delay;
  private static int               selected_button;
  private Clutter.Stage            stage;
  private Clutter.Box              viewport_layout;
  private Clutter.BinLayout        viewport_layout_manager;
  private Clutter.Rectangle        background_layer;
  private static Clutter.Texture   video_preview;
  private static Clutter.Text      countdown_layer;
  private static Clutter.Texture[] arrows;

  private enum Buttons
  {
    PLAY,
    HOUR_UP,
    HOUR_DOWN,
    MIN_UP,
    MIN_DOWN,
    SEC_UP,
    SEC_DOWN
  }

  const OptionEntry[] options = {
    {"fullscreen", 'f',    0,   OptionArg.NONE, ref is_fullscreen, "Start in fullscreen",    null          },
    {"hours",      0,      0,   OptionArg.INT,  ref hours,         "Delay in hours",         "HOURS"       },
    {"minutes",    'm',    0,   OptionArg.INT,  ref minutes,       "Delay in minutes",       "MINUTES"     },
    {"seconds",    's',    0,   OptionArg.INT,  ref seconds,       "Delay in seconds",       "SECONDS"     },
    {null}
  };


  private Retroscope ()
  {
    var clutter_builder = new Clutter.Script ();

    try
    {
      clutter_builder.load_from_file (GLib.Path.build_filename (Config.PACKAGE_DATADIR, "viewport.json"));
    }
    catch (Error err)
    {
      error ("Error: %s", err.message);
    }

    var viewport = new GtkClutter.Embed ();
    this.stage = viewport.get_stage ().get_stage ();
    this.stage.allocation_changed.connect (on_stage_resize);

    this.video_preview           = (Clutter.Texture)clutter_builder.get_object ("video_preview");
    this.viewport_layout         = (Clutter.Box)clutter_builder.get_object ("viewport_layout");
    this.viewport_layout_manager = (Clutter.BinLayout)clutter_builder.get_object ("viewport_layout_manager");
    this.countdown_layer         = (Clutter.Text)clutter_builder.get_object ("countdown_layer");
    this.background_layer        = (Clutter.Rectangle)clutter_builder.get_object ("background");
    this.arrows                  = {
      (Clutter.Texture)clutter_builder.get_object ("play"),
      (Clutter.Texture)clutter_builder.get_object ("arrow_hour_up"),
      (Clutter.Texture)clutter_builder.get_object ("arrow_hour_down"),
      (Clutter.Texture)clutter_builder.get_object ("arrow_min_up"),
      (Clutter.Texture)clutter_builder.get_object ("arrow_min_down"),
      (Clutter.Texture)clutter_builder.get_object ("arrow_sec_up"),
      (Clutter.Texture)clutter_builder.get_object ("arrow_sec_down")
    };

    this.stage.add_actor (this.background_layer);
    this.stage.add_actor (this.viewport_layout);
    viewport_layout.set_layout_manager (this.viewport_layout_manager);
    this.set_time_from_delay ();

    try
    {
      foreach (Clutter.Texture t in this.arrows)
      {
        t.set_from_file (GLib.Path.build_filename (Config.PACKAGE_DATADIR, "pixmaps", "arrow.svg"));
        t.button_release_event.connect (this.on_button_release_event);
        t.animate (Clutter.AnimationMode.LINEAR, 2000, "opacity", BUTTON_NORMAL);
      }
      this.arrows[this.Buttons.PLAY].set_from_file (GLib.Path.build_filename (Config.PACKAGE_DATADIR, "pixmaps", "play.svg"));
      this.arrows[this.Buttons.PLAY].animate (Clutter.AnimationMode.LINEAR, 2000, "opacity", BUTTON_ACTIVE);
      this.selected_button = this.Buttons.PLAY;
    }
    catch (Error err)
    {
      error ("Error: %s", err.message);
    }

    this.set_size_request (WIDTH, HEIGHT);
    this.set_title ("Retroscope");
    this.set_icon_name ("forward");
    this.set_position (WindowPosition.CENTER);
    this.destroy.connect (this.on_quit);
    this.key_press_event.connect (this.on_key_press_event);

    var vbox = new VBox (false, 0);
    vbox.pack_start (viewport, true, true, 0);

    this.add (vbox);
    this.show_all ();
    this.stage.show_all ();

    if (this.is_fullscreen)
      this.fullscreen ();

    this.create_pipeline ();

    this.countdown_layer.animate (Clutter.AnimationMode.LINEAR, 1000, "opacity", 255);
  }

  private void create_pipeline ()
  {
    this.pipeline = ElementFactory.make ("camerabin", "video");
    this.queue    = ElementFactory.make ("queue", "queue");
    this.queue.set_property ("max-size-time", 0);
    this.queue.set_property ("max-size-bytes", 0);
    this.queue.set_property ("max-size-buffers", 0);
    var sink = new ClutterGst.VideoSink (this.video_preview);

    var ffmpeg1 = ElementFactory.make ("ffmpegcolorspace", "ffmpeg1");
    var ffmpeg2 = ElementFactory.make ("ffmpegcolorspace", "ffmpeg2");
    var ffenc   = ElementFactory.make ("ffenc_huffyuv", "ffenc");
    var ffdec   = ElementFactory.make ("ffdec_huffyuv", "ffdec");

    var bin = new Gst.Bin ("delay_bin");
    bin.add_many (ffmpeg1, ffenc, this.queue, ffdec, ffmpeg2);
    ffmpeg1.link_many (ffenc, this.queue, ffdec, ffmpeg2);

    var pad_sink   = ffmpeg1.get_static_pad ("sink");
    var ghost_sink = new GhostPad ("sink", pad_sink);
    bin.add_pad (ghost_sink);

    var pad_src   = ffmpeg2.get_static_pad ("src");
    var ghost_src = new GhostPad ("src", pad_src);
    bin.add_pad (ghost_src);

    this.pipeline.set_property ("viewfinder-filter", bin);
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

  private void set_time_from_delay ()
  {
    if (this.delay < 0)
      this.delay = 0;
    this.countdown_layer.text =
      string.join (":", "%02d".printf (this.delay / 3600), "%02d".printf (this.delay % 3600 / 60),
                   "%02d".printf (this.delay % 60));
  }

  private void do_countdown ()
  {
    this.set_time_from_delay ();
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

  private void play ()
  {
    this.queue.set_property ("min-threshold-time", (uint64) this.delay * 1000000000);
    this.pipeline.set_state (State.PLAYING);

    foreach (Clutter.Texture t in this.arrows)
    {
      t.reactive = false;
      t.animate (Clutter.AnimationMode.LINEAR, 1000, "opacity", 0);
    }

    this.do_countdown ();
  }

  private void highlight_next_button ()
  {
    this.arrows[this.selected_button].animate (Clutter.AnimationMode.LINEAR, 500, "opacity", BUTTON_NORMAL);
    this.selected_button++;
    if (this.selected_button >= this.arrows.length)
      this.selected_button = this.Buttons.PLAY;
    this.arrows[this.selected_button].animate (Clutter.AnimationMode.LINEAR, 500, "opacity", BUTTON_ACTIVE);
  }

  private void highlight_button (int id)
  {
    this.arrows[this.selected_button].animate (Clutter.AnimationMode.LINEAR, 500, "opacity", BUTTON_NORMAL);
    this.selected_button = id;
    if (id >= this.arrows.length || id < 0)
      this.selected_button = this.Buttons.PLAY;
    this.arrows[this.selected_button].animate (Clutter.AnimationMode.LINEAR, 500, "opacity", BUTTON_ACTIVE);
  }

  private void on_quit ()
  {
    this.pipeline.set_state (State.NULL);
    Gtk.main_quit ();
  }

  public void on_stage_resize (Clutter.Actor           actor,
                               Clutter.ActorBox        box,
                               Clutter.AllocationFlags flags)
  {
    this.viewport_layout.set_size (this.stage.width, this.stage.height);
    this.background_layer.set_size (this.stage.width, this.stage.height);
  }

  private bool on_key_press_event (Gdk.EventKey event)
  {
    var keyname = Gdk.keyval_name (event.keyval);

    switch (keyname)
    {
    case "F11":
      this.toggle_fullscreen ();
      break;
    case "Escape":
      if (this.is_fullscreen)
        this.toggle_fullscreen ();
      else
        this.on_quit ();
      break;
    case "Return":
      switch (this.selected_button)
      {
        case this.Buttons.HOUR_UP:
          this.delay += 3600;
          this.set_time_from_delay ();
          break;
        case this.Buttons.HOUR_DOWN:
          this.delay -= 3600;
          this.set_time_from_delay ();
          break;
        case this.Buttons.MIN_UP:
          this.delay += 60;
          this.set_time_from_delay ();
          break;
        case this.Buttons.MIN_DOWN:
          this.delay -= 60;
          this.set_time_from_delay ();
          break;
        case this.Buttons.SEC_UP:
          this.delay++;
          this.set_time_from_delay ();
          break;
        case this.Buttons.SEC_DOWN:
          this.delay--;
          this.set_time_from_delay ();
          break;
        case this.Buttons.PLAY:
          this.play ();
          break;
      }
      break;
    case "Tab":
      if (selected_button == this.Buttons.PLAY)
        highlight_next_button ();
      else
        highlight_button (this.selected_button + 2);
      break;
    case "Left":
      if (selected_button == this.Buttons.PLAY)
        highlight_button (this.Buttons.SEC_UP);
      else
        if (this.selected_button % 2 == 0)
          highlight_button (this.selected_button - 3);
        else
          highlight_button (this.selected_button - 2);
      break;
    case "Right":
      if (selected_button == this.Buttons.PLAY)
        highlight_button (this.Buttons.HOUR_UP);
      else
        if (this.selected_button % 2 == 0)
          highlight_button (this.selected_button + 1);
        else
          highlight_button (this.selected_button + 2);
      break;
    case "Up":
    case "plus":
      if (this.selected_button != this.Buttons.PLAY)
      {
        if (this.selected_button == this.Buttons.HOUR_UP || this.selected_button == this.Buttons.HOUR_DOWN)
        {
          highlight_button (this.Buttons.HOUR_UP);
          this.delay += 3600;
        }
        else if (this.selected_button == this.Buttons.MIN_UP || this.selected_button == this.Buttons.MIN_DOWN)
        {
          highlight_button (this.Buttons.MIN_UP);
          this.delay += 60;
        }
        else
        {
          highlight_button (this.Buttons.SEC_UP);
          this.delay++;
        }
        this.set_time_from_delay ();
      }
      break;
    case "Down":
    case "minus":
      if (this.selected_button != 0)
      {
        if (this.selected_button == this.Buttons.HOUR_UP || this.selected_button == this.Buttons.HOUR_DOWN)
        {
          highlight_button (this.Buttons.HOUR_DOWN);
          this.delay -= 3600;
        }
        else if (this.selected_button == this.Buttons.MIN_UP || this.selected_button == this.Buttons.MIN_DOWN)
        {
          highlight_button (this.Buttons.MIN_DOWN);
          this.delay -= 60;
        }
        else
        {
          highlight_button (this.Buttons.SEC_DOWN);
          this.delay--;
        }
        this.set_time_from_delay ();
      }
      break;
    default:
      break;
    }
    return false;
  }

  private bool on_button_release_event (Clutter.ButtonEvent event)
  {
    switch (event.source.name)
    {
      case "arrow_hour_up":
        this.delay += 3600;
        break;

      case "arrow_hour_down":
        this.delay -= 3600;
        break;

      case "arrow_min_up":
        this.delay += 60;
        break;

      case "arrow_min_down":
        this.delay -= 60;
        break;

      case "arrow_sec_up":
        this.delay++;
        break;

      case "arrow_sec_down":
        this.delay--;
        break;

      case "play":
        this.play ();
        return true;
    }

    this.set_time_from_delay ();
    return true;
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
    if (hours > 0)
      delay = hours * 3600;
    if (minutes > 0)
      delay = delay + minutes * 60;
    if (seconds > 0)
      delay = delay + seconds;
    if (delay == 0)
      delay = 10;

    message ("Delay set to %d seconds", delay);

    new Retroscope ();

    Gtk.main ();

    return 0;
  }
}
