#!/usr/bin/env perl

use strict;
use warnings;

my $phrase = join "", <STDIN>;
chomp $phrase;

if ($phrase) {
    open(my $f, ">>", shift) or die $!;
    print $f "$phrase\n====\n";
    close $f;

    print "Saved!\n";
} else {
    print "I don't like that, GTFO\n";
}
