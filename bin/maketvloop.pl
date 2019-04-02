#!/usr/bin/perl -CS
#
# Script for generating day-long videos that can be shown continuously,
# With appropriate videos shown at the right time.
#
use strict;
use File::Temp qw(tempfile);

use constant GDRIVE_FOLDER => "720p";
use constant PREFIX => "pldi15-";
use constant IDFIELD => 0;
#use constant SESSIONFIELD => 1;
#use constant TALKFIELD => 2;
use constant TITLEFIELD => 3;
use constant AUTHORFIELD => 4;
use constant MP4_FLAGS => "-preset fast -crf 18 "; # https://trac.ffmpeg.org/wiki/Encode/H.264 https://www.ffmpeg.org/faq.html#Which-are-good-parameters-for-encoding-high-quality-MPEG_002d4_003f

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
my %duration;
my %sessionts;

my $talks = shift @ARGV;
my $schedule = shift @ARGV;
my $sessions = shift @ARGV;
my $dest = shift @ARGV;

if ($talks eq "" || $schedule eq "" || $sessions eq "" || $dest eq "") {
  die "usage: $0  <conf-utf16.txt> <schedule.csv> <sessions.csv> <destdir>\n";
}

if (!-e $talks) { die "Could not find $talks"; }
if (!-e $schedule) { die "Could not find $schedule"; }
if (!-e $sessions) { die "Could not find $sessions"; }
if (!-d $dest) { die "Could not find $dest"; }
my $size = "1280x720";

getprogram($talks, $schedule, $sessions);

processsessions($dest);

my $daystart = 8; # 8 am
my $dayend = 18; # 6 pm
my $presession = 16; # 16 min before
my $postsession = 100; # 100 min after

foreach my $d (sort keys %days) {
  print "===$d $dest===\n";
  makedaynew($d, $dest);
}

#makeconf($dest, $images, $format);


#
#  play vids for current session during that session and 20 mins beforehand, otherwise loop through all sessions.
#
sub makedaynew {
  my ($day, $dest) = @_;

  my $loopidx = 1;
  # move to first session in day
  my $nextsession = 1;
  while ($sessionday{$nextsession} ne $day && $sessionday{$nextsession}) { $nextsession++; }
  my $time = $daystart * 60 * 60;

  my $files = "";

  print "--$nextsession---$time---".(($dayend * 60 * 60))."---\n";

  while ($nextsession < 16 && $time < ($dayend * 60 * 60)) {
    my $h = int($sessionstart{$nextsession}/100);
    my $m = int($sessionstart{$nextsession}%100);
    my $ss = 60*($m+(60*$h)-$presession);

    print "--$nextsession---$time---$h:$m---$ss---".(($dayend * 60 * 60))."---\n";

    # loop through all sessions
    my $stop = ($time < $ss) ? $ss : ($dayend * 60 * 60);
    while ($time < $stop) {
      printf("%02d:%02d--%d--%s--%.2f\n", int($time/(60*60)), (int($time/60) % 60), $loopidx, $sessionname{$loopidx}, $duration{$loopidx});
      $files .= ($files ne "" ? "|" : "").$sessionts{$loopidx};  # add the video

      $time += $duration{$loopidx};
      $loopidx++;
      if (!$duration{$loopidx}) {
	$loopidx = 1;
      }
    }
    print "---\n";
    
    my $se = $ss + (($presession+$postsession) * 60);

    # loop through current sessions
    my $t = $sessionstart{$nextsession};
    my $first = $nextsession;
    my $i = $nextsession;
    while ($time < $se) {
      printf("%02d:%02d %s %.1f\n", int($time/(60*60)), (int($time/60) % 60), $sessionname{$i}, $duration{$i});
      $files .= ($files ne "" ? "|" : "").$sessionts{$i};  # add the video
      $time += $duration{$i};

      if ($sessionstart{++$i} != $t) {
	$i = $first;
      }
    }
    while ($sessionstart{++$nextsession} == $t) {}
  }

  # concatenate 
  print "Concatenating...\n";
  my ($fh, $n) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -i \"concat:$files\" -c copy -bsf:a aac_adtstoasc $n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  # re-sync audio
  print "Resyncing...\n";
  my $target = "$dest/".(lc $day).".mp4";
  my $ffcmd = "ffmpeg -y -i $n -i $n -af \"aresample=async=1\" -c:v copy -c:a aac -strict experimental ".MP4_FLAGS." $target";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;
}

sub processsessions {
  my ($dest) = @_;

  print "Extracting session durations..\n";
  # get the video length
  for my $s (keys %sessionname) {
    if ($s != 16) {
      my $in = sprintf("s-%02d.mp4", $s);
      my ($x,$y,$len,$meanvol,$maxvol) = getformat("$dest/$in");
      $duration{$s} = $len;
      print "$in $len\n";

      # make the .ts file here
      my ($fh, $n) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
      my $ffcmd = "ffmpeg -y -i $dest/$in -c copy -bsf:v h264_mp4toannexb -f mpegts $n";
      print "running $ffcmd...\n";
      open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
      close $fffd;
      $sessionts{$s} = $n;
    }
  }

}

# make conference
sub makeconf {
  my ($dest, $images, $format) = @_;

  # one minute madness still
  my ($fh1, $n1) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -ar 48000 -ac 2 -f s16le -i /dev/zero -t 3 -loop 1 -i masters/omm-$size.png -c:v libx264 -tune stillimage -strict experimental -pix_fmt yuv420p -shortest $n1";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
  my $ffcmd = "ffmpeg -y -i $n1 -c copy -bsf:v h264_mp4toannexb -f mpegts $n2";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

#  my $files = "masters/rabbit-lead-$format-1.ts|$n2";
#  my $files = "masters/redrabbit-lead-$format-1.ts|$n2";
  my $files = "";

  foreach my $s (sort { $a <=> $b} keys %sessionname) {
    my $sstr = sprintf("s-%02d", $s);
    my $n = sprintf("$dest/$sstr.mp4", $s);
    my ($fh3, $n3) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
    my $ffcmd = "ffmpeg -y -i $n -c copy -bsf:v h264_mp4toannexb -f mpegts $n3";
    print "running $ffcmd...\n";
    open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
    close $fffd;
    if ($files eq "") { $files = "$n3"; } else { $files .= "|$n3"; }
  }


  # concatenate 
  my ($fh8, $n8) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -i \"concat:$files\" -c copy -bsf:a aac_adtstoasc $n8";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  # re-sync audio
  my $target = "$dest/pldi15.mp4";
  my $ffcmd = "ffmpeg -y -i $n8 -i $n8 -af \"aresample=async=1\" -c:v copy -c:a aac -strict experimental ".MP4_FLAGS." $target";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;
}



# make days
sub makeday {
  my ($day, $dest, $images, $format) = @_;

  # one minute madness still
  my ($fh1, $n1) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -ar 48000 -ac 2 -f s16le -i /dev/zero -t 3 -loop 1 -i masters/omm-$size.png -c:v libx264 -tune stillimage -strict experimental -pix_fmt yuv420p -shortest $n1";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
  my $ffcmd = "ffmpeg -y -i $n1 -c copy -bsf:v h264_mp4toannexb -f mpegts $n2";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

#  my $files = "masters/rabbit-lead-$format-1.ts|$n2";
#  my $files = "masters/redrabbit-lead-$format-1.ts|$n2";
  my $files = "";

  foreach my $s (sort { $a <=> $b} keys %sessionname) {
    if ($sessionday{$s} eq $day && $s != 16) {
      my $sstr = sprintf("s-%02d", $s);
      my $n1 = sprintf("$dest/$sstr.mp4", $s);
      my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
      my $ffcmd = "ffmpeg -y -i $n1 -c copy -bsf:v h264_mp4toannexb -f mpegts $n2";
      print "running $ffcmd...\n";
      open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
      close $fffd;
      if ($files eq "") { $files = "$n2"; } else { $files .= "|$n2"; }
    }
  }


  # concatenate 
  my ($fh8, $n8) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -i \"concat:$files\" -c copy -bsf:a aac_adtstoasc $n8";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  # re-sync audio
  my $target = "$dest/omm-".(lc $day).".mp4";
  my $ffcmd = "ffmpeg -y -i $n8 -i $n8 -af \"aresample=async=1\" -c:v copy -c:a aac -strict experimental ".MP4_FLAGS." $target";
  print "running $ffcmd...\n";
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
  my $ffcmd = "ffmpeg -y -ar 48000 -ac 2 -f s16le -i /dev/zero -t 3 -loop 1 -i masters/omm-$size-$color.png -c:v libx264 -tune stillimage -strict experimental -pix_fmt yuv420p -shortest $n1";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  # session still
  my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -ar 48000 -ac 2 -f s16le -i /dev/zero -t 3 -loop 1 -i $images/$sstr-title-$format.png -c:v libx264 -tune stillimage -strict experimental -pix_fmt yuv420p -shortest $n2";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  if (0) {
  # crossfade
  my ($fh3, $n3) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -i $n1 -i $n2 -f lavfi -i color=black:size=$size -filter_complex \"[0:v]format=pix_fmts=yuva420p,fade=t=out:st=2.5:d=0.5:alpha=1,setpts=PTS-STARTPTS[va0]; [1:v]format=pix_fmts=yuva420p,fade=t=in:st=0:d=0.5:alpha=1,setpts=PTS-STARTPTS+2.5/TB[va1]; [2:v]scale=$size,trim=duration=5.5[over]; [over][va0]overlay[over1]; [over1][va1]overlay=format=yuv420[outv]\" -vcodec libx264 -map [outv] $n3";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  my ($fh4, $n4) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -i $n3 -i silence-60.mp4 -c:v libx264 -c:a aac -strict experimental -b:a 192k -pix_fmt yuv420p -shortest $n4";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;
} 

  # concatenate leadin and all videos in session

  # create stream for leadin
  my ($fh5, $n5) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
  my $ffcmd = "ffmpeg -y -i $n2 -c copy -bsf:v h264_mp4toannexb -f mpegts $n5";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;
  
#  $files = "masters/".$color."rabbit-lead-$format-1.ts|$n5";
  $files = "";

  my %talks = %{$talksinsession{$session}};

  foreach my $t (sort { $a <=> $b } keys %talks) {
    my $p = $talks{$t};

    # create stream for talk
    my ($fh, $n) = tempfile ( CLEANUP => 1 , SUFFIX => '.ts');
    my $ffcmd = "ffmpeg -y -i $dest/$p.mp4 -c copy -bsf:v h264_mp4toannexb -f mpegts $n";
    print "running $ffcmd...\n";
    open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
    close $fffd;
    if ($files ne "") { $files .= "|"; }
    $files .= "$n";
  }

#  $files .= "|masters/rabbit-lead-$format-1.ts";

  my ($fh6, $n6) = tempfile ( CLEANUP => 1 , SUFFIX => '.mp4');
  my $ffcmd = "ffmpeg -y -i \"concat:$files\" -c copy -bsf:a aac_adtstoasc $n6";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  # re-sync audio
  my $target = sprintf("$dest/$sstr.mp4", $session);
  my $ffcmd = "ffmpeg -y -i $n6 -i $n6 -af \"aresample=async=1\" -c:v copy -c:a aac -strict experimental ".MP4_FLAGS." $target";
  print "running $ffcmd...\n";
  open my $fffd, '-|', $ffcmd or die "Could not run command: $ffcmd";
  close $fffd;

  close $fh1;
  close $fh2;
#  close $fh3;
#  close $fh4;
#  close $fh5;
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

sub getformat {
  my ($file) = @_;

  my $x;
  my $y;
  my $duration;
  my $meanvol;
  my $maxvol;

  open my $fffd, '-|', "ffmpeg -i $file -af \"volumedetect\" -f null /dev/null  2>&1" or die "Could not run ffmpeg on $file";
  while (<$fffd>) {
    chomp;
    if (/Video: /) {
      ($x,$y) = /.*? (\d+)x(\d+)[ ,].*/;
    } elsif (/Duration/) {
      my ($h,$m,$s) = /.*?(\d\d):(\d\d):(\d\d.\d\d).*/;
      $duration = $s+(60*($m+(60*$h)));
    } elsif (/mean_volume:/) {
      ($meanvol) = /.*mean_volume:\s+(\S+)\s+dB/;
    } elsif (/max_volume:/) {
      ($maxvol) = /.*max_volume:\s+(\S+)\s+dB/;
    }
  }
  close $fffd;
  if ($x eq "" || $y eq "") {
    die "Could not extract resolution from $file";
  }
  if ($duration eq "") {
    die "Could not extract duration from $file";
  }
  if ($meanvol eq "" || $maxvol eq "") {
    warn "Could not extract volume from $file";
  }
  return ($x, $y, $duration, $meanvol, $maxvol);
}
