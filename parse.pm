#!/opt/perl5/bin/perl

use strict;
use Sog;

package parse;

use Exporter;
use vars qw(@ISA @EXPORT);
@ISA = qw(Exporter);
@EXPORT = qw(parse evaluate);

#///////////////////////////////////////////////////////////////////////////////
#///////////////////////////////////////////////////////////////////////////////

my %cmds = (
    get => { name => "get"    , func => \&eval_net },
    set => { name => "set"    , func => \&eval_net },
    del => { name => "delete" , func => \&eval_net },
    new => { name => "create" , func => \&eval_net },
    add => { name => undef    , func => \&eval_add },
    rem => { name => undef    , func => \&eval_rem },
    def => { name => undef    , func => \&eval_def },
    lit => { name => undef    , func => \&eval_lit },
    err => { name => undef    , func => \&eval_err },
    );
    
my %elts = (
    hlr => { 
        name => "hlrsub" , 
        func => \&id_for_hlr,
        crea => "profile,1:pwd,0486:cat,226:cfb,1,1,32486191922:cfnry,1,1,32486191922:cfnrc,1,1,32486191922:dcf,1,1,32486191922:tick,180:ts21,1:ts22,1:obi,0:obr,0:oick,0" },
    auc => { 
        name => "aucsub" , 
        func => \&id_for_auc,
        crea => "ki,1c7931b89e1339f5203649407ab54561:adkey,1:a38,0" },
    vms => { 
        name => "vmsub"  , 
        func => \&id_for_vms,
        crea => undef },
    nps => { 
        name => "npsub"  , 
        func => \&id_for_nps,
        crea => undef },
    fnr => { 
        name => "fnsub"  , 
        func => \&id_for_nps,
        crea => undef },
    dat => { 
        name => undef    , 
        func => \&id_for_dat,
        crea => undef },
    );

my %dat = (
    msisdn => undef,
    imsi   => undef,
    subid  => undef,
    );

my $sog = new Sog;
    
#///////////////////////////////////////////////////////////////////////////////
#///////////////////////////////////////////////////////////////////////////////

sub parse {
    my $id;
    my $string = preprocess(@_);
    my ($cmd, $elt, $par, $val) = split /\s+/, $string;

    return ("err", "Unknown command: $cmd") unless exists $cmds{$cmd};
    return ("err", "Unknown element: $elt") unless exists $elts{$elt} or $cmd eq 'lit';

    return ($cmd, $elt, $id, $par, $val) if $cmd eq "lit";
    
    $id = $elts{$elt}{func}($par, $val);
    
    return ("err", "Unsufficient info") unless defined $id;
    return ($cmd, $elt, $id, $par, $val);
}

sub id_for_hlr {
    return id_for_net("imsi", "msisdn");
}

sub id_for_auc {
    return id_for_net("imsi");
}

sub id_for_vms {
    return id_for_net("subid");
}

sub id_for_nps {
    return id_for_net("msisdn");
}

sub id_for_dat {
    my ($par, $val) = @_;
    return wash_msisdn($val) if $par eq "msisdn";
    return wash_imsi($val)   if $par eq "imsi";
}

sub preprocess {
    my ($string) = @_;
    $string = $string;
    $string =~ s/define /def /;
    $string =~ s/def/def dat/;
    $string =~ s/und/und dat/;
    $string =~ s/add/add hlr/;
    $string =~ s/rem/rem hlr/;
    return $string;
}

sub id_for_net {
    my $id;

    for my $par (@_) {
        return unless defined $dat{$par};
        $$id{$par} = $dat{$par};
    }

    return $id;
}

sub wash_msisdn {
    my ($msisdn) = @_;
    $msisdn =~ s/[^0-9]//g;
    $msisdn =~ s/^0032/32/; $msisdn =~ s/^+32/32/;
    $msisdn =~ s/^04/324/;  $msisdn =~ s/^4/324/;
    return $msisdn if $msisdn =~ /^324\d{8}$/;
    return;
}

sub wash_imsi {
    my ($imsi) = @_;
    $imsi =~ s/[^0-9]//g;
    return $imsi if $imsi =~ /^206\d{12}$/;
    return;
}

#///////////////////////////////////////////////////////////////////////////////
#///////////////////////////////////////////////////////////////////////////////

sub evaluate {
    my @list = @_;
    my $cmd  = $list[0];
    return $cmds{$cmd}{func}(@list);
}

sub eval_err {
    my (undef, $msg) = @_;
    return "ERROR: $msg";
}

sub eval_net {
    my ($cmd, $elt, $id, $par, $val) = @_;
    $par = $elts{$elt}{crea} if $cmd eq "new";
    my $command = make_command($cmds{$cmd}{name}, $elts{$elt}{name}, $id, $par, $val);
    my @answer = $sog->cmd(uc $command);
    return $answer[0];
}

sub eval_add {
    my ($cmd, $elt, $id, $par, $val) = @_;
    if ($par eq 'camel') {
        return "SUCCESS: Camel added\n" if ($sog->add_camel($id));
        return "FAILED: Could not add Camel\n";
    } elsif ($par eq 'apn') {
        return "SUCCESS: apn added\n" if ($sog->add_apnid($id, $val));
        return "FAILED: Could not add apnid $val!\n";
    } else {
        return "WHAT? I don't get you man!\n";
    }
}

sub eval_rem {
    my ($cmd, $elt, $id, $par, $val) = @_;
     if ($par eq 'camel') {
        return "SUCCESS: Camel deleted\n" if ($sog->del_camel($id,$sog->get_camel($id)));
        return "FAILED: Could not delete Camel\n";
    } elsif ($par eq 'apn') {
        return "SUCCESS: apn deleted\n" if ($sog->del_apnid($id, $val));
        return "FAILED: Could not delete apnid $val!\n";
    } else {
        return "WHAT? I don't get you man!\n";
    }
}
            

sub eval_lit {
    my (undef, $cmd) = @_;
    my @answer = $sog->cmd(uc $cmd);
    return $answer[0];
}   

sub eval_def {
    my (undef, undef, $id, $par, undef) = @_;
    $dat{$par} = $id;
    
    if ($par eq 'msisdn') {
        $dat{subid} = $dat{msisdn};
        $dat{subid} =~ s/^32//;
        return define_imsi();
    } elsif ($par eq 'imsi') {
        return define_msisdn(); 
    }
    
    return "ERROR: Unknown parameter: $par";
}

sub define_imsi {
    my @answer = $sog->cmd("GET:HLRSUB:MSISDN,$dat{msisdn}:IMSI;");
    
    if ($answer[0] =~ /IMSI,(206\d{12})/) {
        $dat{imsi} = $1;
        return "SUCCESS: MSISDN is $dat{msisdn}\tIMSI is $dat{imsi}";
    }
    
    return "WARNING: MSISDN is $dat{msisdn}\tIMSI is $dat{imsi}";
}

sub define_msisdn {
    my @answer = $sog->cmd("GET:HLRSUB:IMSI,$dat{imsi}:MSISDN;");
    
    if ($answer[0] =~ /MSISDN,(324\d{8})/) {
        $dat{msisdn} = $1;
        $dat{subid} = $dat{msisdn};
        $dat{subid} =~ s/^32//;
        return "SUCCESS: MSISDN is $dat{msisdn}\tIMSI is $dat{imsi}";
    }
    
    return "WARNING: MSISDN is $dat{msisdn}\tIMSI is $dat{imsi}";
}

sub make_command {
    my ($cmd, $elt, $id, $par, $val) = @_;
    my $command = "$cmd:$elt:";
    
    for my $key (keys %$id) {
        $command .= "$key,$$id{$key}:";
    }
    
    $command .= "$par," if defined $par;
    $command .= "$val:" if defined $val;
    $command =~ s/:$/;/;
    $command =~ s/,$/;/;
    
    return $command;
}

1;
