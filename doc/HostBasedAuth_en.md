[Afficher la version française](HostBasedAuth_fr.md)

note: english is not my native language. I write in french and then try to
translate afterwards. This file may not be up to date wrt the french one.

I'd like to thanks [Stephen Morton](https://github.com/stephencmorton) for his
help with the translation of this file.

# HostBasedAuth trigger

This trigger enables host based authentication. Host ip, name or fqdn can be used
for authentication. This trigger is designed to be used in smart-http mode.

For each repo:
* some specific users must be authorized (name doesn't matter)
* for each of these users, an option defines autorized hosts or IPs
* if the repo is accessed anonymously with user `anonhttp` from an authorized
  host, then the user corresponding to that host is selected as the new
  effective user. Note: that user doesn't inherit the privileges of the
  anonymous user, even if the anonymous user's privileges are higher.

In the following example:
~~~.gitolite-conf
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
* writable from any address that reverse-resolves to HOST.DOMAIN
* writable from any address that reverse-resolves to HOSTNAME<.ANYDOMAIN>

You need not define users and mappings for reader, writer and enforcer
privileges for each repo. This example is only to show that this is possible.

The following gitolite verbs are supported:
* those associated with git commands (git-upload-pack, git-receive-pack,
  git-upload-archive)
* create (used to create wild-repos)
An implementation of the command info that is HostBasedAuth-aware is also
provided.

For example, with the following configuration:
~~~.gitolite-conf
repo hba/..*
    C = user
    RW+ = user
    option.map-anonhttp = user from myhost
~~~
The following commands create a new repo from myhost on myrepos, clone it and
then commit a file:
~~~.console
# on myhost
curl -fs http://myrepos/anongit/create?hba/test
git clone http://myrepos/anongit/hba/test
cd test
touch .gitignore
git commit -am "initial"
~~~

## Installation

* NetAddr::IP is required. On debian jessie, it can be installed with
    ~~~.console
    sudo apt-get install libnetaddr-ip-perl
    ~~~
  If you have this error:
    ~~~.console
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

* If not done yet, you have to configure `LOCAL_CODE` and `HTTP_ANON_USER` (for
  smart http mode) in gitolite.rc
    ~~~.gitolite-rc
    LOCAL_CODE => "$ENV{HOME}/local",
    HTTP_ANON_USER => "anonhttp",
    ~~~

* Copy `lib` and `commands` to `LOCAL_CODE`
    ~~~.console
    srcdir=PATH/TO/gitolite-contrib

    localdir="$(gitolite query-rc LOCAL_CODE)"
    [ -d "$localdir" ] &&
        rsync -r "$srcdir/localcode/" "$localdir" ||
        echo "LOCAL_DIR: not found nor defined"
    ~~~

* Enable the trigger in gitolite.rc
    ~~~.gitolite-rc
    INPUT => [
        'HostBasedAuth::input',
    ],
    ~~~

* Define symbolic names if you want to use regexes with the options `match-repo`
  and `match-anonhttp`. This step is optional, and there are alternatives. See
  below the description of the option `match-repo` for details. Here is an
  example:
    ~~~.gitolite-rc
    SAFE_CONFIG => {
        QRE => '~', REA => '/^', REZ => '$/',
        1 => '$1', 2 => '$2', 3 => '$3', 4 => '$4', 5 => '$5', 6 => '$6', 7 => '$7', 8 => '$8', 9 => '$9',
        ANY => '(.*)',
        NAME => '([^/]+)',
        PATH => '([^/]+(?:/[^/]+)*)',
        HOST => '(([^/.]+)(\.[^/]+)?)', # %1 is host, %2 is hostname, %3 is .domain
        NSUFF => '([0-9]*)',
        TSUFF => '(?:-(?:prod|test|devel|dev))?',
    },
    ~~~

## Configuration

* IMPORTANT: in smart-http mode, you have to authorize the user `daemon` for all
  relevant repositories, e.g
    ~~~.gitolite-conf
    repo gitolite-admin
        - = daemon
        option deny-rules = 1
    repo @all
        R = daemon
    ~~~
  or for one repo:
    ~~~.gitolite-conf
    repo myrepo
        R = daemon
        RW+ = writer
        option map-anonhttp = writer from myhost.domain
    ~~~

* For each repo:
    * a user must be authorized according to their needed access
    * The `map-anonhttp` option defines autorized hosts or IPs for which `anonhttp` is
      replaced with this user

## Reference

### anonhttp

This user is used with anonymous http access. The user is replaced only with an
anonymous connexion. Indeed, if the connexion is already authenticated, it's
uncesserary to authenticate further.

The default value is `%RC{HTTP_ANON_USER}` or `anonhttp` in this order.

### option map-anonhttp

This option defines a mapping between a user and one or more hosts for which
`anonhttp` is replaced with that user.

#### Standard syntax

~~~
option map-anonhttp = USER from IPSPEC|NAMESPEC...
~~~

With this syntax, the hosts may be specified as:
* IP addresses, e.g `192.168.15.23`
* IP address classes, e.g `10.50.60.0/24`
* host name, e.g `hostname`
* domain name, e.g `.domain.tld`
* fully qualified hosts, e.g `hostname.domain.tld`

Examples:
~~~.gitolite-conf
option map-anonhttp = user from 10.11.12.13 192.168.1.50
option map-anonhttp-1 = user from 10.50.60.0/24
option map-anonhttp-2 = user from hostname.domain .domain hostname
~~~
You can have several `map-anonhttp` options with a suffix '-anything', or you can
have several space-separated values with a single option.

Note: This design has been suggested by Sitaram Chamarty, with the option name
`anonhttp-is`. However, I prefer the name `map-anonhttp`. The two names are
valid and supported.

Note: The syntaxes `*.domain` and `hostname.*` are also supported and are
equivalent to `.domain` and `hostname`, respectively.

#### Regex syntax

~~~
option map-anonhttp[-SUFFIX] = USER from ~REGEX
option map-anonhttp[-SUFFIX] = USER from /REGEX/
~~~

With these syntaxes, the hosts are specified as regexes, that are matched
against the fully qualified host or the hostname, depending on the occurence of
a dot `\.` in the regex.

The former syntax `~REGEX` automatically adds the anchors `^` and `$` and quotes
the character `.` as `\.`. The latter syntax specifies a regex that is to be
used as-is, without modification. Therefore, the two following lines are
strictly equivalent:
~~~.gitolite-conf
option map-anonhttp = user from ~host[0-9]+.tld
option map-anonhttp = user from /^host[0-9]+\.tld$/
~~~
With either syntax, the match is case insensitive. It is not possible to add any
other modifiers to the regex.

The syntax `~REGEX` is particularly useful together with the option
`match-repo`, e.g
~~~.gitolite-conf
repo hosts/..*/..*
    RW+ = user
    # needs SAFE_CONFIG definition in gitolite.rc
    option match-repo = hosts/%HOST/%ANY
    option map-anonhttp = user from %QRE%2%NSUFF%3
~~~
Indeed, as the hostname is extracted as-is from the repo name with `match-repo`,
automatic escaping of the dot character is needed to avoid matching another
unrelated host.

In this example, repos named `hosts/HOST/ANYTHING` are accessible by any host
whose name is HOST with a numeric suffix.
* For example, the repo named `hosts/mysql/config` is accessible by the hosts
`mysql`, `mysql1.we.com` and `mysql2.them.net` (there is no domain in the
corresponding regex `mysql` so the domain name is not checked)
* Likewise, the repo named `hosts/ldap.we.com/data` is accessible by the hosts
`ldap.we.com`, `ldap2.we.com` and `ldap53.we.com` but *not* `ldap15.them.org`
(there is a domain in the corresponding regex `ldap\.we\.com`, so the domain
name is checked)

### option match-repo

This option matches a host based on the name of the repo. It must be used in
conjunction with `map-anonhttp`. First, the repo name is matched with the
match-repo regex. The host is built from capture groups from the regex and
can be used in subsequent `map-anonhttp` options.

In this example, a repo named `hosts/HOST/config` is accessible from the host
`HOST.domain`:
~~~.gitolite-conf
repo hosts/..*
    RW+ = user
    # CAUTION! this example will not work with the default configuration
    option match-repo = hosts/([^/]+)/config
    option map-anonhttp = user from $1.domain
~~~

IMPORTANT: the example above won't work out of the box, because of character
restriction in config variables. There are two solutions to this problem (look
for "compensating for UNSAFE_PATT" on http://gitolite.com/gitolite/git-config)

* The simplest but potentially the more dangerous one is to modify the value of
  $UNSAFE_PATT. In the following example, the characters `$ ( ) |` are allowed:
    ~~~.gitolite-rc
    $UNSAFE_PATT = qr([`~#\&;<>]);
    ~~~

* Another method is to define symbolic names and use them in the regexes. See
  above for a useful starter pack of symbolic names. If you have configured
  these symbolic names, the example above can then be written as:
    ~~~.gitolite-conf
    repo hosts/..*
        RW+ = user
        option match-repo = hosts/%NAME/config
        option map-anonhttp = user from %1.domain
    ~~~

### command info

This command works like the one shipped with gitolite, but take into account the
authorizations given to the calling host. Use the option `-legacy` to have the
standard behavior.

## NetAddr::IP patch for Debian Jessie

As of 29/12/2016, the NetAddr::IP bug still exists on debian jessie. The
following command does the fix (don't forget to adapt paths and/or package
versions)
~~~.console
cd /usr/lib/x86_64-linux-gnu/perl5/5.20/NetAddr/IP
sudo patch <<EOF
--- InetBase.pm.orig 2016-12-29 14:54:19.396359452 +0400
+++ InetBase.pm 2016-12-29 14:33:37.888900910 +0400
@@ -1,5 +1,6 @@
 #!/usr/bin/perl
 package NetAddr::IP::InetBase;
+use Socket;
 
 use strict;
 #use diagnostics;
EOF
~~~

-*- coding: utf-8 mode: markdown -*- vim:sw=4:sts=4:et:ai:si:sta:fenc=utf-8:noeol:binary