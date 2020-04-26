#!/usr/bin/env perl

use strict;
use warnings;

use JSON qw<encode_json>;
use MIME::Base64 qw<encode_base64>;
use Image::Magick;
use File::Temp qw<tempfile>;
use Data::Dumper;

exit unless exists $ENV{'TGUTILS_TYPE'};
exit unless $ENV{'TGUTILS_TYPE'} eq 'IMAGE';

$/ = undef;
binmode STDIN;
my $origimg = <>;

my ($origh, $origpath) = tempfile();

binmode $origh;
print $origh $origimg;
close $origh;

my $imagick = Image::Magick->new;
$imagick->Read($origpath);
$imagick->Resize(geometry => '512x512');

my $newpath = $origpath . ".png";
$imagick->Write($newpath);

open(my $newh, "<", $newpath);
binmode $newh;
my $newimg = <$newh>;
close $newh;

unlink $origpath, $newpath;

print encode_json({type => 'DOCUMENT', caption => 'Tenga, ayúdese',
                   content => encode_base64 $newimg, '',
                   filename => 'cosa.png'});
