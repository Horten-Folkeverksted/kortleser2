#!/usr/bin/env perl
#
# Copyright 2021 Robin Smidsrød
#
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
# IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

use strict;
use warnings;

use Chipcard::PCSC;
use Data::Dumper qw(Dumper);
use HTTP::Tiny ();

my $http = HTTP::Tiny->new();
my $webhook_url = $ENV{'OMNIKEY_WEBHOOK_URL'} or die('Please specify OMNIKEY_WEBHOOK_URL');
my $context = Chipcard::PCSC->new()
    or die "Unable to communicate with pcscd: $Chipcard::PCSC::errno\n";

my @readers = (
    grep { /HID OMNIKEY/i } # we're only interested in this reader
    $context->ListReaders()
);

print STDERR "Starting up with readers: " . join(", ", @readers) . "\n";

my $reader_states = [
    map { { "reader_name" => $_ } }
    @readers
];

while ( my $rc = $context->GetStatusChange($reader_states) ) {
    foreach my $rs ( @$reader_states ) {
        my $atr = $rs->{'ATR'} ? arr2asc($rs->{'ATR'}) : "";
        print join(": ",
            $rs->{'reader_name'},
            $rs->{'current_state'},
            $rs->{'event_state'},
            $atr,
        ), "\n";
        #foreach my $key ( keys %$rs ) {
        #    my $value = $rs->{$key};
        #    print "State: $key => $value\n";
        #}
        # Read next state
        if ( $atr =~ m/^3B 8F 80 01 80 4F 0C A0 00 00 03 06/) {
            read_id($rs->{'reader_name'});
        } 
       $rs->{'current_state'} = $rs->{'event_state'};
    }
    unless ($rc) {
        prnit STDERR "Exiting with return code $rc.\n";
        last;
    }
}

exit;

sub read_id {
    my ($reader) = @_;
    my $card = Chipcard::PCSC::Card->new(
        $context,
        $reader,
        $Chipcard::PCSC::SCARD_SHARE_EXCLUSIVE
    );
    my $tx = [0xFF, 0xCA, 0x00, 0x00, 0x00]; # https://stackoverflow.com/a/13178889
    my $rx = $card->Transmit($tx);
    if ( ref $rx ne ref [] ) {
        warn("Not an array response: $rx\n");
        return;
    }
    my $sw2 = pop @$rx;
    my $sw1 = pop @$rx;
    unless ( $sw1 == 0x90 && $sw2 == 0x00 ) {
        warn("Read ID command not understood." . arr2asc([$sw1,$sw2]) . "\n");
        return;
    }
    emit_id($rx);
    #beep($card); # not making any sound :(
    return 1;
}

sub beep {
    my ($card) = @_;
    my $tx = [0xFF, 0x00, 0x40, 0xCF, 0x04, 0x03, 0x00, 0x01, 0x01];
    my $rx = $card->Transmit($tx);
    if ( ref $rx ne ref [] ) {
        warn("Not an array response: $rx\n");
        return;
    }
    my $sw2 = pop @$rx;
    my $sw1 = pop @$rx;
    unless ( $sw1 == 0x90 && $sw2 == 0x00 ) {
        warn("Beep command not understood." . arr2asc([$sw1,$sw2]) . "\n");
        return;
    }
    return 1;
}

sub arr2asc {
    return Chipcard::PCSC::array_to_ascii(shift @_);
}

sub emit_id {
    my ($id) = @_;
    my $id_str = arr2asc($id);
    print "ID: $id_str...";
    my $response = $http->request(
        'POST',
        $webhook_url,
        {
            'headers' => { 'Content-Type' => 'application/json'},
            'content' => "{\"id\":\"$id_str\"}",
        }
    );
    print $response->{'status'}, " ", $response->{'content'}, "\n";
    return 1;
}

1;
