# maptraceroute
Perl script to map an IP traceroute and saves it either as png graphic or gpx track file.

Command line options:
-h | --help

-t IP/hostname | --target=IP/hostname 

> target host for trace; required option

-o file | --output=file 

>  filename to write data to; default STDOUT

-f format | --format=format

>  output format; currently supported png (default) and gpx

-v | --verbose

>  write out some information (careful if output is STDOUT: unusable output!)

