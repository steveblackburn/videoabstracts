#!/usr/bin/perl
#
# Normalize a video
#   - codec (mp4)
#   - duration (60s)
#   - resolution (1280x720)
#   - peak volume (0dB)
#
use strict;
use File::Temp qw(tempfile);
use File::Basename qw(dirname);
use Cwd  qw(abs_path);
use lib dirname(dirname abs_path $0) . '/lib';
use FFmpeg qw(normalize);

use constant NORM_LEN => 60;

#
# setup
#
my $in = shift @ARGV;
my $out = shift @ARGV;


my $targetlength = ($out =~ /115.mp4/) ? 90 : NORM_LEN; # special case

if ($in eq "" || $out eq "" || !($out =~ /.mp4/)) {
  die "usage: $0  <in.*> <out.mp4>\n";
}

if (!-e $in) { die "Could not find $in"; }

normalize($in, $out, $targetlength);


