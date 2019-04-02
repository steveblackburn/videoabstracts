#!/usr/bin/perl
#
# This script creates 4:3 and 720p - formatted versions of a given input
# video with a lead-in that states the session etc of the video.
#
use strict;
use File::Temp qw(tempfile);

use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lib';
use FFmpeg qw(ffmpeg mp4fromstill concatmp4s xfade blankmp4 overlayimage overlayvideo rescale getformat);

my $leadin = 2.0;
my $crossfade = 0.5;
my $captiontime43 = 15;
my $captiontime720 = 20;
my $captionxfade = 2.5;
my $announcetime = 15;


#
# convert -background black -fill grey -font Helvetica-Bold -pointsize 30 -size 1280x960 -gravity south label:'Vote now: http://goog.le/ASDFX' foo.png
#

my $in = shift @ARGV;
my $dest = shift @ARGV;
my $format = shift @ARGV;
my $images = shift @ARGV;
my $announce = shift @ARGV;

if ($in eq "" || $dest eq "" || ($format ne "43" && $format ne "720p") || $images eq "") {
  die "usage: $0  <in.mp4> <destdir> [43|720p] <imagesdir>\n";
}

if (!-e $in) { die "No such input file $in"; }
my ($id) = $in =~ /\/(\d+).mp4/;
if ($id eq "") { die "Could not extract id from $in"; }
if (!-d $images) { die "No such directory $images"; }
if (!-d $dest) { die "No such directory $dest"; }
if ($announce ne "") {
  if (!-e $announce) { die "No such file $announce"; }
} else {
  $announcetime = 0;
}

my ($x,$y,$len,$meanvol,$maxvol) = getformat($in);

if ($format eq "43") {
  make43($id, $dest, $len);
} else {
  make720($id, $dest, $len);
}

exit(0);

#
# make 4:3 format annotated video
#
sub make43 {
  my ($id, $dest, $len) = @_;

  my $d = "$dest/$id.mp4";
  my $size = "1280x960";

  # create a leadin (talk title and session)
  my $leadin = mp4fromstill("$images/$id-title-43.png", 3);

  # create the caption with fade in
  my $lead = blankmp4(($len - ($captiontime43 + $announcetime)), $size);
  if ($announcetime > 0) {
    my $a = mp4fromstill($announce, $captiontime43);
    $lead = xfade($lead, $a, $captionxfade, ($len - ($captiontime43 + $announcetime)), $announcetime, $size);
  }
  my $caption = overlayimage(blankmp4($captiontime43, $size), "$images/$id-header-shadow.png", 0, 0);
  $caption = overlayimage($caption, "$images/$id-footer-shadow.png", 0, 880);
  my $xf = xfade($lead, $caption, $captionxfade, ($len - $captiontime43), $captiontime43, $size);

  # overlay the original video on top of caption
  my $x = overlayvideo($xf, $in, $size, 0, 160);

  # cross-fade leadin with captioned video
  my $xf = xfade($leadin,$x, 0.5, 3, $len, $size, $d);
}

#
# make 720p format annotated video
#
sub make720 {
  my ($id, $dest, $len) = @_;

  my $d = "$dest/$id.mp4";
  my $size = "1280x720";

  # create a leadin (talk title and session)
  my $leadin = mp4fromstill("$images/$id-title-720.png", 3);

  # create the caption with fade in
  my $blank = blankmp4(($len - $captiontime720), $size);
  my $caption = overlayimage(blankmp4($captiontime720, $size), "$images/$id-footer-720-shadow.png", 0, 670);
  my $xf = xfade($blank, $caption, $captionxfade, ($len - $captiontime720), $captiontime720, $size);

  # overlay the original video on top of caption
  my $ol = rescale($in, 1280, 670);
  my $x = overlayvideo($xf, $ol, $size, 0, 0);

  # cross-fade leadin with captioned video
  my $xf = xfade($leadin,$x, 0.5, 3, $len, $size, $d);
}
