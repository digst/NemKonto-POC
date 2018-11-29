# NemKonto-POC

Projektet indeholder to hovedsektioner:

Containers/          Docker containere
projects/            Java kode

samt denne fil README.md

### Containers/

Hver af de tre contaioners indeholder følgende shell scripts til at bygge og styre containeren:

* build-*           Bygger containeren
* run-*             Kører containeren og eksponerer relevante porte
* stop-*            Standser containeren og implicit fjerner den (pga. anvendt --rm under run)
* attach-*          Åbner en bash shell til den kørende container

I tillæg er der en Dockerfile-* (suffixet med containerens navn)

* appserver-ui        CentOS7-drevet Apache webserver + deployet POC UI
* appserver-ws        CentOS7-drevet Axis2 standalone server + deployet POC REST services
* mapr-db             MapR database, dev instans fra leverandør

Opstart af containers:

* Docker installation skal konfigureres til at give hver container mindst 8gb ram af hensyn til MapR. Dette gøres under "Preferences" -> "Advanced" i Docker-indstillingerne.
* Run-script for hver af de tre containers. Rækkefølgende er ligegyldig, men MapR-containeren tager 1-2 min om at starte, så setuppet kan ikke afprøves inden denne er klar.

* UI er eksponeret på http://localhost
* WS er eksponeret på http://localhost:7575
* MapR tables er eksponeret på web http://localhost:7221 og selve serveren på TCP localhost:7222

### projects/

Der skal være installeret Java 1.8+ på maskinen, koden skal bygges på. I tillæg skal der være Maven.

Java-projektet under projects/DevEnvDemo/DevEnvV1/ kan bygges med:

_mvn compile axis2-aar:aar_

I target/ lander den byggede .aar-fil. Denne kan kopieres ind i _/usr/axis2-1.7.8/repository/services/_ for manuelt at deploye applikationen.
