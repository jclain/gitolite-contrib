[Afficher la version française](HostBasedAuth_fr.md)

note: english is not my native language. I write in french and then try to
translate afterwards. This file may not be up to date wrt the french one.

# HostBasedAuth trigger

This trigger enable host based authentication. Host ip, name or fqdn can be used
for authentication. This trigger is designed to be used in smart-http mode.

For each repo:
* some specific users must be authorized (name doesn't matter)
* for each of these users, an option define autorized hosts or IPs
* if the repo is accessed anonymously with user `anonhttp` from an authorized
  hosts, then the corresponding user is selected

In the following example:
~~~
repo repo1
    R = reader
    RW = writer
    RW+ = forcer
    option map-anonhttp-1 = reader from 10.11.12.13 10.11.12.14
    option map-anonhttp-2 = writer from HOST.DOMAIN
    option map-anonhttp-3 = forcer from HOSTNAME
~~~
the repo is:
* readable from the addresses 10.11.12.13 and 10.11.12.14
* writable from any address that reverse-resolve to HOST.DOMAIN
* writable from any address that reverse-resolve to HOSTNAME<.ANYDOMAIN>

It is not required to define users and mappings for reader, writer and enforcer
privileges for each repo. This example is only to show that this is possible.

## Installation

* NetAddr::IP is required. On debian jessie, it can be installed with
    ~~~
    sudo apt-get install libnetaddr-ip-perl
    ~~~
  If you have this error:
    ~~~
    Can't locate auto/NetAddr/IP/InetBase/AF_INET6.al in @INC (...)
    at /usr/lib/x86_64-linux-gnu/perl5/5.20/NetAddr/IP/InetBase.pm line 81.
    ~~~
  It's a known bug with the autoloader. You have to fix InetBase.pm and add:
    ~~~
    use Socket;
    ~~~
  after the following line:
    ~~~
    package NetAddr::IP::InetBase;
    ~~~
  cf below for a patch usable on debian jessie, as of 12/29/2016

* If not done yet, you have to configure `LOCAL_CODE` in gitolite.rc
    ~~~
    LOCAL_CODE => "$ENV{HOME}/local",
    ~~~

* Copy HostBasedAuth.pm to `LOCAL_CODE`/lib/Gitolite/Triggers
    ~~~
    srcdir=PATH/TO/gitolite-contrib

    localdir="$(gitolite query-rc LOCAL_CODE)"
    [ -d "$localdir" ] &&
        rsync -r "$srcdir/lib" "$localdir" ||
        echo "LOCAL_DIR: not found nor defined"
    ~~~

* Enable the trigger in gitolite.rc
    ~~~
    INPUT => [
        'HostBasedAuth::input',
    ],
    ~~~

## Configuration

* IMPORTANT: in smart-http mode, you have to authorize the user `daemon` for all
  relevant repository, e.g
    ~~~
    repo gitolite-admin
        - = daemon
        option deny-rules = 1
    repo @all
        R = daemon
    ~~~
  or for one repo:
    ~~~
    repo myrepo
        R = daemon
        RW+ = writer
        option map-anonhttp = writer from myhost.domain
    ~~~

* For each repo:
    * a user must be authorized according to needed access
    * `map-anonhttp` option define autorized host or IPs for which `anonhttp` is
      replaced with this user

### anonhttp

This user is used with anonymous http access. User is replaced only with an
anonymous connexion. Indeed, if the connexion is already authenticated, it's
uncesserary to authenticate further.

Default value is `%RC{HTTP_ANON_USER}` or `anonhttp` in this order.

### option map-anonhttp

This option defines a mapping between a user and a list of IP addresses, IP
address class, fully qualified hosts, domains, or hosts for which `anonhttp` is
replaced with the user.

Examples:
~~~
option map-anonhttp = user from 10.11.12.13 192.168.1.50
option map-anonhttp-1 = user from 10.50.60.0/24
option map-anonhttp-2 = user from hostname.domain .domain hostname
~~~
You can have several `map-anonhttp` options with a suffix '-anything', or you can
have several space-separated values with a single option.

Note: This design has been suggested by Sitaram Chamarty, with the option name
`anonhttp-is`. However, I prefer the name `map-anonhttp`. The two names work the
same.

### option match-repo

This option allows to match an host based on the name of the repo. First, the
repo name is matched with the match-repo regex. If successful, the host is built
with numeric groups from the regex.

Example:
~~~
repo hosts/..*
    RW+ = user
    option match-repo = hosts/([^/]+)/config
    option map-anonhttp = user from $1.domain
~~~
In this example, a repo named 'hosts/HOST/config' is accessible from the host
'HOST.domain'

## NetAddr::IP patch for Debian Jessie

As of 29/12/2016, the NetAddr::IP bug still exists on debian jessie. The
following command does the fix (don't forget to adapt paths and/or package
versions)
~~~
sudo patch <<EOF
--- /usr/lib/x86_64-linux-gnu/perl5/5.20/NetAddr/IP/InetBase.pm.orig	2016-12-29 14:54:19.396359452 +0400
+++ /usr/lib/x86_64-linux-gnu/perl5/5.20/NetAddr/IP/InetBase.pm	2016-12-29 14:33:37.888900910 +0400
@@ -1,5 +1,6 @@
 #!/usr/bin/perl
 package NetAddr::IP::InetBase;
+use Socket;
 
 use strict;
 #use diagnostics;
EOF
~~~

-*- coding: utf-8 mode: markdown -*- vim:sw=4:sts=4:et:ai:si:sta:fenc=utf-8:noeol:binary