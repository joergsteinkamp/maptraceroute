#!/usr/bin/env perl

use warnings;
use strict;

use Getopt::Long;
use Data::Validate::IP;
use LWP::UserAgent;
use XML::LibXML::Simple qw(XMLin);
use Net::Traceroute;

### parameters
my $target;
my $outfile;
my $outfmt;
my $help;
my $verbose;

### get the command line parameters
GetOptions("target=s" => \$target,
           "output=s" => \$outfile,
           "format=s" => \$outfmt,
           "help" => \$help,
           "verbose" => \$verbose);

if ($help) {
    print "Performs a tracroute to a given host and saves the trace either as map or gpx track.\n\n";
    print "Options:\n";
    print "-h | --help : print this help.\n";
    print "-t IP/hostname | --target=IP/hostname : target host for trace; required.\n";
    print "-o file | --output=file : filename to write data to; default STDOUT.\n";
    print "-f format | --format=format : output format; currently supported png (default) and gpx.\n";
    print "-v | --verbose : write out some information (careful if output is STDOUT: unusable output!).\n";
    exit;
}

die ("Need at least a hostname or IP address.\n") if (!$target);
$outfile = "-" if (!$outfile);
$outfmt = "png" if (!$outfmt || $outfmt ne "gpx");

### setup base url to produce a google map
my $mapurl = "https://maps.googleapis.com/maps/api/staticmap?center=&zoom=&maptype=roadmap&size=640x640&scale=2";

### setup the UserAgent for web-queries
my $ua = LWP::UserAgent->new;
$ua->timeout(30);
$ua->agent('Mozilla/5.0');

### get my public IP and geographic information
my $query   = "https://ip.anysrc.net/xml";
my $reply   = $ua->get($query);
my $xmldata = %$reply{"_content"};
$xmldata  = XMLin($xmldata);
my $geoip = $$xmldata{"geoip"};
my $myip = $$xmldata{"clientip"};

### initialize the gpx file if desired
if ($outfmt eq "gpx") {
    open(OUT, "> $outfile");
    print OUT "<?xml version=\"1.0\"?>\n";
    print OUT "<gpx version=\"1.0\" creator=\"maptraceroute.pl\" xmlns=\"http://www.topografix.com/GPX/1/0\">\n";
    print OUT "<trk>\n";
    print OUT "  <name>traceroute from $myip to $target </name>\n";
    print OUT "  <cmt>traceroute from $myip to $target </cmt>\n";
    print OUT "  <desc>traceroute from $myip to $target </desc>\n";
    print OUT "  <trkseg>\n";
    print OUT "    <trkpt lat=\"$$geoip{latitude}\" lon=\"$$geoip{longitude}\">\n";
    print OUT "      <label>0</label>\n";
    print OUT "      <ip>$myip</ip>\n";
    print OUT "      <address>$$geoip{locationstring}</address>\n";
    print OUT "    </trkpt>\n";
    # print OUT "  <> </>\n";
}

### create the first marker
my $mapmark = "&markers=color:red|label:1|$$geoip{latitude},$$geoip{longitude}";
my $mappath = "&path=color:0x0000ff|weight:3|$$geoip{latitude},$$geoip{longitude}";

### perform the traceroute
my $trace = Net::Traceroute->new(host => $target);

### get information of routers and 
### add to marker/path list if possible
### or write gpx data
if($trace->found) {
    my $nhop = $trace->hops;
    if($nhop > 1) {
        for (my $i=1; $i<=$nhop; $i++) {
            my $host = $trace->hop_query_host($i, 0);
            next if (!$host);
            next if (is_private_ipv4($host) || is_private_ipv6($host));
            my $timing = $trace->hop_query_time($i, 0);
            $query = "http://ip-api.com/xml/".$host;
            $reply = $ua->get($query);
            $xmldata = %$reply{"_content"};
            $xmldata = XMLin($xmldata);

            if ($verbose) {
                print "$_ : $$xmldata{$_}\n" foreach (keys(%$xmldata));
            }

            print "\n".$i." : ".$host." : ".$$xmldata{lon}."/".$$xmldata{lat}."\n" if ($verbose);
            if ($i==$nhop) {
                $mapmark .= "&markers=color:red|label:${i}|$$xmldata{lat},$$xmldata{lon}";
            } else {
                $mapmark .= "&markers=color:blue|label:${i}|$$xmldata{lat},$$xmldata{lon}";
            }
            $mappath .= "|$$xmldata{lat},$$xmldata{lon}";

            if ($outfmt eq "gpx") {
                print OUT "    <trkpt lat=\"$$xmldata{lat}\" lon=\"$$xmldata{lon}\">\n";
                print OUT "      <label>$i</label>\n";
                print OUT "      <ip>$host</ip>\n";
                print OUT "      <timing>$timing ms</timing>\n";
                my $locationstring;
                $locationstring .= "$$xmldata{country}, " if ($$xmldata{country}); 
                $locationstring .=  "$$xmldata{countryCode}, " if ($$xmldata{countryCode}); 
                $locationstring .=  "$$xmldata{regionName}, " if ($$xmldata{regionName}); 
                $locationstring .= "$$xmldata{region}, " if ($$xmldata{region}); 
                $locationstring .= "$$xmldata{zip}, " if ($$xmldata{zip}); 
                $locationstring .=  "$$xmldata{city}" if ($$xmldata{city});
                print OUT "      <address>$locationstring</address>\n";
                print OUT "    </trkpt>\n";
            }
        }
    }
}

### finish the gpx putput
if ($outfmt eq "gpx") {
    print OUT "  </trkseg>\n";
    print OUT "</trk>\n";
    print OUT "</gpx>\n";
}

if ($outfmt eq "png") {
### get the png image
    $query  = "$mapurl$mapmark$mappath\n";
    $reply  = $ua->get($query);
    my $map = %$reply{"_content"};

### save the data
    open(OUT, "> $outfile");
    binmode OUT;
    print OUT $map;
    close OUT;
}
