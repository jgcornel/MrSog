#!/opt/perl5/bin/perl

use strict;
use lib "/opt_local/cssprd/Jcorneli/Lib";
use parse;

my $prompt = '>>> ';

system("/usr/bin/clear");

print "$prompt";

while (<>) {
	chomp;
	my $input = $_;
	if ( $input eq 'clear' ) { 
	    system("/usr/bin/clear"); 
		print "$prompt";
		next;
    } elsif ( $input eq 'exit' ) {
		last;
	}
	show(evaluate(parse($input)));
	print "$prompt"; 
}

print "\n";

sub show {
	chomp($_[0]);
    print "$_[0]\n";
}
