## Version 0.4.2 du 07/03/2018-11:11

* `5621560` maj doc
* `efa7e09` maj doc

## Version 0.4.1 du 05/05/2017-12:49

* `ced726d` déplacer les fichiers dans localcode/ pour simplifier la maintenance
* `284ac94` maj doc: définir QRE dans SAFE_CONFIG

## Version 0.4.0 du 04/05/2017-18:06

* `31bed15` désactiver le mode debug
* `85c5365` maj doc pour la nouvelle commande info
* `eb35a61` bug
* `2e968a1` support des reverse-proxy
* `ea74489` renommer hbainfo en info et rajouter l'option -legacy pour retrouver le comportement original
* `720a972` refactoriser le code pour implémenter hbainfo

## Version 0.3.1 du 26/04/2017-15:20

* `1ac50d9` maj doc: HTTP_ANON_USER est requis
* `8d50ec3` patch refuse de patcher avec le chemin fourni. se placer manuellement dans le chemin d'abord
* `05a475d` corrections mineures de la doc

## Version 0.3.0 du 25/04/2017-22:00

* `3afa0ee` réorganiser la doc
* `63b5d36` Intégration de la branche map-regexes
  * `1a8ec15` support regexes dans l'option map-anonhttp
  * `6c483c0` maj doc

## Version 0.2.2 du 24/03/2017-14:36

* `6cbba19` maj doc sur l'utilisation des regex avec match-repo
* `34035d5` quelques corrections sur la doc

## Version 0.2.1 du 17/02/2017-00:12

* `c03114e` Maj de la doc: clarifier le fait que le changement d'utilisateur peut induire une perte de droits effectifs

## Version 0.2.0 du 16/02/2017-20:27

* `4ee94fc` Intégration de la branche stephencmorton-master
  * `50d0fe0` quick fixes
  * `e2de6ce` Merge branch 'master' of https://github.com/stephencmorton/gitolite-contrib into stephencmorton-master
  * `84fc8fe` Update `HostBasedAuth_en.md`
  * `7060fbf` Quick grammar changes to `HostBasedAuth_en.md`

## Version 0.1.2 du 12/02/2017-11:48

* `ec93579` bug avec install --help

## Version 0.1.1 du 12/02/2017-11:40

* `1f1af8d` désactiver la trace pour la production

## Version 0.1.0 du 12/02/2017-11:34

* `2b5530b` Intégration de la branche sitaramc-design
* `80bd8ab` support des syntaxes `*.domain` et `hostname.*`
* `5077158` support de la commande create
* `b63207c` support de l'installation dans un dépôt gitolite-admin
* `45c7e82` ajout d'une liste de tâches
* `7355e86` maj de la documentation anglaise. petites corrections dans la doc française
* `e31ab7f` documentation en français du nouveau design
* `9ea8956` implémentation initiale du design de sitaramc
