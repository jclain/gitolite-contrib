# gitolite-hba (host based authentication)

Ce dépôt contient une implémentation d'autorisation basée sur le nom de l'hôte
qui fait la requête.

La documentation complète des fonctionnalités à implémenter est toujours en
cours de rédaction.

ça ne fonctionne probablement qu'avec l'accès par http, puisque l'accès par ssh
est forcément par clé. rappel: il faut ajouter l'accès par le daemon git si on
veut accéder aux dépôts par http
~~~
repo gitolite-admin
    - = daemon
    option deny-rules = 1
repo @all
    R = daemon
~~~

## en vrac

voici quelques idées en vrac pour l'implémentation:

* pour la sécurité, il faudrait identifier explicitement les dépôts qui
  autorisent l'authentification basé sur le nom d'hôte, e.g

    ~~~
    repo myrepo
         option allow-host-based-auth = 1
    ~~~

* il faut installer un trigger qui remplace l'utilisateur "anonyme" (et
  seulement celui-là) par l'utilisateur anyone@HOSTNAME. Par exemple, si on push
  depuis l'hôte 'myhost.tld' et que `REPLACE_WITH` vaut 'anyone@HOSTNAME', alors
  l'utilisateur courant devient 'anyone@myhost'

* dans la configuration gitolite.rc, il faudra spécifier le nom de l'utilisateur
  anonyme

    ~~~
    HOST_BASED_AUTH => {
        ANON_USER => 'anonhttp',
        REPLACE_WITH => 'anyone@HOST', # ou 'anyone@HOSTNAME' ou 'anyone@IP'
    }
    ~~~

  La valeur par défaut de `ANON_USER` est la valeur de `HTTP_ANON_USER`. Est-il
  nécessaire de faire une configuration à part? oui si on veut supporter
  d'autres modes d'authentification

* autre idée: on remplace toujours par une valeur fixe 'anonhost'. ce sont les
  options qui déterminent depuis quel hôte on fait le remplacement:

    ~~~
    repo myrepo
        RW+ = anonhost
        option allow-from = host.tld
        option allow-from = hostname
        option allow-from = ip
    ~~~

  Je préfère de beaucoup cette idée et elle me semble plus flexible!!!

  Du coup, la configuration serait plus simple:

    ~~~
    HOST_BASED_AUTH => {
        ANON_USER => 'anonhttp',
        HOST_USER => 'anonhost',
    }
    ~~~

  Avec par défaut `ANON_USER` == `HTTP_ANON_USER` et `HOST_USER` == 'anonhost'

  Autre possibilité encore: dans gitolite.rc, configurer quels hôtes doivent
  être traduits vers quels users... mais je ne suis pas sûr que ce soit très
  pratique... e.g

    ~~~
    HOST_BASED_AUTH => {
        ANON_USER => 'anonhttp',
        HOST_USER_MAP => [
            'host1.tld user1',   # nom d'hôte complet
            'hostname2 user2',   # nom d'hôte
            '10.0.0.0/24 user3', # CIDR
            '*.tld user4',       # wildcard match sur host
            '10.* user5',        # wildcard match sur IPs
            '* anonhost',        # fallback
        ],
    }
    ~~~
  

-*- coding: utf-8 mode: markdown -*- vim:sw=4:sts=4:et:ai:si:sta:fenc=utf-8:noeol:binary