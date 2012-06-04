package Aviation::Wx::MetFlight;

use 5.014;

use utf8;
use autodie;

use WWW::Mechanize;
use HTML::Selector::XPath 'selector_to_xpath';
use HTML::TreeBuilder::XPath;
use URI;
use Carp 'croak';

=head1 NAME

Aviation::Wx::MetFlight - Fetch Weather Briefings from MetFlight GA

=head1 SYNOPSIS

  my $brief = Aviation::Wx::MetFlight::fetch(
  	username => '...',
  	password => '...',
  	regions	 => 'SA ST DV',
  	hours	 => 6
  );

=head1 DESCRIPTION

Fetches weather briefings from MetFlight GA. The briefings can then be
decoded and used in planning tools, actual weather for simulators, etc.

Note: This module requires a valid logon to MetFlight GA, which is available
as a subscription service for holders of New Zealand Aviation Documents.

=head1 PARAMETERS

username - *Required*.
password - *Required*.
regions - *Required*. Space-separated list of ARFOR region codes.
	Valid regions:
  	FN - Far North		TA - Tamaki		TK - Te Kuiti
  	ED - Edgecumbe 		CP - Central Plateau 	MH - Mahia
  	SA - Sanson 		DV - Dannevirke		ST - Straits
  	TN - Tasman 		WW - Windward 		KA - Kaikouras
  	AL - Alps		PL - Plains		FD - Fiordland
  	CY - Clyde		GE - Gore 

hours - Number of hours' METAR/SPECI reports to download. Default 1.
ua - User agent string to use when fetching the pages. Default: FF12 on Linux

=cut

sub fetch {
	my %args = @_;

	my $username = $args{username}	// croak 'username required';
	my $password = $args{password}	// croak 'password required';
	my $regions = $args{regions} 	// croak 'regions required';
	my $hours = $args{hours}	// 1;
	my $agent = $args{ua}		// 
		'Mozilla/5.0 (X11; Linux x86_64; rv:12.0) Gecko/20100101 Firefox/12.0';

	my $ua = WWW::Mechanize->new( agent => $agent );

	$ua->get('http://metflight.metra.co.nz/MetFlight.php');
	$ua->submit_form(
		form_number => 1,
		fields => {
			MetFlightUsername => $username,
			MetFlightPassword => $password,
			SubmitLogin => 'Login & Agree'
		}
	);

	croak 'Login Failed'
		unless $ua->content =~ m/window\.open\('([^']+)/;
	my $control_uri = $1;

	$ua->get($control_uri);

	my $brief_uri = URI->new('http://metflight.metra.co.nz/MetFlightBrief.php');

	$brief_uri->query_form(
		BRIEFING => 'GET WEATHER BRIEFING',
		ARFOR => 'Yes',
		TAF => 'Yes',
		METAR => 'Yes',
		METARhours => $hours,
		GAWX => '',
		SIGMET => 'Yes',
		Areas => $regions,
		User => $username,
		UserName => $username,
		session => $ua->current_form->value('session')
	);

	$ua->get($brief_uri);

	my $dom = HTML::TreeBuilder::XPath->new;
	$dom->parse( $ua->content );

	my $chunks = [ map { $_->as_text } _sel($dom, 'pre, b') ];

	my $data = {};

	my $section = undef;
	my $ad = undef;

	foreach my $x (@$chunks) {

		given ($x) {
			when(/^(\S+) Listings$/) { $section = $1; }
			when(/^[A-Z]{2,4}$/) { $data->{$section}{$ad = $x} = []; }
			default { push @{$data->{$section}{$ad}}, $x; }
		}
	}

	return $data;
}

# some plumbing to allow the use of CSS selectors
# with HTML::TreeBuilder::XPath DOMs.
sub _sel {
	my ($dom, $css) = @_;
	my $xpath = selector_to_xpath($css);
	return $dom->findnodes( $xpath );
}

1;
