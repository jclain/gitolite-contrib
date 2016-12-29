[Show english version](HostBasedAuth_en.md)

# Trigger HostBasedAuth

Ce trigger permet d'authentifier sur la base de l'adresse ip ou du nom de l'hôte
qui fait la requête. Il est conçu pour fonctionner avec le mode d'accès http

Le principe est le suivant: pour les dépôts concernés:
* il faut autoriser l'utilisateur `anyhost`
* définir des options pour la liste des hôtes ou des adresses IPs qui sont
  autorisés
* si l'accès est effectué en mode anonyme avec l'utilisateur `anonhttp` depuis
  les hôtes spécifiés, alors l'utilisateur est traduit en `anyhost`

Dans l'exemple suivant:
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
le dépôt repo1 est accessible en lecture depuis l'adresse 10.11.12.13;
le dépôt repo2 est accessible en écriture depuis toute adresse ip dont la résolution inverse est HOST.DOMAIN;
le dépôt repo3 est accessible en écriture depuis toute adresse ip dont la résolution inverse est un domaine dont le nom de base est HOSTNAME

## Installation

* Ce trigger utilise NetAddr::IP. Sur debian jessie, il est possible de
  l'installer avec la commande suivante:
    ~~~
    sudo apt-get install libnetaddr-ip-perl
    ~~~
  Si l'erreur suivante apparait lors de l'utilisation du module:
    ~~~
    Can't locate auto/NetAddr/IP/InetBase/AF_INET6.al in @INC (...)
    at /usr/lib/x86_64-linux-gnu/perl5/5.20/NetAddr/IP/InetBase.pm line 81.
    ~~~
  Il s'agit d'un bug connu avec l'autoloader. Il suffit de corriger le fichier
  InetBase.pm et rajouter
    ~~~
    use Socket;
    ~~~
  juste après
    ~~~
    package NetAddr::IP::InetBase;
    ~~~
  cf ci-dessous pour une procédure automatique de correction sur debian jessie,
  valable au 29/12/2016

* Si ce n'est déjà fait, configurer `LOCAL_CODE` dans gitolite.rc
    ~~~
    LOCAL_CODE => "$ENV{HOME}/local",
    ~~~

* Dans le répertoire `LOCAL_CODE`, copier HostBasedAuth.pm dans le
  sous-répertoire lib/Gitolite/Triggers
    ~~~
    srcdir=PATH/TO/gitolite-contrib

    localdir="$(gitolite query-rc LOCAL_CODE)"
    [ -d "$localdir" ] &&
        rsync -r "$srcdir/lib" "$localdir" ||
        echo "LOCAL_DIR: not found nor defined"
    ~~~

* Activer le trigger HostBasedAuth dans gitolite.rc
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

* IMPORTANT: comme il s'agit d'un accès par http, il faut autoriser l'accès au
  user `daemon` pour tous les dépôt concerncés, e.g
    ~~~
    repo gitolite-admin
        - = daemon
        option deny-rules = 1
    repo @all
        R = daemon
    ~~~
  ou spécifiquement pour un dépôt:
    ~~~
    repo myrepo
        R = daemon
        RW+ = anyhost
        option allow-host = myhost.domain
    ~~~

* Une fois que la condition précédente est remplie, tous les dépôts qui doivent
  être autorisés sur la base de l'hôte doivent remplir au moins deux conditions:
    * Autoriser le user `anyhost` en fonction des accès à fournir
    * Définir l'option `allow-host` pour définir les hôtes pour lesquels le user
      `anonhttp` est traduit en `anyhost`

### anonhttp

Ce user est celui qui identifie les connexions http anonymes. C'est uniquement
si la connexion est anonyme qu'une traduction du nom d'utilisateur est faite.

En effet, on considère que si la connexion n'est pas anonyme, alors il n'est pas
nécessaire d'authentifier plus encore.

Par défaut, on prend la valeur de `%RC{HOST_BASED_AUTH}{ANON_USER}`, sinon la
valeur de `%RC{HTTP_ANON_USER}`, sinon la valeur `anonhttp`

### anyhost

Ce user est celui qui doit recevoir les autorisation sur les dépôts.

Par défaut, on prend la valeur de `%RC{HOST_BASED_AUTH}{HOST_USER}`, sinon la
valeur `anyhost`.

### option allow-host

Cette option permet de définir une liste d'adresses IP, de classes d'adresses
IP, de noms d'hôtes pleinement qualifiés, de domaines ou de noms d'hôtes pour
lequels la traduction `anonhttp --> anyhost` est effectuée, c'est à dire qui
sont autorisés à accéder au dépôt.

Exemples:
~~~
option allow-host 10.11.12.13 192.168.1.50
option allow-host-1 10.50.60.0/24
option allow-host-2 hostname.domain .domain hostname
~~~
Cet exemple montre qu'il est possible de spécifier plusieurs lignes allow-host
en les suffixant par '-qqchose'. Il est aussi possible de spécifier plusieurs
valeurs dans une même option en les séparant par des espaces.

Les règles de correspondance sont:
* correspondance exacte pour les adresses IP
* correspondance exacte de réseau pour la notation CIDR
* correspondance exacte insensible à la casse pour les domaines

### option match-repo

Cette option permet de faire des correspondance d'hôte sur la base du nom du
dépôt. Tout d'abord, le nom du dépôt est mis en correspondance avec l'expression
régulière de l'option `match-repo`. Si une correspondance est trouvée, alors le
nom d'hôte est construit à partir des groupes de correspondances numériques
trouvés sur le nom du dépôt.

Un exemple sera sans doute plus parlant:
~~~
repo hosts/..*
    RW+ = anyhost
    option match-repo = hosts/([^/]+)/config
    option allow-host = $1.domain
~~~
Dans cet exemple, les dépôts de la forme 'hosts/HOST/config' sont accessibles et
modifiables depuis les hôtes 'HOST.domain'

## Patch de NetAddr::IP pour Debian Jessie

Au 29/12/2016, le bug avec NetAddr::IP existe toujours sur debian jessie et
peut-être corrigé de cette manière (ne pas oublier de corriger les chemins et/ou
les versions des packages):
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