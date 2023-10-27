'******************************************************************************

' CCCC  :  C-Control Clockwork Commander 1.3d :  (c) 2007-2010 Fabian Schneider

' DCF77-gesteuerte Ansteuerung einer "Nebenuhr" (Bahnhofsuhr) mit polwendenden
' Minutenimpulsen inklusive Speicherung des letzten Zeigerstandes im EEPROM
' für die automatische Nachführung fehlender Impulse nach einer Spannungs-
' unterbrechung.

' Beim ersten Start oder wenn das EEPROM unsinnige Werte enthält, nimmt das
' Programm den Zeigerstand "Zwölf Uhr" an und stellt, ausgehend von diesem
' Zeigerstand, die Uhr auf die aktuelle DCF77-Zeit.
' Über einen am Port 16 angeschlossenen Taster kann die Uhr minutenweise
' vorgestellt werden, um Differenzen der Zeigerstellung zum gespeicherten
' Zeigerstand zu korrigieren (bei Verwendung des Tasters wird der Wert im
' EEPROM *nicht* verändert).

' Die Relais müssen so angeschlossen werden, dass das Relais an port[7]
' eine positive Spannung von 12-24V (je nach Uhrwerk) schaltet, und das
' Relais an port[8] die entsprechende negative Spannung. Die Länge des
' Minutenimpulses beträgt 0,6 Sekunden im Normalbetrieb und 0,5 Sekunden im
' Stellbetrieb. Bei Verwendung des Stelltasters wird der Impuls solange
' ausgegeben, bis der Taster losgelassen wird.

' Seit Version 1.2 ist zusätzlich die Ausgabe eines "Big Ben"-ähnlichen
' Glockenschlags alle 15 Minuten mit Gongtönen zur vollen Stunde möglich.
' Zur Konfiguration dienen Ports 9 und 10: Sind beide HIGH (offen, kein
' Jumper gesteckt), so ertönt das Schlagwerk nur tagsüber (8 - 22 Uhr).
' Wird Port 9 auf LOW gejumpert, ist das Schlagwerk vollständig deaktiviert.
' Wird Port 10 auf LOW gejumpert, ertönt das Schlagwerk immer (auch nachts).

' Mehr Informationen unter:  www.fabianswebworld.de

'******************************************************************************

' === Variablendefinitionen ===================================================

define currpos word[1]   ' Aktuelle Zeigerposition (0 = 12:00 bis 719 = 11:59)
define savedpos word[2]  ' Zeigerposition im EEPROM (s.o.)
define dcfpos word[3]    ' Zeigerposition von DCF77 (Sollzeit)
define count byte[7]     ' Allgemeine (Zähl-)variable
define schlag byte[8]    ' Zähler für Glockenschläge
define m byte[9]         ' Hilfsvariable
define s byte[10]        ' Hilfsvariable

define polarity bit[81]  ' Polarität des LETZTEN gesendeten Impulses
                         ' (ON = positiv, OFF = negativ)

define imp_done bit[82]  ' Impuls in der 00. Sekunde abgearbeitet?
define set_done bit[83]  ' Zeitkorrektur in der 23. Minute abgearbeitet?

' --- Portdefinitionen --------------------------------------------------------

define imp_pos port[7]   ' Digitalport für den positiven Minutenimpuls
define imp_neg port[8]   ' Digitalport für den negativen Minutenimpuls

define sw1 port[16]      ' Taster zum Vorstellen der Uhr.
define sw2 port[9]       ' Jumper zum vollständigen Abschalten des Schlagwerks
define sw3 port[10]      ' Jumper zum ständigen Aktivieren des Schlagwerks
                         ' (auch nachts)! Ist dieser nicht gesteckt (-> HIGH).
                         ' so ist das Schlagwerk von 22 - 8 Uhr deaktiviert.

define sw4 port[11]      ' Jumper zum Überspringen der DCF-Wartezeit (Debug)

define rel1 port[1]      ' Externes Relais 1 (für zukünftige Zwecke)
define rel2 port[2]      ' Externes Relais 2 (für zukünftige Zwecke)

define modem port[9]     ' Externes Relais (Reserve)
define reserve port[10]  ' Für zukünftige Zwecke (momentan nur Transistorstufe)


' === Hauptprogramm ===========================================================

' Polarität des letzten Impulses sowie der letzten Zeigerstellung vor
' Wiederanlegen der Spannung aus dem EEPROM lesen.

imp_pos = OFF
imp_neg = OFF

rel1 = OFF
rel2 = OFF
modem = OFF
reserve = OFF

open# for read
 input# polarity
 input# savedpos

'DEBUG-Anweisungen (Werte im EEPROM simulieren)
'polarity=ON
'savedpos=700
'hour=11
'minute=59
'second=45
'/DEBUG-Anweisungen

if (savedpos > 719) or (savedpos < 0) then savedpos = 0

' Reset-Routine: Nach Anschließen der Spannung piepst der Beeper für ~2 Sek.
' Wird während dieser Zeit die Spannung wieder entfernt, sind alle Werte
' auf Null und die Uhr geht beim nächsten Start von der Zeigerposition 0 aus.

pause 70
beep 250,0,0

open# for write
 print# 0
 print# 0

pause 85

beep 0,0,0

open# for write
 print# polarity
 print# savedpos

' Ende der Reset-Routine ------------------------------------------------------

' Ersteinmal in den Stromsparmodus schalten, denn wir brauchen keine hohe
' Rechenleistung:

slowmode on

for dcfpos = 0 to 1200               ' Auf DCF77-Empfänger warten (~4 Minuten)
  pause 10
  if not sw1 then gosub short_imp    ' Dabei manuelles Stellen erlauben und...
  if not sw4 then gosub bypass_dcf   ' ...mit Taster an Port 11 alles übergehen
next

#bypass_dcf

dcfpos = 0

' -----------------------------------------------------------------------------
' Wir nehmen an dass die Zeiger da stehen, wo sie vor Unterbrechung der
' Spannung standen. Auf dieser Annahme basiert die ganze Logik. Wenn das
' Uhrwerk zwischendurch anderweitig verstellt wurde, wird sich die Uhr
' letztendlich auf eine falsche Zeit einstellen und annehmen diese sei
' richtig. Wenn sie diesen Zustand eingenommen hat, kann mit dem Taster
' die Position der Zeiger wiederum an den Stand im EEPROM angeglichen werden!
' Also hier die Annahme:

currpos = savedpos

#setclock                ' Loop zum Stellen der Uhr.

' Zeigerposition aus DCF77-Zeit errechnen
gosub getpos

' Wenn Zeigerpositionen stimmen, direkt in den Hauptloop springen.
' Dies ist der Fall wenn setclock mindestens einmal durchlaufen wurde oder
' aber die Zeigerposition zufällig schon stimmt (sehr unwahrscheinlich).
' Falls die Zeigerposition maximal 200 Minuten "vorgeht", wird die Uhr
' nicht gestellt, sondern die entsprechende Anzahl an Minuten gewartet.
' Das spart Strom und Schreibzyklen und schont die Mechanik.

if (currpos > dcfpos) and ((currpos - dcfpos) <= 200) then gosub drink_tea
if (currpos < 60) and (dcfpos > 620) then gosub drink_tea

if (currpos > dcfpos) and ((currpos - dcfpos) > 200) then dcfpos = dcfpos + 720

if currpos = dcfpos then set_done = ON
if currpos = dcfpos then goto clockwork

for currpos = savedpos + 1 to dcfpos
  gosub short_imp
  pause 2
next

currpos = currpos mod 720
dcfpos = dcfpos mod 720

open# for write
 print# polarity
 print# currpos

savedpos = currpos

goto setclock


' Programmschleife (CLOCKWORK) ------------------------------------------------

' ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#clockwork

  m = minute
  s = second

  ' Wenn Minute voll, dann Impuls ausgeben

  if (s >= 0) and (s <= 2) and (not imp_done) then gosub impuls
  if (s > 49) and (s < 55) then imp_done = OFF

  ' Alle 12 Stunden zur 23. Minute schauen wir nach, ob die Zeit noch stimmt
  if ((hour mod 12) = 0) and (m = 23) and (not set_done) then goto setclock
  if ((hour mod 12) = 0) and (m = 22) then set_done = OFF

  ' Wenn Stelltaster gedrueckt, dann Impuls ausgeben
  if not sw1 then gosub man_imp

  ' Noch ein bisschen Strom sparen...
  pause 2

' Schleife wiederholen
goto clockwork

' ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

' === Unterprogramme ==========================================================

' --- impuls ------------------------------------------------------------------
' Stellt die Uhr eine Minute weiter und sichert Zeigerposition im EEPROM
' -----------------------------------------------------------------------------

#impuls

  imp_neg = polarity
  imp_pos = not polarity

  pause 25               ' Länge des Impulses: 0,5 Sekunden

  imp_neg = OFF
  imp_pos = OFF

  ' Polarität für den nächsten Impuls invertieren.

  polarity = not polarity

  ' Zeigerposition um 1 erhöhen. Falls 12:00-Stellung (720) erreicht ist,
  ' wieder auf Null zurücksetzen.

  currpos = (currpos + 1) mod 720

  ' Polarität und Zeigerposition im EEPROM speichern.

  open# for write
   print# polarity
   print# currpos

  savedpos = currpos     ' Damit wir wissen: Der Wert im EEPROM ist aktuell.
  imp_done = ON

  if (not sw2) or (((hour > 21) or (hour < 9)) and (sw3)) then return

  ' Schlagwerk?
  if minute = 0  then gosub st_schlag
  if minute = 15 then gosub vs_schlag
  if minute = 30 then gosub hs_schlag
  if minute = 45 then gosub ds_schlag

return                   'impuls


' --- man_imp -----------------------------------------------------------------
' Stellt die Uhr eine Minute weiter und sichert NICHT die Zeigerposition!
' Die Polarität wird jedoch gespeichert.
' -----------------------------------------------------------------------------

#man_imp

  imp_neg = polarity
  imp_pos = not polarity

  ' Wir halten den Impuls solange, bis die Taste wieder losgelassen wird!
  ' Somit ermöglichen wir dem Benutzer, die Uhr so schnell zu stellen wie
  ' die Trägheit der Mechanik dies ermöglicht:

  wait sw1 ' = off

  imp_neg = OFF
  imp_pos = OFF

  ' Polarität für den nächsten Impuls invertieren.

  polarity = not polarity

  ' Polarität im EEPROM speichern.

  open# for write
  print# polarity

  savedpos = currpos     ' Damit wir wissen: Der Wert im EEPROM ist aktuell.

return                   'man_imp


' --- short_imp ---------------------------------------------------------------
' Gibt einen kürzeren Minutenimpuls aus (0,5 Sekunden) für den Stellbetrieb.
' Es wird nicht die Zeigerposition gespeichert.
' -----------------------------------------------------------------------------

#short_imp

  imp_neg = polarity
  imp_pos = not polarity

  pause 25               ' Länge des Impulses: 0,5 Sekunden

  imp_neg = OFF
  imp_pos = OFF

  ' Polarität für den nächsten Impuls invertieren.

  polarity = not polarity

return                   'short_imp


' --- getpos ------------------------------------------------------------------
' Berechnet aus dem aktuellen Wert der Echtzeituhr (DCF77-Empfänger) die
' Sollposition für das Uhrwerk. Diese wird in dcfpos gespeichert.
' -----------------------------------------------------------------------------

#getpos

  dcfpos = (hour mod 12) * 60 + minute

return                  'getpos


' --- drink_tea ---------------------------------------------------------------
' "Abwarten und Tee trinken": Wir warten einfach ab, bis die Zeigerposition
' wieder stimmt. Anstatt die Uhr z.B. bei der Winterzeitumstellung 11 Stunden
' vorzustellen, warten wir doch lieber 1 Stunde ab.
' -----------------------------------------------------------------------------

#drink_tea

  gosub getpos

  #loop

    if (minute mod 30) = 0 then gosub getpos

    ' Wenn Stelltaster gedrueckt, dann Impuls ausgeben
    if not sw1 then gosub man_imp

    pause 3

    if currpos > dcfpos then goto loop
    if (currpos < 60) and (dcfpos > 620) then goto loop

    imp_done = ON

return                  'drink_tea


' -----------------------------------------------------------------------------
' Ab hier beginnen die Ton- und Melodiedefinitionen für das "Schlagwerk".
' Die Uhr simuliert den Schlag des "Big Ben" und verwendet dafür 4 verschiedene
' Melodievarianten. Diese werden nach folgendem Schema abgespielt:
'
' Variante 1                         = Viertelstunden
' Variante 1 + 2                     = Halbe Stunden,
' Variante 1 + 2 + 3                 = Dreiviertelstunden,
' Variante 1 + 2 + 3 + Stundenschlag = Volle Stunden
' -----------------------------------------------------------------------------


' --- vs_schlag ---------------------------------------------------------------
' Viertelstundenschlag
' -----------------------------------------------------------------------------

#vs_schlag

slowmode off
gosub melody_1
slowmode on

return                  'vs_schlag


' --- hs_schlag ---------------------------------------------------------------
' Halbstundenschlag
' -----------------------------------------------------------------------------

#hs_schlag

slowmode off
gosub melody_1
gosub melody_2
slowmode on

return                  'hs_schlag


' --- ds_schlag ---------------------------------------------------------------
' Dreiviertelstundenschlag
' -----------------------------------------------------------------------------

#ds_schlag

slowmode off
gosub melody_1
gosub melody_2
gosub melody_3
slowmode on

return                  'ds_schlag


' --- st_schlag ---------------------------------------------------------------
' Stundenschlag
' -----------------------------------------------------------------------------

#st_schlag

slowmode off
gosub melody_1
gosub melody_2
gosub melody_3

for schlag = 1 to (((hour + 11) mod 12) + 1)
  gosub gong
  pause 50
next
slowmode on

return                  'st_schlag


' --- melody_1 ----------------------------------------------------------------
' Ausgabe der "Big Ben"-Melodie am BEEP-Port, Variante 1
' -----------------------------------------------------------------------------

#melody_1

beep 319,2,0
beep 253,27,10

beep 402,2,0
beep 319,27,10

beep 358,2,0
beep 284,27,10

beep 536,2,0
beep 426,32,12
pause 37

return                  'melody_1


' --- melody_2 ----------------------------------------------------------------
' Ausgabe der "Big Ben"-Melodie am BEEP-Port, Variante 2
' -----------------------------------------------------------------------------

#melody_2

beep 536,2,0
beep 426,25,12

beep 358,2,0
beep 284,25,12

beep 319,2,0
beep 253,25,12

beep 402,2,0
beep 319,32,12
pause 37

return                  'melody_2


' --- melody_3 ----------------------------------------------------------------
' Ausgabe der "Big Ben"-Melodie am BEEP-Port, Variante 3
' -----------------------------------------------------------------------------

#melody_3

beep 319,2,0
beep 253,25,12

beep 358,2,0
beep 284,25,12

beep 402,2,0
beep 319,25,12

beep 536,2,0
beep 426,32,12
pause 37

return                  'melody_3


' --- gong -------------------------------------------------------------------
' Ausgabe eines sonoren "Glockenschlages" (Stundenschlag) am BEEP-Port
' -----------------------------------------------------------------------------

#gong

beep 2146,2,0
beep 1073,2,0
beep 716,2,0
beep 568,2,0
beep 478,2,0
for count = 1 to 9
  beep 426,2,0
  beep 1072,3,0
next

return                  'gong
