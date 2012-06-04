#!/usr/bin/env perl

use 5.014;
use Aviation::Wx::MetFlight;
use Data::Dumper;

my $brief = Aviation::Wx::MetFlight::fetch(
	username => 'REDACTED',
	password => 'REDACTED',
	hours => 6,
	regions => 'ST SA DV'
);

say Data::Dumper::Dumper( $brief );

