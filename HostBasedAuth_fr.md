[Show english version](HostBasedAuth_en.md)

# Trigger HostBasedAuth

Ce trigger permet d'authentifier sur la base de l'adresse ip ou du nom de l'hôte
qui fait la requête. Il est conçu pour fonctionner avec le mode d'accès http

Le principe est le suivant: pour chaque dépôt concerné:
* il faut autoriser certains utilisateurs (le nom choisi importe peu)
* pour chacun de ces utilisateurs, il faut définir une option pour la liste des
  hôtes ou des adresses IPs à partir desquels ils sont autorisés
* si l'accès est effectué en mode anonyme avec l'utilisateur `anonhttp` depuis
  les hôtes spécifiés, alors l'utilisateur est traduit en fonction des règles
  définies précédemment.

Dans l'exemple suivant:
~~~
repo repo1
    R = reader
    RW = writer
    RW+ = forcer
    option map-anonhttp-1 = reader from 10.11.12.13 10.11.12.14
    option map-anonhttp-2 = writer from HOST.DOMAIN
    option map-anonhttp-3 = forcer from HOSTNAME
~~~
le dépôt est accessible:
* en lecture depuis les adresses 10.11.12.13 et 10.11.12.14
* en écriture depuis toute adresse ip dont la résolution inverse est
  HOST.DOMAIN
* en écriture depuis toute adresse ip dont la résolution inverse est un domaine
  dont le nom de base est HOSTNAME

Bien entendu, il n'est pas obligatoire de définir chacun des types d'accès pour
le dépôt. L'exemple montre simplement qu'il est possible de définir des règles
différentes en fonction de l'hôte qui fait la requête.

Les verbes supportés sont la commande create (pour les dépôts de type wild) et
tous ceux associés aux commandes git (git-upload-pack, git-receive-pack,
git-upload-archive). Voici un exemple complet:

Pour la configuration suivante:
~~~
# gitolite.conf
repo hba/.*
    C = user
    RW+ = user
    option.map-anonhttp = user from myhost
~~~
Les commandes suivantes permettent depuis myhost de créer un dépôt sur le
serveur myrepos, de le cloner puis de faire le commit initial:
~~~
# on myhost
curl -fs http://myrepos/anongit/create?hba/test
git clone http://myrepos/anongit/hba/test
cd test
touch .gitignore
git commit -am "initial"
~~~

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
        RW+ = writer
        option map-anonhttp = writer from myhost.domain
    ~~~

* Une fois que la condition précédente est remplie, tous les dépôts que l'on
  veut autoriser sur la base de l'hôte doivent définir une correspondance
  `map-anonhttp` entre un utilisateur autorisé et les hôtes pour lesquels le
  user `anonhttp` doit être traduit.

### anonhttp

Ce user est celui qui identifie les connexions http anonymes. C'est uniquement
si la connexion est anonyme qu'une traduction du nom d'utilisateur est faite.

En effet, on considère que si la connexion n'est pas anonyme, alors il n'est pas
nécessaire d'authentifier plus encore.

Par défaut, on prend la valeur de `%RC{HTTP_ANON_USER}`, sinon `anonhttp`

### option map-anonhttp

Cette option permet de définir une correspondance entre un nom d'utilisateur et
une liste d'adresses IP, de classes d'adresses IP, de noms d'hôtes pleinement
qualifiés, de domaines ou de noms d'hôtes pour lequels la traduction est
effectuée, c'est à dire qui sont autorisés à accéder au dépôt.

Exemples:
~~~
option map-anonhttp = user from 10.11.12.13 192.168.1.50
option map-anonhttp-1 = user from 10.50.60.0/24
option map-anonhttp-2 = user from hostname.domain .domain hostname
~~~
Cet exemple montre qu'il est possible de spécifier plusieurs fois l'option
`map-anonhttp` en la suffixant par '-qqchose'. Il est aussi possible de
spécifier plusieurs valeurs dans une même option en les séparant par des
espaces.

Les règles de correspondance sont:
* correspondance exacte pour les adresses IP
* correspondance exacte de réseau pour la notation CIDR
* correspondance exacte insensible à la casse pour les domaines

Note: cette implémentation fait suite à une suggestion de Sitaram Chamarty. Il
avait à l'origine proposé comme nom d'option `anonhttp-is` mais j'ai une
préférence pour `map-anonhttp`. Pour lui faire honneur, les deux noms sont
valides.

Note: pour les nom d'hôte et de domaine, les syntaxes `*.domain` et `hostname.*`
sont supportées et sont équivalentes respectivement à `.domain` et `hostname`

### option match-repo

Cette option permet de faire des correspondance d'hôte sur la base du nom du
dépôt. Tout d'abord, le nom du dépôt est mis en correspondance avec l'expression
régulière de l'option `match-repo`. Si une correspondance est trouvée, alors
le nom d'hôte est construit à partir des groupes de correspondances numériques
trouvés sur le nom du dépôt.

Un exemple sera sans doute plus parlant:
~~~
repo hosts/..*
    RW+ = user
    option match-repo = hosts/([^/]+)/config
    option map-anonhttp = user from $1.domain
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