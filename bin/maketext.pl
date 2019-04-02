#!/usr/bin/perl -CS
#
# This script generates text slides that are prepended to each video,
# identifying the session and the talk within the session.  This includes
# coloring the tracks as red or blue depending on which track the talk
# is in.
#
use strict;
use File::Temp qw(tempfile);

use constant PREFIX => "pldi15-";
use constant IDFIELD => 0;
#use constant SESSIONFIELD => 1;
#use constant TALKFIELD => 2;
use constant TITLEFIELD => 3;
use constant AUTHORFIELD => 4;
use constant FONT => "Helvetica-Bold";
use constant TITLEHEIGHT => 100;
use constant TITLESIZE => 40;
use constant AUTHORHEIGHT => 60;
use constant AUTHORSIZE => 24;
use constant FOOTERSIZE => 45;
use constant WIDTH => 1280;
use constant CONFLOGO => "pldi15logo80x80-clear.png";
use constant CONFLOGOSM => "pldi15logo50x50-clear.png";
use constant OMMLOGO => "omm-107x80-clear.png";
use constant OMMLOGOSM => "omm-67x50-clear.png";

my $talks = shift @ARGV;
my $schedule = shift @ARGV;
my $sessions = shift @ARGV;
my $aec = shift @ARGV;
my $masters = shift @ARGV;
my $dest = shift @ARGV;

if ($talks eq "" || $schedule eq "" || $sessions eq "" || $aec eq "" || $masters eq "" || $dest eq "") {
  die "usage: $0  <conf-utf16.txt> <schedule.csv> <sessions.csv> <aec.csv> <mastersdir> <destdir>\n";
}

if (!-e $talks) { die "Could not find $talks"; }
if (!-e $schedule) { die "Could not find $schedule"; }
if (!-e $sessions) { die "Could not find $sessions"; }
if (!-e $aec) { die "Could not find $aec"; }
if (!-d $dest) { die "No such directory $dest"; }
if (!-d $masters) { die "No such directory $masters"; }

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
my %aec;

getprogram($talks, $schedule, $sessions, $aec);

maketext($dest);

sub maketext {
  my ($dest) = @_;

  my @ids = (keys %title); #(113, 142); # 
  
if (0) {
  foreach my $id (@ids) {
    if ($id ne "") {
      makefooter($dest, $id, $sessioncolor{$session{$id}});
      makeheader($dest, $id, $sessioncolor{$session{$id}});
    }
  }
  foreach my $id (@ids) {
    if ($id ne "") {
      maketitle($dest, $id, $sessioncolor{$session{$id}});
    }    
  }
}
  foreach my $s (keys %sessioncolor) {
    print "-->$s<--\n";
    if ($s ne "" && $s ne 16) {
      makesessiontitle($dest, $s, $sessioncolor{$s});
    }
  }
}


sub makesessiontitle {
  my ($dir, $session, $color) = @_;

  my $files = "";
  my %ts = %{$talksinsession{$session}};
  my $firsttalk;
  foreach my $t (sort keys %ts) {
    my $i = $ts{$t};
    $files .= "$dir/$i-header-plain.png ";
    if (!$firsttalk) { $firsttalk = $i; }
  }

  my $prefix = sprintf("s-%02d", $session);
  
  my ($fh1, $n1) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -append $files $n1";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  # 720
  my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -size 1280x640 xc:$color $n2";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my ($fh3, $n3) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "composite -gravity center $n1 $n2 $n3";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my $imcmd = "convert -append $n3 $dir/$firsttalk-footer.png $dir/$prefix-title-720.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;


  # 4:3
  my ($fh4, $n4) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -size 1280x880 xc:$color $n4";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my ($fh5, $n5) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "composite -gravity center $n1 $n4 $n5";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my $imcmd = "convert -append $n5 $dir/$firsttalk-footer.png $dir/$prefix-title-43.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  close $fh1;
  close $fh2;
  close $fh3;
  close $fh4;
  close $fh5;

}


sub maketitle {
  my ($dir, $id, $color) = @_;

  my $files = "";
  my %ts = %{$talksinsession{$session{$id}}};
  foreach my $t (sort keys %ts) {
    my $i = $ts{$t};
    $files .= "$dir/$i-header".(($i ne $id) ? "-faint" : "-plain").".png ";
  }
  my ($fh1, $n1) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -append $files $n1";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  # 720
  my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -size 1280x640 xc:$color $n2";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my ($fh3, $n3) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "composite -gravity center $n1 $n2 $n3";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my $imcmd = "convert -append $n3 $dir/$id-footer.png $dir/$id-title-720.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;


  # 4:3
  my ($fh4, $n4) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -size 1280x880 xc:$color $n4";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my ($fh5, $n5) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "composite -gravity center $n1 $n4 $n5";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my $imcmd = "convert -append $n5 $dir/$id-footer.png $dir/$id-title-43.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  close $fh1;
  close $fh2;
  close $fh3;
  close $fh4;
  close $fh5;

}

sub makefooter {
  my ($dir, $id, $color) = @_;
  
  my $xconflogo = 80;
  my $xommlogo = 107;
  my $xname = (1280/2)-$xconflogo;
  my $xtime = (1280/2)-$xommlogo;

  # make session name
  my $sn = $sessionname{$session{$id}};
  my ($fh1, $n1) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -size ".$xname."x80 xc:none -fill white  -font ".FONT." -pointsize ".FOOTERSIZE." -gravity west -draw \"text 0,5 '  $sn'\" $n1";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  # make session time
  my $sd = $sessionday{$session{$id}};
  my $ss = $sessionstart{$session{$id}};
  my ($sh,$sm) = $ss =~ /(\d\d)(\d\d)/;
  my $tn = $talknumber{$id};
  my $tm = ($tn - 1) * $sessiontalklen{$session{$id}};
  $tm += $sm;
  $sh = sprintf("%02d", $sh+int($tm/60));
  $sm = sprintf("%02s", $tm % 60);
  my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $time = "$sd $sh:$sm";
  my $imcmd = "convert -size ".$xtime."x80 xc:none -fill white  -font ".FONT." -pointsize ".FOOTERSIZE." -gravity east -draw \"text 0,5 '  $time  '\" $n2";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;


  # make 4:3 footer
  my ($fh3, $n3) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert +append $masters/".CONFLOGO." $n1 $n2 $masters/".OMMLOGO." $n3";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my ($fh4, $n4) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert -size 1280x80 xc:$color $n4";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  $imcmd = "composite $n3 $n4 $dir/$id-footer.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  $imcmd = "composite -blend 50 -gravity north $masters/bot-shadow-1280x70.png $dir/$id-footer.png $dir/$id-footer-shadow.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;


  # make 720 footer
  my ($fh6, $n6) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert $n1 -resize 1280x50 $n6";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  my ($fh7, $n7) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert +append $masters/".CONFLOGOSM." $n6 $n7";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
 
  my ($fh8, $n8) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert $n2 -resize 1280x50 $n8";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  my ($fh9, $n9) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert +append $n8 $masters/".OMMLOGOSM." $n9";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  my ($fh10, $n10) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert -size 1280x50 xc:$color $n10";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  my ($fh11, $n11) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "composite -gravity west $n7 $n10 $n11";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  my ($fh12, $n12) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "composite -gravity east $n9 $n11 $n12";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;


  # make text
  my $tps = 14;
  my $aps = 9;
  my $fw = 640;
  my $t = titlestring($title{$id}, "-font ".FONT." -pointsize $tps", ($fw*0.95));
  my $a = authorstring($authors{$id}, "-font ".FONT." -pointsize $aps", ($fw*0.7));

  # white title
  my ($fh13, $n13) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -background none -fill white -font ".FONT." -pointsize $tps -size ".$fw."x33 -gravity south label:'$t' $n13";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my ($fh2, $n14) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert -background none -fill white -font ".FONT." -pointsize $aps -size ".$fw."x17 -gravity center label:'$a' $n14";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  my ($fh15, $n15) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert -append $n13 $n14 $n15";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  if ($aec{$id}) {
    $imcmd = "composite -gravity southeast $masters/aec-badge-pldi-30x30-clearbg.png $n15 $dir/$id-footertext.png";
  } else {
    $imcmd = "cp $n15 $dir/$id-footertext.png";
  }
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;


  close $fh1;
  close $fh2;
  close $fh3;


  $imcmd = "composite -gravity center $dir/$id-footertext.png $n12 $dir/$id-footer-720.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  $imcmd = "composite -blend 50 -gravity north $masters/bot-shadow-1280x70.png $dir/$id-footer-720.png $dir/$id-footer-720-shadow.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  close $fh1;
  close $fh2;
  close $fh3;
  close $fh4;
#  close $fh5;
  close $fh6;
  close $fh7;
  close $fh8;
}

sub makeheader {
  my ($dir, $id, $color) = @_;
  
  # make text
  my $t = titlestring($title{$id}, "-font ".FONT." -pointsize ".TITLESIZE, 1280);
  my $a = authorstring($authors{$id}, "-font ".FONT." -pointsize ".AUTHORSIZE, 1280);

  makeheadertxtimage($dir, $id, "white", $color, $t, $a);
}

sub makeheadertxtimage {
  my ($dir, $id, $txtcolor, $bgcolor, $title, $authors) = @_;

  
  # white title
  my ($fh1, $n1) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  my $imcmd = "convert -background none -fill $txtcolor -font ".FONT." -pointsize ".TITLESIZE." -size ".WIDTH."x".TITLEHEIGHT." -gravity south label:'$title' $n1";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
  
  my ($fh2, $n2) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  
  $imcmd = "convert -background none -fill $txtcolor -font ".FONT." -pointsize ".AUTHORSIZE." -size ".WIDTH."x".AUTHORHEIGHT." -gravity center label:'$authors' $n2";
#  print "====>$imcmd<====\n";
#  print "====>".encode_utf8($authors)."<====>".decode( 'iso-8859-1', $authors )."<======>".$authors."<===\n";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  my ($fh3, $n3) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert -append $n1 $n2 $n3";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  if ($aec{$id}) {
    $imcmd = "composite -gravity southeast $masters/aec-badge-pldi-66x66-clearbg.png $n3 $dir/$id-headertext.png";
  } else {
    $imcmd = "cp $n3 $dir/$id-headertext.png";
  }
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;


  close $fh1;
  close $fh2;

  my ($fh4, $n4) = tempfile ( CLEANUP => 1 , SUFFIX => '.png');
  $imcmd = "convert -size 1280x160 xc:$bgcolor $n4";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
 
  $imcmd = "composite -blend 40 $n3 $n4 $dir/$id-header-faint.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  $imcmd = "composite $n3 $n4 $dir/$id-header-plain.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  $imcmd = "composite $dir/$id-headertext.png $n4 $dir/$id-header.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;

  $imcmd = "composite -blend 50 -gravity south $masters/top-shadow-1280x50.png $dir/$id-header.png $dir/$id-header-shadow.png";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  close $imfd;
}

sub titlestring {
  my ($title, $font, $width) = @_;
  $title =~ s/'/'\\\''/g;
  $title =~ s/"//g;
  my $tot = gettextwidth($title, $font);
  my $max = (($tot > $width) ? (0.66 * $tot) : $width);
  my @words = split(/ /, $title);
  my $str = "";

  foreach my $w (@words) {
    my $x = gettextwidth($str.$w, $font);
    if ($x > $max) {
      $str .= '\n';
    } elsif ($str ne "") {
      $str .= " ";
    }
    $str .= $w;
  }
  return $str;
}

sub authorstring {
  my ($authors, $font) = @_;
  $authors =~ s/'/'\\\''/g;
  my $str = $authors;
  $str =~ s/; /    /g;
  my $tot = gettextwidth($str, $font);
  my $max = ($tot > 1200) ? (0.66 * $tot) : 1200;
  $str = "";

  my @names = split(/; /, $authors);
  foreach my $a (@names) {
    my $w = gettextwidth($str.$a, $font);
    if ($w > $max) {
      $str .= '\n';
    } elsif ($str ne "") {
      $str .= "    ";
    }
    $str .= $a;
  }
  return $str;
}

sub gettextwidth {
  my ($string, $font) = @_;
  
  my $width = -1;

  my $imcmd = "convert -debug annotate  xc: $font -annotate 0 '$string' null: 2>&1";
  open my $imfd, '-|', $imcmd or die "Could not run command: $imcmd";
  while (<$imfd>) {
    if (/Metrics:/) {
      ($width) = / width: (\S+);/;
    }
  }
  close $imfd;
  return $width;
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
    $sessionname{$id} = $n;
    $sessioncolor{$id} = $c;
    $sessionday{$id} = $d;
    $sessionstart{$id} = $s;
    $sessiontalklen{$id} = $l;
  }
  close ($sessionsfd);

  open my $aecfd, '<', $aec or die "Could not open $aec";
  while (<$aecfd>) {
    chomp;
    if ($_ ne "") { $aec{$_} = 1; }
  }
}
