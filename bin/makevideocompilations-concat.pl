#!/usr/bin/perl -CS

use strict;
use File::Temp qw(tempfile);

use constant GDRIVE_FOLDER => "720p";
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
if (!($format eq "720") || ($format eq "43")) { die "Format must be 720p or 43, was $format"; }

getprogram($talks, $schedule, $sessions);

# make sessions
foreach my $s (sort { $a <=> $b} keys %sessionname) { 
  if ($s == 1) {
    print "==>$s<==$sessionname{$s}\n";
    makesession($s, $dest, $images, $format);
  }
}

foreach my $d (sort values %sessionday) {
  if ($d ne "Monday") {
#    makeday($d, $dest, $images, $format);
  }
}

# make days
sub makeday {
  my ($day, $dest, $images, $format) = @_;


  my $files = "";

  foreach my $s (sort { $a <=> $b} keys %sessionname) {
    if ($sessionday{$s} eq $day && $s != 16) {
      my ($fh1, $n1) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
      makesession($s, $dest, $images, $format, $n1);
      my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
      my $ffcmd = "ffmpeg -y -i $n1 -c copy -bsf:v h264_mp4toannexb -f mpegts $n2";
      print "running $ffcmd...\n";
      open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
      close $fffd;
      if ($files eq "") { $files = "$n2"; } else { $files .= "|$n2"; }
    }
  }

  my $target = "$dest/omm-".(lc $day).".mp4";
  my $ffcmd = "ffmpeg -y -i \"concat:$files\" -c copy -bsf:a aac_adtstoasc $target";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;
}

sub makesession {
  my ($session, $dest, $images, $format, $target) = @_;

  print "Creating session stream $session\n";
  my $sstr = sprintf("s-%02d", $session);
  if ($target eq "") { 
    $target = sprintf("$dest/$sstr.mp4", $session);
  }

  my $files;
  # create session lead-in
  my $color = $sessioncolor{$session};
 
  # one minute madness still
  my ($fh1, $n1) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -ar 48000 -ac 2 -f s16le -i /dev/zero -t 3 -loop 1 -i masters/omm-1280x720-".$color.".png -c:v libx264 -tune stillimage -strict experimental -pix_fmt yuv420p -shortest $n1";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  # session still
  my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -ar 48000 -ac 2 -f s16le -i /dev/zero -t 3 -loop 1 -i $images/$sstr-title-$format.png -c:v libx264 -tune stillimage -strict experimental -pix_fmt yuv420p -shortest $n2";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  # crossfade
  my ($fh3, $n3) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -i $n1 -i $n2 -f lavfi -i color=black:size=1280x720 -filter_complex \"[0:v]format=pix_fmts=yuva420p,fade=t=out:st=2.5:d=0.5:alpha=1,setpts=PTS-STARTPTS[va0]; [1:v]format=pix_fmts=yuva420p,fade=t=in:st=0:d=0.5:alpha=1,setpts=PTS-STARTPTS+2.5/TB[va1]; [2:v]scale=1280x720,trim=duration=5.5[over]; [over][va0]overlay[over1]; [over1][va1]overlay=format=yuv420[outv]\" -vcodec libx264 -map [outv] $n3";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  my ($fh4, $n4) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -i $n3 -i silence-60.mp4 -c:v libx264 -c:a aac -strict experimental -b:a 192k -pix_fmt yuv420p -shortest $n4";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  # concatenate leadin and all videos in session

  # create stream for leadin
  my ($fh5, $n5) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
  my $ffcmd = "ffmpeg -y -i $n4 -c copy -bsf:v h264_mp4toannexb -f mpegts $n5";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;
  
  $files = "masters/".$color."rabbit-lead-720-1.ts|$n5";

  my %talks = %{$talksinsession{$session}};
  foreach my $t (sort { $a <=> $b } keys %talks) {
    my $p = $talks{$t};

    # create stream for talk
    my ($fh, $n) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
    my $ffcmd = "ffmpeg -y -i $dest/$p.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts $n";
    print "running $ffcmd...\n";
    open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
    close $fffd;
    if ($files eq $n5) { $files = "$n|$n5"; }
    $files .= "|$n";
  }

  my $ffcmd = "ffmpeg -y -i \"concat:$files\" -c copy -bsf:a aac_adtstoasc $target";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  close $fh1;
  close $fh2;
  close $fh3;
  close $fh4;
  close $fh5;
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
    $sessionstart{$id} = $s;
    $sessiontalklen{$id} = $l;
  }
  }
  close ($sessionsfd);
}

