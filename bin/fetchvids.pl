#!/usr/bin/perl
#
# This script will take as input a tab-separated file (tsv) produced by
# google forms (or any other tool), and then will fetch each of the
# videos, writing them into the directory specified as the second argument.
#
# The format of the tsv file is:
# <timestamp> <paper number> <poster?> <video url> <email>
#
use strict;
use File::stat;

my $tsv = shift @ARGV;
my $dir = shift @ARGV;


if ($tsv eq "" || $dir eq "") {
  die "usage: $0  <videos.tsv> <videodir>\n";
}

if (!-e $tsv) { die "Could not find $tsv"; }
if (!-d $dir) { die "No such directory $dir"; }

getvids(geturls($tsv), $dir);

sub getvids {
  my ($u, $videodir) = @_;
  my %urls = %{$u};

  my @submissions = keys %urls;

  foreach my $k (sort { $a <=> $b} @submissions) {
    my $get = checkhdr($urls{$k}, $videodir, $k);

    if ($get) {
      my ($fmt) = $urls{$k} =~ /[.](\w+)$/;
      if ($fmt eq "") {
	$fmt = "???";
      }

      my $rawname = "$k.$fmt";
      my $curl = "curl --location --silent --remote-time --time-cond $videodir/$rawname --output $videodir/$rawname \"".$urls{$k}."\"";
      print "Downloading with $curl\n";
      open my $curlfd, '-|', $curl or die "Could not get video ".$urls{$k};
      print "Downloading $k $urls{$k}";
      close $curlfd;
      print "...done\n";
      checkforgoogleoversize("$videodir/$rawname", $urls{$k}, $videodir);
    }
  }
}

sub checkforgoogleoversize {
  my ($result, $url, $videodir) = @_;
  
  my $sb = stat($result);
  if (!($sb)) {
    warn "WARNING: problem with stat for file $result, $url\n";
  } elsif ($sb->size < 100000) {  # not a video
    warn "WARNING: could not extract download link for file $result, $url\n";
  }
}

sub checkhdr {
  my ($url, $videodir, $k) = @_;

  my @tags = ("ETag:", "Content-Length:", "Last-Modified:");

  open my $curlfd, '-|', "curl --silent --location --head \"".$url."\"" or die "Could not get header for video ".$url;
  print "Checking header for $k $url\n";
  my %newhdr = ();
  while (<$curlfd>) {
    chomp;
    for my $t (@tags) {
      if (/$t/) { ($newhdr{$t}) = /\s*$t\s+(\S.+\S)\s*$/; }
    }
  }
  close $curlfd;

  my $hdrname = ".$k.txt";
  my %oldhdr = ();
  my $get = 1;
  if (-e "$videodir/$hdrname") {
    open my $hdrfd, '<', "$videodir/$hdrname";
    while (<$hdrfd>) {
      chomp;
      my ($k, $v) = /\s*(\S+:)\s+(\S.+\S)\s*$/;
      $oldhdr{$k} = $v;
    }
    close $hdrfd;
    if ((keys %newhdr) == (keys %oldhdr)) {
      my $match = 1;
      foreach my $k (keys %newhdr) {
	print "==$oldhdr{$k}==$newhdr{$k}==\n";
	if ($newhdr{$k} ne $oldhdr{$k}) {
	  $match = 0;
	}
      }
      if ($match == 1) { $get = 0; }
    }
  }
  if ($get == 1) {
    open my $hdrfd, '>', "$videodir/$hdrname";
    foreach my $k (keys %newhdr) {
      print $hdrfd "$k $newhdr{$k}\n";
    }
    close $hdrfd;
    return 1;
  } else {
    return 0;
  }
}

sub geturls {
  my ($tsv) = @_;

  my %urls = ();
  open my $tsvfd, '<', $tsv or die "Could not open $tsv";
  while (<$tsvfd>) {
    chomp;
    if (!/^Timestamp/) {
      my @fields = split /\t/;
      my $url = $fields[4];
      if ($url =~ /drive.google.com/ && !/export=download/) {
	my $gid;
	if ($url =~ /\/file\/d\//) {
	  ($gid) = $url =~ /\/d\/([^?\/]+)/;
	} elsif ($url =~ /id=/) {
	  ($gid) = $url =~ /id=([^& ]+)/;
	}
	if ($gid eq "") {
	  warn "Could not extract id for $url\n";
	} else {
	  my $fixed = "https://drive.google.com/uc?export=download&id=".$gid;
	  print "Remapping $url to $fixed\n";
	  $urls{$fields[1]} = $fixed;
	}
      } else {
	$urls{$fields[1]} = $url;
      }
    }
  }
  return \%urls;
}
