#!/usr/bin/env perl

use strict;
use warnings;
use Path::Class;
use JSON::MaybeXS;
use URI;
use String::ShellQuote;
use IPC::Run3;
use v5.014;

my $url = URI->new( $ARGV[0] // 'https://www.khanacademy.org/science/organic-chemistry' );

my $data = decode_json( file('ka-data.json')->slurp );

my $url_to_file = map_files();

my @video_urls = grep { exists $data->{$_}{video} and not exists $data->{$_}{children} } keys $data;

my $use_run3 = 0;
for my $video_url (@video_urls) {
	my $youtube_url = $data->{$video_url}{video};
	my $file = $url_to_file->{$video_url};
	$file->dir->mkpath;

	my $cmd = [ 'get_flash_videos', "-f",  "$file", "$youtube_url" ];
	if( $use_run3 ) {
		my $in = "n\n"; # say no to resuming
		run3 $cmd, \$in, \my $out, \my $err;
		print $out;
		print $err;
		my $ret = $?;
		die "get_flash_videos failed on $youtube_url: $file" unless $ret == 0
			or $err =~ /has been fully downloaded/s;
	} else {
		say shell_quote @$cmd;
	}
}

sub map_files {
	# TODO start at top
	my %url_to_file;
	$url_to_file{ $url->as_string } = dir( ($url->path_segments)[-1] );

	my @queue;
	push @queue, $url;
	do {
		my $cur_url = shift @queue;
		if( $data->{$cur_url}{children} ) {
			my $num = 1;

			# only process direct children (direct children might have a /v/ in between)
			my @children = grep { $_ =~ m,^\Q$cur_url\E(/v)?/[^/]+$, } @{ $data->{$cur_url}{children} };

			#use DDP; p @children;
			for my $child ( @children ) {
				my $child_uri = URI->new( $child );
				my $name = sprintf "%02d---%s", $num, ($child_uri->path_segments)[-1];
				my $child_filename;

				if( $child =~ m,/v/, ) {
					# a video -> goes in a file
					$child_filename = $url_to_file{ $cur_url }->file( "$name.mp4" );
				} else {
					# a subdir
					$child_filename = $url_to_file{ $cur_url }->subdir( $name );
				}
				$url_to_file{ $child } = $child_filename;
				$num++;
				push @queue, $child;
			}
		}
	} while(@queue);

	\%url_to_file;
}
