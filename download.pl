#!/usr/bin/env perl

use strict;
use warnings;
use Web::Scraper;
use Set::Scalar;
use URI;
use List::AllUtils qw(uniq);
use Path::Class;
use JSON::MaybeXS;
use v5.014;

my $url = URI->new( 'https://www.khanacademy.org/science/organic-chemistry' );

my @queue;
my $set_todo = Set::Scalar->new();
my $set_done = Set::Scalar->new();
my $site_data = {};

my $scraper = scraper {
	process "a", "links[]" => '@href';
	process 'link[rel="video_src"]', 'video' => '@href';
};

add_url( $url->as_string );
while( @queue ) {
	my $current_url = get_url();
	say $current_url;
	my $cur_data = $scraper->scrape( URI->new($current_url) );
	#use DDP; p $cur_data;

	my @urls_to_try = uniq
		grep { $_ =~ /^\Q$current_url\E\/./ }
		grep { not $set_done->has($_) }
		grep { filter_url($_) }
		map { $_->as_string } # turn all URIs into strings for Set::Scalar and JSON
		@{ $cur_data->{links} };
	#use DDP; p @urls_to_try;
	if(@urls_to_try) {
		$site_data->{ $current_url }{children} = \@urls_to_try;
		add_url( $_ ) for @urls_to_try;
	}
	#use DDP; p $set_done;

	$site_data->{ $current_url }{video} = $cur_data->{video}->as_string if exists $cur_data->{video};
	mark_done($current_url);

	use DDP; p $site_data->{ $current_url };
}
file('ka-data.json')->spew( encode_json( $site_data ) );

sub add_url {
	my ($site) = @_;
	unless( $set_done->has( $site ) or $set_todo->has( $site ) ) {
		push @queue, $site;
		$set_todo->insert( $site );
	}
}

sub mark_done {
	my ($site) = @_;
	$set_todo->delete( $site );
	$set_done->insert( $site );
}

sub get_url {
	my $current_url = shift @queue;
	$current_url;
}

sub filter_url {
	my ($site) = @_;
	$site =~ /^\Q$url\E/         # is a child of URL
		and $site !~ m,\/d$, # and is not a dicussion site
		and $site !~ m,\#$,; # and is not a fragment
}
