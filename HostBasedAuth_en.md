[Afficher la version française](HostBasedAuth_fr.md)

note: english is not my native language. I write in french and then try to
translate afterwards. This file may not be up to date wrt the french one.

# HostBasedAuth trigger

This trigger enable host based authentication. Host ip, name or fqdn can be used
for authentication. This trigger is designed to be used in smart-http mode.

For each repo:
* `anyhost` user must be authorized
* `allow-host` option define autorized host or IPs
* if the repo is accessed anonymously with user `anonhttp` from authorized
  hosts, then the user is replaced with `anyhost`

In the following example:
~~~
repo repo1
    R = anyhost
    option allow-host = 10.11.12.13
repo repo2
    RW = anyhost
    option allow-host = HOST.DOMAIN
repo repo3
    RW = anyhost
    option allow-host = HOSTNAME
~~~
repo1 is readable from address 10.11.12.13;
repo2 is writable from any address that reverse-resolve to HOST.DOMAIN;
repo3 is writable from any address that reverse-resolve to HOSTNAME<.ANYDOMAIN>

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

    # Uncomment if customization is needed
    #HOST_BASED_AUTH => {
    #    ANON_USER => 'anonhttp',
    #    HOST_USER => 'anyhost',
    #},
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
        RW+ = anyhost
        option allow-host = myhost.domain
    ~~~

* For each repo:
    * `anyhost` user must be authorized according to needed access
    * `allow-host` option define autorized host or IPs for which `anonhttp` is
      replaced with `anyhost`

### anonhttp

This user is used with anonymous http access. User is replaced only with an
anonymous connexion. Indeed, if the connexion is already authenticated, it's
uncesserary to authenticate further.

Default value is `%RC{HOST_BASED_AUTH}{ANON_USER}` or `%RC{HTTP_ANON_USER}` or
`anonhttp` in this order.

### anyhost

This user have to be authorized on the repositories that support host based
authorization.

Default value is `%RC{HOST_BASED_AUTH}{HOST_USER}` or `anyhost` in this order.

### option allow-host

This option define a list of IP addresses, IP address class, fully qualified
hosts, domains, or hosts for which `anonhttp` is replaced with `anyhost`.

Examples:
~~~
option allow-host = 10.11.12.13 192.168.1.50
option allow-host-1 = 10.50.60.0/24
option allow-host-2 = hostname.domain .domain hostname
~~~
You can have several allow-host options with a suffix '-anything', or you can
have several space-separated values with a single option.

### option match-repo

This option allows to match an host based on the name of the repo. First, the
repo name is matched with the match-repo regex. If successful, the host is built
with numeric groups from the regex.

Example:
~~~
repo hosts/..*
    RW+ = anyhost
    option match-repo = hosts/([^/]+)/config
    option allow-host = $1.domain
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