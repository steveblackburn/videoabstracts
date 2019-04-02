#!/usr/bin/perl
#
# Make all of the videos
#
use strict;
use File::Temp qw(tempfile);

use constant PREFIX => "pldi15-";
use constant IDFIELD => 0;
#use constant SESSIONFIELD => 1;
#use constant TALKFIELD => 2;
use constant TITLEFIELD => 3;
use constant AUTHORFIELD => 4;

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
my $norm = shift @ARGV;
my $dest = shift @ARGV;
my $images = shift @ARGV;
my $format = shift @ARGV;
my $day = shift @ARGV;
my $announce = shift @ARGV;

my $announcepng;

if ($norm eq "" || $talks eq "" || $schedule eq "" || $sessions eq "" || $dest eq "" || $images eq "" || $format eq "" || ($day ne "" && $announce eq "")) {
  die "usage: $0 <conf-utf16.txt> <schedule.csv> <sessions.csv> <normdir> <destdir> <images> <43|720p> [day announce]\n";
}

if (!-e $talks) { die "Could not find $talks"; }
if (!-e $schedule) { die "Could not find $schedule"; }
if (!-e $sessions) { die "Could not find $sessions"; }
if (!-d $dest) { die "Could not find $dest"; }
if (!-d $images) { die "Could not find $images"; }
if (!(($format eq "720p") || ($format eq "43"))) { die "Format must be 720p or 43, was $format"; }
my $size = ($format eq "43") ? "1280x960" : "1280x720";

getprogram($talks, $schedule, $sessions);

if ($day ne "") {
  if ($days{$day} eq "") { die "No talks on $day\n"; }
  
  my $fh;
  ($fh, $announcepng) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -background black -fill grey -font Helvetica-Bold -pointsize 30 -size $size -gravity south label:'$announce' $announcepng";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
}

opendir (DIR, $norm) or die $!;

while (my $file = readdir(DIR)) {
  my ($id) = $file =~ /(.+).mp4/;
  
  if ($id ne ""  && ($day eq "" || ($sessionday{$session{$id}} eq $day))) { #== 61 || $id == 134 || $id == 196) {
    my $cmd = "bin/makevideo.pl $norm/$file $dest $format $images ".(($day ne "") ? $announcepng : "");
    print "$cmd\n";
    open my $cmdfd, '-|', $cmd or die "Could not run command: $cmd";
    while (<$cmdfd>) {};
    close $cmdfd;
  }
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
