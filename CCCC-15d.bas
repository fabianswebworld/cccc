'******************************************************************************

' CCCC  :  C-Control Clockwork Commander 1.5d :  (c) 2007-2010 Fabian Schneider

' DCF77-gesteuerte Ansteuerung einer "Nebenuhr" (Bahnhofsuhr) mit polwendenden
' Minutenimpulsen inklusive Speicherung des letzten Zeigerstandes im EEPROM
' für die automatische Nachführung fehlender Impulse nach einer Spannungs-
' unterbrechung.

' ACHTUNG: Seit CCCC Version 1.4 wird die Position der Uhr nur noch bei Druck
' auf den Debug-Taster bzw. Jumper an Port 11 im EEPROM gespeichert, da das
' EEPROM laut Datenblatt nur 100000 Schreibzyklen hat!

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
' Minutenimpulses beträgt 0,9 Sekunden (Normalbetrieb und Stellbetrieb).
' Sie kann über die Konstanten "imp_len" und "sh_imp_len" an die
' eigenen Wünsche angepasst werden. Bei Verwendung des Stelltasters wird
' der Impuls solange ausgegeben, bis der Taster losgelassen wird.

' Das Schlagwerk wurde in Version 1.4 wieder entfernt, um Platz für zukünftige
' Entwicklungen zu schaffen. Durch den räumlichen Versatz von Uhr(en) und
' C-Control ist der Sinn einer Soundausgabe ohnehin fraglich.

' Mehr Informationen unter:  www.fabianswebworld.de

'******************************************************************************


' === Konstantendefinitionen ==================================================

define imp_len 45        ' Länge des Minutenimpulses im Normalbetrieb (x*20ms)
define sh_imp_len 45     ' Länge des Minutenimpulses im Stellbetrieb (x*20ms)

' === Variablendefinitionen ===================================================

define currpos word[1]   ' Aktuelle Zeigerposition (0 = 12:00 bis 719 = 11:59)
define savedpos word[2]  ' Zeigerposition im EEPROM (s.o.)
define dcfpos word[3]    ' Zeigerposition von DCF77 (Sollzeit)
define count word[4]     ' Allgemeine (Zähl-)variable (momentan unbenutzt)

define m byte[9]         ' Hilfsvariable
define s byte[10]        ' Hilfsvariable

define polarity bit[81]  ' Polarität des LETZTEN gesendeten Impulses
                         ' (ON = positiv, OFF = negativ)

define imp_done bit[82]  ' Impuls in der 00. Sekunde abgearbeitet?
define set_done bit[83]  ' Zeitkorrektur in der 23. Minute abgearbeitet?
define no_dcf bit[84]    ' DCF-Signal (vorübergehend) ignorieren?

' --- Portdefinitionen --------------------------------------------------------

define imp_pos port[7]   ' Digitalport für den positiven Minutenimpuls
define imp_neg port[8]   ' Digitalport für den negativen Minutenimpuls

define sw1 port[16]      ' Taster zum Vorstellen der Uhr.

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

for dcfpos = 0 to 4800               ' Auf DCF77 warten (max. ~16 Minuten)
  pause 10
  if not sw1 then gosub short_imp    ' Dabei manuelles Stellen erlauben

  if (not sw4) or (dcfstatus and 16) then goto dcf_ok

  ' Wird ein gültiges Signal erkannt (Bit 4 von ccstatus ist HIGH), so wird
  ' die Schleife ebenfalls verlassen (dies ist eigentlich der Normalfall).
  ' Alternativ kann der Empfangsversuch manuell mit dem Debug-Taster (Port 11)
  ' abgebrochen werden. Nach ~16 Minuten wird automatisch abgebrochen und die
  ' Uhr läuft los, von wo immer sie stand.

next

no_dcf = ON

#dcf_ok
slowmode off
beep 300,130,0                        ' Langer, hoher Ton: DCF wurde empfangen!
if not sw4 then no_dcf = ON           ' Wird SW4 gehalten: DCF ignorieren
if not sw4 then beep 600,30,0         ' Zur Bestätigung: Kurzer, tiefer Ton.
slowmode on

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
if no_dcf then currpos = dcfpos
if no_dcf then savedpos = dcfpos

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

  ' Wenn Debug-Taster gedrueckt, dann Position im EEPROM speichern
  if not sw4 then gosub savepos

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

  pause imp_len          ' Länge des Impulses

  imp_neg = OFF
  imp_pos = OFF

  ' Polarität für den nächsten Impuls invertieren.

  polarity = not polarity

  ' Zeigerposition um 1 erhöhen. Falls 12:00-Stellung (720) erreicht ist,
  ' wieder auf Null zurücksetzen.

  currpos = (currpos + 1) mod 720

  savedpos = currpos     ' Damit wir wissen: Der Wert im EEPROM ist aktuell.
  imp_done = ON

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

return                   'man_imp


' --- short_imp ---------------------------------------------------------------
' Gibt einen kürzeren Minutenimpuls aus für den Stellbetrieb.
' Es wird nicht die Zeigerposition gespeichert.
' -----------------------------------------------------------------------------

#short_imp

  imp_neg = polarity
  imp_pos = not polarity

  pause sh_imp_len       ' Länge des Impulses

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


' --- savepos -----------------------------------------------------------------
' Speichert die aktuelle Zeigerposition im EEPROM (nur noch bei Bedarf, wegen
' begrenzter Anzahl Schreibzyklen!)
' -----------------------------------------------------------------------------

#savepos

  open# for write
   print# polarity
   print# currpos

  wait sw4 ' = high

  slowmode off
  beep 250,2,0
  slowmode on

  savedpos = currpos

return                  'savepos


' --- dcfstatus ---------------------------------------------------------------
' Nutzt einen Bug des Betriebssystems (mittels einer "table" können beliebige
' Adressen im RAM über CCBASIC abgefragt werden), um herauszubekommen, ob das
' DCF-Zeitsignal mindestens einmal komplett empfangen wurde.
' -----------------------------------------------------------------------------

#dcfstatus
  table ccstatus
    2938
  tabend
return                  'dcfstatus
