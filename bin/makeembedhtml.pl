#!/usr/bin/perl -CS
#
# Generate an embeddable html fragment for each video.
#
# The script takes the conference program as a csv exported from hotcrp
# (note that it is utf16, as titles and authors may contain utf16 characters).
# To do this: in hotcrp, search for accepted papers, then select them all,
# then download "ACM CMS csv". The open the file in excel (or similar), then
# save as UTF-16 txt (which is tab-delimited).
#
# The glog input file is a log of google drive, which allows scripting of the
# hashes used by google drive, which we need to script the generation of links.
# The file looks like row pairs of this form:
#
# [15-06-07 21:30:22:503 AEST] 720p/60.mp4
# [15-06-07 21:30:22:504 AEST] 0B7iRCsp7iT4xLXlEUUZ1SHRvWTg
# [15-06-07 21:30:22:505 AEST] 720p/58.mp4
# [15-06-07 21:30:22:505 AEST] 0B7iRCsp7iT4xV2dydmdBTFZLR0k
#
# The first row gives the file name (including google drive subdirectory)
# the second row in each pair gives the hash.
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
my $glog = shift @ARGV;

if ($talks eq "" || $schedule eq "" || $sessions eq "" || $glog eq "") {
  die "usage: $0  <conf-utf16.txt> <schedule.csv> <sessions.csv> <google.log>\n";
}

if (!-e $talks) { die "Could not find $talks"; }
if (!-e $schedule) { die "Could not find $schedule"; }
if (!-e $sessions) { die "Could not find $sessions"; }
if (!-e $glog) { die "Could not find $glog"; }

getprogram($talks, $schedule, $sessions);
readglog($glog);

foreach my $s (sort { $a <=> $b} keys %sessionname) {
  print $sessionday{$s}."\t$sessionname{$s}\n";
  if ($talksinsession{$s}) {
    my %talks = %{$talksinsession{$s}};
    foreach my $t (sort { $a <=> $b } keys %talks) {
      my $p = $talks{$t};
      print substr($title{$p}, 0, 40)."...  ($sessionname{$s})\n";
      my $t = substr($title{$p}, 0, 20)."...";
      print "$p\t$title{$p} (PLDI'15)\n";
      print "$p\t$t\t<iframe src=\"https://docs.google.com/file/d/".$rowid{$p}."/preview\" width=\"640\" height=\"480\"></iframe>\n";
    }
  }
}

sub readglog {
  my ($glog) = @_;
  open my $gfd, '<', $glog or die "Could not open $glog";
  my $id;
  while (<$gfd>) {
    chomp;
    if (/.mp4/) {
      my $f = GDRIVE_FOLDER;
      ($id) = /\[.+\]\s+$f\/(\d+).mp4/;
    } elsif ($id) {
      my ($rid) = /\[.+\]\s+(\S+)/;
      $rowid{$id} = $rid;
      undef $id;
    }
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
    $sessionstart{$id} = $s;
    $sessiontalklen{$id} = $l;
  }
  }
  close ($sessionsfd);
}

