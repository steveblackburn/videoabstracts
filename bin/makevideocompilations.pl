#!/usr/bin/perl -CS
#
# Script for making various compilations of videos, including a highlights
# video.
#
#
use strict;
use File::Temp qw(tempfile);
use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lib';
use FFmpeg qw(ffmpeg mp4fromstill concatmp4s xfade getformat);

use constant TITLEFIELD => 3;
use constant AUTHORFIELD => 4;

# videos to include in highlights
my @highlights = (73, 58, 115, 74, 236, 130, 279, 60, 92, 231);


my %title;
my %authors;
my %session;
my %talknumber;
my %sessionname;
my %sessioncolor;
my %sessionday;
my %sessionstart;
my %sessiontalklen;
my %talksinsession;
my %rowid;
my %days;

my $talks = shift @ARGV;
my $schedule = shift @ARGV;
my $sessions = shift @ARGV;
my $dest = shift @ARGV;
my $images = shift @ARGV;
my $format = shift @ARGV;

if ($talks eq "" || $schedule eq "" || $sessions eq "" || $dest eq "" || $images eq "" || $format eq "") {
  die "usage: $0  <conf-utf16.txt> <schedule.csv> <sessions.csv> <destdir> <images> [43|720p]\n";
}

if (!-e $talks) { die "Could not find $talks"; }
if (!-e $schedule) { die "Could not find $schedule"; }
if (!-e $sessions) { die "Could not find $sessions"; }
if (!-d $dest) { die "Could not find $dest"; }
if (!-d $images) { die "Could not find $images"; }
if (!(($format eq "720") || ($format eq "43"))) { die "Format must be 720 or 43, was $format"; }
my $size = ($format eq "43") ? "1280x960" : "1280x720";

getprogram($talks, $schedule, $sessions);

# make sessions
foreach my $s (sort { $a <=> $b} keys %sessionname) { 
  if ($s != 16) {
#    makesession($s, $dest, $images, $format);
  }
}

foreach my $d (sort keys %days) {
#  makeday($d, $dest, $images, $format);
}

# makeconf($dest, $images, $format, "pldi15");

if (@highlights) {
  makehighlights($dest, $images, $format, "$dest/highlights.mp4", @highlights);
}

exit(0);


# make conference
sub makeconf {
  my ($dest, $images, $format, $name) = @_;

  my $ommleadin = mp4fromstill("masters/omm-$size.png", 3);

  my @selection = ();
  foreach my $s (sort { $a <=> $b} keys %sessionname) {
    if ($s != 16) {
      push @selection, sprintf("$dest/s-%02d.mp4", $s);
    }
  }
  my $target = "$dest/$name.mp4";
  concatmp4s($target, $ommleadin, @selection);
}

sub makeday {
  my ($day, $dest, $images, $format) = @_;

  my $ommleadin = mp4fromstill("masters/omm-$size.png", 3);

  my @selection = ();
  foreach my $s (sort { $a <=> $b} keys %sessionname) {
    if ($sessionday{$s} eq $day && $s != 16) {
      push @selection, sprintf("$dest/s-%02d.mp4", $s);
    }
  }
  my $target = "$dest/omm-".(lc $day).".mp4";
  concatmp4s($target, $ommleadin, @selection);
}

sub makesession {
  my ($session, $dest, $images, $format) = @_;

  print "Creating session stream $session\n";
  my $sstr = sprintf("s-%02d", $session);
  my $target = sprintf("$dest/$sstr.mp4", $session);
  my $color = $sessioncolor{$session};
  my %talks = %{$talksinsession{$session}};

  my $ommleadin = mp4fromstill("masters/omm-$size-$color.png", 3);
  my $ssleadin = mp4fromstill("$images/$sstr-title-$format.png", 3);
  my $xf = xfade($ommleadin,$ssleadin, 0.5, 3, 3, $size);

  my @selection = ();
  foreach my $t (sort { $a <=> $b } keys %talks) {
    push @selection, $talks{$t};
  }
  concatmp4s($target, $xf, @{mp4sfortalks(@selection)});
}

sub makehighlights {
  my ($dest, $images, $format, $target, @selection) = @_;

  print "Creating highlights stream\n";
  my $leadin = mp4fromstill("masters/omm-$size.png", 3);
#  concatmp4s($target, $leadin, @{mp4sfortalks(@selection)});
  my $c = concatmp4s("", @{mp4sfortalks(@selection)});
  my ($x,$y,$duration,$meanvol,$maxvol,$mono) = getformat($c);

  xfade($leadin, $c, 0.5, 3, $duration, $size, $target);
}

sub mp4sfortalks {
  my (@talks) = @_;
  
  my @mp4s = ();
  foreach my $t (@talks) {
    push @mp4s, "$dest/$t.mp4";
  }

  return \@mp4s;
}





sub getprogram {
  my ($talks, $schedule, $sessions) = @_;

  # assumption that we're reading a utf16 saved from excel, after a hotcrp csv export...
  open my $talksfd, '<:encoding(UTF-16)', $talks or die "Could not open $talks";
  while (<$talksfd>) {
    chomp;
    my @lines = split /\r/;
    foreach my $l (@lines) {
      my @fields = split (/\t/, $l);
      my ($id) = $fields[0] =~ /-(\d+)$/;
      if ($id) {
	$title{$id} = $fields[TITLEFIELD];
	$authors{$id} = $fields[AUTHORFIELD];
      }
    }
  }
  close($talksfd);

  open my $schedulefd, '<', $schedule or die "Could not open $schedule";
  while (<$schedulefd>) {
    chomp;
    my @fields = split /,/;
    my ($id,$s,$n) = @fields;
    $id =~ s/.+[-]//g;
    $session{$id} = $s;
    $talknumber{$id} = $n;
    my %talks = ();
    if ($talksinsession{$s}) { %talks = %{$talksinsession{$s}}; }
    $talks{$n} = $id;
    $talksinsession{$s} = \%talks;
  }
  close ($schedulefd);

  open my $sessionsfd, '<', $sessions or die "Could not open $sessions";
  while (<$sessionsfd>) {
    chomp;
    my @fields = split /,/;
    my ($id,$n,$c,$d,$s,$l) = @fields;
    if ($id) {
    $sessionname{$id} = $n;
    $sessioncolor{$id} = $c;
    $sessionday{$id} = $d;
    $days{$d} = 1;
    $sessionstart{$id} = $s;
    $sessiontalklen{$id} = $l;
  }
  }
  close ($sessionsfd);
}

