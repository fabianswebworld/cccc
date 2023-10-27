# C-Control Clockwork Commander: Nebenuhrsteuerung mit der Conrad C-Control

Im folgenden stelle ich den Quellcode meiner Nebenuhrsteuerung für die Conrad C-Control I (Classic) kostenlos zur Verfügung. Er läuft natürlich *nur* auf der C-Control I (CCBASIC). Die Funktionsweise des Programms ist ausführlich im Code dokumentiert. 

## Schaltung

Soviel vorab, man kommt leider nicht mit den auf dem "Starterboard" vorhandenen 1xUM-Relais aus, man braucht 2 Stück 2xUM-Relais (sonst gibt's Kurzschlüsse)... Ich habe in meiner Schaltung zwei 5V-Relais auf das Lötfeld des Starterboards gelötet, mit je einer kleinen Transistorschaltung zur Ansteuerung. Diese Schaltung ist unbedingt nötig, denn eine direkte Beschaltung der Ausgangsports des Controllers mit der Relaisspule könnte den Ausgang zerstören, und falls nicht, wird das Relais aufgrund des zu niedrigen Stromes wahrscheinlich nicht richtig schalten.

Die Relais müssen so angeschlossen werden, dass das Relais an port[7] eine positive Spannung von 12-24V (je nach Uhrwerk) schaltet, und das Relais an port[8] die entsprechende negative Spannung. Die Länge des Minutenimpulses beträgt 0,9 Sekunden (Normalbetrieb und Stellbetrieb). Sie kann über die Konstanten "imp_len" und "sh_imp_len" an die eigenen Wünsche angepasst werden. Bei Verwendung des Stelltasters wird der Impuls solange ausgegeben, bis der Taster losgelassen wird.

## Code

Der hier hochgeladene Quellcode liegt in zwei Versionen vor: mit Gong (Version 1.3d) und ohne Gong (Version 1.5d).

Die Version mit Gong erzeugt über einen am BEEP-Port (Pins 1 und 11 an der oberen Steckerleiste des Starterboards) angeschlossenen Piezo-Piepser zu jeder vollen, halben, Viertel- und Dreiviertelstunde einen Big Ben-ähnlichen Gong, der natürlich jeweils eine unterschiedliche Melodiekombination und -länge aufweist. Zu jeder vollen Stunde "schlägt" die Uhr danach eine der aktuellen Stunde entsprechende Anzahl an Schlägen. Über Jumper zwischen Port 9 bzw. Port 10 kann das Schlagwerk konfiguriert werden (Nachtabschaltung, immer aus, immer an). Nähreres dazu steht am Beginn des Quellcodes.

Diese Version des Programms belegt natürlich mehr Platz im seriellen EEPROM der C-Control (ca. 1490 Bytes) als die Version ohne Gong. Wer also das Schlagwerk nicht braucht und auf dem CCCC-Programm aufbauend noch weitere, eigene Ideen realisieren will, die viel Platz benötigen, ist wahrscheinlich mit Version 1.5 (ohne Gong) am besten bedient, in der das Schlagwerk wieder entfernt wurde.

**Wichtig:** Die älteren Versionen 1.0 bis 1.3 (also auch die hier zu findende Version 1.3d mit Gong) empfehle ich **nicht** mehr für den täglichen Einsatz, da diese den Zeigerstand nach jeder Minute abspeichern, was mir im Nachhinein als nicht sonderlich EEPROM-schonend erschien.

**Empfohlen wird also die Version 1.5d ohne Gong.** (Für eine Hauptuhr, die ja räumlich von den Nebenuhren getrennt ist, ist der Sinn einer Soundausgabe ohnehin fraglich.)

## Bedienung

Vor der ersten Inbetriebnahme muss die Uhr manuell auf Zeigerstellung 12 Uhr gebracht werden. Dann muss einfach die Spannung eingeschaltet und sofort der Reset-Taster der C-Control gedrückt werden (noch während der eventuell angeschlossene Beeper piepst). Das stellt sicher, dass die Uhr intern bei 0 startet.

Jetzt einfach warten, bis sich die Uhr auf das DCF-Signal synchronisiert und nach ca. 10 Minuten beginnt, sich auf die aktuelle Uhrzeit einzustellen. Es sind normalerweise keine weiteren Bedienungsschritte nötig. Die Umstellung auf Sommer-/Winterzeit erfolgt automatisch. Es gibt aber die Möglichkeit, bei einem eventuellen Nachgehen der Uhr manuell einzelne Impulse auszugeben. Dazu den an port[16] angeschlossenen Taster betätigen.

- Bei Version 1.3 (mit Gong und minütlicher Speicherung des Zeigerstandes): Nach einem Stromausfall die Uhr **nicht** manuell weiterstellen! Nach ca. 10 Minuten der DCF-Synchronisation stellt das Programm automatisch die Uhr nach.

- Bei Version 1.5 (ohne Gong): Nach Stromausfall geht die Uhr davon aus, **dass sie bei 12:00 steht**, wenn nicht vorher per Druck auf den Stelltaster (port[16]) die Position gesichert wurde (z.B. bei kontrolliertem Trennen der Spannung). Will man verhindern, dass in einem solchen Falle die Uhr beginnt, von der (unbekannten) Position "alias 12:00" aus loszustellen, muss nach der DCF-Synchronisierung, während ein Ton (3 Sekunden) ertönt, der Taster an port[11] gedrückt werden. Es wird dann einfach nicht nachgestellt und die Uhr läuft von der aktuellen Position aus normal los. Zur Bestätigung ertönt kurz ein tiefer Ton.
