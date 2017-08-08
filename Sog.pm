#!/opt/perl5/bin/perl

package Sog;
use Net::Telnet;
@ISA = ( "Net::Telnet" );

my $host    = 'XXXXXXXXXXX';
my $user    = 'XXXXXX';
my $pass    = 'XXXXXX';
my $prompt  = '/Enter command\: /';
my $timeout = 60;
my $login   = 'LOGIN:CAI_OP1:CAI_OP1;';

#///////////////////////////////////////////////////////////////////////////////
# Constructor
# Constructs a new Sog object
# Sample Usage: my $sog = new Sog;
#///////////////////////////////////////////////////////////////////////////////
sub new {
	my $self = 
	new Net::Telnet( Host => $host, Prompt => $prompt, Timeout => $timeout );
	$self->login( "$user", "$pass" );
	$self->cmd( "$login" );
	bless( $self, 'Sog' );
	return $self; 
}

#///////////////////////////////////////////////////////////////////////////////
# Destructor
# Run automatically when a Sog object goes out of scope
#///////////////////////////////////////////////////////////////////////////////
sub DESTROY {
	my $self = shift;
	$self->cmd( "LOGOUT" );
	$self->close(); 
}

#///////////////////////////////////////////////////////////////////////////////
# get a parameter from an element
# Returns the parameter or undef if something went awry
# Sample Usage: my $imsi = $sog->get('HLRSUB', {MSISDN => $msisdn}, 'IMSI')
#///////////////////////////////////////////////////////////////////////////////
sub get {
	my ( $self, $element, $hashref, $parameter ) = @_;
	my $output = _probeer_( $self, 'GET', $element, $hashref, $parameter );
	return $1 if ( $output =~ /$parameter,(.*);/ );
	return; 
}

#///////////////////////////////////////////////////////////////////////////////
# set a parameter on an element
# Returns 1 or undef if something went  awry
# Sample Usage: $sog->set('HLRSUB', {MSISDN => $msisdn, IMSI => $imsi}, 'NAM', 0)
#///////////////////////////////////////////////////////////////////////////////
sub set {
	my ( $self, $element, $hashref, $parameter, $value ) = @_;
	my $output = _probeer_( $self, 'SET', $element, $hashref, undef );
	return 1 if ( $output =~ /RESP:0;/ );
	return; 
}

#///////////////////////////////////////////////////////////////////////////////
# mak e a new element
# Returns 1 or undef if something went awry
# Sample Usage: $sog->mak('VMSUB', {SUBID => $subid})
#///////////////////////////////////////////////////////////////////////////////
sub mak {
	my ( $self, $element, $hashref ) = @_;
	my $output = _probeer( $self, 'CREATE', $element, $hashref, undef );
	return 1 if ( $output =~ /RESP:0;/ );
	return; 
}

#///////////////////////////////////////////////////////////////////////////////
# del ete an existing element
# Returns 1 or undef if something went awry
# Sample Usage: $sog->del('HLRSUB', {MSISDN => $msisdn, IMSI => $imsi})
#///////////////////////////////////////////////////////////////////////////////
sub del {
	my ( $self, $element, $hashref ) = @_;
	my $output = _probeer_( $self, 'DELETE', $element, $hashref, undef );
	return 1 if ( $output =~ /RESP:0;/ );
	return;
}
	
#///////////////////////////////////////////////////////////////////////////////
# flip_nam changes the nam to the opposite value 
# Returns 1 or undef if something went awry
# Sample Usage: $sog->flip_nam({MSISDN => $msisdn, IMSI => $imsi})
#///////////////////////////////////////////////////////////////////////////////
sub flip_nam {
	my ( $self, $hashref ) = @_;
	my $nam    = $self->get( 'HLRSUB', $hashref, 'NAM' );
	my $newnam = not $nam;
	my $hash   = (%$hashref, 'NAM' => "$newnam" );
	$hashref   = \%hash;
	my $output = $self->set( 'HLRSUB', $hashref );
	return 1 if ( $output =~ /RESP:0;/ );
	return; 
}

#///////////////////////////////////////////////////////////////////////////////
# get_camel gets CAMEL
# Returns a reference to an array with the parameters or undef
# Sample Usage: my $array_ref = $sog->get_camel({MSISDN => $msisdn, IMSI => $imsi})
#///////////////////////////////////////////////////////////////////////////////
sub get_camel {
	my ( $self, $hashref ) = @_;
	my $output = $self->get( 'HLRSUB', $hashref, 'CAMEL' );
	return undef unless ( defined( $output ) );
	return [$1, $2] if ( $output =~ /.*(OCTDP,\d+),.*(OSMSTDP,\d+),.*/ ); 
	return [ ];
}

#///////////////////////////////////////////////////////////////////////////////
# add_camel adds CAMEL 
# Returns 1 or undef if something went awry
# Sample Usage: $sog->add_camel({MSISDN => $msisdn, IMSI => $imsi})
#///////////////////////////////////////////////////////////////////////////////
sub add_camel {
	my ( $self, $hashref ) = @_;
	my ( $eoick, $gsa ) = _get_eoick_gsa_( $$hashref{'MSISDN'} );
	my $value = "OCTDP,2,GSA,$gsa,SK,99,DEH,0,CCH,1:CAMEL,DEF,OSMSTDP,1,GSA,$gsa,";
	$value   .= "SK,36,DEH,0,CCH,3,SET,OCAMEL,MCSO,1,OSMSSO,1:";
	$value   .= "CAMEL,SET,ECAMEL,EOICK,$eoick,ETICK,0;";
	my %hash = (%$hashref, 'CAMEL,DEF' => $value);
	my $hashref = \%hash;
	my $output = $self->set( 'HLRSUB', $hashref );
	return 1 if $output;
	return; 
}

#///////////////////////////////////////////////////////////////////////////////
# del camel: removes CAMEL
# Returns 1 or undef if something went awry
# Expects an array ref with the CAMEL parameters
# Sample Usage: $sog->del_camel({MSISDN => $msisdn, IMSI => $imsi}, $array_ref)
#///////////////////////////////////////////////////////////////////////////////
sub del_camel {
	my ( $self, $hashref, $arrayref ) = @_;
	for my $parameter ( @$arrayref ) { 
		my %hash = (%$hashref, 'CAMEL,DEL' => $parameter);
		$hashref   = \%hash;
		my $output  = $self->set( 'HLRSUB', $hashref );
		return unless $output; 
	}
	return 1; 
}

#///////////////////////////////////////////////////////////////////////////////
# get_apnids: get APNIDs
# Returns a reference to an array containing the parameters or undef
# Sample Usage: $sog->get_apnids({MSISDN => $msisdn, IMSI => $imsi})
#///////////////////////////////////////////////////////////////////////////////
sub get_apnids {
	my ( $self, $hashref ) = @_;
	my @apnids = ();
	my $output = $self->get( 'HLRSUB', $hashref, 'GPRS' );
	return unless ( defined( $output ) );
	my @answers = split( /APNID,/, $output );
	for my $element ( @answers ) {
		if ( $element =~ /^(\d+),/ ) { push( @apnids, $1 ); } 
	}
	return \@apnids; 
}

#///////////////////////////////////////////////////////////////////////////////
# add_apnid: add an APNID
# Returns 1 or undef if something went awry
# Sample Usage: $sog->add_apnid({MSISDN => $msisdn, IMSI => $imsi}, $apnid)
#///////////////////////////////////////////////////////////////////////////////
sub add_apnid {
	my ( $self, $hashref, $apnid ) = @_;
	my %zever = ( %$hashref, ( 'GPRS,DEF,PDPCONTEXT,APNID' => "$apnid,QOS,3-1-2-9-18,VPAA,0" ) );
	$hashref = \%zever;
	my $output = $self->set( 'HLRSUB', $hashref );
	return 1 if $output;
	return; 
}

#///////////////////////////////////////////////////////////////////////////////
# del_apnid: delete an APNID
# Returns 1 or undef if something went awry
# Sample Usage: $sog->del_apnid({MSISDN => $msisdn, IMSI => $imsi}, $apnid)
#///////////////////////////////////////////////////////////////////////////////
sub del_apnid {
	my ( $self, $hashref, $apnid ) = @_;
	my %hash = ( %$hashref, 'GPRS,DEL,PDPCONTEXT,APNID' => "$apnid" );
	$hashref = \%hash;
	my $output = $self->set( 'HLRSUB', $hashref );
	return 1 if $output;
	return; 
}

#///////////////////////////////////////////////////////////////////////////////
#///////////////////////////////////////////////////////////////////////////////
# You are not supposed to use the following functions                          #
#///////////////////////////////////////////////////////////////////////////////
#///////////////////////////////////////////////////////////////////////////////
sub _probeer_ {
	my ( $self, $action, $element, $hashref, $parameter ) = @_;
	my $command = "$action:$element:";
	my @response;
	for my $key ( reverse( sort( keys( %$hashref ) ) ) ) { 
		$KEY = uc $key;
		$command .= "$KEY,$$hashref{$key}:"; 
	}
	$command .= "$parameter:" if $parameter;
	$command =~ s/:$/;/g;
	@response = $self->cmd( "$command" );
	return $response[0]; 
}

sub  _get_eoick_gsa_ {
	my $msisdn = shift;
	my ( $eoick, $gsa );
	my @digits = split( //, $msisdn );
	if ( $msisdn =~ /^32486|^3247|^3249|^32484[0-4]/ ) {
		if ( $digits[6] < 5 ) { $eoick = 100; $gsa = 32486000040; }
		else                  { $eoick = 101; $gsa = 32486000039; } 
	} else {
		if ( $digits[6] < 5 ) { $eoick = 200; $gsa = 32486000036; }
		else                  { $eoick = 201; $gsa = 32486000037; } 
	}
	return ( $eoick, $gsa ); 
}
