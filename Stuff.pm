#!/opt/perl5/bin/perl

use strict;
use locale;

package Stuff;

BEGIN {
    use Exporter;
    use vars qw(@ISA @EXPORT);
    @ISA = qw(Exporter);
    @EXPORT = qw(extract_from_arg1 unify_msisdn unify_imsi);
}

sub extract_from_arg1 {
    my $key = shift;
    my $string = shift;
    $string =~ /${key}=(\d+),/;
    my $value = $1;
    if ( $key == 'MSISDN' ) { $value =~ s/^0/32/; }
    return $value;
}

sub unify_msisdn {
    my ($msisdn) = @_;
    $msisdn =~ s/[^0-9]//g;
    $msisdn =~ s/^0032/32/; $msisdn =~ s/^+32/32/;
    $msisdn =~ s/^04/324/;  $msisdn =~ s/^4/324/;
    return $msisdn if $msisdn =~ /^324\d{8}$/;
    return;
}

sub unify_imsi {
    my ($imsi) = @_;
    $imsi =~ s/[^0-9]//g;
    return $imsi if $imsi =~ /^206\d{12}$/;
    return;
}

1
